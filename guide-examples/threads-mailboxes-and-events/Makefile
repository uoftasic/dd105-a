# DD105-A guide example: Threads, mailboxes and events
# (docs/guide/threads-mailboxes-and-events.md). Run it in the course image:
#
#   make build                                   the simulator (about 100 s the first time)
#   make run UVM_TESTNAME=fork_test              fork...join, join_any and join_none
#   make run UVM_TESTNAME=mailbox_test           a generator and a driver, unbounded mailbox
#   make run UVM_TESTNAME=mailbox_test PLUSARGS=+BOUND=1
#   make run UVM_TESTNAME=capture_test           threads forked in a loop
#   make run UVM_TESTNAME=static_loop_test PLUSARGS=+STATIC_LOOP
#                                                the same loop in a module's initial block
#   make run UVM_TESTNAME=event_test             @done against wait (done.triggered)
#   make run UVM_TESTNAME=disable_test           disable fork, bare and in its own fork
#   make clean
#
# The build is the labs' build (labs/common/uvm.mk), so the UVM library is
# compiled in even though the demonstrations don't use it.

TOP     := threads_top
TB_SRCS := threads_demo_pkg.sv threads_tests_pkg.sv threads_top.sv
TESTS   := fork_test mailbox_test capture_test static_loop_test event_test disable_test
# No file here has a `timescale, so this makes #10 ten ns and $time count ns.
VFLAGS  := --timescale 1ns/1ps
include ../../labs/common/uvm.mk
