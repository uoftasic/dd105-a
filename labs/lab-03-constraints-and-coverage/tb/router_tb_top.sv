// DD105-A Lab 02: the top module.
//
// A 10 ns clock, a reset at the start, the interfaces, the router, and
// run_test(). rst_n is 0 from time 0 and rises 1 ns after the third rising
// edge, as the specification asks (change it just after an edge).
//
// The testbench drives the input stream through in_s and the outputs'
// ready through out0 and out1. The monitors watch through in_mon and
// out0_mon, which carry copies of the same four signals as inputs.

module router_tb_top;
  import uvm_pkg::*;
  import router_test_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst_n = 1'b0;
  initial begin
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;
  end

  apb_if        apb  (clk, rst_n);
  stream_src_if in_s (clk, rst_n);
  stream_snk_if out0 (clk, rst_n);
  stream_snk_if out1 (clk, rst_n);

  stream_mon_if in_mon   (clk, rst_n, in_s.valid, in_s.ready, in_s.data, in_s.last);
  stream_mon_if out0_mon (clk, rst_n, out0.valid, out0.ready, out0.data, out0.last);

  router dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .psel      (apb.psel),
    .penable   (apb.penable),
    .pwrite    (apb.pwrite),
    .paddr     (apb.paddr),
    .pwdata    (apb.pwdata),
    .prdata    (apb.prdata),
    .pready    (apb.pready),
    .pslverr   (apb.pslverr),
    .irq       (),
    .in_valid  (in_s.valid),
    .in_ready  (in_s.ready),
    .in_data   (in_s.data),
    .in_last   (in_s.last),
    .out0_valid(out0.valid),
    .out0_ready(out0.ready),
    .out0_data (out0.data),
    .out0_last (out0.last),
    .out1_valid(out1.valid),
    .out1_ready(out1.ready),
    .out1_data (out1.data),
    .out1_last (out1.last)
  );

  initial begin
    uvm_config_db#(virtual stream_src_if)::set(null, "uvm_test_top", "in_vif", in_s);
    uvm_config_db#(virtual stream_snk_if)::set(null, "uvm_test_top", "out0_vif", out0);
    uvm_config_db#(virtual stream_snk_if)::set(null, "uvm_test_top", "out1_vif", out1);
    uvm_config_db#(virtual stream_mon_if)::set(null, "uvm_test_top", "in_mon_vif", in_mon);
    uvm_config_db#(virtual stream_mon_if)::set(null, "uvm_test_top", "out0_mon_vif", out0_mon);
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top", "apb_vif", apb);
    run_test();
  end
endmodule
