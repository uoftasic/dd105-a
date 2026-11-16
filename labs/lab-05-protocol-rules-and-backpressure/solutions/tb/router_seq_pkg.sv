// DD105-A Lab 05: the virtual sequences.
//
// A virtual sequence runs on router_vsequencer and drives every agent at
// once: register reads and writes through the APB agent, packets through the
// source, the sinks' backpressure through their configuration, and reset.
//
//   router_base_vseq    the helpers every sequence below uses
//   router_lab04_vseq   Lab 04's stimulus, moved out of the test
//   router_lab05_vseq   this lab's: backpressure, oversize packets, and a
//                       configuration that changes under traffic
//   router_main_vseq    the two, one after the other: what router_test runs
//
// None of them checks anything itself. The scoreboard and the assertions
// check every cycle of every run, so a sequence only has to make the
// interesting thing happen.

package router_seq_pkg;
  import uvm_pkg::*;
  import apb_pkg::*;
  import stream_pkg::*;
  import router_env_pkg::*;
  `include "uvm_macros.svh"

  // Register addresses (docs/reference/router-spec.md, "Register map").
  localparam bit [7:0] A_ID = 8'h00, A_CTRL = 8'h04, A_STATUS = 8'h08, A_INT_EN = 8'h0C,
                       A_DROP_CNT = 8'h10, A_LEVEL = 8'h14, A_ROUTE0 = 8'h20;

  class router_base_vseq extends uvm_sequence;
    `uvm_object_utils(router_base_vseq)
    `uvm_declare_p_sequencer(router_vsequencer)

    bit traffic_done;              // set by a sequence when its packets are all sent

    function new(string name = "router_base_vseq");
      super.new(name);
    endfunction

    task body();
    endtask

    // ── time ───────────────────────────────────────────────────────────────
    // n clock cycles. Each wait ends at a rising edge.
    task cycles(int n);
      repeat (n) @(p_sequencer.vif.mon_cb);
    endtask

    // ── reset ──────────────────────────────────────────────────────────────
    // rst_n low for n cycles. The router forgets its configuration, so a
    // sequence sets it up again afterwards.
    task reset(int n = 3);
      router_reset_seq rs = router_reset_seq::type_id::create("rs");
      rs.cycles = n;
      rs.start(p_sequencer.sys_sqr, this);
    endtask

    // ── registers ──────────────────────────────────────────────────────────
    // One APB transfer. The scoreboard checks every read against its model,
    // so a read here is a check, and nothing needs the value.
    task raw(bit write, bit [7:0] addr, bit [31:0] data = 0, int unsigned idle = 0);
      apb_rw_seq s = apb_rw_seq::type_id::create("raw");
      s.write = write;
      s.addr  = addr;
      s.wdata = data;
      s.idle  = idle;
      s.start(p_sequencer.apb_sqr, this);
    endtask

    task wr(bit [7:0] addr, bit [31:0] data);
      raw(1, addr, data);
    endtask

    task rd(bit [7:0] addr);
      raw(0, addr);
    endtask

    // Routing table entry n: EN and PORT.
    task route(int n, bit en, bit port);
      wr(A_ROUTE0 + 8'(4 * n), {30'b0, port, en});
    endtask

    task ctrl(bit en);
      wr(A_CTRL, {31'b0, en});
    endtask

    // ── stimulus ───────────────────────────────────────────────────────────
    task send(stream_pkt p);
      stream_list_seq s = stream_list_seq::type_id::create("one");
      s.pkts.push_back(p);
      s.start(p_sequencer.src_sqr, this);
    endtask

    task send_list(stream_pkt ps[$]);
      stream_list_seq s = stream_list_seq::type_id::create("list");
      s.pkts = ps;
      s.start(p_sequencer.src_sqr, this);
    endtask

    // n packets of len beats to DST d, back to back, tags counting from tag0.
    task burst(bit [1:0] d, int n, int len = 1, int tag0 = 0);
      stream_pkt ps[$];
      for (int i = 0; i < n; i++) ps.push_back(stream_pkt::make(d, len, 6'(tag0 + i)));
      send_list(ps);
    endtask

    // n random packets. mask: the DSTs allowed (bit d for DST d). gap_pct:
    // how often a beat has idle cycles before it. w_over: the weight of
    // oversize packets (9 to 14 beats) against 90 for the legal lengths.
    task send_rand(int n, bit [3:0] mask = 4'hF, int gap_pct = 25, int w_over = 0);
      stream_rand_seq s = stream_rand_seq::type_id::create("rand");
      s.n = n;
      s.dst_mask = mask;
      s.gap_pct = gap_pct;
      s.w_over = w_over;
      s.start(p_sequencer.src_sqr, this);
    endtask

    // ── the sinks ──────────────────────────────────────────────────────────
    // Sink p's mode from now on; stall = 1 also holds its ready at 0.
    function void sink(int p, snk_mode_e mode, bit stall = 0);
      p_sequencer.snk_cfg[p].mode  = mode;
      p_sequencer.snk_cfg[p].stall = stall;
    endfunction

    function void stall(int p, bit on);
      p_sequencer.snk_cfg[p].stall = on;
    endfunction

    // Both sinks stalled (on = 1) or released, from the same cycle. It waits
    // for a rising edge first, so that both drivers see the change at the
    // same falling edge and the two ready signals stay equal.
    task stall_both(bit on);
      cycles(1);
      stall(0, on);
      stall(1, on);
    endtask

    // Let both outputs empty: both sinks fast, then wait until the scoreboard's
    // model holds no beats for a few cycles in a row. A router that keeps beats
    // forever is reported, and the test goes on.
    task drain(int budget = 3000);
      int quiet = 0, n = 0;
      cycles(1);
      sink(0, SNK_FAST);
      sink(1, SNK_FAST);
      while (quiet < 4 && n < budget) begin
        cycles(1);
        n++;
        quiet = p_sequencer.sb.idle() ? quiet + 1 : 0;
      end
      if (quiet < 4)
        `uvm_error("DRAIN", $sformatf("after %0d cycles with both sinks always ready, beats are still waiting to come out", budget))
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Lab 04's stimulus, moved out of the test's run_phase into a virtual
  // sequence. The steps are the same. Both sinks are stalled and released
  // together, so the two out_ready signals are always equal.
  // ══════════════════════════════════════════════════════════════════════════
  class router_lab04_vseq extends router_base_vseq;
    `uvm_object_utils(router_lab04_vseq)
    function new(string name = "router_lab04_vseq");
      super.new(name);
    endfunction
    task body();
      super.body();
      reset(4);
      // Every DST does something different: two go to output 0, one to
      // output 1, and one is disabled.
      route(0, 1, 0);
      route(1, 1, 1);
      route(2, 0, 1);
      route(3, 1, 0);
      ctrl(1);

      // Random packets of 1 to 8 beats, with idle cycles between beats.
      send_rand(150);
      drain();
      rd(A_DROP_CNT);
      rd(A_STATUS);

      // Nine 1-beat packets into a stalled output 0 are admitted at levels
      // 0 to 8; the tenth finds level 9 and is a FULL drop (E5). Output 1 is
      // empty all the while.
      stall_both(1);
      burst(0, 9, 1, 1);
      cycles(3);
      rd(A_LEVEL);
      burst(0, 1, 2, 10);
      rd(A_DROP_CNT);
      drain();

      // The other way round: output 1 holds nine beats and output 0 is
      // empty, so packets for output 0 are admitted.
      stall_both(1);
      burst(1, 9, 1, 20);
      burst(0, 2, 3, 30);
      cycles(3);
      rd(A_LEVEL);
      rd(A_DROP_CNT);
      drain();

      // Two 8-beat packets: the second is admitted at exactly 8 and fills
      // output 0 to 16, and the next packet for it is a FULL drop.
      stall_both(1);
      burst(0, 2, 8, 40);
      burst(3, 1, 1, 42);
      rd(A_LEVEL);
      rd(A_DROP_CNT);
      drain();

      // A disabled route whose PORT names a full output: NOROUTE, never FULL.
      route(2, 0, 0);
      stall_both(1);
      burst(0, 9, 1, 50);
      burst(2, 3, 2, 60);
      rd(A_DROP_CNT);
      rd(A_STATUS);
      drain();

      // Enough traffic to wrap both buffers several times over.
      route(2, 1, 1);
      send_rand(150);
      drain();
      rd(A_DROP_CNT);
      rd(A_LEVEL);
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Lab 05: backpressure, oversize packets, and a configuration that changes
  // while packets are in flight.
  // ══════════════════════════════════════════════════════════════════════════
  class router_lab05_vseq extends router_base_vseq;
    `uvm_object_utils(router_lab05_vseq)
    function new(string name = "router_lab05_vseq");
      super.new(name);
    endfunction

    // Until traffic_done, each sink changes its mode every 30 to 250 cycles,
    // on its own: random, fast, slow or stalled.
    task backpressure();
      while (!traffic_done) begin
        for (int p = 0; p < 2; p++) begin
          int k = $urandom_range(99);
          if      (k < 40) sink(p, SNK_RANDOM);
          else if (k < 60) sink(p, SNK_FAST);
          else if (k < 80) sink(p, SNK_SLOW);
          else             sink(p, SNK_FAST, 1);
        end
        cycles($urandom_range(250, 30));
      end
    endtask

    task body();
      super.body();
      reset(3);
      // 1. The configuration: every route enabled, two DSTs to each output.
      route(0, 1, 0);
      route(1, 1, 1);
      route(2, 1, 0);
      route(3, 1, 1);
      ctrl(1);

      // 2. One output stalled while the other runs, then the other way round.
      sink(0, SNK_FAST, 1);
      sink(1, SNK_FAST);
      burst(1, 4, 3, 0);
      burst(0, 2, 3, 10);
      cycles(10);
      drain();
      sink(0, SNK_FAST);
      sink(1, SNK_FAST, 1);
      burst(0, 4, 3, 20);
      burst(1, 2, 3, 30);
      cycles(10);
      drain();

      // 3. Oversize packets to every route, with random backpressure. Each
      //    should come out cut to 8 beats, the 8th with out_last.
      sink(0, SNK_RANDOM);
      sink(1, SNK_RANDOM);
      burst(0, 1, 9, 40);
      burst(1, 1, 12, 41);
      burst(2, 2, 10, 42);
      burst(3, 1, 20, 44);
      drain();

      // 4. Everything at once: random packets, oversize ones among them,
      //    while each sink changes its mode on its own and two routes move
      //    to the other output and back.
      traffic_done = 0;
      fork
        begin
          send_rand(300, 4'hF, 20, 15);
          traffic_done = 1;
        end
        backpressure();
        begin
          cycles(150);
          route(1, 1, 0);
          cycles(150);
          route(2, 1, 1);
          cycles(150);
          route(1, 1, 1);
          route(2, 1, 0);
        end
      join
      drain();
      rd(A_DROP_CNT);
      rd(A_STATUS);
      rd(A_LEVEL);
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Lab 04's steps, then Lab 05's: the test make check grades.
  // ══════════════════════════════════════════════════════════════════════════
  class router_main_vseq extends router_base_vseq;
    `uvm_object_utils(router_main_vseq)
    function new(string name = "router_main_vseq");
      super.new(name);
    endfunction
    task body();
      router_lab04_vseq lab04 = router_lab04_vseq::type_id::create("lab04");
      router_lab05_vseq lab05 = router_lab05_vseq::type_id::create("lab05");
      super.body();
      `uvm_info("VSEQ", "starting Lab 04's steps", UVM_LOW)
      lab04.start(p_sequencer, this);
      `uvm_info("VSEQ", "starting Lab 05's steps", UVM_LOW)
      lab05.start(p_sequencer, this);
    endtask
  endclass
endpackage
