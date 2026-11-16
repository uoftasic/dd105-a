// DD105-A Lab 01: the top module. A clock, the ALU, the interface between
// them, and run_test(), which builds the test named by +UVM_TESTNAME.
module alu_tb_top;
  import uvm_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;

  alu_if aif (clk);

  ALU u_alu (.ALUop(aif.ALUop), .A(aif.A), .B(aif.B),
             .N(aif.N), .Z(aif.Z), .ALUout(aif.ALUout));

  initial begin
    uvm_config_db#(virtual alu_if.DRV)::set(null, "uvm_test_top*", "drv_vif", aif.DRV);
    uvm_config_db#(virtual alu_if.MON)::set(null, "uvm_test_top*", "mon_vif", aif.MON);
    run_test();
  end
endmodule
