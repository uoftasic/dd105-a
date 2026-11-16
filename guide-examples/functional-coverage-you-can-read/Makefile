# DD105-A guide example: Functional coverage you can read.
#
# A covergroup on ALU vectors, sampled by two tests, and two small
# covergroups that show how Verilator 5.050 counts bins. One build serves
# both tests:
#
#   make build                               the simulator (one UVM build)
#   make run UVM_TESTNAME=cov_plain_test     300 vectors, A and B uniformly random
#   make run UVM_TESTNAME=cov_biased_test    300 vectors, with A == B and A at 00/ff more often
#   make cov                                 every bin of every run in build/runs, with its count
#   make clean
#
#   make build VFLAGS=+define+CG_MEMBER BUILD_DIR=$PWD/build/member
#                                            the covergroup that reads a class member;
#                                            the build stops in seconds with COVERIGN
#
# ../README.md lists the commands and the output the guide page quotes.

TOP     := cov_top
TB_SRCS := cov_pkg.sv cov_top.sv
TESTS   := cov_plain_test cov_biased_test
include ../../labs/common/uvm.mk
