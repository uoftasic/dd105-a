# DD105-A guide example: The UVM skeleton.
#
# A test, an environment and two agents that print a line in each phase, so
# you can see the order UVM runs them in and what ends the run:
#
#   make build                              the simulator (one UVM build)
#   make run UVM_TESTNAME=sk_phase_test     the phases, with objections of 100 and 150 ns
#   make run UVM_TESTNAME=sk_noobj_test     the same, with no objection raised
#   make run UVM_TESTNAME=sk_error_test     one UVM_ERROR: the summary and the exit status
#   make clean
#
# ../README.md lists the commands and the output the guide page quotes.

TOP     := sk_top
TB_SRCS := sk_pkg.sv sk_top.sv
TESTS   := sk_phase_test sk_noobj_test sk_error_test
# No file here has a `timescale, so this makes #40ns and the printed times ns.
VFLAGS  := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
