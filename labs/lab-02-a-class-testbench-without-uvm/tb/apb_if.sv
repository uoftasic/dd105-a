// DD105-A Lab 02: the router's APB port.
//
// The testbench is the APB master. It drives psel, penable, pwrite, paddr and
// pwdata through the clocking block 1 ns after each rising edge, and samples
// pready (and the other slave outputs) with #1step, the value each one had
// just before the edge. This lab only writes the configuration at the start
// of the test, so nothing here reads prdata.

interface apb_if (input logic clk, input logic rst_n);
  logic        psel    = 1'b0;
  logic        penable = 1'b0;
  logic        pwrite  = 1'b0;
  logic [7:0]  paddr   = 8'h00;
  logic [31:0] pwdata  = 32'h0;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output psel, penable, pwrite, paddr, pwdata;
    input  prdata, pready, pslverr, rst_n;
  endclocking
endinterface
