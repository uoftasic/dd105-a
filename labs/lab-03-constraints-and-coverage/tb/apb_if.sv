// DD105-A Lab 03: the router's APB port, unchanged from Lab 02.
//
// The testbench is the APB master. It drives psel, penable, pwrite, paddr and
// pwdata through the clocking block 1 ns after each rising edge, and samples
// pready (and the other slave outputs) with #1step, the value each one had
// just before the edge. Lab 02 only wrote registers; this lab also reads
// DROP_CNT, and apb_master.read() takes prdata from this clocking block.

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
