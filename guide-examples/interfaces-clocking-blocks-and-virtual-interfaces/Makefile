# DD105-A guide example: Interfaces, clocking blocks and virtual interfaces
# (docs/guide/interfaces-clocking-blocks-and-virtual-interfaces.md). Run it in
# the course image:
#
#   make build                                the simulator (about 100 s the first time)
#   make run UVM_TESTNAME=edge_test           sampled values and pins at each edge
#   make waves UVM_TESTNAME=edge_test         the same run, with build/runs/edge_test-s1/waves.fst
#   make run UVM_TESTNAME=typedef_test        one interface through two kinds of handle
#   make run UVM_TESTNAME=module_task_test PLUSARGS=+MODULE_TASK
#                                             a module task in a repeat loop
#   make clean
#
# The design is the golden router (labs/common/rtl). The build is the labs'
# build (labs/common/uvm.mk), so the UVM library is compiled in even though
# the classes don't use it.

TOP     := rtr_top
DUT_F   := ../../labs/common/rtl/router.f
TB_SRCS := rtr_ifs.sv rtr_demo_pkg.sv rtr_tests_pkg.sv rtr_top.sv
TESTS   := edge_test typedef_test module_task_test
# No file here has a `timescale, so this makes #5 in the top module 5 ns.
VFLAGS  := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
