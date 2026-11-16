# DD105-A guide example: From cocotb to SystemVerilog classes
# (docs/guide/from-cocotb-to-systemverilog-classes.md). Run it in the course image:
#
#   make build                            the simulator (about 100 s the first time)
#   make run UVM_TESTNAME=t01_test        DD104's t01 in SystemVerilog, on the golden ALU
#   make run UVM_TESTNAME=t01_test BUG=A01
#   make run UVM_TESTNAME=widths_test     one sum in three widths, and a string literal
#   make clean
#
# The ALU is Lab 01's rtl/alu.sv, with its +BUG switch. The build is the labs'
# build (labs/common/uvm.mk), so the UVM library is compiled in even though the
# class under test uses none of it.

TOP      := alu_t01_top
DUT_SRCS := ../../labs/lab-01-one-alu-two-testbenches/rtl/alu.sv
TB_SRCS  := alu_pins_if.sv alu_t01_pkg.sv alu_t01_tests_pkg.sv alu_t01_top.sv
TESTS    := t01_test widths_test
# No file here has a `timescale, so this makes #1 one ns.
VFLAGS   := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
