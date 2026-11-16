// SELFTEST -- the ALU's pins, with a clocking block for the driver and one for
// the monitor.
interface st_if (input logic clk);
  logic       rst_n;
  logic       in_valid;
  logic [2:0] op;
  logic [7:0] a, b;
  logic       out_valid;
  logic [7:0] result;
  logic       carry, zero;
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output in_valid, op, a, b;
  endclocking
  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst_n, in_valid, op, a, b, out_valid, result, carry;
  endclocking
  modport DRV (clocking drv_cb, output rst_n);
  modport MON (clocking mon_cb);
endinterface
