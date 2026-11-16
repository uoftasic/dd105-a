// DD105-A guide example: The UVM skeleton. The top module only starts UVM,
// which builds the test that +UVM_TESTNAME names. There is no design.
module sk_top;
  import uvm_pkg::*;
  import sk_pkg::*;
  initial run_test();
endmodule
