# DD105-A Lab 02: A class testbench without UVM. README.md says what's here.
#
#   make                                    build if needed, then run router_class_test
#   make run PLUSARGS="+SHOW=5"             the same, printing the first 5 packets on each stream
#   make run BUG=B09 PLUSARGS="+N=16 +DSTS=0 +LEN=1"
#   make check-all                          the golden router, then B05 and B09
#
# `make help` lists every target; labs/common/README.md describes them.

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
INCDIRS       := tb
TB_SRCS       := tb/apb_if.sv tb/stream_if.sv tb/router_tb_pkg.sv tb/router_test_pkg.sv \
                 tb/router_tb_top.sv
TESTS         := router_class_test
BUG_LIST      := B05 B09
BUG_CATALOGUE := ../common/bugs.py
# No file here has a `timescale, so this makes #5 in the top module 5 ns.
VFLAGS        := --timescale 1ns/1ps
# The scoreboard reports each mismatch with $error, and Verilator ends a run
# at its first $error unless the error limit is raised. Every run of this lab
# gets the higher limit, including runs where you set PLUSARGS yourself.
override PLUSARGS := $(strip $(filter-out +verilator+error+limit+%,$(PLUSARGS)) +verilator+error+limit+100)
include ../common/uvm.mk

build/rtl/router.f: $(wildcard ../common/rtl/*.sv) ../common/bugs.py ../common/inject.py
	python3 ../common/inject.py --all --out build/rtl
