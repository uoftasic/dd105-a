// DD105-A guide example: the top module. No design, no clock: run_test()
// builds the test named by +UVM_TESTNAME, and the test runs one demonstration.
module classes_top;
  import uvm_pkg::*;
  import classes_tests_pkg::*;

  initial run_test();
endmodule
