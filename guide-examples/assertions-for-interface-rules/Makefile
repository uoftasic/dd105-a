# DD105-A guide example for "Assertions for interface rules": a one-beat
# valid/ready stage, its three rules written as assertions, and a bind that
# puts them inside it. One build serves every run:
#
#   make run                                  the golden stage
#   make run BUG=drop                         the stage that drops a waiting beat
#   make run BUG=drop PLUSARGS=               the same, with the simulator's default error limit
#   make run BUG=drop PLUSARGS="+verilator+error+limit+1000 +READY_PCT=100"
#
# guide-examples/README.md lists the runs the page quotes.

TOP      := stage_tb_top
DUT_SRCS := stage.sv
TB_SRCS  := stage_sva.sv stage_tb.sv
TESTS    := stage_test
VFLAGS   := --timescale 1ns/1ps
# Every failing assertion prints and the run goes on, as in Labs 05 to 07.
PLUSARGS ?= +verilator+error+limit+1000
include ../../labs/common/uvm.mk
