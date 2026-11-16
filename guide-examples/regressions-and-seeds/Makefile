# DD105-A guide example for "Regressions and seeds": a saturating counter that
# random stimulus gets to 15 on some seeds and not others, and a test that
# shows what a seed fixes. One build serves every run:
#
#   make run UVM_TESTNAME=count_test SEED=3
#   make seeds UVM_TESTNAME=count_test SEEDS="1 2 3 4 5 6 7 8 9 10"
#   make seeds UVM_TESTNAME=count_test SEEDS="1 2 3 4 5 6 7 8 9 10" BUG=wrap
#   make run UVM_TESTNAME=random_test SEED=1 PLUSARGS=+EXTRA_NEW
#
# guide-examples/README.md lists the runs the page quotes.

TOP      := seeds_tb_top
DUT_SRCS := satcnt.sv
TB_SRCS  := seeds_tb.sv
TESTS    := count_test random_test
VFLAGS   := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
