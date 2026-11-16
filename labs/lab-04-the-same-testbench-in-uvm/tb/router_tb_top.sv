// DD105-A Lab 04: the top module.
//
// A 10 ns clock, a reset, the four interfaces, the router, and run_test().
// As in Lab 02, run_test() builds whichever test +UVM_TESTNAME names. The
// top module hands each agent its virtual interface through config_db, so
// no test has to fetch the interfaces and pass them down itself.

module router_tb_top;
  import uvm_pkg::*;
  import router_tests_pkg::*;
  `include "uvm_macros.svh"

  logic clk = 1'b0;
  always #5 clk = ~clk;

  // Reset is low through the first three rising edges and goes high 1 ns
  // after the third, so every cycle is wholly in reset or wholly out of it
  // (spec, Reset). The tests don't reset the router again.
  logic rst_n = 1'b0;
  initial begin
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;
  end

  apb_if        apb  (clk, rst_n);
  stream_src_if in_s (clk, rst_n);
  stream_snk_if out0 (clk, rst_n);
  stream_snk_if out1 (clk, rst_n);
  logic         irq;

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
    .irq       (irq),
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
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.apb*", "vif", apb);
    uvm_config_db#(virtual stream_src_if)::set(null, "uvm_test_top.env.src*", "vif", in_s);
    uvm_config_db#(virtual stream_snk_if)::set(null, "uvm_test_top.env.out0*", "vif", out0);
    uvm_config_db#(virtual stream_snk_if)::set(null, "uvm_test_top.env.out1*", "vif", out1);
    run_test();
  end
endmodule
