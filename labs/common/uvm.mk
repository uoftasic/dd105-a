# DD105-A: the shared UVM build. Every lab's Makefile names its sources and
# includes this file:
#
#     TOP      := router_tb_top
#     DUT_SRCS := rtl/router.sv
#     TB_SRCS  := tb/router_if.sv tb/router_env_pkg.sv tb/router_tb_top.sv
#     TESTS    := router_smoke_test router_rand_test
#     include ../common/uvm.mk
#
# One build serves every test in the lab. The test, its knobs, the seed and the
# planted bug are all chosen when you run, so changing them never rebuilds:
#
#     make                                   build if needed, run the first test
#     make run UVM_TESTNAME=x SEED=3 PLUSARGS=+N=500
#     make run BUG=B03                       the same, with planted bug B03 on
#
# `make help` lists every target and variable; labs/common/README.md has the
# full table. Paths are worked out from this file's location, so it runs from
# a lab folder in the workspace clone (/foss/designs/...) and in a bare
# container alike, with make and the course image and nothing else.

SHELL := /bin/bash
.DEFAULT_GOAL := all

UVM_MK       := $(abspath $(lastword $(MAKEFILE_LIST)))
COMMON       := $(patsubst %/,%,$(dir $(UVM_MK)))
REPO_ROOT    := $(abspath $(COMMON)/../..)
LAB_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))
LAB_DIR      := $(patsubst %/,%,$(dir $(LAB_MAKEFILE)))

# ── what the lab's Makefile sets ─────────────────────────────────────────────
# DUT_F names Verilator file lists (passed with -F, so their paths are relative
# to the list), for example the faulty router's build/rtl/router.f. BUILD_DEPS
# are extra prerequisites of the build, such as the rule that writes that list.
TOP           ?=
DUT_F         ?=
BUILD_DEPS    ?=
DUT_SRCS      ?=
TB_SRCS       ?=
INCDIRS       ?=
VLT           ?=
VFLAGS        ?=
TESTS         ?=
BUG_LIST      ?=
BUG_CATALOGUE ?=
HUNT_POOL     ?= $(BUG_LIST)
# If the design prints a line when a bug is on, BUG_CONFIRM is that line with
# {id} for the bug, and the graders then refuse a bug run without it. Off by
# default: the router prints nothing unless the run has +BUG_ECHO.
BUG_CONFIRM   ?=

# ── what you set when you run ────────────────────────────────────────────────
UVM_TESTNAME ?= $(firstword $(TESTS))
SEED         ?= 1
BUG          ?=
PLUSARGS     ?=
VERBOSITY    ?=
NSEEDS       ?= 10
SEEDS        ?= $(shell seq 1 $(NSEEDS))
RUN_TIMEOUT  ?= 300
VERBOSE      ?=

# ── how the build is done ────────────────────────────────────────────────────
JOBS      ?= 2
# Verilator 5.050 concatenates its C++ into as many files as there are jobs.
# With -j 2 that makes two files so big that g++ needs 2.6 GB for one at -Os,
# and two at once swap in a 3 GB container: a 526 s cold build. Eight groups
# and -O0 measured 103 s, and the simulator runs about 1.4 times slower
# (2,000 ALU items: 1.68 s against 1.19 s). OPT_FAST=-Os for long regressions.
OUTPUT_GROUPS ?= 8
OPT_FAST  ?= -O0
COVERAGE  ?= 1
TRACE     ?= 1
TRACE_PKGS ?= 0
BUILD_DIR ?= $(LAB_DIR)/build
PYTHON    ?= python3
VERILATOR ?= verilator
UVM_HOME  ?= $(REPO_ROOT)/third_party/uvm/src
DD105_UVM := $(COMMON)/uvm

OBJ_DIR   := $(BUILD_DIR)/obj
SIM       := $(BUILD_DIR)/sim
# Verilator's folder of generated C++ is about 900 MB, two thirds of it
# precompiled headers. A rebuild recompiles through ccache whether it is
# there or not, so by default only the simulator is kept. SLIM=0 keeps it.
SLIM      ?= 1
BUILD_LOG := $(BUILD_DIR)/build.log
STAMP     := $(BUILD_DIR)/build.flags

ifeq ($(SEED),random)
  override SEED := $(shell echo $$((RANDOM * 32768 + RANDOM + 1)))
endif

# Without a solver, every constrained randomize() returns 0 and the run still
# passes. Every run gets this in its environment. The build bakes it into the
# simulator too, as the default for a run started by hand, but not the way
# Verilator 5.050 does it: from VERILATOR_SOLVER it writes the default as
# "yices-smt2\ --incremental", which no shell can run. So the build runs
# Verilator without the variable and passes the define itself (VL_SOLVER).
VERILATOR_SOLVER := yices-smt2 --incremental
export VERILATOR_SOLVER

# ccache lives at the top of the course clone, which is in your workspace
# (/foss/designs), so it survives a container restart. Without it every new
# container pays the full cold build.
CCACHE_DIR     := $(REPO_ROOT)/.ccache
CCACHE_MAXSIZE := 2G
export CCACHE_DIR CCACHE_MAXSIZE

# ── the Verilator command line ───────────────────────────────────────────────
# Verilator runs in the top of the course clone and every file is named from
# there (third_party/uvm/src/..., labs/<lab>/tb/...). The file names end up in
# the generated C++, so this keeps the UVM part of it identical in every lab
# and wherever the clone is mounted, and ccache can reuse it.
abs       = $(foreach f,$(1),$(if $(filter /%,$(f)),$(f),$(LAB_DIR)/$(f)))
fromroot  = $(if $(strip $(1)),$(shell realpath -m --relative-to=$(REPO_ROOT) $(call abs,$(1))))
UVM_REL   := $(call fromroot,$(UVM_HOME))
DD105_REL := $(call fromroot,$(DD105_UVM))

# The UVM field macros expand to code with ~200 width warnings, and Verilator
# stops on any warning. These five are off in the build; `make lint` shows them.
VL_WNO := -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-SYMRSVDWORD -Wno-CASTCONST \
          -Wno-IMPLICITSTATIC

# Waves: the image's Verilator can't build --trace-fst (its FST writer needs
# lz4.h, which the image doesn't ship), so the simulator writes VCD and
# `make waves` converts it to FST with vcd2fst, from GTKWave.
# dd105_trace.vlt leaves every package out of the waves (TRACE_PKGS=1 puts
# them back): the UVM library's statics, and the variable that says which bug
# is on.
VL_OPTS := $(if $(filter 1,$(COVERAGE)),--coverage-user) \
           $(if $(filter 1,$(TRACE)),--trace-vcd $(if $(filter 1,$(TRACE_PKGS)),,$(DD105_REL)/dd105_trace.vlt))

VL_SRCS := +define+DD105_TOP=$(TOP) \
           +incdir+$(UVM_REL) $(UVM_REL)/uvm_pkg.sv \
           +incdir+$(DD105_REL) $(DD105_REL)/dd105_pkg.sv $(DD105_REL)/dd105_waves.sv \
           $(addprefix +incdir+,$(call fromroot,$(INCDIRS))) $(call fromroot,$(VLT)) \
           $(addprefix -F ,$(call fromroot,$(DUT_F))) \
           $(call fromroot,$(DUT_SRCS)) $(call fromroot,$(TB_SRCS)) $(VFLAGS)

VL_SOLVER := -CFLAGS "-DVM_SOLVER_DEFAULT='\"$(VERILATOR_SOLVER)\"'"

VL_BUILD := --binary --timing --vpi --prefix Vtb --top-module $(TOP) \
            --Mdir $(OBJ_DIR) -o sim $(VL_OPTS) $(VL_WNO) $(VL_SOLVER) \
            --output-groups $(OUTPUT_GROUPS) $(if $(OPT_FAST),-MAKEFLAGS OPT_FAST=$(OPT_FAST)) \
            $(UVM_REL)/dpi/uvm_dpi.cc $(VL_SRCS)

VL_LINT  := --lint-only --timing --vpi --top-module $(TOP) -Wno-fatal \
            $(LINT_FLAGS) $(VL_OPTS) $(VL_SRCS)

# The simulator is rebuilt when a source in a lab source folder changes, or
# when anything on the command line above changes (build.flags).
SRC_DIRS := $(sort $(dir $(call abs,$(DUT_F) $(DUT_SRCS) $(TB_SRCS) $(VLT))) \
            $(addsuffix /,$(call abs,$(INCDIRS))) $(DD105_UVM)/)
SRC_DEPS := $(sort $(call abs,$(DUT_SRCS) $(TB_SRCS) $(VLT)) \
            $(wildcard $(foreach d,$(SRC_DIRS),$(d)*.sv $(d)*.svh $(d)*.v $(d)*.vh $(d)*.vlt $(d)*.f)))

# ── how a test is run ────────────────────────────────────────────────────────
RUN_NAME ?= $(UVM_TESTNAME)-s$(SEED)$(if $(BUG),-$(BUG))
RUN_DIR  ?= $(BUILD_DIR)/runs/$(RUN_NAME)
RUN_ARGS  = +UVM_TESTNAME=$(UVM_TESTNAME) +verilator+seed+$(SEED) \
            $(if $(BUG),+BUG=$(BUG)) $(if $(VERBOSITY),+UVM_VERBOSITY=$(VERBOSITY)) \
            $(if $(filter 1,$(COVERAGE)),+verilator+coverage+file+coverage.dat) \
            $(PLUSARGS)

# $(call run_sim,<run dir>,<extra plusargs>,<quiet>) runs the simulator once in
# its own folder and leaves run.log, exit_status, seconds and cmd there. This
# is the only place a simulation is started; the graders call it through
# `make _run`. A run longer than RUN_TIMEOUT seconds is stopped (exit 124).
define run_sim
mkdir -p $(1) && cd $(1) && rm -f run.log exit_status seconds cmd coverage.dat waves.vcd waves.fst && \
printf '%s\n' '$(SIM) $(strip $(RUN_ARGS) $(2))' > cmd && \
t0=$$(date +%s.%N); \
timeout -k 5 $(RUN_TIMEOUT) stdbuf -oL -eL $(SIM) $(RUN_ARGS) $(2) 2>&1 | $(if $(3),cat > run.log,tee run.log); \
rc=$${PIPESTATUS[0]}; t1=$$(date +%s.%N); echo $$rc > exit_status; \
awk "BEGIN{printf \"%.2f\n\", $$t1 - $$t0}" > seconds
endef

RUN_DEPS := $(if $(NOBUILD),,$(SIM))
RULE     := ========================================================================
comma    := ,
GRADER    = --makefile $(LAB_MAKEFILE) --build-dir $(BUILD_DIR) \
            --test "$(UVM_TESTNAME)" --seed "$(SEED)" --plusargs "$(PLUSARGS)" \
            --bugs "$(BUG_LIST)" --catalogue "$(BUG_CATALOGUE)" --pool "$(HUNT_POOL)" \
            --tb-srcs "$(call abs,$(TB_SRCS))" --timeout $(RUN_TIMEOUT) \
            --bug-confirm "$(BUG_CONFIRM)" --uvm-home $(UVM_HOME) $(if $(VERBOSE),--verbose)
VERDICT   = $(PYTHON) $(COMMON)/verdict.py $(RUN_DIR) --uvm-home $(UVM_HOME) \
            --bug-confirm "$(BUG_CONFIRM)" $(if $(BUG),--bug $(BUG))
SAYFAIL   = { echo ""; echo "  The verdict above is FAIL, so this target exits non-zero and make"; \
              echo "  prints an error line under this one. That is the verdict talking,"; \
              echo "  not a broken Makefile."; exit 1; }

.PHONY: all build run waves tests regress seeds cov lint check check-all new hunt \
        verdict reveal clean clean-cache cache help solver-check _run FORCE

## all — build if needed, then run UVM_TESTNAME (what plain `make` does)
all: run

## build — build the simulator, if a source or a build flag changed
build: $(SIM)
	@echo " $(SIM) is up to date."

$(SIM): $(STAMP) $(BUILD_DEPS) $(SRC_DEPS) | solver-check
	@if [ -z "$(strip $(TOP))" ]; then echo "uvm.mk: the lab's Makefile must set TOP (the top module)."; exit 1; fi
	@echo "$(RULE)"
	@echo " BUILD  $(TOP)   ($(JOBS) jobs; ccache: $(CCACHE_DIR))"
	@echo " A cold build takes 5 to 6 minutes on 2 CPUs; a rebuild with a warm"
	@echo " ccache takes from 10 s to about 2 minutes. Full log: $(BUILD_LOG)"
	@echo "$(RULE)"
	@mkdir -p $(BUILD_DIR) $(CCACHE_DIR)
	@rm -f $(SIM) $(OBJ_DIR)/sim; t0=$$(date +%s); \
	( cd $(REPO_ROOT) && MAKEFLAGS= MAKELEVEL= env -u VERILATOR_SOLVER $(VERILATOR) -j $(JOBS) $(VL_BUILD) ) 2>&1 \
	  | tee $(BUILD_LOG) \
	  | sed -u -n -E -e '/^%(Error|Warning)/p' -e '/: (fatal )?error: /p' \
	        -e 's/^(ccache )?g\+\+ .* -c -o ([^ ]+\.o) .*$$/    compiling \2/p' \
	        -e 's/^(ccache )?g\+\+ .* -o sim( .*)?$$/    linking sim/p' -e '/^- V/p'; \
	rc=$${PIPESTATUS[0]}; t1=$$(date +%s); echo $$((t1 - t0)) > $(BUILD_DIR)/build.seconds; \
	if [ $$rc -ne 0 ] || [ ! -x $(OBJ_DIR)/sim ]; then \
	  echo "$(RULE)"; echo " BUILD FAILED after $$((t1 - t0)) s. The last 30 lines of $(BUILD_LOG):"; \
	  echo "$(RULE)"; tail -n 30 $(BUILD_LOG); rm -f $(SIM) $(OBJ_DIR)/sim; exit 1; fi; \
	ln -f $(OBJ_DIR)/sim $(SIM) 2>/dev/null || cp -p $(OBJ_DIR)/sim $(SIM); \
	obj=$$(du -sh $(OBJ_DIR) | cut -f1); \
	if [ "$(SLIM)" = 1 ]; then rm -rf $(OBJ_DIR); fi; \
	echo "$(RULE)"; \
	echo " built $(SIM) in $$((t1 - t0)) s ($$(du -h $(SIM) | cut -f1);" \
	     "$(if $(filter 1,$(SLIM)),the $$obj of generated C++ was deleted$(comma) SLIM=0 keeps it,$$obj in $(OBJ_DIR)))"; \
	echo " ccache: $$(ccache -s 2>/dev/null | grep -m2 -E '^ *(Hits|Misses):' | tr -s ' ' | paste -sd ' ')"; \
	echo "$(RULE)"

$(STAMP): FORCE
	@mkdir -p $(BUILD_DIR)
	@printf '%s\n' '$(subst ','\'',$(strip verilator=$(shell $(VERILATOR) --version 2>/dev/null) solver=$(VERILATOR_SOLVER) $(VL_BUILD)))' > $@.new; \
	if cmp -s $@.new $@; then rm -f $@.new; else mv -f $@.new $@; fi

solver-check:
	@if [ -z "$(strip $(VERILATOR_SOLVER))" ]; then \
	  echo "$(RULE)"; echo " VERILATOR_SOLVER is empty."; echo "$(RULE)"; \
	  echo " Without a solver every constrained randomize() returns 0, nothing is"; \
	  echo " randomized, and the run still passes. Leave VERILATOR_SOLVER alone; this"; \
	  echo " makefile sets it to \"yices-smt2 --incremental\"."; exit 1; fi
	@if ! command -v $(firstword $(VERILATOR_SOLVER)) > /dev/null 2>&1; then \
	  echo "$(RULE)"; echo " VERILATOR_SOLVER is \"$(VERILATOR_SOLVER)\", and $(firstword $(VERILATOR_SOLVER)) is not on PATH."; \
	  echo "$(RULE)"; echo " Without a solver every constrained randomize() returns 0, nothing is"; \
	  echo " randomized, and the run still passes. Are you in the course image?"; exit 1; fi

## run — run one test: UVM_TESTNAME, SEED, BUG and PLUSARGS pick what runs
run: $(RUN_DEPS) | solver-check
	@$(call run_sim,$(RUN_DIR),,)
	@$(VERDICT)

# the graders' entry point: one quiet run into RUN_DIR, no verdict printed
_run: $(RUN_DEPS) | solver-check
	@$(call run_sim,$(RUN_DIR),$(EXTRA_PLUSARGS),quiet)

## waves — the same run as `make run`, writing waves.fst into the run folder
waves: $(RUN_DEPS) | solver-check
	@if [ "$(TRACE)" != 1 ]; then echo "This build has no tracing (TRACE=$(TRACE)). Build with TRACE=1."; exit 1; fi
	@$(call run_sim,$(RUN_DIR),+WAVES=waves.vcd,)
	@$(VERDICT) || true
	@cd $(RUN_DIR) && vcd2fst waves.vcd waves.fst > /dev/null && rm -f waves.vcd
	@echo " waves: $(RUN_DIR)/waves.fst ($$(du -h $(RUN_DIR)/waves.fst | cut -f1))"
	@echo " open them with:  surfer $(RUN_DIR)/waves.fst   (or gtkwave)"

## tests — the tests this lab lists in TESTS
tests:
	@echo "Tests in this lab (TESTS in $(LAB_MAKEFILE)):"
	@for t in $(TESTS); do echo "  $$t"; done
	@echo "Run one with:  make run UVM_TESTNAME=<test>"

## regress — every test in TESTS on every seed in SEEDS, then the coverage
regress: $(SIM) | solver-check
	@$(PYTHON) $(COMMON)/regress.py $(GRADER) --tests "$(TESTS)" --seeds "$(SEEDS)"

## seeds — UVM_TESTNAME on every seed in SEEDS (NSEEDS=10: seeds 1 to 10)
seeds: $(SIM) | solver-check
	@$(PYTHON) $(COMMON)/regress.py $(GRADER) --tests "$(UVM_TESTNAME)" --seeds "$(SEEDS)"

## cov — merge coverage.dat from every run in build/runs and report it
cov:
	@$(PYTHON) $(COMMON)/covreport.py $(BUILD_DIR)/runs --out $(BUILD_DIR)/coverage

## lint — Verilator's front end with the warnings the build hides shown (seconds)
lint: | solver-check
	@echo "$(RULE)"
	@echo " LINT  $(TOP): the build's sources and flags, without $(VL_WNO)"
	@echo "$(RULE)"
	@mkdir -p $(BUILD_DIR)
	@( cd $(REPO_ROOT) && $(VERILATOR) $(VL_LINT) ) > $(BUILD_DIR)/lint.log 2>&1; rc=$$?; \
	cat $(BUILD_DIR)/lint.log; echo "$(RULE)"; \
	n=$$(grep -c '^%Warning' $(BUILD_DIR)/lint.log); echo " $$n warnings, by kind:"; \
	grep -oE '^%Warning-[A-Z0-9_]+' $(BUILD_DIR)/lint.log | sed 's/%Warning-//' | sort | uniq -c | sort -rn; \
	echo "$(RULE)"; cd $(LAB_DIR) && $(PYTHON) $(COMMON)/drivecheck.py $(TB_SRCS); \
	echo "$(RULE)"; exit $$rc

## check — the verdict: your test passes the golden design and fails on BUG
check: | solver-check
	@$(PYTHON) $(COMMON)/check.py $(GRADER) --bug "$(BUG)" || $(SAYFAIL)

## check-all — your test against every bug in BUG_LIST, from one build
check-all: | solver-check
	@$(PYTHON) $(COMMON)/check.py $(GRADER) --all || $(SAYFAIL)

## new — deal a mystery bug from HUNT_POOL. You are not told which one.
new:
	@$(PYTHON) $(COMMON)/hunt.py new $(GRADER) $(if $(BUGPICK),--pick $(BUGPICK))

## hunt — your test against the mystery bug, no grade (VERBOSE=1 shows the log)
hunt: | solver-check
	@$(PYTHON) $(COMMON)/hunt.py hunt $(GRADER)

## verdict — the hunt's grade: pass on the golden design, fail on the mystery bug
verdict: | solver-check
	@$(PYTHON) $(COMMON)/hunt.py verdict $(GRADER) || $(SAYFAIL)

## reveal — give up on the hunt and be told which bug it was
reveal:
	@$(PYTHON) $(COMMON)/hunt.py reveal $(GRADER)

## clean — remove build/ (the simulator, the runs, the waves); keeps the ccache
clean:
	rm -rf $(BUILD_DIR)
	@echo " removed $(BUILD_DIR). The ccache ($(CCACHE_DIR)) is kept: make clean-cache removes it."

## clean-cache — remove the ccache too; the next build is a cold one
clean-cache:
	rm -rf $(CCACHE_DIR)

## cache — how full the ccache is (capped at CCACHE_MAXSIZE)
cache:
	@echo " ccache: $(CCACHE_DIR), capped at $(CCACHE_MAXSIZE)"
	@ccache -s

## help — this list
help:
	@echo "Targets:"
	@grep -hE '^## ' $(LAB_MAKEFILE) $(UVM_MK) | sed 's/^## /  make /'
	@echo ""
	@echo "Variables (now):"
	@echo "  UVM_TESTNAME=$(UVM_TESTNAME)  SEED=$(SEED)  BUG=$(BUG)  PLUSARGS=$(PLUSARGS)"
	@echo "  VERBOSITY=$(VERBOSITY)  SEEDS=$(strip $(SEEDS))  RUN_TIMEOUT=$(RUN_TIMEOUT)"
	@echo "  JOBS=$(JOBS)  COVERAGE=$(COVERAGE)  TRACE=$(TRACE)  BUILD_DIR=$(BUILD_DIR)"
	@echo "  CCACHE_DIR=$(CCACHE_DIR)  CCACHE_MAXSIZE=$(CCACHE_MAXSIZE)"

FORCE:
