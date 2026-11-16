# DD105-A guide example: The factory and config_db.
#
# The environment from ../monitors-analysis-ports-and-scoreboards, unchanged,
# with tests that change it through the factory and config_db:
#
#   make build                               the simulator (one UVM build)
#   make run UVM_TESTNAME=fac_equal_test     every alu_item replaced by an alu_equal_item
#   make run UVM_TESTNAME=fac_flags_test     the scoreboard told to check N and Z
#   make run UVM_TESTNAME=fac_typo_test      the same, with a misspelt path
#   make run UVM_TESTNAME=fac_prec_test      two sets of one knob: which one wins
#   make check-all UVM_TESTNAME=fac_flags_test
#                                            a test against DD104's three ALU bugs
#   make clean
#
# ../README.md lists the commands and the output the guide page quotes.

MON           := ../monitors-analysis-ports-and-scoreboards
TOP           := fac_top
DUT_SRCS      := ../../labs/lab-01-one-alu-two-testbenches/rtl/alu.sv
TB_SRCS       := $(MON)/mon_if.sv $(MON)/mon_pkg.sv fac_pkg.sv fac_top.sv
TESTS         := fac_equal_test fac_flags_test fac_typo_test fac_prec_test mon_rand_test
BUG_LIST      := A01 A02 A03
BUG_CATALOGUE := ../../labs/lab-01-one-alu-two-testbenches/bugs.json
# No file here has a `timescale, so this makes #5 in the top module 5 ns.
VFLAGS        := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
