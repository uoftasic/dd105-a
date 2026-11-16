# DD105-A guide example: Sequences, sequencers and drivers.
#
# SimProc's ALU (Lab 01's rtl/alu.sv) driven by a sequence, a sequencer and
# a driver, with a line printed at every step of the handshake:
#
#   make build                                the simulator (one UVM build)
#   make run UVM_TESTNAME=sq_timeline_test    one sequence of three vectors
#   make run UVM_TESTNAME=sq_two_test         two sequences on one sequencer
#   make run UVM_TESTNAME=sq_nested_test      a sequence that starts two others
#   make waves UVM_TESTNAME=sq_timeline_test  the same run, with waves.fst
#   make clean
#
# ../README.md lists the commands and the output the guide page quotes.

TOP      := sq_top
DUT_SRCS := ../../labs/lab-01-one-alu-two-testbenches/rtl/alu.sv
TB_SRCS  := sq_if.sv sq_pkg.sv sq_top.sv
TESTS    := sq_timeline_test sq_two_test sq_nested_test
# No file here has a `timescale, so this makes #5 in the top module 5 ns.
VFLAGS   := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
