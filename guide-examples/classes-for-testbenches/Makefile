# DD105-A guide example: Classes for testbenches
# (docs/guide/classes-for-testbenches.md). Run it in the course image:
#
#   make build                              the simulator (about 100 s the first time)
#   make run UVM_TESTNAME=handles_test      null, two handles to one object, and a copy
#   make run UVM_TESTNAME=reuse_test        a reused object kept three times in a queue
#   make run UVM_TESTNAME=dispatch_test     a virtual and a plain method through a base handle
#   make run UVM_TESTNAME=null_test         a null handle used as if it had an object
#   make lint VFLAGS="--timescale 1ns/1ps +define+FUNCTION_WAITS"
#                                           a function with a delay in it: a compile error
#   make clean
#
# The build is the labs' build (labs/common/uvm.mk), so the UVM library is
# compiled in even though the demonstrations don't use it.

TOP     := classes_top
TB_SRCS := classes_demo_pkg.sv classes_tests_pkg.sv classes_top.sv
TESTS   := handles_test reuse_test dispatch_test null_test
# No file here has a `timescale, so this makes #10 ten ns.
VFLAGS  := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
