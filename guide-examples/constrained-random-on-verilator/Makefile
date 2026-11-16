# DD105-A guide example: Constrained random on Verilator.
#
# Small experiments with randomize() and constraints, each one a UVM test, so
# one build serves all of them and UVM_TESTNAME picks one:
#
#   make build                              the simulator (one UVM build)
#   make run UVM_TESTNAME=cr_item_test      randomize(), inline constraints, a failure
#   make run UVM_TESTNAME=cr_enum_test      how often each value of a rand enum comes out
#   make run UVM_TESTNAME=cr_dist_test      dist written with names and with numbers; dist and with {}
#   make run UVM_TESTNAME=cr_solve_test     solve...before
#   make clean
#
# There is no design: each test randomizes small classes and prints counts.
# ../README.md lists the commands and the output the guide page quotes.

TOP     := cr_top
TB_SRCS := cr_pkg.sv cr_top.sv
TESTS   := cr_item_test cr_enum_test cr_dist_test cr_solve_test
include ../../labs/common/uvm.mk
