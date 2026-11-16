// DD105-A Lab 07: the router's APB port.
//
// The testbench is the APB master. It drives psel, penable, pwrite, paddr and
// pwdata through the clocking block `cb`, 1 ns after each rising edge, and
// samples the slave's outputs (prdata, pready, pslverr) through `cb` and
// `mon_cb` with #1step, which is the value each signal had just before the
// edge: the value "in the cycle" in the specification's sense.
//
// `cycle` numbers the clock cycles as the specification does: cycle n is the
// period that ends at rising edge n, so sampled at edge n it reads n. Every
// interface in this testbench keeps its own copy, and they all agree because
// they count the same clock from time 0.
//
// hold_at is a testbench signal, not an APB one: the first cycle of a reset
// the testbench has scheduled (0 when none is). Rule A4 says psel is 0 while
// rst_n is 0, and the driver decides each cycle's psel at the edge before
// it, so it needs to know a cycle ahead that rst_n is about to fall.

interface apb_if (input logic clk, input logic rst_n, input int unsigned hold_at);
  logic        psel    = 1'b0;
  logic        penable = 1'b0;
  logic        pwrite  = 1'b0;
  logic [7:0]  paddr   = 8'h00;
  logic [31:0] pwdata  = 32'h0;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  int unsigned cycle = 1;
  always @(posedge clk) cycle <= cycle + 1;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output psel, penable, pwrite, paddr, pwdata;
    input  prdata, pready, pslverr, rst_n, cycle;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr, rst_n, cycle;
  endclocking
endinterface
