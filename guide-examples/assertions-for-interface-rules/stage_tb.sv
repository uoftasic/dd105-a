// DD105-A guide example, "Assertions for interface rules": the testbench.
//
// stage_test drives random beats into the stage and a random out_ready, for
// CYCLES cycles (default 200). Plusargs:
//
//   +READY_PCT=n   out_ready is 1 in n percent of cycles (default 50)
//   +CYCLES=n      how many cycles to run
//   +IGNORE_SVA    don't turn the checker's failure count into a UVM_ERROR
//
// The source keeps S1 and S2 itself: a beat it offers stays on in_data, with
// in_valid at 1, until the stage takes it.

interface stage_if (input logic clk, input logic rst_n);
  logic       in_valid, in_ready;
  logic [7:0] in_data;
  logic       out_valid, out_ready;
  logic [7:0] out_data;
  int unsigned n_fail, n_tried, n_covered;   // copied from the checker
  // The test drives 1 ns after each rising edge and reads the values the
  // signals had just before it.
  clocking cb @(posedge clk);
    default input #1step output #1;
    output in_valid, in_data, out_ready;
    input  in_ready, out_valid, out_data;
  endclocking
endinterface

package stage_tests_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class stage_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(stage_test)
    virtual stage_if vif;
    int unsigned n_cycles  = 200;
    int unsigned ready_pct = 50;
    int unsigned valid_pct = 70;
    int unsigned n_in, n_out;
    bit          ignore_sva;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual stage_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "no virtual stage_if in config_db")
      void'($value$plusargs("READY_PCT=%d", ready_pct));
      void'($value$plusargs("CYCLES=%d", n_cycles));
      ignore_sva = $test$plusargs("IGNORE_SVA");
    endfunction

    task run_phase(uvm_phase phase);
      bit       v = 0;      // in_valid in the cycle that just ended
      bit [7:0] d = 0;      // in_data
      bit       r = 0;      // out_ready in the cycle that just ended
      phase.raise_objection(this);
      @(posedge vif.rst_n);
      repeat (n_cycles) begin
        @(vif.cb);
        // What moved at the edge that ended the last cycle?
        if (v && vif.cb.in_ready) begin v = 0; n_in++; end
        if (r && vif.cb.out_valid) n_out++;
        // The next cycle: a new beat if the last one was taken, and a coin
        // flip for out_ready.
        if (!v && $urandom_range(99) < valid_pct) begin v = 1; d++; end
        r = ($urandom_range(99) < ready_pct);
        vif.cb.in_valid  <= v;
        vif.cb.in_data   <= d;
        vif.cb.out_ready <= r;
      end
      phase.drop_objection(this);
    endtask

    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (vif.n_fail > 0 && !ignore_sva)
        `uvm_error("SVA", $sformatf("the bound assertions counted %0d failures", vif.n_fail))
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("STAGE", $sformatf("%0d beats in, %0d out; a beat waited in %0d cycles (cover property: %0d); %0d assertion failures",
                n_in, n_out, vif.n_tried, vif.n_covered, vif.n_fail), UVM_LOW)
    endfunction
  endclass
endpackage

module stage_tb_top;
  import uvm_pkg::*;
  import stage_tests_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  // Low through the first three rising edges, high 1 ns after the third.
  logic rst_n = 1'b0;
  initial begin
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;
  end

  stage_if sif (clk, rst_n);

  stage dut (
    .clk(clk), .rst_n(rst_n),
    .in_valid(sif.in_valid), .in_ready(sif.in_ready), .in_data(sif.in_data),
    .out_valid(sif.out_valid), .out_ready(sif.out_ready), .out_data(sif.out_data)
  );

  assign sif.n_fail    = dut.u_sva.n_fail;
  assign sif.n_tried   = dut.u_sva.n_tried;
  assign sif.n_covered = dut.u_sva.n_covered;

  initial begin
    uvm_config_db#(virtual stage_if)::set(null, "uvm_test_top", "vif", sif);
    run_test();
  end
endmodule
