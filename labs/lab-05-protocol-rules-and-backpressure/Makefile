# DD105-A Lab 05: Protocol rules and backpressure.
#
# Lab 04's UVM testbench for the router, with assertions bound into the
# router, a sink that can answer each beat, and a virtual sequence. One build
# serves every test, seed and planted bug:
#
#   make build                         build the simulator
#   make run                           router_test on the golden router
#   make run BUG=B10                   the same, with planted bug B10 on
#   make run UVM_TESTNAME=router_lab05_test
#   make check                         the verdict: pass on the golden router, fail on B11
#   make check-all                     the same against B11, B10 and B12
#
# `make help` lists every target; labs/common/README.md describes them.

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
TB_SRCS       := tb/router_ifs.sv tb/router_agents_pkg.sv tb/router_env_pkg.sv \
                 tb/router_vseq_pkg.sv tb/router_tests_pkg.sv \
                 tb/router_sva.sv tb/router_sva_bind.sv tb/router_tb_top.sv
TESTS         := router_test router_lab05_test router_sink_test router_inject_test \
                 router_stall_test router_rand_test router_fill_test router_class_test
# B11 first: make check with no BUG grades it, and it's the one bug of the
# three that Lab 04's testbench misses.
BUG_LIST      := B11 B10 B12
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
# Lab 04 files: make loc FILES="../lab-04-the-same-testbench-in-uvm/tb/*.sv"
FILES ?=

.PHONY: loc

## loc — lines and code lines in this lab's testbench, and in FILES if you give it
loc:
	@echo "This lab's UVM testbench:"
	@$(PYTHON) $(LAB_DIR)/src/loc.py $(TB_SRCS)
	@if [ -n "$(strip $(FILES))" ]; then echo "FILES:"; $(PYTHON) $(LAB_DIR)/src/loc.py $(FILES); fi
