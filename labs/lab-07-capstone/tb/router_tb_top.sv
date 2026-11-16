// DD105-A Lab 07: the top module.
//
// A 10 ns clock, a reset, the five interfaces, the router, and run_test().
// As in Lab 02, run_test() builds whichever test +UVM_TESTNAME names. The
// top module hands each agent its virtual interface through config_db, so
// no test has to fetch the interfaces and pass them down itself.
//
// Lab 05 binds the assertions in router_sva.sv into the router
// (router_sva_bind.sv), and passes their failure count, dut.u_sva.n_fail,
// to the scoreboard through router_sva_if.
//
// Lab 06 wires irq to router_sys_if, whose monitor reports it every cycle.
//
// Lab 07 lets the testbench reset the router again later: rst_n is low
// while either the reset at time 0 or the reset driver (rst_req_n in
// router_sys_if) holds it low. The APB driver gets router_sys_if too, for
// its warning that a reset is coming.

module router_tb_top;
  import uvm_pkg::*;
  import router_tests_pkg::*;
  `include "uvm_macros.svh"

  logic clk = 1'b0;
  always #5 clk = ~clk;

  // The reset at time 0 is low through the first three rising edges and
  // goes high 1 ns after the third, so every cycle is wholly in reset or
  // wholly out of it (spec, Reset). Lab 07: the reset driver can pull rst_n
  // low again at any time after that.
  logic rst_init_n = 1'b0;
  initial begin
    repeat (3) @(posedge clk);
    #1 rst_init_n = 1'b1;
  end
  wire rst_n;

  apb_if        apb  (clk, rst_n);
  stream_src_if in_s (clk, rst_n);
  stream_snk_if out0 (clk, rst_n);
  stream_snk_if out1 (clk, rst_n);
  router_sva_if sva  ();
  router_sys_if sys  (clk, rst_n);

  assign rst_n = rst_init_n && sys.rst_req_n;

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

  assign sva.n_fail = dut.u_sva.n_fail;

  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.apb*", "vif", apb);
    uvm_config_db#(virtual stream_src_if)::set(null, "uvm_test_top.env.src*", "vif", in_s);
    uvm_config_db#(virtual stream_snk_if)::set(null, "uvm_test_top.env.out0*", "vif", out0);
    uvm_config_db#(virtual stream_snk_if)::set(null, "uvm_test_top.env.out1*", "vif", out1);
    uvm_config_db#(virtual router_sva_if)::set(null, "uvm_test_top.env.sb", "sva", sva);
    uvm_config_db#(virtual router_sys_if)::set(null, "uvm_test_top.env.sys*", "vif", sys);
    uvm_config_db#(virtual router_sys_if)::set(null, "uvm_test_top.env.apb.drv", "sys_vif", sys);
    run_test();
  end
endmodule
