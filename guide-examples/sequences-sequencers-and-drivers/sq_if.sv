// DD105-A guide example: the ALU's pins, as in Lab 01's alu_if, with one
// clocking block for the driver. The ALU has no clock and no valid signal;
// the interface adds both, and neither goes to the ALU.
interface sq_alu_if (input logic clk);
  logic       valid = 1'b0;
  logic [2:0] ALUop = 3'd0;
  logic [7:0] A = 8'h00, B = 8'h00;
  logic [7:0] ALUout;
  logic       N, Z;

  // Drives 1 ns after a rising edge; reads the value just before it.
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output valid, ALUop, A, B;
    input  ALUout;
  endclocking
endinterface
