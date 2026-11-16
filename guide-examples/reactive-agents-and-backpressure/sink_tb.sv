// DD105-A guide example, "Reactive agents and backpressure": the testbench.
//
// The design decides when each beat appears; the sink agent decides when each
// one is taken. The sink has two modes, chosen with +MODE=:
//
//   coin   in every cycle ready is 1 with probability READY_PCT percent,
//          whether or not a beat is on offer (Lab 04's sink)
//   beat   a reactive sink: each beat is answered by one item from the sink's
//          sequence, and the item says how many cycles the beat waits
//
// Plusargs: +MODE=coin|beat (default coin), +READY_PCT=n (default 50),
// +MAX_DELAY=n (the longest wait an item asks for, default 12), +BEATS=n
// (how many beats to take before the test ends, default 2000), and
// +URANDOM, which picks each item's delay with $urandom_range instead of
// randomize(), so that the constraint solver plays no part.
//
// The monitor counts how long each beat waited, from its first cycle on offer
// to its handshake, and checks that the beats arrive in order.

interface snk_if (input logic clk, input logic rst_n);
  logic       valid, ready;
  logic [7:0] data;
  // The driver's: drive ready 1 ns after each rising edge.
  clocking cb @(posedge clk);
    default input #1step output #1;
    output ready;
    input  valid, data;
  endclocking
  // The monitor's: every signal as it was just before the edge.
  clocking mcb @(posedge clk);
    default input #1step;
    input valid, ready, data;
  endclocking
endinterface

package sink_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum int {SNK_COIN, SNK_BEAT} snk_mode_e;

  // The sink's knobs. The agent's driver and sequence both read it, so a test
  // or a virtual sequence can change the backpressure while the test runs.
  class snk_cfg extends uvm_object;
    `uvm_object_utils(snk_cfg)
    snk_mode_e   mode      = SNK_COIN;
    int unsigned ready_pct = 50;
    int unsigned max_delay = 12;
    bit          use_urandom;
    function new(string name = "snk_cfg");
      super.new(name);
    endfunction
  endclass

  // What the sink does for one beat: how many cycles the beat waits after it
  // first appears. 0 means ready is already 1 when the beat appears.
  class snk_item extends uvm_sequence_item;
    `uvm_object_utils(snk_item)
    rand bit [4:0] delay;
    int unsigned   max_delay = 12;
    constraint c_delay { int'(delay) <= max_delay; }
    function new(string name = "snk_item");
      super.new(name);
    endfunction
  endclass

  // One item per beat, for as long as the test runs. The agent starts it and
  // raises no objection for it, so it never keeps the test alive.
  class snk_seq extends uvm_sequence #(snk_item);
    `uvm_object_utils(snk_seq)
    snk_cfg cfg;
    function new(string name = "snk_seq");
      super.new(name);
    endfunction
    task body();
      snk_item it;
      int      ok;
      forever begin
        it = snk_item::type_id::create("it");
        start_item(it);
        it.max_delay = cfg.max_delay;
        if (cfg.use_urandom) begin
          it.delay = 5'($urandom_range(cfg.max_delay));
        end else begin
          ok = it.randomize();
          if (ok == 0) `uvm_fatal("RAND", "snk_item randomize() failed")
        end
        finish_item(it);
      end
    endtask
  endclass

  class snk_driver extends uvm_driver #(snk_item);
    `uvm_component_utils(snk_driver)
    virtual snk_if vif;
    snk_cfg        cfg;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      snk_item     it;        // the item for the beat on offer, or for the next one
      int unsigned left;      // cycles that beat still has to wait
      bit          rdy = 0;   // ready in the cycle that starts at the next edge
      forever begin
        // A rising edge: drive ready for the cycle that starts here.
        @(vif.cb);
        if (cfg.mode == SNK_COIN) rdy = ($urandom_range(99) < cfg.ready_pct);
        vif.cb.ready <= rdy;
        if (cfg.mode == SNK_COIN) continue;
        // The middle of the cycle: valid and ready are settled.
        @(negedge vif.clk);
        if (vif.valid && rdy) begin              // the beat moves at the next edge
          seq_item_port.item_done();
          it = null;
        end else if (vif.valid && it != null && left > 0) begin
          left--;                                // one more cycle waited
        end
        if (it == null) begin
          seq_item_port.try_next_item(it);       // returns at once, with or without an item
          if (it != null) left = int'(it.delay);
        end
        rdy = (it != null) && (left == 0);
      end
    endtask
  endclass

  class snk_monitor extends uvm_monitor;
    `uvm_component_utils(snk_monitor)
    virtual snk_if vif;
    int unsigned   n;            // beats taken
    int unsigned   hist[41];     // hist[w]: beats that waited w cycles (40: 40 or more)
    int unsigned   total_wait;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      int unsigned w = 0;
      bit [7:0]    expect_data = 0;
      forever begin
        @(vif.mcb);
        if (!vif.rst_n) continue;
        if (vif.mcb.valid && !vif.mcb.ready) w++;
        if (vif.mcb.valid && vif.mcb.ready) begin
          if (vif.mcb.data != expect_data)
            `uvm_error("ORDER", $sformatf("took beat %0d, expected %0d", vif.mcb.data, expect_data))
          expect_data = vif.mcb.data + 8'd1;
          hist[w > 40 ? 40 : w]++;
          total_wait += w;
          n++;
          w = 0;
        end
      end
    endtask
  endclass

  class snk_agent extends uvm_agent;
    `uvm_component_utils(snk_agent)
    uvm_sequencer #(snk_item) sqr;
    snk_driver                drv;
    snk_monitor               mon;
    snk_cfg                   cfg;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      virtual snk_if vif;
      super.build_phase(phase);
      if (!uvm_config_db#(virtual snk_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "no virtual snk_if in config_db")
      if (!uvm_config_db#(snk_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "no snk_cfg in config_db")
      sqr = uvm_sequencer#(snk_item)::type_id::create("sqr", this);
      drv = snk_driver::type_id::create("drv", this);
      mon = snk_monitor::type_id::create("mon", this);
      drv.vif = vif;
      drv.cfg = cfg;
      mon.vif = vif;
    endfunction
    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
    // The sink's sequence runs from the start of the test to the end.
    task run_phase(uvm_phase phase);
      snk_seq s = snk_seq::type_id::create("s");
      s.cfg = cfg;
      s.start(sqr);
    endtask
  endclass

  class sink_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(sink_test)
    snk_agent      snk;
    snk_cfg        cfg;
    virtual snk_if vif;
    int unsigned   n_beats = 2000;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      string m;
      super.build_phase(phase);
      cfg = snk_cfg::type_id::create("cfg");
      if ($value$plusargs("MODE=%s", m) && m == "beat") cfg.mode = SNK_BEAT;
      void'($value$plusargs("READY_PCT=%d", cfg.ready_pct));
      void'($value$plusargs("MAX_DELAY=%d", cfg.max_delay));
      void'($value$plusargs("BEATS=%d", n_beats));
      cfg.use_urandom = $test$plusargs("URANDOM");
      if (!uvm_config_db#(virtual snk_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "no virtual snk_if in config_db")
      uvm_config_db#(snk_cfg)::set(this, "snk", "cfg", cfg);
      uvm_config_db#(virtual snk_if)::set(this, "snk", "vif", vif);
      snk = snk_agent::type_id::create("snk", this);
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      while (snk.mon.n < n_beats) @(posedge vif.clk);
      phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
      int unsigned b0, b1, b4, b21;
      string       s = "";
      string       what;
      super.report_phase(phase);
      foreach (snk.mon.hist[w]) begin
        if      (w == 0) b0  += snk.mon.hist[w];
        else if (w <= 3) b1  += snk.mon.hist[w];
        else if (w <= 20) b4 += snk.mon.hist[w];
        else             b21 += snk.mon.hist[w];
        s = {s, $sformatf(" %0d", snk.mon.hist[w])};
      end
      if (cfg.mode == SNK_COIN)
        what = $sformatf("coin-flip sink at %0d%%", cfg.ready_pct);
      else if (cfg.use_urandom)
        what = $sformatf("per-beat sink, delays 0 to %0d from $urandom_range", cfg.max_delay);
      else
        what = $sformatf("per-beat sink, delays 0 to %0d from randomize()", cfg.max_delay);
      `uvm_info("WAIT", $sformatf("%s: %0d beats; waited 0: %0d, 1 to 3: %0d, 4 to 20: %0d, more than 20: %0d; mean %0.2f cycles",
                what, snk.mon.n, b0, b1, b4, b21, real'(snk.mon.total_wait) / snk.mon.n), UVM_LOW)
      `uvm_info("HIST", {"beats that waited 0, 1, ..., 39, 40 or more cycles:", s}, UVM_LOW)
    endfunction
  endclass
endpackage

module sink_tb_top;
  import uvm_pkg::*;
  import sink_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst_n = 1'b0;
  initial begin
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;
  end

  snk_if sif (clk, rst_n);
  beat_src dut (.clk(clk), .rst_n(rst_n), .valid(sif.valid), .ready(sif.ready), .data(sif.data));

  initial begin
    uvm_config_db#(virtual snk_if)::set(null, "uvm_test_top", "vif", sif);
    run_test();
  end
endmodule
