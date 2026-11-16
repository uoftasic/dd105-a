// DD105-A Lab 07: the router's valid/ready streams.
//
// Two interfaces, one per direction, so that each signal has exactly one
// driver: on the input stream the testbench drives valid, data and last and
// the router drives ready; on an output stream it's the other way round.
// Both have the same `mon_cb`, which samples all four signals with #1step,
// so one monitor class (stream_pkg) watches any of the three streams.

// The input stream. The testbench is the source.
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
    input  ready, rst_n;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid, ready, data, last, rst_n, cycle;
  endclocking
endinterface

// An output stream. The testbench is the sink.
interface stream_snk_if (input logic clk, input logic rst_n);
  logic       valid;
  logic       ready = 1'b0;
  logic [7:0] data;
  logic       last;

  int unsigned cycle = 1;
  always @(posedge clk) cycle <= cycle + 1;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output ready;
    input  valid, rst_n;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input valid, ready, data, last, rst_n, cycle;
  endclocking
endinterface
