// DD105-A Lab 04: the router's ports as three interfaces.
//
//   apb_if         the APB register port; the testbench is the master
//   stream_src_if  the input stream; the testbench is the source and drives valid
//   stream_snk_if  an output stream; the testbench is the sink and drives ready
//
// Each interface has two clocking blocks. A driver uses `cb`: it drives the
// testbench's signals 1 ns after a rising edge and reads the router's with
// #1step, which is the value a signal had just before the edge, the value
// "in the cycle" in the specification's sense. A monitor uses `mon_cb`, which
// reads every signal that way and drives nothing.
//
// `cycle` numbers the clock cycles as the specification does: cycle n is the
// period that ends at rising edge n, so read through a clocking block at edge
// n it gives n. Every interface keeps its own copy, and they agree because
// they count the same clock from time 0. The monitors stamp each beat with it.

interface apb_if (input logic clk, input logic rst_n);
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
    input  prdata, pready, pslverr;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr, rst_n, cycle;
  endclocking
endinterface

// The input stream. The testbench drives valid, data and last.
interface stream_src_if (input logic clk, input logic rst_n);
  logic       valid = 1'b0;
  logic       ready;
  logic [7:0] data  = 8'h00;
  logic       last  = 1'b0;

  int unsigned cycle = 1;
  always @(posedge clk) cycle <= cycle + 1;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output valid, data, last;
    input  ready;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid, ready, data, last, rst_n, cycle;
  endclocking
endinterface

// An output stream. The testbench drives ready. It starts at 1, so an output
// with no agent on it takes every beat the moment it appears.
interface stream_snk_if (input logic clk, input logic rst_n);
  logic       valid;
  logic       ready = 1'b1;
  logic [7:0] data;
  logic       last;

  int unsigned cycle = 1;
  always @(posedge clk) cycle <= cycle + 1;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output ready;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid, ready, data, last, rst_n, cycle;
  endclocking
endinterface
