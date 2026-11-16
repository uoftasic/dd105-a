// DD105-A Lab 07: the virtual sequences.
//
// A virtual sequence runs on router_vsequencer and drives every agent at
// once: the register model (and raw APB transfers for bad addresses), the
// source, the sinks' backpressure, and reset. router_base_vseq has the
// helpers; each sequence below it sets up one part of the specification
// and pushes the router into its corners. None of them checks anything
// itself: the scoreboard and the assertions check every cycle of every run,
// so a sequence only has to make the interesting thing happen.
//
// Two sequences are yours to write in this lab, and their bodies are empty:
// router_reset_vseq (TODO Part 5) and router_saturate_vseq (TODO Part 6).
// Their tests exist already, and an empty body fails on the golden design
// with "nothing was checked". Two more TODOs put your work into the random
// sequence (Part 5) and into router_all_vseq, the test that check-all and
// the hunt grade (Parts 5 and 6).

package router_seq_pkg;
  import uvm_pkg::*;
  import apb_pkg::*;
  import stream_pkg::*;
  import router_ral_pkg::*;
  import router_env_pkg::*;
  `include "uvm_macros.svh"

  class router_base_vseq extends uvm_sequence;
    `uvm_object_utils(router_base_vseq)
    `uvm_declare_p_sequencer(router_vsequencer)

    router_reg_block regs;
    uvm_status_e     st;

    function new(string name = "router_base_vseq");
      super.new(name);
    endfunction

    task body();
      regs = p_sequencer.regs;
    endtask

    // ── time ───────────────────────────────────────────────────────────────
    task cycles(int n);
      repeat (n) @(p_sequencer.vif.mon_cb);
    endtask

    // ── reset ──────────────────────────────────────────────────────────────
    // rst_n low for n cycles. The router forgets its configuration, so the
    // register model goes back to its reset values too.
    task reset(int n = 3);
      router_reset_seq rs = router_reset_seq::type_id::create("rs");
      rs.cycles = n;
      rs.start(p_sequencer.sys_sqr, this);
      regs.reset();
      p_sequencer.predictor.flush();
    endtask

    // ── registers ──────────────────────────────────────────────────────────
    task wr(uvm_reg r, uvm_reg_data_t v);
      r.write(st, v, .parent(this));
      if (st != UVM_IS_OK)
        `uvm_error("VSEQ", $sformatf("writing %s returned %s", r.get_name(), st.name()))
    endtask

    task rd(uvm_reg r, output uvm_reg_data_t v);
      r.read(st, v, .parent(this));
      if (st != UVM_IS_OK)
        `uvm_error("VSEQ", $sformatf("reading %s returned %s", r.get_name(), st.name()))
    endtask

    task rd_(uvm_reg r);
      uvm_reg_data_t v;
      rd(r, v);
    endtask

    task rd_all();
      rd_(regs.id);
      rd_(regs.ctrl);
      rd_(regs.status);
      rd_(regs.int_en);
      rd_(regs.drop_cnt);
      rd_(regs.level);
      foreach (regs.route[n]) rd_(regs.route[n]);
    endtask

    task route(int n, bit en, bit port);
      wr(regs.route[n], {port, en});
    endtask

    task ctrl(bit en);
      wr(regs.ctrl, en);
    endtask

    // A transfer to any address, good or bad, outside the register model.
    task raw(bit write, bit [7:0] addr, bit [31:0] data = 0, int unsigned idle = 0);
      apb_rw_seq s = apb_rw_seq::type_id::create("raw");
      s.write = write;
      s.addr  = addr;
      s.wdata = data;
      s.idle  = idle;
      s.start(p_sequencer.apb_sqr, this);
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

    task send_rand(int n, bit [3:0] mask = 4'hF, int gap_pct = 25, int w_over = 10);
      stream_rand_seq s = stream_rand_seq::type_id::create("rand");
      s.n = n;
      s.dst_mask = mask;
      s.gap_pct = gap_pct;
      s.w_over = w_over;
      s.start(p_sequencer.src_sqr, this);
    endtask

    // ── the sinks ──────────────────────────────────────────────────────────
    function void sink(int p, snk_mode_e mode, bit stall = 0);
      p_sequencer.snk_cfg[p].mode  = mode;
      p_sequencer.snk_cfg[p].stall = stall;
    endfunction

    function void stall(int p, bit on);
      p_sequencer.snk_cfg[p].stall = on;
    endfunction

    // Let both outputs empty: fast sinks, then wait until the model holds no
    // beats for a few cycles in a row. A router that keeps beats forever is
    // reported, and the test goes on.
    task drain(int budget = 3000);
      int quiet = 0, n = 0;
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
  // Smoke: one configuration, a few dozen packets, every register read.
  // ══════════════════════════════════════════════════════════════════════════
  class router_smoke_vseq extends router_base_vseq;
    `uvm_object_utils(router_smoke_vseq)
    function new(string name = "router_smoke_vseq");
      super.new(name);
    endfunction
    task body();
      stream_pkt ps[$];
      super.body();
      reset(4);
      rd_all();                    // every register at its reset value
      route(0, 1, 0);              // DST 0 to output 0
      route(1, 1, 1);              // DST 1 to output 1
      route(2, 0, 1);              // DST 2 disabled (PORT set anyway)
      route(3, 1, 0);              // DST 3 to output 0
      wr(regs.int_en, 3'b111);
      ctrl(1);
      sink(0, SNK_RANDOM);
      sink(1, SNK_RANDOM);
      ps.push_back(stream_pkt::make(0, 3, 1));
      ps.push_back(stream_pkt::make(1, 1, 2));
      ps.push_back(stream_pkt::make(3, 8, 3));
      ps.push_back(stream_pkt::make(2, 2, 4));
      send_list(ps);
      send_rand(40);
      rd_all();
      drain();
      rd_all();
      wr(regs.status, 3'b111);
      wr(regs.drop_cnt, 0);
      rd_all();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // FULL: the admission threshold, from both sides, and independent outputs.
  // ══════════════════════════════════════════════════════════════════════════
  class router_full_vseq extends router_base_vseq;
    `uvm_object_utils(router_full_vseq)
    function new(string name = "router_full_vseq");
      super.new(name);
    endfunction
    task body();
      super.body();
      reset(3);
      route(0, 1, 0);
      route(1, 1, 1);
      route(2, 1, 0);
      route(3, 1, 1);
      wr(regs.int_en, 3'b010);
      ctrl(1);
      sink(1, SNK_FAST);

      // Nine 1-beat packets into a stalled output 0 are admitted at levels 0
      // to 8; the tenth finds level 9 and is dropped (E5).
      sink(0, SNK_FAST, 1);
      burst(0, 9, 1, 1);
      cycles(3);
      rd_(regs.level);
      burst(0, 1, 2, 10);
      rd_(regs.status);
      rd_(regs.drop_cnt);
      // Output 1 keeps going while output 0 is stalled (O7).
      burst(1, 4, 3, 20);
      burst(3, 2, 8, 30);
      cycles(12);
      rd_(regs.level);
      drain();

      // Two 8-beat packets: the second is admitted at exactly 8 and fills the
      // buffer to 16; the next packet for output 0 is dropped.
      stall(0, 1);
      burst(0, 2, 8, 1);
      burst(2, 1, 1, 3);
      cycles(3);
      rd_(regs.level);
      rd_(regs.drop_cnt);
      drain();

      // 8 beats, then a 1-beat packet at level 8 (admitted, level 9), then an
      // 8-beat packet at level 9 (dropped, all its beats taken anyway).
      stall(0, 1);
      burst(0, 1, 8, 1);
      burst(0, 1, 1, 2);
      burst(0, 1, 8, 3);
      rd_(regs.level);
      // Headers arriving in the cycles the sink starts taking beats again:
      // the decision uses the level before that cycle's handshake.
      fork
        burst(2, 14, 1, 10);
        begin
          cycles(3);
          sink(0, SNK_FAST, 0);
        end
      join
      drain();

      // A disabled route whose PORT names a full output: NOROUTE, never FULL.
      // ROUTE1 is disabled with PORT = 0 while output 0 holds 9 beats, and
      // a FULL drop for DST 0 follows each one.
      route(1, 0, 0);
      wr(regs.drop_cnt, 0);
      wr(regs.status, 3'b111);
      stall(0, 1);
      burst(0, 9, 1, 40);
      for (int k = 0; k < 4; k++) begin
        burst(1, 1, 3, 50 + k);
        burst(0, 1, 1, 60 + k);
      end
      rd_(regs.drop_cnt);
      rd_(regs.status);
      route(1, 1, 1);
      drain();

      // The same threshold on output 1, with random gaps and backpressure.
      sink(1, SNK_SLOW);
      send_rand(30, 4'b1010, 10, 0);
      rd_(regs.level);
      rd_(regs.drop_cnt);
      drain();
      rd_all();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Oversize packets: cut to 8, the tail thrown away, STATUS.OVERSIZE.
  // ══════════════════════════════════════════════════════════════════════════
  class router_oversize_vseq extends router_base_vseq;
    `uvm_object_utils(router_oversize_vseq)
    function new(string name = "router_oversize_vseq");
      super.new(name);
    endfunction
    task body();
      stream_pkt p, ps[$];
      super.body();
      reset(3);
      route(0, 1, 0);
      route(1, 1, 1);
      route(2, 0, 0);
      route(3, 1, 1);
      wr(regs.int_en, 3'b100);
      ctrl(1);
      sink(0, SNK_FAST);
      sink(1, SNK_RANDOM);

      burst(0, 1, 9, 1);           // the shortest oversize packet
      cycles(4);
      rd_(regs.status);
      wr(regs.status, 3'b100);
      burst(0, 1, 8, 2);           // exactly 8: not oversize
      burst(1, 1, 10, 3);          // E6
      burst(1, 1, 1, 4);           // the next packet is handled normally
      burst(3, 1, 20, 5);
      burst(2, 1, 12, 6);          // oversize and NOROUTE: counted once, both bits
      rd_(regs.status);
      rd_(regs.drop_cnt);
      wr(regs.status, 3'b111);

      // Oversize with idle cycles inside it, and back to back with others.
      p = stream_pkt::make(0, 11, 7);
      foreach (p.gap[i]) p.gap[i] = i % 3;
      ps.push_back(p);
      ps.push_back(stream_pkt::make(0, 9, 8));
      ps.push_back(stream_pkt::make(1, 9, 9));
      ps.push_back(stream_pkt::make(0, 1, 10));
      ps.push_back(stream_pkt::make(3, 16, 11));
      send_list(ps);

      // Oversize while output 1 is full: a FULL drop and OVERSIZE.
      sink(1, SNK_FAST, 1);
      burst(1, 9, 1, 20);
      burst(1, 1, 13, 30);
      rd_(regs.status);
      rd_(regs.drop_cnt);
      drain();
      rd_all();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // CTRL.EN: the input stops and starts only between packets (E7).
  // ══════════════════════════════════════════════════════════════════════════
  class router_ctrl_vseq extends router_base_vseq;
    `uvm_object_utils(router_ctrl_vseq)
    function new(string name = "router_ctrl_vseq");
      super.new(name);
    endfunction
    task body();
      stream_pkt p, ps[$];
      super.body();
      reset(3);
      route(0, 1, 0);
      route(1, 1, 1);
      sink(0, SNK_FAST);
      sink(1, SNK_FAST);

      // CTRL.EN is 0 after reset: a header offered now waits.
      fork
        burst(0, 1, 3, 1);
        begin
          cycles(20);
          rd_(regs.ctrl);
          ctrl(1);
        end
      join

      // E7: CTRL.EN cleared while a packet with idle cycles is coming in. It
      // finishes; the next header waits until CTRL.EN is set again.
      p = stream_pkt::make(0, 8, 2);
      foreach (p.gap[i]) p.gap[i] = (i == 0) ? 0 : 2;
      ps.push_back(p);
      ps.push_back(stream_pkt::make(1, 2, 3));
      fork
        send_list(ps);
        begin
          cycles(4);
          ctrl(0);
          cycles(40);
          ctrl(1);
        end
      join

      // CTRL written while 1-beat packets go in back to back, one per cycle,
      // so some writes complete in the cycle of a header.
      fork
        burst(0, 60, 1, 0);
        begin
          cycles(5);
          ctrl(0);
          cycles(6);
          ctrl(1);
          cycles(3);
          ctrl(0);
          cycles(2);
          ctrl(1);
          ctrl(0);
          ctrl(1);
        end
      join

      // The same with longer packets and random gaps.
      fork
        send_rand(30, 4'b0011, 30, 5);
        repeat (8) begin
          cycles($urandom_range(15, 2));
          ctrl(0);
          cycles($urandom_range(10, 1));
          ctrl(1);
        end
      join
      ctrl(1);
      drain();
      rd_all();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Same-cycle rules: a write and an event in the same cycle.
  // ══════════════════════════════════════════════════════════════════════════
  class router_same_cycle_vseq extends router_base_vseq;
    `uvm_object_utils(router_same_cycle_vseq)
    function new(string name = "router_same_cycle_vseq");
      super.new(name);
    endfunction
    task body();
      super.body();
      reset(3);
      wr(regs.int_en, 3'b011);
      ctrl(1);
      sink(0, SNK_FAST);
      sink(1, SNK_FAST);

      // E9: every route is disabled and 1-beat packets drop one per cycle, so
      // the DROP_CNT write completes in the cycle of a drop.
      fork
        burst(1, 30, 1, 0);
        begin
          cycles(10);
          wr(regs.drop_cnt, 32'hFFFF_FFFF);
          rd_(regs.drop_cnt);
        end
      join
      rd_(regs.drop_cnt);

      // A STATUS write that clears NOROUTE in the cycle another drop sets it.
      fork
        burst(2, 30, 1, 0);
        begin
          cycles(10);
          wr(regs.status, 3'b001);
          rd_(regs.status);
        end
      join
      rd_(regs.status);
      wr(regs.status, 3'b111);

      // ROUTE written while its packets go in one per cycle: the header in
      // the write's completion cycle uses the old entry.
      fork
        burst(1, 60, 1, 0);
        begin
          cycles(6);
          route(1, 1, 0);
          cycles(5);
          route(1, 1, 1);
          cycles(4);
          route(1, 0, 1);
          route(1, 1, 0);
        end
      join
      // INT_EN written while events keep coming.
      fork
        burst(3, 30, 1, 0);
        begin
          cycles(4);
          wr(regs.int_en, 3'b000);
          wr(regs.int_en, 3'b001);
          wr(regs.status, 3'b001);
        end
      join

      // LEVEL read while beats go in: a beat accepted in a read's first access
      // cycle isn't in the value it returns.
      route(0, 1, 0);
      sink(0, SNK_FAST, 1);
      fork
        burst(0, 2, 4, 0);
        repeat (6) rd_(regs.level);
      join
      sink(0, SNK_RANDOM, 0);
      fork
        send_rand(20, 4'b0001, 0, 0);
        repeat (20) rd_(regs.level);
      join
      drain();
      rd_all();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Saturation: both counters to 255, and clears.
  // ══════════════════════════════════════════════════════════════════════════
  class router_saturate_vseq extends router_base_vseq;
    `uvm_object_utils(router_saturate_vseq)
    function new(string name = "router_saturate_vseq");
      super.new(name);
    endfunction
    task body();
      super.body();
      // TODO (Part 6): drive both drop counters to 255 and past it, and read
      // them on the way, so that these corners happen:
      //
      //   C_NOROUTE_SATURATED  a NOROUTE drop with NOROUTE_CNT already 255
      //   C_FULL_SATURATED     a FULL drop with FULL_CNT already 255
      //
      // A 1-beat packet for a disabled route is a drop per cycle; a FULL drop
      // needs its output stalled (sink(p, SNK_FAST, 1)) and holding more than
      // 8 beats first. Clear the counters with a write and read them after.
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Registers: reset values, access policies, reserved bits, all 256 addresses.
  // ══════════════════════════════════════════════════════════════════════════
  class router_regs_vseq extends router_base_vseq;
    `uvm_object_utils(router_regs_vseq)
    function new(string name = "router_regs_vseq");
      super.new(name);
    endfunction
    task set_nonzero();
      ctrl(1);
      wr(regs.int_en, 3'b111);
      foreach (regs.route[n]) route(n, 1, n[0]);
    endtask
    task body();
      bit [31:0] pats[8] = '{32'hFFFF_FFFF, 32'h0000_0000, 32'h5555_5555, 32'hAAAA_AAAA,
                            32'h0000_0001, 32'h0000_0002, 32'h0000_0004, 32'hFFFF_FFFE};
      super.body();
      reset(3);
      rd_all();

      // Read every address with the read-write registers at their reset values
      // and then with them set, so that a bad address that aliases a register
      // returns something other than 0.
      for (int a = 0; a < 256; a++) raw(0, 8'(a));
      set_nonzero();
      for (int a = 0; a < 256; a++) raw(0, 8'(a), 0, a % 2);

      // Write zeros to every bad address, then all ones, and read the good
      // registers after each pass: a bad write changes nothing.
      for (int a = 0; a < 256; a++)
        if (!router_model::good_addr(8'(a))) raw(1, 8'(a), 32'h0, a % 3);
      rd_all();
      reset(2);
      for (int a = 0; a < 256; a++)
        if (!router_model::good_addr(8'(a))) raw(1, 8'(a), 32'hFFFF_FFFF);
      rd_all();

      // Read-write registers: patterns written and read back; reserved bits
      // read 0. ID and LEVEL ignore writes (written outside the model, whose
      // map has them read-only).
      foreach (pats[i]) begin
        wr(regs.ctrl, pats[i]);
        wr(regs.int_en, pats[i]);
        foreach (regs.route[n]) wr(regs.route[n], pats[i] >> n);
        raw(1, 8'h00, pats[i]);
        raw(1, 8'h14, pats[i]);
        rd_all();
      end
      // STATUS and DROP_CNT written with everything: STATUS has nothing set,
      // and DROP_CNT clears whatever the value.
      wr(regs.status, 32'hFFFF_FFFF);
      wr(regs.drop_cnt, 32'hFFFF_FFFF);
      rd_all();

      // Back-to-back transfers: no idle cycle between them.
      for (int i = 0; i < 40; i++)
        raw(i % 2, (i % 4 == 3) ? 8'h0C : 8'(4 * (i % 12)), $urandom, 0);
      rd_all();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Reset with packets in flight (E8), in the middle of APB transfers, and
  // with a packet half delivered.
  // ══════════════════════════════════════════════════════════════════════════
  class router_reset_vseq extends router_base_vseq;
    `uvm_object_utils(router_reset_vseq)
    function new(string name = "router_reset_vseq");
      super.new(name);
    endfunction
    task setup();
      route(0, 1, 0);
      route(1, 1, 1);
      route(2, 1, 0);
      route(3, 1, 1);
      wr(regs.int_en, 3'b111);
      ctrl(1);
    endtask
    task body();
      super.body();
      // TODO (Part 5): reset the router with traffic in flight, and check
      // nothing from before the reset comes out after it. Every other
      // sequence resets only at its start, when the buffers are empty.
      // Reach at least these, each followed by setup() and more traffic:
      //
      //   example E8: output 0 stalled with a packet waiting in its buffer,
      //     and the next packet half accepted when reset(2) starts
      //     (C_RESET_WITH_BEATS, C_RESET_MID_PACKET). Then let the sink take
      //     beats again: nothing should come out.
      //   a reset while register transfers are going on (fork a loop of
      //     reads and writes beside a reset; rule A4)
      //   a reset with output 1 part way through delivering an 8-beat packet
      //     to a slow sink
      //
      // reset() also puts the register model back to its reset values. A
      // transfer abandoned by the reset leaves the model's mirror unsure of
      // that register, so call regs.reset() once more after a fork that
      // resets in the middle of register traffic.
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Interrupt: each STATUS bit against each INT_EN setting.
  // ══════════════════════════════════════════════════════════════════════════
  class router_irq_vseq extends router_base_vseq;
    `uvm_object_utils(router_irq_vseq)
    function new(string name = "router_irq_vseq");
      super.new(name);
    endfunction
    task body();
      super.body();
      reset(3);
      route(0, 1, 0);
      route(1, 0, 0);
      ctrl(1);
      sink(0, SNK_FAST);
      sink(1, SNK_FAST);
      for (int en = 0; en < 8; en++) begin
        wr(regs.int_en, en);
        burst(1, 1, 1, 0);                 // NOROUTE
        burst(0, 1, 9, 1);                 // OVERSIZE
        sink(0, SNK_FAST, 1);
        burst(0, 10, 1, 2);                // the tenth is a FULL drop
        rd_(regs.status);
        wr(regs.int_en, 3'b000);           // irq falls with its enable
        wr(regs.int_en, en);               // and rises again
        wr(regs.status, 3'b001);           // clear one bit at a time
        cycles(2);
        wr(regs.status, 3'b100);
        wr(regs.status, 3'b010);
        rd_(regs.status);
        drain();
      end
      rd_all();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Random: random configurations, traffic, backpressure, register traffic
  // and the occasional reset, all at once. +N=<packets> (default 1200),
  // +PHASES=<n> (default 6).
  // ══════════════════════════════════════════════════════════════════════════
  class router_rand_vseq extends router_base_vseq;
    `uvm_object_utils(router_rand_vseq)
    int unsigned n_pkts = 1200;
    int unsigned n_phases = 6;
    bit          traffic_done;

    function new(string name = "router_rand_vseq");
      super.new(name);
    endfunction

    task random_config();
      foreach (regs.route[n]) route(n, $urandom_range(99) < 80, $urandom_range(1));
      wr(regs.int_en, $urandom_range(7));
      ctrl(1);
    endtask

    task reg_traffic();
      while (!traffic_done) begin
        int k = $urandom_range(99);
        cycles($urandom_range(30));
        if (traffic_done) break;
        if      (k < 25) rd_(regs.status);
        else if (k < 45) rd_(regs.drop_cnt);
        else if (k < 60) rd_(regs.level);
        else if (k < 66) wr(regs.status, $urandom_range(7));
        else if (k < 70) wr(regs.drop_cnt, $urandom);
        else if (k < 78) route($urandom_range(3), $urandom_range(99) < 75, $urandom_range(1));
        else if (k < 82) wr(regs.int_en, $urandom_range(7));
        else if (k < 86) begin
          ctrl(0);
          cycles($urandom_range(20));
          ctrl(1);
        end
        else if (k < 90) raw(0, 8'($urandom));
        else if (k < 92) raw(1, 8'h30 + 8'($urandom_range(200)), $urandom);
        else             rd_all();
      end
    endtask

    task sink_traffic();
      while (!traffic_done) begin
        for (int p = 0; p < 2; p++) begin
          int k = $urandom_range(99);
          if      (k < 40) sink(p, SNK_RANDOM);
          else if (k < 60) sink(p, SNK_FAST);
          else if (k < 75) sink(p, SNK_SLOW);
          else             sink(p, SNK_FAST, 1);     // stalled
        end
        cycles($urandom_range(250, 30));
      end
    endtask

    task body();
      int unsigned per;
      super.body();
      void'($value$plusargs("N=%d", n_pkts));
      void'($value$plusargs("PHASES=%d", n_phases));
      if (n_phases == 0) n_phases = 1;
      per = n_pkts / n_phases;
      reset(3);
      random_config();
      for (int ph = 0; ph < n_phases; ph++) begin
        `uvm_info("VSEQ", $sformatf("random phase %0d of %0d: %0d packets", ph + 1, n_phases, per),
                  UVM_LOW)
        traffic_done = 0;
        fork
          begin
            send_rand(per, 4'hF, $urandom_range(40), $urandom_range(15));
            traffic_done = 1;
          end
          reg_traffic();
          sink_traffic();
          // TODO (Part 5): in about a third of the phases after the first,
          // a fourth thread here that waits 50 to 400 cycles, resets the
          // router for 1 to 4 cycles, and sets up a random configuration
          // again. Say so in the phase's uvm_info line above.
        join
        if ($urandom_range(1)) drain();
        if ($urandom_range(1)) random_config();
      end
      drain();
      rd_all();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // All of the above, one after another: the test check-all grades.
  // ══════════════════════════════════════════════════════════════════════════
  class router_all_vseq extends router_base_vseq;
    `uvm_object_utils(router_all_vseq)
    function new(string name = "router_all_vseq");
      super.new(name);
    endfunction
    task run(router_base_vseq s);
      `uvm_info("VSEQ", {"starting ", s.get_type_name()}, UVM_LOW)
      s.start(p_sequencer, this);
    endtask
    task body();
      router_rand_vseq r;
      super.body();
      run(router_smoke_vseq::type_id::create("smoke"));
      run(router_regs_vseq::type_id::create("regs"));
      run(router_full_vseq::type_id::create("full"));
      run(router_oversize_vseq::type_id::create("oversize"));
      run(router_ctrl_vseq::type_id::create("ctrl"));
      run(router_same_cycle_vseq::type_id::create("same_cycle"));
      // TODO (Part 6): router_saturate_vseq here.
      run(router_irq_vseq::type_id::create("irq"));
      // TODO (Part 5): router_reset_vseq here.
      r = router_rand_vseq::type_id::create("rand");
      r.n_pkts = 600;
      r.n_phases = 4;
      run(r);
    endtask
  endclass
endpackage
