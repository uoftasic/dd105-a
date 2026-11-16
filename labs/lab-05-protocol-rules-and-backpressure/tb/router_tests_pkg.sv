// DD105-A Lab 05: the tests. Every one is in the same simulator, and
// +UVM_TESTNAME picks one when the simulator starts:
//
//   router_test         router_inject_test, then router_lab05_vseq (Part 4);
//                       make check and make check-all grade this one
//   router_lab05_test   router_lab05_vseq on its own
//   router_sink_test    router_rand_test with both sinks answering each
//                       beat at random (Part 3)
//   router_inject_test  router_stall_test, with router_noroute_pkt swapped
//                       in for router_pkt by a factory override (Lab 04)
//   router_stall_test   router_rand_test, with one output stalled in each
//                       phase while the other runs (Lab 04)
//   router_rand_test    Lab 03's test: CTRL.EN, then +PHASES phases of +N
//                       random packets, each with its own random routing
//                       table and a DROP_CNT check; then close_holes() and a
//                       last DROP_CNT check
//   router_fill_test    Lab 03's close_holes() on its own
//   router_class_test   Lab 02's test: +N random packets on +ROUTES, and a
//                       DROP_CNT check
//
// Plusargs: +N=<packets> (200 per phase; 100 in router_class_test),
// +PHASES=<n> (4), +ROUTES=<abcd> (0110, router_class_test only),
// +MAX_CYCLES=<n> (200000).
//
// This is Lab 04's file, with the solution to Lab 04 in it, and Lab 05's
// three tests at the end.

package router_tests_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  import router_agents_pkg::*;
  import router_env_pkg::*;
  import router_vseq_pkg::*;
  `include "uvm_macros.svh"

  // Lab 03's fill_plan: packet lengths that add up to target. A 0 is "no
  // packet", so the plan has 1 to 8 packets. The array has a fixed size
  // because sum() on a dynamic array can't be solved here (Lab 03, traps
  // line 5).
  class fill_plan;
    rand int unsigned lens[8];
    int unsigned      target = 8;
    constraint c_sum { foreach (lens[i]) lens[i] inside {[0:8]};
                       lens.sum() == target; }
  endclass

  // ── the base test ─────────────────────────────────────────────────────────
  // Lab 03's router_base_test made the environment in run_phase, handed it
  // the interfaces and called body(), and its env had the steps a test
  // calls (write_routes, enable, send_random, send, drain, check_drops and
  // so on). Here build_phase builds, the agents fetch their own interfaces
  // from config_db, and those steps are tasks of the base test, written on
  // the agents' sequences. dd105_base_test turns any UVM_ERROR into a
  // failing exit status.
  class router_base_test extends dd105_base_test;
    `uvm_component_utils(router_base_test)

    router_env     env;
    out_cfg        ocfg[2];       // each output agent's knobs; the test keeps the handles
    virtual apb_if vif;           // for its clock and reset
    string         routes;        // the routing table written last, as +ROUTES writes it
    bit [3:0]      route_en;      // ... and its EN bits, for the packets' c_dst
    int unsigned   next_tag;      // the next packet's number, for its header
    int unsigned   max_cycles = 200000;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // A scoreboard that has lost step prints an error per beat; stop at 50.
      uvm_report_server::get_server().set_max_quit_count(50);
      void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
      foreach (ocfg[p]) begin
        ocfg[p] = out_cfg::type_id::create($sformatf("ocfg%0d", p));
        ocfg[p].port = p;
        uvm_config_db#(out_cfg)::set(this, $sformatf("env.out%0d*", p), "cfg", ocfg[p]);
      end
      if (!uvm_config_db#(virtual apb_if)::get(this, "env.apb", "vif", vif))
        `uvm_fatal("NOVIF", "the test has no virtual apb_if")
      env = router_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      wait (vif.rst_n == 1'b1);
      @(vif.cb);
      fork
        body();
        begin
          repeat (max_cycles) @(vif.cb);
          `uvm_error("WATCHDOG", $sformatf("the test was still running after %0d cycles", max_cycles))
        end
      join_any
      disable fork;
      phase.drop_objection(this);
    endtask

    // What the test does; each test overrides it.
    virtual task body();
    endtask

    // Lab 03's apb_master.write() and read(), as one-item sequences on the
    // APB agent. The APB monitor reports both to the scoreboard.
    task write_reg(bit [7:0] addr, bit [31:0] data);
      apb_rw_seq s = apb_rw_seq::type_id::create("wr");
      s.write = 1;
      s.addr  = addr;
      s.wdata = data;
      s.start(env.apb.sqr);
    endtask

    task read_reg(bit [7:0] addr, output bit [31:0] data);
      apb_rw_seq s = apb_rw_seq::type_id::create("rd");
      s.write = 0;
      s.addr  = addr;
      s.start(env.apb.sqr);
      data = s.t.rdata;
    endtask

    // ROUTE0 to ROUTE3, written as Lab 03's env.write_routes() wrote them:
    // one character per route, 0 or 1 for the output, - for disabled
    // (written with PORT 0). The scoreboard follows the table from the APB
    // writes, so call this only while no packet is coming in.
    task write_routes(string r);
      if (r.len() != 4)
        `uvm_fatal("ROUTES", $sformatf("routes %s: give four characters, one per route, for example 0110", r))
      foreach (r[i])
        if (!(r[i] inside {"0", "1", "-"}))
          `uvm_fatal("ROUTES", $sformatf("routes %s: each character must be 0, 1 or - (disabled)", r))
      routes = r;
      for (int d = 0; d < 4; d++) begin
        route_en[d] = r[d] != "-";
        write_reg(A_ROUTE0 + 8'(4 * d), {30'b0, r[d] == "1", r[d] != "-"});
      end
    endtask

    // CTRL.EN, which opens the input.
    task enable();
      write_reg(A_CTRL, 32'h1);
    endtask

    // A new packet that knows which routes are enabled, not yet randomized,
    // for close_holes(). It's made with new() rather than through the
    // factory, so a factory override (Lab 04, Part 4) doesn't reach it.
    function router_pkt new_packet();
      router_pkt p = new("pkt");
      p.route_en = route_en;
      return p;
    endfunction

    // n random packets for the routes written last. Returns when the last
    // one has gone into the router.
    task send_random(int unsigned n);
      router_rand_seq s = router_rand_seq::type_id::create("rand");
      s.n         = n;
      s.route_en  = route_en;
      s.first_tag = next_tag;
      next_tag   += n;
      s.start(env.src.sqr);
    endtask

    // Packets the test made itself, in order, each with the next tag.
    // Returns when the last one has gone into the router.
    task send(router_pkt pkts[$]);
      router_one_seq s;
      foreach (pkts[i]) begin
        s = router_one_seq::type_id::create("one");
        pkts[i].tag     = 6'(next_tag++);
        pkts[i].data[0] = {pkts[i].hdr_dst, pkts[i].tag};
        s.pkt = pkts[i];
        s.start(env.src.sqr);
      end
    endtask

    task cycles(int unsigned n);
      repeat (n) @(vif.cb);
    endtask

    // Make both outputs ready and wait until the scoreboard expects nothing
    // more, or 300 cycles.
    task drain();
      foreach (ocfg[p]) ocfg[p].ready_pct = 100;
      for (int i = 0; i < 300 && env.sb.outstanding() > 0; i++) @(vif.cb);
      repeat (4) @(vif.cb);
    endtask

    // Lab 03's check_drops(): read DROP_CNT. The scoreboard compares what the
    // read returns with the drops it predicted.
    task check_drops();
      bit [31:0] d;
      read_reg(A_DROP_CNT, d);
    endtask

    // Write DROP_CNT, which clears both counters; the scoreboard sees the
    // write and clears its counts too.
    task clear_drops();
      write_reg(A_DROP_CNT, 32'h0);
    endtask

    // Lab 03's close_holes(): the two coverage holes, on output 0. ROUTE0 is
    // enabled to output 0 and the other three routes are disabled. With
    // output 0's sink stalled, packets for DST 0 whose lengths add up to
    // exactly 8 fill it to level 8, and then two packets follow:
    //
    //   1. a random packet for DST 0: decided at level 8, so admitted
    //      (out0_x_at_8, B08's bin), which takes the level to 9 to 16;
    //   2. a random packet for DST 1, a disabled route whose PORT is 0:
    //      NOROUTE with the level above 8 (noroute_x_at_9 or noroute_x_high,
    //      B07's bin). c_dst would keep it off a disabled route, so it is
    //      switched off for this one packet.
    //
    // The two random packets come from new_packet(), not the factory. In
    // router_inject_test the factory makes a router_noroute_pkt, whose own
    // c_dst stayed on when this switched c_dst off through a router_pkt
    // handle, and randomize() then failed for the DST 1 packet.
    //
    // Nothing more goes to output 0 while it holds more than 8 beats, and
    // nothing goes to output 1. The test reads DROP_CNT after this, and the
    // scoreboard expects 00000001.
    virtual task close_holes();
      fill_plan  plan = new();
      router_pkt pkts[$];
      router_pkt p;
      string     lens = "";
      int        ok;
      write_routes("0---");
      ocfg[0].ready_pct = 0;
      cycles(2);
      ok = plan.randomize();
      if (ok == 0) `uvm_fatal("RAND", "fill_plan randomize() failed")
      foreach (plan.lens[i])
        if (plan.lens[i] != 0) begin
          pkts.push_back(router_pkt::make(2'd0, plan.lens[i]));
          lens = {lens, $sformatf(" %0d", plan.lens[i])};
        end
      p = new_packet();
      ok = p.randomize() with { hdr_dst == 0; };
      if (ok == 0) `uvm_fatal("RAND", "router_pkt randomize() failed")
      pkts.push_back(p);
      p = new_packet();
      p.c_dst.constraint_mode(0);
      ok = p.randomize() with { hdr_dst == 1; };
      if (ok == 0) `uvm_fatal("RAND", "router_pkt randomize() failed")
      pkts.push_back(p);
      `uvm_info("HOLES", $sformatf("output 0 stalled and filled to 8 by packets of%s beats, then %0d beats for DST 0 and %0d for DST 1",
                lens, pkts[pkts.size() - 2].len, p.len), UVM_LOW)
      send(pkts);
      ocfg[0].ready_pct = 100;
      drain();
    endtask
  endclass

  // ── Lab 03 ────────────────────────────────────────────────────────────────
  class router_rand_test extends router_base_test;
    `uvm_component_utils(router_rand_test)
    int unsigned n = 200, phases = 4;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      void'($value$plusargs("N=%d", n));
      void'($value$plusargs("PHASES=%d", phases));
    endfunction

    task body();
      string r;
      enable();
      for (int k = 1; k <= phases; k++) begin
        r = random_routes();
        write_routes(r);
        set_sinks(k);
        `uvm_info("PHASE", $sformatf("%0d of %0d: routes %s, %0d packets; output 0 ready %0d%%, output 1 ready %0d%%",
                  k, phases, r, n, ocfg[0].ready_pct, ocfg[1].ready_pct), UVM_LOW)
        send_random(n);
        drain();
        check_drops();
        clear_drops();
      end
      close_holes();
      check_drops();
    endtask

    // Lab 03's random routing table, written as +ROUTES is, with at least
    // one disabled route and an enabled route to each output.
    function string random_routes();
      string r;
      bit    off, to0, to1;
      do begin
        r   = "----";
        off = 0;
        to0 = 0;
        to1 = 0;
        for (int d = 0; d < 4; d++)
          case ($urandom_range(2))
            0: off = 1;
            1: begin r[d] = "0"; to0 = 1; end
            2: begin r[d] = "1"; to1 = 1; end
          endcase
      end while (!(off && to0 && to1));
      return r;
    endfunction

    // How ready each output is in phase k (1 to +PHASES). In Lab 03 both
    // always were.
    virtual function void set_sinks(int k);
      ocfg[0].ready_pct = 100;
      ocfg[1].ready_pct = 100;
    endfunction
  endclass

  class router_fill_test extends router_base_test;
    `uvm_component_utils(router_fill_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task body();
      enable();
      close_holes();
      check_drops();
    endtask
  endclass

  // ── Lab 02 ────────────────────────────────────────────────────────────────
  // Lab 02's test, as Lab 03 kept it: +N random packets (100) on the
  // routing table +ROUTES gives (0110), a drain, and a DROP_CNT check.
  class router_class_test extends router_base_test;
    `uvm_component_utils(router_class_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task body();
      int unsigned n = 100;
      string       r = "0110";
      void'($value$plusargs("N=%d", n));
      void'($value$plusargs("ROUTES=%s", r));
      `uvm_info("ENV", $sformatf("%0d packets, routes %s", n, r), UVM_LOW)
      write_routes(r);
      enable();
      send_random(n);
      drain();
      check_drops();
    endtask
  endclass

  // ── Lab 04 ────────────────────────────────────────────────────────────────
  // Lab 04, Part 3: stall one output at a time. Output 0 in phases 1 and 3
  // and output 1 in phases 2 and 4 is ready in 5% of cycles, so it fills
  // past 8 beats while the other output, always ready, stays nearly empty.
  class router_stall_test extends router_rand_test;
    `uvm_component_utils(router_stall_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void set_sinks(int k);
      int s = (k % 2 == 1) ? 0 : 1;     // the output that stalls in phase k
      ocfg[s].ready_pct     = 5;
      ocfg[1 - s].ready_pct = 100;
    endfunction
  endclass

  // Lab 04, Part 4: a packet that goes to a disabled route one time in
  // four. It replaces router_pkt's c_dst constraint, which has the same name.
  class router_noroute_pkt extends router_pkt;
    `uvm_object_utils(router_noroute_pkt)
    bit to_disabled;

    constraint c_dst { to_disabled  -> ((route_en >> hdr_dst) & 4'h1) == 4'h0;
                       !to_disabled -> ((route_en >> hdr_dst) & 4'h1) == 4'h1; }

    function new(string name = "router_noroute_pkt");
      super.new(name);
    endfunction

    function void pre_randomize();
      super.pre_randomize();
      to_disabled = (route_en != 4'hF) && ($urandom_range(3) == 0);
    endfunction
  endclass

  // Lab 04, Part 4: router_stall_test, with every router_pkt the factory
  // makes replaced by a router_noroute_pkt. Nothing else changes.
  class router_inject_test extends router_stall_test;
    `uvm_component_utils(router_inject_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      router_pkt::type_id::set_type_override(router_noroute_pkt::get_type());
      super.build_phase(phase);
    endfunction
  endclass
  // ── Lab 05 ────────────────────────────────────────────────────────────────
  // Part 3: Lab 03's random phases with both sinks in SNK_RANDOM, so each
  // beat's answer comes from an item of the sink's sequence. close_holes()
  // stalls output 0 with ready_pct 0, which only SNK_PCT reads, so the sinks
  // go back to Lab 04's mode for it.
  class router_sink_test extends router_rand_test;
    `uvm_component_utils(router_sink_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void set_sinks(int k);
      foreach (ocfg[p]) ocfg[p].mode = SNK_RANDOM;
    endfunction

    virtual task close_holes();
      foreach (ocfg[p]) ocfg[p].mode = SNK_PCT;
      super.close_holes();
    endtask
  endclass

  // The graded test: everything router_inject_test does, unchanged, and
  // then this lab's virtual sequence (Part 4). The factory override is still
  // on, so the sequence's random packets are router_noroute_pkts too; with
  // every route enabled they behave as router_pkts.
  class router_test extends router_inject_test;
    `uvm_component_utils(router_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    // The sequence is made only after router_inject_test's steps, because
    // making an object draws from the random state of the thread that makes
    // it: made first, it would change every random choice those steps make.
    task body();
      router_lab05_vseq v;
      super.body();
      `uvm_info("VSEQ", "router_inject_test is done; starting router_lab05_vseq", UVM_LOW)
      v = router_lab05_vseq::type_id::create("vseq");
      v.start(env.vsqr);
    endtask
  endclass

  // The virtual sequence on its own, from a router just out of reset.
  class router_lab05_test extends router_base_test;
    `uvm_component_utils(router_lab05_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task body();
      router_lab05_vseq v = router_lab05_vseq::type_id::create("vseq");
      v.start(env.vsqr);
    endtask
  endclass
endpackage
