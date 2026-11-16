# DD105-A guide example for "Reactive agents and backpressure": a source that
# decides when its beats appear, and a sink agent that either flips a coin in
# every cycle or answers each beat with an item from its sequence. One build
# serves every run:
#
#   make run PLUSARGS="+MODE=coin +READY_PCT=5"
#   make run PLUSARGS="+MODE=coin +READY_PCT=50"
#   make run PLUSARGS="+MODE=beat +MAX_DELAY=12"
#
# guide-examples/README.md lists the runs the page quotes.

TOP      := sink_tb_top
DUT_SRCS := beat_src.sv
TB_SRCS  := sink_tb.sv
TESTS    := sink_test
VFLAGS   := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
