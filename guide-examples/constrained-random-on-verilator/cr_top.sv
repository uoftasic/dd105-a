// DD105-A guide example: Constrained random on Verilator. The top module
// only starts UVM, which builds the test that +UVM_TESTNAME names.
module cr_top;
  import uvm_pkg::*;
  import cr_pkg::*;
  initial run_test();
endmodule
