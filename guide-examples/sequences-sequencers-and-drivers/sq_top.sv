// DD105-A guide example: a 10 ns clock, SimProc's ALU from Lab 01, the
// interface between them, and run_test().
module sq_top;
  import uvm_pkg::*;
  import sq_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  sq_alu_if aif (clk);

  ALU u_alu (.ALUop(aif.ALUop), .A(aif.A), .B(aif.B),
             .N(aif.N), .Z(aif.Z), .ALUout(aif.ALUout));

  initial begin
    uvm_config_db#(virtual sq_alu_if)::set(null, "uvm_test_top.agent.drv", "vif", aif);
    run_test();
  end
endmodule
