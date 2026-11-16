// DD105-A Lab 01: the ALU's pins, as the UVM testbench sees them.
//
// The ALU has no clock and no valid signal, because it's combinational: the
// cocotb test drives a vector, waits 1 ns and reads the answer. A UVM driver
// and monitor work in clock cycles, so this interface adds a clock (from the
// top module) and a valid signal, which the driver raises in every cycle that
// carries a vector and the monitor reads to know which cycles to record.
// Neither one goes to the ALU.
interface alu_if (input logic clk);
  logic       valid;
  logic [2:0] ALUop;
  logic [7:0] A, B;
  logic [7:0] ALUout;
  logic       N, Z;

  // The driver writes a vector 1 ns after a clock edge, and the monitor
  // samples it, with the ALU's answer, just before the next edge.
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output valid, ALUop, A, B;
  endclocking
  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid, ALUop, A, B, ALUout, N, Z;
  endclocking
  modport DRV (clocking drv_cb);
  modport MON (clocking mon_cb);
endinterface
