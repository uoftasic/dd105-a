// DD105-A Lab 02: the router's valid/ready streams.
//
// Three interface types, so that every signal has exactly one driver:
//
//   stream_src_if  the input stream. The testbench is the source: it drives
//                  valid, data and last, and the router drives ready.
//   stream_snk_if  an output stream. The router drives valid, data and last,
//                  and the testbench is the sink: it drives ready.
//   stream_mon_if  any of the three streams, as a monitor sees it. Every
//                  signal is an input, so a class holding this interface can
//                  watch a stream and can't drive it. The top module makes
//                  one for each stream it watches and wires it to that
//                  stream's four signals.
//
// Every clocking block samples its inputs with #1step, which is the value a
// signal had just before the rising edge: the value "in the cycle" that ends
// at that edge, in the specification's sense. Outputs change 1 ns after the
// edge (output #1), so nothing the testbench drives changes at the moment
// anything is sampled.

interface stream_src_if (input logic clk, input logic rst_n);
  logic       valid = 1'b0;
  logic       ready;
  logic [7:0] data  = 8'h00;
  logic       last  = 1'b0;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output valid, data, last;
    input  ready;
  endclocking
endinterface

interface stream_snk_if (input logic clk, input logic rst_n);
  logic       valid;
  logic       ready = 1'b0;
  logic [7:0] data;
  logic       last;

  clocking cb @(posedge clk);
    default input #1step output #1;
    output ready;
    input  valid, rst_n;
  endclocking
endinterface

interface stream_mon_if (input logic       clk,
                         input logic       rst_n,
                         input logic       valid,
                         input logic       ready,
                         input logic [7:0] data,
                         input logic       last);
  clocking cb @(posedge clk);
    default input #1step;
    input rst_n, valid, ready, data, last;
  endclocking
endinterface
