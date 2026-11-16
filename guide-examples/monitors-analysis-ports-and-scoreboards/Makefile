# DD105-A guide example: Monitors, analysis ports and scoreboards.
#
# SimProc's ALU (Lab 01's rtl/alu.sv) with an agent whose monitor writes to
# one analysis port, and three subscribers on it:
#
#   make build                              the simulator (one UVM build)
#   make run UVM_TESTNAME=mon_rand_test     200 vectors on the golden ALU
#   make run UVM_TESTNAME=mon_rand_test BUG=A01
#                                           the same on the ALU whose SUB computes B - A
#   make run UVM_TESTNAME=mon_alias_test    a monitor that reuses one item for every write
#   make clean
#
# ../README.md lists the commands and the output the guide page quotes.

TOP           := mon_top
DUT_SRCS      := ../../labs/lab-01-one-alu-two-testbenches/rtl/alu.sv
TB_SRCS       := mon_if.sv mon_pkg.sv mon_top.sv
TESTS         := mon_rand_test mon_alias_test
BUG_LIST      := A01 A02 A03
BUG_CATALOGUE := ../../labs/lab-01-one-alu-two-testbenches/bugs.json
# No file here has a `timescale, so this makes #5 in the top module 5 ns.
VFLAGS        := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
