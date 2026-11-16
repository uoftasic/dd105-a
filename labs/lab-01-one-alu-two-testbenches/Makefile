# DD105-A Lab 01: One ALU, two testbenches.
#
# Two testbenches for SimProc's ALU from DD104, one build of each:
#
#   make cocotb                the cocotb test (cocotb/test_alu.py) on the golden ALU
#   make cocotb BUG=A03        ... with bug A03 switched on
#   make cocotb-all            ... on the golden ALU and each of A01 to A03
#   make build                 build the UVM simulator (the first build takes a while)
#   make run                   run alu_rand_test on the golden ALU
#   make check BUG=A03         the verdict: pass on the golden ALU, fail on A03
#   make loc                   count each testbench's lines
#
# `make help` lists every target; labs/common/README.md describes the UVM ones.

TOP           := alu_tb_top
DUT_SRCS      := rtl/alu.sv
TB_SRCS       := tb/alu_if.sv tb/alu_pkg.sv tb/alu_tb_top.sv
TESTS         := alu_rand_test alu_directed_test
BUG_LIST      := A01 A02 A03
BUG_CATALOGUE := bugs.json
# No file here has a `timescale, so this makes #5 in the top module 5 ns.
VFLAGS        := --timescale 1ns/1ps
include ../common/uvm.mk

# ── the cocotb testbench ─────────────────────────────────────────────────────
# cocotb/Makefile does the work. COCOTB_SIM picks the simulator (icarus, as in
# DD104, or verilator) and TB the Python module in cocotb/ (default test_alu).
COCOTB_SIM ?= icarus
TB         ?= test_alu
COCOTB_DIR := $(LAB_DIR)/build/cocotb/$(COCOTB_SIM)
COCOTB     := $(MAKE) --no-print-directory -C $(LAB_DIR)/cocotb SIM=$(COCOTB_SIM) TB=$(TB)

# $(call cocotb_one,<bug or empty>): build if needed, then run once. Prints how
# long each half took and leaves cocotb's own report above it.
define cocotb_one
rm -f $(COCOTB_DIR)/results-$(TB)-$(or $(1),golden).xml; \
t0=$$(date +%s.%N); $(COCOTB) BUG=$(1) simbin || exit 1; t1=$$(date +%s.%N); \
$(COCOTB) BUG=$(1) sim; rc=$$?; t2=$$(date +%s.%N); \
echo "$(RULE)"; \
awk "BEGIN{printf \" cocotb, $(TB) on $(COCOTB_SIM), $(or $(1),the golden ALU): build %.1f s, run %.1f s\n\", $$t1 - $$t0, $$t2 - $$t1}"; \
echo "$(RULE)"; exit $$rc
endef

.PHONY: cocotb cocotb-all loc

## cocotb — the cocotb test (TB=test_alu) on the golden ALU, or on BUG
cocotb:
	@$(call cocotb_one,$(BUG))

## cocotb-all — the cocotb test on the golden ALU, then on each bug in BUG_LIST
cocotb-all:
	@for b in "" $(BUG_LIST); do echo "$(RULE)"; $(MAKE) --no-print-directory -s cocotb BUG=$$b 2>&1 \
	  | grep -E '^ cocotb, |\*\* TESTS=|\*\* [^ ]+\.[^ ]+ +(PASS|FAIL) |^ *AssertionError: |^ALU: ' \
	  | sed -E 's/^ {20,}//'; done; echo "$(RULE)"

## loc — lines of code in each testbench: cocotb/$(TB).py, then the UVM files
loc:
	@echo "cocotb testbench:"
	@$(PYTHON) $(LAB_DIR)/src/loc.py cocotb/$(TB).py
	@echo "UVM testbench:"
	@$(PYTHON) $(LAB_DIR)/src/loc.py $(TB_SRCS)
