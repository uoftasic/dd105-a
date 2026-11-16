# DD105-A guide example for "Virtual sequences": a four-beat FIFO, a source
# agent, a sink driven by a knob, and a virtual sequence on a virtual
# sequencer that steers both from one place.
#
#   make run           vs_test, which runs vs_demo_vseq
#
# guide-examples/README.md lists the runs the page quotes.

TOP      := vseq_tb_top
DUT_SRCS := fifo4.sv
TB_SRCS  := vseq_tb.sv
TESTS    := vs_test
VFLAGS   := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
