// DD105-A Lab 06: the virtual sequences.
//
// A virtual sequence runs on router_vsequencer and drives every agent from
// one place: register writes and reads through the APB agent, as raw
// transfers or through the register model, packets through the source
// agent, and each sink's backpressure through its out_cfg.
//
//   router_base_vseq      the steps every virtual sequence uses, written on
//                         Lab 04's sequences (apb_rw_seq, router_rand_seq,
//                         router_one_seq) and, from Lab 06, the register model
//   router_lab05_vseq     Lab 05's: backpressure, oversize packets, and
//                         routes that move while packets are coming in
//   router_lab06_vseq     this lab's: the register block
//   router_backdoor_vseq  what peek and poke do on this router (Lab 06)
//
// This is the reference solution: router_lab05_vseq::body() and
// router_lab06_vseq::body() are filled in.
//
// None of them checks anything itself. The scoreboard and the assertions
// check every cycle of every run, so a sequence only has to make the
// interesting thing happen.

package router_vseq_pkg;
  import uvm_pkg::*;
  import router_agents_pkg::*;
  import router_ral_pkg::*;
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
    router_reg_block regs;        // Lab 06: the register model
    uvm_status_e     st;          // Lab 06: the status of the last register operation

    function new(string name = "router_base_vseq");
      super.new(name);
    endfunction

    // Lab 06: the register model's handle, from the virtual sequencer.
    task pre_start();
      regs = p_sequencer.regs;
    endtask

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

    // ── registers, through the register model (Lab 06) ──────────────────────
    // A write or a read of one register, by name: wr_reg(regs.ctrl, 1). The
    // adapter turns each into one APB transfer. A status other than
    // UVM_IS_OK means the transfer ended with PSLVERR, which a register in
    // the map never should.
    task wr_reg(uvm_reg r, uvm_reg_data_t v);
      r.write(st, v, .parent(this));
      if (st != UVM_IS_OK)
        `uvm_error("VSEQ", $sformatf("writing %s returned %s", r.get_name(), st.name()))
    endtask

    task rd_reg(uvm_reg r);
      uvm_reg_data_t v;
      r.read(st, v, .parent(this));
      if (st != UVM_IS_OK)
        `uvm_error("VSEQ", $sformatf("reading %s returned %s", r.get_name(), st.name()))
    endtask

    // A read that the register model compares with its mirror, whether or
    // not check-on-read is on: mirror() with UVM_CHECK reports a mismatch as
    // "value read from DUT ... does not match mirrored value".
    task check_reg(uvm_reg r);
      r.mirror(st, UVM_CHECK, .parent(this));
      if (st != UVM_IS_OK)
        `uvm_error("VSEQ", $sformatf("reading %s returned %s", r.get_name(), st.name()))
    endtask

    // Every register in the map, read through the model.
    task rd_all_regs();
      rd_reg(regs.id);
      rd_reg(regs.ctrl);
      rd_reg(regs.status);
      rd_reg(regs.int_en);
      rd_reg(regs.drop_cnt);
      rd_reg(regs.level);
      foreach (regs.route[n]) rd_reg(regs.route[n]);
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

      // 2. Output 1 stalled while packets go to both outputs, then output 0
      //    stalled instead.
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
  // ══════════════════════════════════════════════════════════════════════════
  // Lab 06: the register block, one step per part of the lab. It runs first
  // in router_test, because the reset values can only be read before
  // anything has written the registers.
  // ══════════════════════════════════════════════════════════════════════════
  class router_lab06_vseq extends router_base_vseq;
    `uvm_object_utils(router_lab06_vseq)
    function new(string name = "router_lab06_vseq");
      super.new(name);
    endfunction

    task body();
      uvm_reg_hw_reset_seq hw;           // Part 2
      uvm_reg_bit_bash_seq bb;           // Part 3

      // Part 2: the reset values. The sequence reads every register that has
      // a field it can check and compares it with the model's reset value.
      hw = uvm_reg_hw_reset_seq::type_id::create("hw_reset");
      hw.model = regs;
      hw.start(null, this);

      // Part 3: every bit of every register written and read back. Then the
      // router set up with raw APB writes, as Labs 04 and 05 do, and read
      // back through the model, which knows about them only through the
      // predictor.
      bb = uvm_reg_bit_bash_seq::type_id::create("bit_bash");
      bb.model = regs;
      bb.start(null, this);
      route(0, 1, 0);
      route(1, 1, 1);
      route(2, 0, 1);
      route(3, 1, 1);
      ctrl(1);
      check_reg(regs.ctrl);
      foreach (regs.route[n]) check_reg(regs.route[n]);

      // Part 4: the 246 addresses outside the map, which the model can't
      // reach. Each must end with PSLVERR, read 0 and change nothing.
      for (int a = 0; a < 256; a++)
        if (!good_addr(8'(a))) rd(8'(a));
      for (int a = 0; a < 256; a++)
        if (!good_addr(8'(a))) wr(8'(a), 32'hFFFF_FFFF);
      rd_all_regs();

      // Part 5: STATUS and INT_EN. DST 1 is disabled, so its packet is a
      // NOROUTE drop; a 9-beat packet is OVERSIZE; and ten packets into a
      // stalled, empty output 0 end with a FULL drop. INT_EN is 0 all the
      // while, so irq stays 0.
      route(1, 0, 0);
      sink(0, SNK_FAST);
      sink(1, SNK_FAST);
      burst(1, 1, 1);                    // NOROUTE
      burst(0, 1, 9);                    // OVERSIZE
      drain();
      stall(0);
      burst(0, 10, 1);                   // FULL
      rd_reg(regs.status);
      // Each enable on its own: irq follows the one bit it lets through.
      for (int b = 0; b < 3; b++) begin
        wr_reg(regs.int_en, uvm_reg_data_t'(1) << b);
        cycles(2);
      end
      // Every enable on, and the bits cleared one at a time: irq stays 1
      // until the last one goes.
      wr_reg(regs.int_en, 'b111);
      wr_reg(regs.status, 'b001);
      rd_reg(regs.status);
      wr_reg(regs.status, 'b100);
      rd_reg(regs.status);
      wr_reg(regs.status, 'b010);
      rd_reg(regs.status);
      drain();
      rd_all_regs();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Lab 06: the back door, peek and poke through the HDL paths in the
  // register model. router_backdoor_test runs this, and the [BACKDOOR] lines
  // in the log say what each step saw. A peek or a poke takes no simulation
  // time and sends nothing on the bus, so the scoreboard, which watches the
  // bus, never hears of a poke. So every poke here is undone by another poke
  // before anything reads the register through the front door, and the test
  // passes on the golden router. +BACKDOOR_READBACK adds one front-door read
  // of DROP_CNT while it still holds the poked value, to show what the
  // scoreboard, which checks every DROP_CNT read, makes of it.
  // ══════════════════════════════════════════════════════════════════════════
  class router_backdoor_vseq extends router_base_vseq;
    `uvm_object_utils(router_backdoor_vseq)
    function new(string name = "router_backdoor_vseq");
      super.new(name);
    endfunction

    function void say(string what, uvm_reg_data_t v);
      `uvm_info("BACKDOOR", $sformatf("%-38s %4h  (%s)", what, v, st.name()), UVM_LOW)
    endfunction

    task peek_say(uvm_reg r, string what);
      uvm_reg_data_t v;
      r.peek(st, v, .parent(this));
      say(what, v);
    endtask

    // Poke r with v, then peek it at once, after one rising edge and after
    // two. Returns what r held before the poke.
    task poke_watch(uvm_reg r, uvm_reg_data_t v, output uvm_reg_data_t was);
      r.peek(st, was, .parent(this));
      r.poke(st, v, .parent(this));
      say($sformatf("poke %s with", r.get_name()), v);
      peek_say(r, "  peek at once:");
      cycles(1);
      peek_say(r, "  peek one rising edge later:");
      cycles(1);
      peek_say(r, "  peek two rising edges later:");
    endtask

    task body();
      uvm_reg_data_t was_ctrl, was_int_en, was_cnt;
      // A poke sets the mirror to the value poked, whether or not the design
      // keeps it, so the model's read check is off until the end.
      regs.default_map.set_check_on_read(0);

      // 1. Peek: reading a register without the bus. CTRL is written with a
      //    raw transfer, so this test works before the adapter does. Every
      //    route is disabled after reset, so a packet is a NOROUTE drop.
      ctrl(1);
      peek_say(regs.ctrl, "peek CTRL as the write of 1 returns:");
      cycles(1);
      peek_say(regs.ctrl, "peek CTRL one rising edge later:");
      burst(1, 1, 1);                    // a NOROUTE drop
      cycles(3);
      peek_say(regs.status, "peek STATUS after a NOROUTE drop:");
      peek_say(regs.drop_cnt, "peek DROP_CNT:");

      // 2. Poke: writing a register without the bus. INT_EN gets 110, which
      //    leaves NOROUTE's enable at 0, so irq can't rise.
      poke_watch(regs.ctrl, 0, was_ctrl);
      poke_watch(regs.int_en, 'b110, was_int_en);
      poke_watch(regs.drop_cnt, 'h0505, was_cnt);
      if ($test$plusargs("BACKDOOR_READBACK")) begin
        uvm_reg_data_t v;
        regs.drop_cnt.read(st, v, .parent(this));
        say("front-door read of DROP_CNT:", v);
      end

      // 3. Everything poked back as it was, so the router, the mirror and the
      //    scoreboard agree again, and the read check back on.
      regs.ctrl.poke(st, was_ctrl, .parent(this));
      regs.int_en.poke(st, was_int_en, .parent(this));
      regs.drop_cnt.poke(st, was_cnt, .parent(this));
      cycles(2);
      regs.default_map.set_check_on_read(1);
      rd_all_regs();
    endtask
  endclass
endpackage
