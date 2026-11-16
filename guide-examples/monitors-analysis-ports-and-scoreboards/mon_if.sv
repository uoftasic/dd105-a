// DD105-A guide example: the ALU's pins, as in Lab 01's alu_if: a clock and
// a valid signal added, a clocking block for the driver and one for the
// monitor.
interface mon_alu_if (input logic clk);
  logic       valid = 1'b0;
  logic [2:0] ALUop = 3'd0;
  logic [7:0] A = 8'h00, B = 8'h00;
  logic [7:0] ALUout;
  logic       N, Z;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output valid, ALUop, A, B;
  endclocking

  // Reads every signal as it was just before the edge, and drives nothing.
  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid, ALUop, A, B, ALUout, N, Z;
  endclocking
endinterface
