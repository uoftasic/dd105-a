// DD105-A guide example: Functional coverage you can read. The top module
// only starts UVM, which builds the test that +UVM_TESTNAME names.
module cov_top;
  import uvm_pkg::*;
  import cov_pkg::*;
  initial run_test();
endmodule
