# DD105-A Lab 04: The same testbench in UVM.
#
# Lab 03's class testbench for the router, ported to UVM. One build serves
# every test, seed and planted bug:
#
#   make build                         build the simulator (about 2 minutes the first time)
#   make run                           router_inject_test on the golden router
#   make run UVM_TESTNAME=router_rand_test SEED=3
#   make check BUG=B13                 the verdict: pass on the golden router, fail on B13
#   make check-all                     the same against B06 and B13
#   make loc                           count the testbench's lines (FILES=... adds yours)
#
# `make help` lists every target; labs/common/README.md describes them.

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
TB_SRCS       := tb/router_ifs.sv tb/router_agents_pkg.sv tb/router_env_pkg.sv \
                 tb/router_tests_pkg.sv tb/router_tb_top.sv
TESTS         := router_inject_test router_stall_test router_rand_test router_smoke_test
BUG_LIST      := B06 B13
BUG_CATALOGUE := ../common/bugs.py
# No file here has a `timescale, so this makes #5 in the top module 5 ns.
VFLAGS        := --timescale 1ns/1ps
include ../common/uvm.mk

build/rtl/router.f: $(wildcard ../common/rtl/*.sv) ../common/bugs.py ../common/inject.py
	python3 ../common/inject.py --all --out build/rtl

# ── line counts ──────────────────────────────────────────────────────────────
# FILES names another testbench to count beside this one, for example your
# Lab 02 files: make loc FILES="../lab-02-.../tb/*.sv"
FILES ?=

.PHONY: loc

## loc — lines and code lines in this lab's testbench, and in FILES if you give it
loc:
	@echo "This lab's UVM testbench:"
	@$(PYTHON) $(LAB_DIR)/src/loc.py $(TB_SRCS)
	@if [ -n "$(strip $(FILES))" ]; then echo "FILES:"; $(PYTHON) $(LAB_DIR)/src/loc.py $(FILES); fi
