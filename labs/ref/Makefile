# DD105-A: the reference UVM environment for the router, written from the
# specification (docs/reference/router-spec.md). README.md says what's here.
#
#   make                         build if needed, run router_all_test
#   make run UVM_TESTNAME=router_rand_test SEED=7 PLUSARGS="+N=3000"
#   make seeds                   router_all_test on seeds 1 to 10
#   make check-all               router_all_test against every planted bug

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
TB_SRCS       := tb/apb_if.sv tb/stream_if.sv tb/router_sys_if.sv \
                 tb/apb_pkg.sv tb/stream_pkg.sv tb/router_ral_pkg.sv \
                 tb/router_env_pkg.sv tb/router_seq_pkg.sv tb/router_test_pkg.sv \
                 tb/router_sva.sv tb/router_sva_bind.sv tb/router_tb_top.sv
TESTS         := router_all_test router_smoke_test router_rand_test \
                 router_full_test router_oversize_test router_ctrl_test \
                 router_same_cycle_test router_saturate_test router_regs_test \
                 router_reset_test router_irq_test
BUG_CATALOGUE := ../common/bugs.py
VFLAGS        := --timescale 1ns/1ps
# Every assertion failure prints and the run goes on: without this the first
# failing assertion ends the run (the simulator's default error limit is 1).
PLUSARGS      ?= +verilator+error+limit+100000
include ../common/uvm.mk

build/rtl/router.f: $(wildcard ../common/rtl/*.sv) ../common/bugs.py ../common/inject.py
	python3 ../common/inject.py --all --out build/rtl
