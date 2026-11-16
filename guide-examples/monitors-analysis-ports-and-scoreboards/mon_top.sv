// DD105-A guide example: a 10 ns clock, SimProc's ALU from Lab 01, the
// interface between them, and run_test(). The ALU's +BUG switch picks the
// golden ALU or one of DD104's bugs A01 to A03.
module mon_top;
  import uvm_pkg::*;
  import mon_pkg::*;

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
