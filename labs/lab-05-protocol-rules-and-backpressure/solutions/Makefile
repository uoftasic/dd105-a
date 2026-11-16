# DD105-A Lab 05: the reference solution. README.md says what's here.
#
# It builds the lab's testbench with the three files you edit in the lab
# replaced by the finished ones in tb/; every other file comes from the lab
# folder above. Run it from this folder:
#
#   make                         build if needed, run router_test
#   make check-all               router_test against B12, B10 and B11
#   make clean

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
TB_SRCS       := ../tb/apb_if.sv ../tb/stream_if.sv ../tb/router_sys_if.sv \
                 ../tb/apb_pkg.sv tb/stream_pkg.sv ../tb/router_env_pkg.sv \
                 tb/router_seq_pkg.sv ../tb/router_test_pkg.sv \
                 tb/router_sva.sv ../tb/router_sva_bind.sv ../tb/router_tb_top.sv
TESTS         := router_test router_lab05_test
BUG_LIST      := B12 B10 B11
BUG_CATALOGUE := ../../common/bugs.py
VFLAGS        := --timescale 1ns/1ps
# Every assertion failure prints and the run goes on: without this the first
# failing assertion ends the run (the simulator's default error limit is 1).
PLUSARGS      ?= +verilator+error+limit+100000
include ../../common/uvm.mk

build/rtl/router.f: $(wildcard ../../common/rtl/*.sv) ../../common/bugs.py ../../common/inject.py
	python3 ../../common/inject.py --all --out build/rtl
