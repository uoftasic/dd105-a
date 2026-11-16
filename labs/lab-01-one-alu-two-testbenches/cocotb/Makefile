# DD105-A Lab 01: the cocotb side.
#
# You don't run this file yourself. The lab's Makefile runs it for
# `make cocotb` and `make cocotb-all`, one folder up. It has to be a separate
# file because cocotb's makefiles and uvm.mk both define `all`, `clean` and
# friends.
#
#   SIM   icarus (the default, as in DD104) or verilator
#   TB    the Python module with the tests, in this folder (default test_alu)
#   BUG   empty for the golden ALU, or A01, A02 or A03
#
# The ALU is elaborated on its own as the top level (COCOTB_TOPLEVEL=ALU), as
# in DD104 Lab 03, so a test written there for `dut.ALUop`, `dut.A`, `dut.B`,
# `dut.ALUout`, `dut.N` and `dut.Z` runs here unchanged. The bug is picked at
# run time with +BUG, so one build serves all four designs.

SIM ?= icarus
TB  ?= test_alu
BUG ?=

LAB                 := $(abspath ..)
TOPLEVEL_LANG       := verilog
VERILOG_SOURCES     := $(LAB)/rtl/alu.sv
COCOTB_TOPLEVEL     := ALU
COCOTB_TEST_MODULES := $(TB)
SIM_BUILD           := $(LAB)/build/cocotb/$(SIM)
COCOTB_RESULTS_FILE := $(SIM_BUILD)/results-$(TB)-$(or $(BUG),golden).xml
COCOTB_PLUSARGS     += +BUG_ECHO $(if $(BUG),+BUG=$(BUG))

# cocotb imports TB from PYTHONPATH, so this folder has to be on it.
export PYTHONPATH := $(CURDIR):$(PYTHONPATH)

# The simulator cocotb builds, so the lab's Makefile can time the build and
# the run separately: `make simbin`, then `make sim`.
SIM_BIN := $(SIM_BUILD)/$(if $(filter verilator,$(SIM)),Vtop,sim.vvp)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: simbin
simbin: $(SIM_BIN)
