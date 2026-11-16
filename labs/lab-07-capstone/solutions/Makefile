# DD105-A Lab 07: the reference solution. README.md says what's here.
#
# It builds the lab's testbench with the two files you edit in the lab
# replaced by the finished ones in tb/; every other file comes from the lab
# folder above. Run it from this folder:
#
#   make                         build if needed, run router_test
#   make regress                 all 13 tests on seeds 1 to 10, then the coverage
#   make check-all               router_test against every planted bug
#   make clean

TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
TB_SRCS       := ../tb/router_ifs.sv ../tb/router_agents_pkg.sv ../tb/router_ral_pkg.sv \
                 ../tb/router_env_pkg.sv tb/router_vseq_pkg.sv ../tb/router_tests_pkg.sv \
                 tb/router_sva.sv ../tb/router_sva_bind.sv ../tb/router_tb_top.sv
VLT           := ../tb/router_regs.vlt
TESTS         := router_test router_lab07_test router_reset_test router_saturate_test \
                 router_lab06_test router_backdoor_test router_lab05_test router_sink_test \
                 router_inject_test router_stall_test router_rand_test router_fill_test \
                 router_class_test
BUG_LIST      := B15 B01 B02 B03 B04 B05 B06 B07 B08 B09 B10 B11 B12 B13 B14
BUG_CATALOGUE := ../../common/bugs.py
VFLAGS        := --timescale 1ns/1ps
# Every assertion failure prints and the run goes on: without this the first
# failing assertion ends the run (the simulator's default error limit is 1).
PLUSARGS      ?= +verilator+error+limit+100000
include ../../common/uvm.mk

build/rtl/router.f: $(wildcard ../../common/rtl/*.sv) ../../common/bugs.py ../../common/inject.py
	python3 ../../common/inject.py --all --out build/rtl
