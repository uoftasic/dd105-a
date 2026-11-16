// DD105-A guide example, "Virtual sequences": the testbench.
//
// Two things drive the FIFO: a source agent (a sequencer and a driver, which
// sends one beat per item) and a sink driver that sets out_ready each cycle
// from a knob, ready_pct, in a configuration object. Neither knows about the
// other. vs_vsequencer holds a handle to each, and vs_demo_vseq, which runs
// on it, makes them work together in three steps:
//
//   1  stall the sink, send six beats, and release the sink while the source
//      is still blocked on a full FIFO
//   2  send 30 beats while a second branch changes the sink's readiness
//   3  start two sequences on the source's sequencer at the same time
//
// The monitor checks that the beats come out in the order they went in.

interface vs_if (input logic clk, input logic rst_n);
  logic       in_valid, in_ready, out_valid, out_ready;
  logic [7:0] in_data, out_data;
  logic [2:0] level;
  clocking src_cb @(posedge clk);
    default input #1step output #1;
    output in_valid, in_data;
    input  in_ready;
  endclocking
  clocking snk_cb @(posedge clk);
    default input #1step output #1;
    output out_ready;
    input  out_valid;
  endclocking
  clocking mon_cb @(posedge clk);
    default input #1step;
    input in_valid, in_ready, in_data, out_valid, out_ready, out_data, level;
  endclocking
endinterface

package vs_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ── the source agent's pieces ─────────────────────────────────────────────
  class src_item extends uvm_sequence_item;
    `uvm_object_utils(src_item)
    bit [7:0]      data;
    rand bit [1:0] gap;     // idle cycles before the beat
    function new(string name = "src_item");
      super.new(name);
    endfunction
  endclass

  // n beats, numbered from base.
  class src_seq extends uvm_sequence #(src_item);
    `uvm_object_utils(src_seq)
    int unsigned n;
    bit [7:0]    base;
    function new(string name = "src_seq");
      super.new(name);
    endfunction
    task body();
      src_item it;
      int      ok;
      for (int i = 0; i < n; i++) begin
        it = src_item::type_id::create("it");
        start_item(it);
        ok = it.randomize();
        if (ok == 0) `uvm_fatal("RAND", "src_item randomize() failed")
        it.data = base + 8'(i);
        finish_item(it);
      end
    endtask
  endclass

  class src_driver extends uvm_driver #(src_item);
    `uvm_component_utils(src_driver)
    virtual vs_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      vif.src_cb.in_valid <= 1'b0;
      forever begin
        seq_item_port.get_next_item(req);
        @(vif.src_cb);                         // drive from a clock edge
        repeat (int'(req.gap)) @(vif.src_cb);
        vif.src_cb.in_valid <= 1'b1;
        vif.src_cb.in_data  <= req.data;
        do @(vif.src_cb); while (!vif.src_cb.in_ready);
        vif.src_cb.in_valid <= 1'b0;
        seq_item_port.item_done();
      end
    endtask
  endclass

  // ── the sink: a driver with a knob, and no sequence ───────────────────────
  class snk_cfg extends uvm_object;
    `uvm_object_utils(snk_cfg)
    int unsigned ready_pct = 100;
    function new(string name = "snk_cfg");
      super.new(name);
    endfunction
  endclass

  class snk_driver extends uvm_component;
    `uvm_component_utils(snk_driver)
    virtual vs_if vif;
    snk_cfg       cfg;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        @(vif.snk_cb);
        vif.snk_cb.out_ready <= ($urandom_range(99) < cfg.ready_pct);
      end
    endtask
  endclass

  // ── the monitor, which is also the checker ────────────────────────────────
  class vs_monitor extends uvm_monitor;
    `uvm_component_utils(vs_monitor)
    virtual vs_if vif;
    bit [7:0]     sent[$];     // beats taken by the FIFO, not yet out
    bit [7:0]     taken[$];    // every beat the sink took, in order
    int unsigned  n_in, n_bad;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      bit [7:0] want;
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.out_valid && vif.mon_cb.out_ready) begin
          want = sent.pop_front();
          taken.push_back(vif.mon_cb.out_data);
          if (vif.mon_cb.out_data != want) begin
            n_bad++;
            `uvm_error("ORDER", $sformatf("out_data %h, expected %h", vif.mon_cb.out_data, want))
          end
        end
        if (vif.mon_cb.in_valid && vif.mon_cb.in_ready) begin
          sent.push_back(vif.mon_cb.in_data);
          n_in++;
        end
      end
    endtask
    function void report_phase(uvm_phase phase);
      `uvm_info("MON", $sformatf("%0d beats in, %0d out, %0d out of order", n_in, taken.size(), n_bad), UVM_LOW)
    endfunction
  endclass

  // ── the virtual sequencer: handles, and nothing else ──────────────────────
  class vs_vsequencer extends uvm_sequencer;
    `uvm_component_utils(vs_vsequencer)
    uvm_sequencer #(src_item) src_sqr;
    snk_cfg                   snk;
    vs_monitor                mon;
    virtual vs_if             vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class vs_env extends uvm_env;
    `uvm_component_utils(vs_env)
    uvm_sequencer #(src_item) src_sqr;
    src_driver                src_drv;
    snk_driver                snk_drv;
    vs_monitor                mon;
    vs_vsequencer             vsqr;
    snk_cfg                   cfg;
    virtual vs_if             vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual vs_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "no virtual vs_if in config_db")
      cfg     = snk_cfg::type_id::create("cfg");
      src_sqr = uvm_sequencer#(src_item)::type_id::create("src_sqr", this);
      src_drv = src_driver::type_id::create("src_drv", this);
      snk_drv = snk_driver::type_id::create("snk_drv", this);
      mon     = vs_monitor::type_id::create("mon", this);
      vsqr    = vs_vsequencer::type_id::create("vsqr", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      src_drv.seq_item_port.connect(src_sqr.seq_item_export);
      src_drv.vif  = vif;
      snk_drv.vif  = vif;
      snk_drv.cfg  = cfg;
      mon.vif      = vif;
      vsqr.src_sqr = src_sqr;
      vsqr.snk     = cfg;
      vsqr.mon     = mon;
      vsqr.vif     = vif;
    endfunction
  endclass

  // ── the virtual sequences ─────────────────────────────────────────────────
  class vs_base_vseq extends uvm_sequence;
    `uvm_object_utils(vs_base_vseq)
    `uvm_declare_p_sequencer(vs_vsequencer)
    bit traffic_done;
    function new(string name = "vs_base_vseq");
      super.new(name);
    endfunction
    task cycles(int unsigned n);
      repeat (n) @(p_sequencer.vif.snk_cb);
    endtask
    // n beats from base, through the source agent; returns when the last has gone in.
    task send(int unsigned n, bit [7:0] base);
      src_seq s = src_seq::type_id::create($sformatf("src_%h", base));
      s.n    = n;
      s.base = base;
      s.start(p_sequencer.src_sqr, this);
    endtask
    function void sink(int unsigned pct);
      p_sequencer.snk.ready_pct = pct;
      `uvm_info("VSEQ", $sformatf("sink ready %0d%% of cycles", pct), UVM_LOW)
    endfunction
  endclass

  class vs_demo_vseq extends vs_base_vseq;
    `uvm_object_utils(vs_demo_vseq)
    function new(string name = "vs_demo_vseq");
      super.new(name);
    endfunction
    task body();
      int unsigned pick[3] = '{0, 30, 100};
      int unsigned mark;
      string       s;

      // Step 1: six beats into a stalled FIFO, and a release from another branch.
      sink(0);
      fork
        begin
          send(6, 8'h10);
          `uvm_info("VSEQ", "step 1: all 6 beats have gone in", UVM_LOW)
        end
        begin
          cycles(15);
          `uvm_info("VSEQ", $sformatf("step 1: the FIFO holds %0d beats", p_sequencer.vif.level), UVM_LOW)
          sink(100);
        end
      join
      cycles(10);

      // Step 2: traffic and backpressure at the same time.
      traffic_done = 0;
      fork
        begin
          send(30, 8'h40);
          traffic_done = 1;
          `uvm_info("VSEQ", "step 2: all 30 beats have gone in", UVM_LOW)
        end
        while (!traffic_done) begin
          sink(pick[$urandom_range(2)]);
          cycles($urandom_range(12, 4));
        end
      join
      sink(100);
      cycles(10);

      // Step 3: two sequences on one sequencer at once.
      mark = p_sequencer.mon.taken.size();
      fork
        send(4, 8'h80);
        send(4, 8'hA0);
      join
      cycles(10);
      for (int i = mark; i < p_sequencer.mon.taken.size(); i++)
        s = {s, $sformatf(" %h", p_sequencer.mon.taken[i])};
      `uvm_info("VSEQ", {"step 3: the sink took", s}, UVM_LOW)
    endtask
  endclass

  class vs_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(vs_test)
    vs_env env;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = vs_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      vs_demo_vseq v = vs_demo_vseq::type_id::create("v");
      phase.raise_objection(this);
      @(posedge env.vif.rst_n);
      v.start(env.vsqr);
      phase.drop_objection(this);
    endtask
  endclass
endpackage

module vseq_tb_top;
  import uvm_pkg::*;
  import vs_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst_n = 1'b0;
  initial begin
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;
  end

  vs_if sif (clk, rst_n);
  fifo4 dut (
    .clk(clk), .rst_n(rst_n),
    .in_valid(sif.in_valid), .in_ready(sif.in_ready), .in_data(sif.in_data),
    .out_valid(sif.out_valid), .out_ready(sif.out_ready), .out_data(sif.out_data),
    .level(sif.level)
  );

  initial begin
    uvm_config_db#(virtual vs_if)::set(null, "uvm_test_top.env", "vif", sif);
    run_test();
  end
endmodule
