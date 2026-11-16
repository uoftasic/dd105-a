// DD105-A Lab 05: the virtual sequences.
//
// A virtual sequence runs on router_vsequencer and drives every agent from
// one place: register writes and reads through the APB agent, packets
// through the source agent, and each sink's backpressure through its
// out_cfg.
//
//   router_base_vseq   the steps every virtual sequence uses, written on
//                      Lab 04's sequences (apb_rw_seq, router_rand_seq,
//                      router_one_seq)
//   router_lab05_vseq  this lab's: backpressure, oversize packets, and
//                      routes that move while packets are coming in (Part 4)
//
// This is the reference solution: router_lab05_vseq::body() is filled in.
//
// None of them checks anything itself. The scoreboard and the assertions
// check every cycle of every run, so a sequence only has to make the
// interesting thing happen.

package router_vseq_pkg;
  import uvm_pkg::*;
  import router_agents_pkg::*;
  import router_env_pkg::*;
  `include "uvm_macros.svh"

  // The steps are the base test's (Lab 04), rewritten as a sequence's
  // tasks: a virtual sequence can't call the test's tasks, but it reaches
  // every sequencer through p_sequencer.
  class router_base_vseq extends uvm_sequence;
    `uvm_object_utils(router_base_vseq)
    `uvm_declare_p_sequencer(router_vsequencer)

    bit [3:0]    route_en;        // the EN bits this sequence has written, for the packets' c_dst
    int unsigned next_tag;        // the next packet's number, for its header
    bit          traffic_done;    // set by a sequence when its packets have all gone in

    function new(string name = "router_base_vseq");
      super.new(name);
    endfunction

    task body();
    endtask

    // ── time ────────────────────────────────────────────────────────────────
    // n clock cycles; each wait ends at a rising edge.
    task cycles(int unsigned n);
      repeat (n) @(p_sequencer.vif.cb);
    endtask

    // ── registers ───────────────────────────────────────────────────────────
    // One APB transfer each, as the base test's write_reg and read_reg. The
    // scoreboard checks every DROP_CNT read, so a read is a check, and
    // nothing here needs the value.
    task wr(bit [7:0] addr, bit [31:0] data);
      apb_rw_seq s = apb_rw_seq::type_id::create("wr");
      s.write = 1;
      s.addr  = addr;
      s.wdata = data;
      s.start(p_sequencer.apb_sqr, this);
    endtask

    task rd(bit [7:0] addr);
      apb_rw_seq s = apb_rw_seq::type_id::create("rd");
      s.write = 0;
      s.addr  = addr;
      s.start(p_sequencer.apb_sqr, this);
    endtask

    // Routing table entry n: EN and PORT.
    task route(int n, bit en, bit port);
      route_en[n] = en;
      wr(A_ROUTE0 + 8'(4 * n), {30'b0, port, en});
    endtask

    task ctrl(bit en);
      wr(A_CTRL, {31'b0, en});
    endtask

    // ── packets ─────────────────────────────────────────────────────────────
    // Packets made by hand, in order, each with the next tag. Returns when
    // the last one has gone into the router.
    task send(router_pkt pkts[$]);
      router_one_seq s;
      foreach (pkts[i]) begin
        s = router_one_seq::type_id::create("one");
        pkts[i].tag     = 6'(next_tag++);
        pkts[i].data[0] = {pkts[i].hdr_dst, pkts[i].tag};
        s.pkt = pkts[i];
        s.start(p_sequencer.src_sqr, this);
      end
    endtask

    // n packets of len beats for DST d, back to back. len may be more than 8.
    task burst(bit [1:0] d, int n, int unsigned len);
      router_pkt pkts[$];
      for (int i = 0; i < n; i++) pkts.push_back(router_pkt::make(d, len));
      send(pkts);
    endtask

    // n random packets to the routes this sequence has enabled. gap_pct: how
    // often a beat waits 1 to 3 idle cycles first. w_over: the weight of
    // oversize packets (9 to 12 beats) against 100 for the other lengths.
    task send_rand(int unsigned n, int unsigned gap_pct = 25, int unsigned w_over = 0);
      router_rand_seq s = router_rand_seq::type_id::create("rand");
      s.n         = n;
      s.route_en  = route_en;
      s.first_tag = next_tag;
      s.gap_pct   = gap_pct;
      s.w_over    = w_over;
      next_tag   += n;
      s.start(p_sequencer.src_sqr, this);
    endtask

    // ── the sinks ───────────────────────────────────────────────────────────
    // Sink p's mode from now on; ready_pct matters only in SNK_PCT.
    function void sink(int p, snk_mode_e mode, int unsigned ready_pct = 100);
      p_sequencer.ocfg[p].mode      = mode;
      p_sequencer.ocfg[p].ready_pct = ready_pct;
    endfunction

    // Sink p stalled: Lab 04's sink with ready_pct 0.
    function void stall(int p);
      sink(p, SNK_PCT, 0);
    endfunction

    // The base test's drain(): both sinks always ready, then wait until the
    // scoreboard expects no more beats, or 300 cycles.
    task drain();
      sink(0, SNK_PCT, 100);
      sink(1, SNK_PCT, 100);
      for (int i = 0; i < 300 && p_sequencer.sb.outstanding() > 0; i++) cycles(1);
      cycles(4);
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Lab 05: backpressure, oversize packets, and a routing table that changes
  // while packets are coming in.
  // ══════════════════════════════════════════════════════════════════════════
  class router_lab05_vseq extends router_base_vseq;
    `uvm_object_utils(router_lab05_vseq)
    function new(string name = "router_lab05_vseq");
      super.new(name);
    endfunction

    // Until traffic_done, each sink changes its mode every 30 to 250 cycles,
    // on its own: SNK_RANDOM, SNK_FAST, SNK_SLOW or stalled.
    task backpressure();
      int k;
      while (!traffic_done) begin
        for (int p = 0; p < 2; p++) begin
          k = $urandom_range(99);
          if      (k < 40) sink(p, SNK_RANDOM);
          else if (k < 60) sink(p, SNK_FAST);
          else if (k < 80) sink(p, SNK_SLOW);
          else             stall(p);
        end
        cycles($urandom_range(250, 30));
      end
    endtask

    task body();
      // 1. The configuration: every route enabled, two DSTs to each output.
      route(0, 1, 0);
      route(1, 1, 1);
      route(2, 1, 0);
      route(3, 1, 1);
      ctrl(1);

      // 2. One output stalled while packets go to the other, then the other
      //    way round.
      stall(1);
      sink(0, SNK_FAST);
      burst(0, 4, 3);
      burst(1, 2, 3);
      cycles(10);
      drain();
      stall(0);
      sink(1, SNK_FAST);
      burst(1, 4, 3);
      burst(0, 2, 3);
      cycles(10);
      drain();

      // 3. Oversize packets to every DST, with both sinks random. Each
      //    should come out cut to 8 beats, the 8th with out_last.
      sink(0, SNK_RANDOM);
      sink(1, SNK_RANDOM);
      burst(0, 1, 9);
      burst(1, 1, 12);
      burst(2, 2, 10);
      burst(3, 1, 20);
      drain();

      // 4. Everything at once: random packets with oversize ones among them,
      //    while each sink changes its mode on its own and two routes move
      //    to the other output and back.
      traffic_done = 0;
      fork
        begin
          send_rand(300, 20, 15);
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
    endtask
  endclass
endpackage
