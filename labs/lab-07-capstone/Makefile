# DD105-A Lab 07: the capstone. README.md says what's here, and
# docs/labs/lab-07-capstone-overview.md is the lab.
#
#   make                         build if needed, run router_all_test
#   make regress                 every test in TESTS on seeds 1 to 10, then the coverage
#   make new / hunt / verdict    a mystery bug from the whole catalogue
#   make check-all               router_all_test against every planted bug
#   make clean

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
TB_SRCS       := tb/apb_if.sv tb/stream_if.sv tb/router_sys_if.sv \
                 tb/apb_pkg.sv tb/stream_pkg.sv tb/router_ral_pkg.sv \
                 tb/router_env_pkg.sv tb/router_seq_pkg.sv tb/router_test_pkg.sv \
                 tb/router_sva.sv tb/router_sva_bind.sv tb/router_tb_top.sv
# router_all_test comes first: make, check, check-all and the hunt run it.
# TODO (Parts 5 and 6): add router_reset_test and router_saturate_test once
# their sequences are written.
TESTS         := router_all_test router_smoke_test router_rand_test \
                 router_full_test router_oversize_test router_ctrl_test \
                 router_same_cycle_test router_regs_test router_irq_test
# No BUG_LIST: check-all and the hunt use every bug in the catalogue.
BUG_CATALOGUE := ../common/bugs.py
VFLAGS        := --timescale 1ns/1ps
# Every assertion failure prints and the run goes on: without this the first
# failing assertion ends the run (the simulator's default error limit is 1).
PLUSARGS      ?= +verilator+error+limit+100000
include ../common/uvm.mk

build/rtl/router.f: $(wildcard ../common/rtl/*.sv) ../common/bugs.py ../common/inject.py
	python3 ../common/inject.py --all --out build/rtl
