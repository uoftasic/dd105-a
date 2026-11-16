# DD105-A Lab 03: Constraints and coverage. README.md says what's here.
#
# The class testbench from Lab 02, with constrained-random packets, a level
# tracker, a covergroup and a check on DROP_CNT:
#
#   make build                 build the simulator (the first build took 94 to 110 s on 2 CPUs)
#   make run                   run router_rand_test on the golden router
#   make cov                   merge every coverage.dat under build/runs and list the bins
#   make check-all             router_rand_test on the golden router, B07 and B08
#   make traps                 the constraint experiments in traps/traps.sv (seconds)
#
# `make help` lists every target; labs/common/README.md describes the shared ones.

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
INCDIRS       := tb
TB_SRCS       := tb/apb_if.sv tb/stream_if.sv tb/router_tb_pkg.sv tb/router_test_pkg.sv \
                 tb/router_tb_top.sv
TESTS         := router_rand_test router_fill_test router_class_test
BUG_LIST      := B07 B08
BUG_CATALOGUE := ../common/bugs.py
# No file here has a `timescale, so this makes #5 in the top module 5 ns.
VFLAGS        := --timescale 1ns/1ps
# The scoreboard and the DROP_CNT check report each mismatch with $error, and
# Verilator ends a run at its first $error unless the error limit is raised.
# Every run of this lab gets the higher limit, including runs where you set
# PLUSARGS yourself.
override PLUSARGS := $(strip $(filter-out +verilator+error+limit+%,$(PLUSARGS)) +verilator+error+limit+100)
include ../common/uvm.mk

build/rtl/router.f: $(wildcard ../common/rtl/*.sv) ../common/bugs.py ../common/inject.py
	python3 ../common/inject.py --all --out build/rtl

# ── the constraint experiments ───────────────────────────────────────────────
# traps/traps.sv is a plain SystemVerilog file with no UVM and no router, so
# Verilator builds it in seconds. Each experiment prints one line. Every
# randomize() call that fails prints UNSATCONSTR warnings; they go to
# build/traps/run.log, and only their number is shown here.
TRAPS_DIR := $(BUILD_DIR)/traps
TRAPS_LOG := $(patsubst $(LAB_DIR)/%,%,$(TRAPS_DIR))/run.log

.PHONY: traps
## traps — build and run traps/traps.sv, the constraint experiments (SEED picks the seed)
traps: | solver-check
	@mkdir -p $(TRAPS_DIR)
	@t0=$$(date +%s.%N); \
	if ! $(VERILATOR) --binary -j $(JOBS) --timing -Wno-fatal --Mdir $(TRAPS_DIR)/obj -o sim \
	       --top-module traps $(LAB_DIR)/traps/traps.sv > $(TRAPS_DIR)/build.log 2>&1; then \
	  echo " the build failed; the last 20 lines of $(TRAPS_DIR)/build.log:"; tail -n 20 $(TRAPS_DIR)/build.log; exit 1; fi; \
	t1=$$(date +%s.%N); \
	$(TRAPS_DIR)/obj/sim +verilator+seed+$(SEED) > $(TRAPS_DIR)/run.log 2>&1; \
	t2=$$(date +%s.%N); \
	grep -v -e '^%Warning-UNSATCONSTR' -e '^- ' -e '^ *: ' $(TRAPS_DIR)/run.log; \
	echo "$(RULE)"; \
	awk "BEGIN{printf \" traps: build %.1f s, run %.1f s, seed $(SEED); \", $$t1 - $$t0, $$t2 - $$t1}"; \
	echo "$$(grep -c '^%Warning-UNSATCONSTR' $(TRAPS_DIR)/run.log) UNSATCONSTR warnings in $(TRAPS_LOG)"; \
	echo "$(RULE)"
