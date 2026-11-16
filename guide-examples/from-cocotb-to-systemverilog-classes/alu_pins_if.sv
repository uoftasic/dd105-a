// DD105-A guide example: the ALU's six pins, so that a class can reach them
// through a virtual interface. No clock: the ALU is combinational, and this
// example waits 1 ns after each vector as the cocotb test does.
interface alu_pins_if;
  logic [2:0] ALUop = 3'd0;
  logic [7:0] A = 8'h00, B = 8'h00;
  logic [7:0] ALUout;
  logic       N, Z;
endinterface
