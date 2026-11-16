// DD105-A guide example: the top module. Lab 01's ALU (with its +BUG switch),
// the interface the class reaches it through, and run_test().
module alu_t01_top;
  import uvm_pkg::*;
  import alu_t01_tests_pkg::*;

  alu_pins_if pins ();

  ALU u_alu (.ALUop(pins.ALUop), .A(pins.A), .B(pins.B),
             .N(pins.N), .Z(pins.Z), .ALUout(pins.ALUout));

  initial begin
    uvm_config_db#(virtual alu_pins_if)::set(null, "uvm_test_top", "vif", pins);
    run_test();
  end
endmodule
