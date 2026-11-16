// DD105-A Lab 06: the router's ports as three interfaces, one for the
// assertions' failure count, and one for reset and the interrupt.
//
//   apb_if         the APB register port; the testbench is the master
//   stream_src_if  the input stream; the testbench is the source and drives valid
//   stream_snk_if  an output stream; the testbench is the sink and drives ready
//   router_sva_if  how many times the bound assertions have failed (Lab 05)
//   router_sys_if  rst_n and irq, which the sys monitor reports every cycle (Lab 06)
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

// Lab 05: the number of failures the assertions bound into the router
// (router_sva.sv) have counted so far. The top module assigns it from
// dut.u_sva.n_fail, and the scoreboard reads it at the end of the test: a
// class in a package can't name a module instance, but it can hold a
// virtual interface.
interface router_sva_if;
  int unsigned n_fail;
endinterface

// Lab 06: reset and the interrupt. The top module drives rst_n, as it has
// since Lab 04, and wires the router's irq here; the sys monitor reports
// both in every cycle, so the scoreboard can check irq cycle by cycle.
interface router_sys_if (input logic clk, input logic rst_n);
  logic irq;

  int unsigned cycle = 1;
  always @(posedge clk) cycle <= cycle + 1;

  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst_n, irq, cycle;
  endclocking
endinterface
