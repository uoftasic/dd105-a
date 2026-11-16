# DD105-A Lab 06: the register block. README.md says what's here, and
# docs/labs/lab-06-the-register-block-overview.md is the lab.
#
#   make                         build if needed, run router_test
#   make run BUG=B14             the same, with planted bug B14 on
#   make run UVM_TESTNAME=router_lab06_test    this lab's steps on their own
#   make check BUG=B03           router_test passes the golden design and fails on B03
#   make check-all               the same against B01, B02, B03, B04 and B14
#   make clean

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
TB_SRCS       := tb/apb_if.sv tb/stream_if.sv tb/router_sys_if.sv \
                 tb/apb_pkg.sv tb/stream_pkg.sv tb/router_ral_pkg.sv \
                 tb/router_env_pkg.sv tb/router_seq_pkg.sv tb/router_test_pkg.sv \
                 tb/router_sva.sv tb/router_sva_bind.sv tb/router_tb_top.sv
# The signals the register model's back door reaches (Part 6).
VLT           := tb/router_regs.vlt
TESTS         := router_test router_lab06_test router_backdoor_test
BUG_LIST      := B01 B02 B03 B04 B14
BUG_CATALOGUE := ../common/bugs.py
VFLAGS        := --timescale 1ns/1ps
# Every assertion failure prints and the run goes on: without this the first
# failing assertion ends the run (the simulator's default error limit is 1).
PLUSARGS      ?= +verilator+error+limit+100000
include ../common/uvm.mk

build/rtl/router.f: $(wildcard ../common/rtl/*.sv) ../common/bugs.py ../common/inject.py
	python3 ../common/inject.py --all --out build/rtl
