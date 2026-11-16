// DD105-A guide example: the monitors example's top module, with this
// folder's tests. A 10 ns clock, SimProc's ALU from Lab 01, the interface
// and run_test().
module fac_top;
  import uvm_pkg::*;
  import mon_pkg::*;
  import fac_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  mon_alu_if aif (clk);

  ALU u_alu (.ALUop(aif.ALUop), .A(aif.A), .B(aif.B),
             .N(aif.N), .Z(aif.Z), .ALUout(aif.ALUout));

  initial begin
    uvm_config_db#(virtual mon_alu_if)::set(null, "uvm_test_top.env.agent.*", "vif", aif);
    run_test();
  end
endmodule
