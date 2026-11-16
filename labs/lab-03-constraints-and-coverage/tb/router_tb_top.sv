// DD105-A Lab 03: the top module.
//
// A 10 ns clock, the four interfaces, the router, and run_test(). The test
// gets the interfaces from uvm_config_db and hands them to the testbench's
// classes when it creates them.

module router_tb_top;
  import uvm_pkg::*;
  import router_test_pkg::*;
  `include "uvm_macros.svh"

  logic clk = 1'b0;
  always #5 clk = ~clk;

  router_sys_if sys  (clk);
  apb_if        apb  (clk, sys.rst_n);
  stream_src_if in_s (clk, sys.rst_n);
  stream_snk_if out0 (clk, sys.rst_n);
  stream_snk_if out1 (clk, sys.rst_n);

  router dut (
    .clk       (clk),
    .rst_n     (sys.rst_n),
    .psel      (apb.psel),
    .penable   (apb.penable),
    .pwrite    (apb.pwrite),
    .paddr     (apb.paddr),
    .pwdata    (apb.pwdata),
    .prdata    (apb.prdata),
    .pready    (apb.pready),
    .pslverr   (apb.pslverr),
    .irq       (sys.irq),
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
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top", "apb_vif", apb);
    uvm_config_db#(virtual stream_src_if)::set(null, "uvm_test_top", "src_vif", in_s);
    uvm_config_db#(virtual stream_snk_if)::set(null, "uvm_test_top", "snk0_vif", out0);
    uvm_config_db#(virtual stream_snk_if)::set(null, "uvm_test_top", "snk1_vif", out1);
    uvm_config_db#(virtual router_sys_if)::set(null, "uvm_test_top", "sys_vif", sys);
    run_test();
  end
endmodule
