# DD105-A guide example for "Register models": four registers on a one-cycle
# bus, their UVM register model, an adapter and a predictor. One build serves
# every run:
#
#   make run UVM_TESTNAME=reg_reset_test
#   make run UVM_TESTNAME=reg_reset_test BUG=en_reset_1
#   make run UVM_TESTNAME=reg_bitbash_test BUG=mode_stuck
#   make run UVM_TESTNAME=reg_mirror_test PLUSARGS=+PREDICT=auto
#
# guide-examples/README.md lists the runs the page quotes.

TOP      := regblk_tb_top
DUT_SRCS := regblk.sv
TB_SRCS  := regblk_tb.sv
TESTS    := reg_reset_test reg_bitbash_test reg_mirror_test
VFLAGS   := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
