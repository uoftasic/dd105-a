# DD105-A Lab 07: the capstone. README.md says what's here, and
# docs/labs/lab-07-capstone-overview.md is the lab.
#
# Lab 06's UVM testbench for the router, with a reset driver, a scoreboard
# that follows a reset with traffic in flight, and four corners in the
# coverage. One build serves every test, seed and planted bug:
#
#   make build                         build the simulator
#   make run                           router_test on the golden router
#   make regress                       every test in TESTS on seeds 1 to 10, then the coverage
#   make new / hunt / verdict          a mystery bug from the whole catalogue
#   make check                         the verdict: pass on the golden router, fail on B15
#   make check-all                     the same against all 15 bugs
#
# `make help` lists every target; labs/common/README.md describes them.

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
TB_SRCS       := tb/router_ifs.sv tb/router_agents_pkg.sv tb/router_ral_pkg.sv \
                 tb/router_env_pkg.sv tb/router_vseq_pkg.sv tb/router_tests_pkg.sv \
                 tb/router_sva.sv tb/router_sva_bind.sv tb/router_tb_top.sv
# The five register signals the back door reaches (Lab 06, Part 6).
VLT           := tb/router_regs.vlt
# router_test comes first: make, check, check-all and the hunts run it.
# TODO (Parts 5 and 6): add router_reset_test and router_saturate_test once
# their sequences are written.
TESTS         := router_test router_lab07_test router_lab06_test router_backdoor_test \
                 router_lab05_test router_sink_test router_inject_test router_stall_test \
                 router_rand_test router_fill_test router_class_test
# Every bug in the catalogue. B15, the one this lab's work catches, comes
# first, because `make check` grades the first bug in the list.
BUG_LIST      := B15 B01 B02 B03 B04 B05 B06 B07 B08 B09 B10 B11 B12 B13 B14
BUG_CATALOGUE := ../common/bugs.py
# No file here has a `timescale, so this makes #5 in the top module 5 ns.
VFLAGS        := --timescale 1ns/1ps
# Every failing assertion prints and the run goes on. Without this the
# first failing assertion ends the run, because the simulator's default
# error limit is 1.
PLUSARGS      ?= +verilator+error+limit+100000
include ../common/uvm.mk

build/rtl/router.f: $(wildcard ../common/rtl/*.sv) ../common/bugs.py ../common/inject.py
	python3 ../common/inject.py --all --out build/rtl

# ── line counts ──────────────────────────────────────────────────────────────
# FILES names another testbench to count beside this one, for example your
# Lab 06 files: make loc FILES="../lab-06-the-register-block/tb/*.sv"
FILES ?=

.PHONY: loc

## loc — lines and code lines in this lab's testbench, and in FILES if you give it
loc:
	@echo "This lab's UVM testbench:"
	@$(PYTHON) $(LAB_DIR)/src/loc.py $(TB_SRCS)
	@if [ -n "$(strip $(FILES))" ]; then echo "FILES:"; $(PYTHON) $(LAB_DIR)/src/loc.py $(FILES); fi
