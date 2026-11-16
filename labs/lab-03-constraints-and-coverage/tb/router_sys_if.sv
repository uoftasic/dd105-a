// DD105-A Lab 03: reset and the interrupt.
//
// The test drives rst_n through `cb`, so it changes 1 ns after a rising edge,
// as the specification asks. rst_n starts at 0, which holds the router in
// reset through the first rising edges until the test lets it go.

interface router_sys_if (input logic clk);
  logic rst_n = 1'b0;
  logic irq;

  int unsigned cycle = 1;
  always @(posedge clk) cycle <= cycle + 1;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output rst_n;
    input  cycle;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst_n, irq, cycle;
  endclocking
endinterface
