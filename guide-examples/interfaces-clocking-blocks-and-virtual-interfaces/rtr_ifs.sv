// DD105-A guide example: Interfaces, clocking blocks and virtual interfaces
// (docs/guide/interfaces-clocking-blocks-and-virtual-interfaces.md).
//
// rtr_pins_if  the router's APB port, its input stream and both outputs'
//              ready, with one clocking block for the class that drives them.
// rtr_mon_if   four of the router's signals as a monitor sees them: all
//              inputs, with two identical clocking blocks, so that each can
//              be read one way only (see typedef_test).

interface rtr_pins_if (input logic clk, input logic rst_n);
  logic        psel = 1'b0, penable = 1'b0, pwrite = 1'b0;
  logic [7:0]  paddr  = 8'h00;
  logic [31:0] pwdata = 32'h0;
  logic [31:0] prdata;
  logic        pready, pslverr;
  logic        in_valid = 1'b0, in_last = 1'b0;
  logic [7:0]  in_data  = 8'h00;
  logic        in_ready;
  logic        out0_valid, out0_last, out1_valid, out1_last;
  logic [7:0]  out0_data, out1_data;
  logic        out0_ready = 1'b1, out1_ready = 1'b1;

  // Inputs are sampled at #1step, the value just before the rising edge.
  // Outputs change 1 ns after the rising edge.
  clocking cb @(posedge clk);
    default input #1step output #1;
    output psel, penable, pwrite, paddr, pwdata, in_valid, in_data, in_last;
    input  pready, in_ready, out0_valid, out0_data, rst_n;
  endclocking
endinterface

interface rtr_mon_if (input logic clk, input logic rst_n, input logic in_ready,
                      input logic out0_valid);
  clocking cb_a @(posedge clk);
    default input #1step;
    input rst_n, in_ready, out0_valid;
  endclocking
  clocking cb_b @(posedge clk);
    default input #1step;
    input rst_n, in_ready, out0_valid;
  endclocking
endinterface
