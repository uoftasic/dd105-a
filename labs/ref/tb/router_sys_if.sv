// DD105-A reference environment: reset, the interrupt, and the assertion count.
//
// The testbench drives rst_n through `cb`, so it changes 1 ns after a rising
// edge both ways, as the specification asks: every cycle is either wholly in
// reset or wholly out of it. rst_n starts at 0, which holds the router in
// reset through the first rising edges until the first reset item ends.
//
// rst_at is the first cycle of the reset the driver has scheduled, or 0. The
// driver sets it a cycle before rst_n falls, so the APB driver can drop psel
// in time (rule A4); the top module passes it to apb_if as hold_at.
//
// irq is the router's interrupt. sva_fails is the number of assertion
// failures the bound checker (router_sva.sv) has counted so far; the top
// module wires it up, and the scoreboard reports it at the end of the test.

interface router_sys_if (input logic clk);
  logic        rst_n = 1'b0;
  int unsigned rst_at = 0;
  logic        irq;
  int unsigned sva_fails;

  int unsigned cycle = 1;
  always @(posedge clk) cycle <= cycle + 1;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output rst_n;
    input  cycle;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst_n, irq, sva_fails, cycle;
  endclocking
endinterface
