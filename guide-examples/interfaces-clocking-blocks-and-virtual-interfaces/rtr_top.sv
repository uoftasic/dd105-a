// DD105-A guide example: the top module. A 10 ns clock, a reset, the router,
// the interfaces, and run_test().
module rtr_top;
  import uvm_pkg::*;
  import rtr_tests_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst_n = 1'b0;
  initial begin
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;
  end

  rtr_pins_if pins (clk, rst_n);
  rtr_mon_if  mon  (clk, rst_n, pins.in_ready, pins.out0_valid);

  router dut (
    .clk(clk), .rst_n(rst_n),
    .psel(pins.psel), .penable(pins.penable), .pwrite(pins.pwrite),
    .paddr(pins.paddr), .pwdata(pins.pwdata), .prdata(pins.prdata),
    .pready(pins.pready), .pslverr(pins.pslverr), .irq(),
    .in_valid(pins.in_valid), .in_ready(pins.in_ready),
    .in_data(pins.in_data), .in_last(pins.in_last),
    .out0_valid(pins.out0_valid), .out0_ready(pins.out0_ready),
    .out0_data(pins.out0_data), .out0_last(pins.out0_last),
    .out1_valid(pins.out1_valid), .out1_ready(pins.out1_ready),
    .out1_data(pins.out1_data), .out1_last(pins.out1_last));

  // When each pin the edge demo drives actually changes.
  always @(pins.in_valid) if ($time > 0) $display("%0d ns: in_valid pin changes to %0b", $time, pins.in_valid);

  initial begin
    uvm_config_db#(virtual rtr_pins_if)::set(null, "uvm_test_top", "pins_vif", pins);
    uvm_config_db#(virtual rtr_mon_if)::set(null, "uvm_test_top", "mon_vif", mon);
    run_test();
  end

  // module_task_test: one signal raised for a cycle three times by a module
  // task called in a repeat loop, and another raised the same way through a
  // clocking block. Each "<= 1" runs after the previous "<= 0", in the same
  // time step, so by the standard both signals are high at all three edges.
  logic by_task = 1'b0, by_cb = 1'b0;
  clocking pcb @(posedge clk);
    default input #1step output #1;
    output by_cb;
  endclocking
  int unsigned high_task, high_cb;
  always @(posedge clk) begin
    high_task += int'(by_task);
    high_cb   += int'(by_cb);
  end
  task automatic pulse_by_task();
    by_task <= 1'b1;
    @(posedge clk);
    by_task <= 1'b0;
  endtask
  task automatic pulse_by_cb();
    pcb.by_cb <= 1'b1;
    @(pcb);
    pcb.by_cb <= 1'b0;
  endtask
  initial if ($test$plusargs("MODULE_TASK")) begin
    @(posedge clk);
    repeat (3) pulse_by_task();
    @(pcb);
    repeat (3) pulse_by_cb();
    repeat (3) @(posedge clk);
    $display("module task, <= on the signal:           high at %0d of 3 edges", high_task);
    $display("module task, through a clocking block:   high at %0d of 3 edges", high_cb);
  end
endmodule
