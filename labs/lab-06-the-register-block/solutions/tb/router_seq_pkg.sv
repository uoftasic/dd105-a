// DD105-A Lab 06: the virtual sequences.
//
// A virtual sequence runs on router_vsequencer and drives every agent at
// once: register reads and writes through the register model or as raw APB
// transfers, packets through the source, the sinks' backpressure through
// their configuration, and reset.
//
//   router_base_vseq      the helpers every sequence below uses
//   router_lab04_vseq     Lab 04's stimulus
//   router_lab05_vseq     Lab 05's: backpressure, oversize packets, and a
//                         configuration that changes under traffic
//   router_lab06_vseq     this lab's: the register block
//   router_backdoor_vseq  what the back door does on this simulator
//   router_main_vseq      Lab 04's, Lab 05's and Lab 06's steps, one after
//                         another: what router_test runs
//
// None of them checks anything itself. The scoreboard and the assertions
// check every cycle of every run, so a sequence only has to make the
// interesting thing happen.

package router_seq_pkg;
  import uvm_pkg::*;
  import apb_pkg::*;
  import stream_pkg::*;
  import router_ral_pkg::*;
  import router_env_pkg::*;
  `include "uvm_macros.svh"

  // Register addresses (docs/reference/router-spec.md, "Register map").
  localparam bit [7:0] A_ID = 8'h00, A_CTRL = 8'h04, A_STATUS = 8'h08, A_INT_EN = 8'h0C,
                       A_DROP_CNT = 8'h10, A_LEVEL = 8'h14, A_ROUTE0 = 8'h20;

  class router_base_vseq extends uvm_sequence;
    `uvm_object_utils(router_base_vseq)
    `uvm_declare_p_sequencer(router_vsequencer)

    bit traffic_done;              // set by a sequence when its packets are all sent
    router_reg_block regs;         // the register model
    uvm_status_e     st;           // the status of the last register operation

    function new(string name = "router_base_vseq");
      super.new(name);
    endfunction

    task body();
      regs = p_sequencer.regs;
    endtask

    // ── time ───────────────────────────────────────────────────────────────
    // n clock cycles. Each wait ends at a rising edge.
    task cycles(int n);
      repeat (n) @(p_sequencer.vif.mon_cb);
    endtask

    // ── reset ──────────────────────────────────────────────────────────────
    // rst_n low for n cycles. The router forgets its configuration, so a
    // sequence sets it up again afterwards, and the register model goes back
    // to its reset values too: reset() sets every field's mirror to its reset
    // value, and the predictor forgets any transfer it saw half of.
    task reset(int n = 3);
      router_reset_seq rs = router_reset_seq::type_id::create("rs");
      rs.cycles = n;
      rs.start(p_sequencer.sys_sqr, this);
      p_sequencer.regs.reset();
      p_sequencer.predictor.flush();
    endtask

    // ── registers, through the register model ──────────────────────────────
    // A write or a read of one register, by name: wr_reg(regs.ctrl, 1). The
    // adapter turns it into one APB transfer. A status other than UVM_IS_OK
    // means the transfer ended with PSLVERR, which a register in the map
    // never should.
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

    // ── registers, as raw APB transfers ────────────────────────────────────
    // One APB transfer to any address, good or bad, which the register model
    // doesn't send. Labs 04 and 05 set up the router this way. The scoreboard
    // checks every read against its model, so a read here is a check, and
    // nothing needs the value.
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
  // Lab 06: the register block, one step per part of the lab.
  // ══════════════════════════════════════════════════════════════════════════
  class router_lab06_vseq extends router_base_vseq;
    `uvm_object_utils(router_lab06_vseq)
    function new(string name = "router_lab06_vseq");
      super.new(name);
    endfunction

    task body();
      uvm_reg_hw_reset_seq hw;           // Part 2
      uvm_reg_bit_bash_seq bb;           // Part 3
      super.body();
      reset(3);
      // Part 2: the reset values. The sequence reads every register that has
      // a field it can check and compares it with the model's reset value.
      hw = uvm_reg_hw_reset_seq::type_id::create("hw_reset");
      hw.model = regs;
      hw.start(null, this);

      // Part 3: every bit of every register written with 1 and with 0, and
      // read back.
      bb = uvm_reg_bit_bash_seq::type_id::create("bit_bash");
      bb.model = regs;
      bb.start(null, this);
      // The router set up with raw APB writes, as Labs 04 and 05 do, and read
      // back through the model, which knows about them only through the
      // predictor.
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
        if (!router_model::good_addr(8'(a))) raw(0, 8'(a));
      for (int a = 0; a < 256; a++)
        if (!router_model::good_addr(8'(a))) raw(1, 8'(a), 32'hFFFF_FFFF);
      rd_all_regs();

      // Part 5: STATUS and INT_EN. DST 1 is disabled, so its packets are
      // NOROUTE drops; a 9-beat packet is OVERSIZE; and ten packets into a
      // stalled output 0 end with a FULL drop. INT_EN is 0 all the while, so
      // irq stays 0.
      route(1, 0, 0);
      sink(0, SNK_FAST);
      sink(1, SNK_FAST);
      burst(1, 1, 1, 0);                 // NOROUTE
      burst(0, 1, 9, 1);                 // OVERSIZE
      sink(0, SNK_FAST, 1);
      burst(0, 10, 1, 2);                // FULL
      rd_reg(regs.status);
      // Each enable on its own: irq follows the one bit it lets through.
      for (int b = 0; b < 3; b++) begin
        wr_reg(regs.int_en, 3'b001 << b);
        cycles(2);
      end
      // Every enable on, and the bits cleared one at a time: irq stays 1
      // until the last one goes.
      wr_reg(regs.int_en, 3'b111);
      wr_reg(regs.status, 3'b001);
      rd_reg(regs.status);
      wr_reg(regs.status, 3'b100);
      rd_reg(regs.status);
      wr_reg(regs.status, 3'b010);
      rd_reg(regs.status);
      drain();
      rd_all_regs();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // The back door: peek and poke through the HDL paths in the register model.
  // router_backdoor_test runs this, and the [BACKDOOR] lines in the log say
  // what each step saw. A peek or a poke takes no simulation time and sends
  // nothing on the bus, so the scoreboard, which watches the bus, never
  // hears of a poke. So every poke here is undone by another poke before
  // anything reads the register through the front door, and the test passes
  // on the golden router. +BACKDOOR_READBACK adds one front-door read of a
  // poked register first, to show what the scoreboard makes of it.
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
      super.body();
      reset(3);
      // A poke sets the mirror to the value poked, whether or not the design
      // keeps it, so the model's read check is off until the end.
      regs.default_map.set_check_on_read(0);

      // 1. Peek: reading a register without the bus.
      wr_reg(regs.ctrl, 1);
      peek_say(regs.ctrl, "peek CTRL as the write of 1 returns:");
      cycles(1);
      peek_say(regs.ctrl, "peek CTRL one rising edge later:");
      route(1, 0, 0);
      burst(1, 1, 1, 0);                 // a NOROUTE drop
      cycles(3);
      peek_say(regs.status, "peek STATUS after a NOROUTE drop:");
      peek_say(regs.drop_cnt, "peek DROP_CNT:");

      // 2. Poke: writing a register without the bus. INT_EN gets 110, which
      //    leaves NOROUTE's enable at 0, so irq can't rise.
      poke_watch(regs.ctrl, 0, was_ctrl);
      poke_watch(regs.int_en, 3'b110, was_int_en);
      poke_watch(regs.drop_cnt, 16'h0505, was_cnt);
      if ($test$plusargs("BACKDOOR_READBACK")) begin
        uvm_reg_data_t v;
        regs.int_en.read(st, v, .parent(this));
        say("front-door read of INT_EN:", v);
      end

      // 3. Everything poked back as it was, so the router, the mirror and the
      //    scoreboard's model agree again, and the read check back on.
      regs.ctrl.poke(st, was_ctrl, .parent(this));
      regs.int_en.poke(st, was_int_en, .parent(this));
      regs.drop_cnt.poke(st, was_cnt, .parent(this));
      cycles(2);
      regs.default_map.set_check_on_read(1);
      rd_all_regs();
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Lab 04's steps, then Lab 05's, then Lab 06's: the test make check grades.
  // ══════════════════════════════════════════════════════════════════════════
  class router_main_vseq extends router_base_vseq;
    `uvm_object_utils(router_main_vseq)
    function new(string name = "router_main_vseq");
      super.new(name);
    endfunction
    task body();
      router_lab04_vseq lab04 = router_lab04_vseq::type_id::create("lab04");
      router_lab05_vseq lab05 = router_lab05_vseq::type_id::create("lab05");
      router_lab06_vseq lab06 = router_lab06_vseq::type_id::create("lab06");
      super.body();
      `uvm_info("VSEQ", "starting Lab 04's steps", UVM_LOW)
      lab04.start(p_sequencer, this);
      `uvm_info("VSEQ", "starting Lab 05's steps", UVM_LOW)
      lab05.start(p_sequencer, this);
      `uvm_info("VSEQ", "starting Lab 06's steps", UVM_LOW)
      lab06.start(p_sequencer, this);
    endtask
  endclass
endpackage
