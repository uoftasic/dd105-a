# DD105-A Lab 05: protocol rules and backpressure. README.md says what's here,
# and docs/labs/lab-05-protocol-rules-and-backpressure-overview.md is the lab.
#
#   make                         build if needed, run router_test
#   make run BUG=B10             the same, with planted bug B10 on
#   make check                   router_test passes the golden design and fails on B12
#   make check-all               the same against B12, B10 and B11
#   make clean

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
TB_SRCS       := tb/apb_if.sv tb/stream_if.sv tb/router_sys_if.sv \
                 tb/apb_pkg.sv tb/stream_pkg.sv tb/router_env_pkg.sv \
                 tb/router_seq_pkg.sv tb/router_test_pkg.sv \
                 tb/router_sva.sv tb/router_sva_bind.sv tb/router_tb_top.sv
TESTS         := router_test router_lab05_test
BUG_LIST      := B12 B10 B11
BUG_CATALOGUE := ../common/bugs.py
VFLAGS        := --timescale 1ns/1ps
# Every assertion failure prints and the run goes on: without this the first
# failing assertion ends the run (the simulator's default error limit is 1).
PLUSARGS      ?= +verilator+error+limit+100000
include ../common/uvm.mk

build/rtl/router.f: $(wildcard ../common/rtl/*.sv) ../common/bugs.py ../common/inject.py
	python3 ../common/inject.py --all --out build/rtl
