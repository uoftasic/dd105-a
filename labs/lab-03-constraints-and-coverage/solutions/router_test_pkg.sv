// DD105-A Lab 03: the tests, the one piece of UVM in this lab (reference
// solution).
//
// A test does what the `initial` block of a classic SystemVerilog testbench
// does: it makes the environment, hands it the interfaces, and runs the
// stimulus. It's a UVM test, extending dd105_base_test, only so that `make`
// picks it with +UVM_TESTNAME and the graders read UVM's report summary. If
// the testbench reported any errors, it reports one UVM_ERROR saying how
// many, and dd105_base_test turns that into a failing exit status.
//
//   router_rand_test   CTRL.EN, then +PHASES phases (default 4) of +N random
//                      packets each (default 200), each phase with its own
//                      random routing table; then close_holes() and a last
//                      DROP_CNT check. `make check` grades this one.
//   router_fill_test   close_holes() on its own, for a short run and its waves.
//   router_class_test  Lab 02's test: +N packets (default 100) on +ROUTES.

package router_test_pkg;
  import uvm_pkg::*;
  import router_tb_pkg::*;
  `include "uvm_macros.svh"

  // Part 4: packet lengths that add up to target. A 0 is "no packet", so the
  // plan has 1 to 8 packets. The array has a fixed size because sum() on a
  // dynamic array can't be solved here (traps line 5).
  class fill_plan;
    rand int unsigned lens[8];
    int unsigned      target = 8;
    constraint c_sum { foreach (lens[i]) lens[i] inside {[0:8]};
                       lens.sum() == target; }
  endclass

  // Makes the environment as Lab 02's test did, then runs body().
  class router_base_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(router_base_test)

    router_cfg cfg;
    env        e;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      virtual stream_src_if in_vif;
      virtual stream_snk_if out0_vif, out1_vif;
      virtual stream_mon_if in_mon_vif, out0_mon_vif;
      virtual apb_if        apb_vif;
      phase.raise_objection(this);
      if (!uvm_config_db#(virtual stream_src_if)::get(this, "", "in_vif", in_vif) ||
          !uvm_config_db#(virtual stream_snk_if)::get(this, "", "out0_vif", out0_vif) ||
          !uvm_config_db#(virtual stream_snk_if)::get(this, "", "out1_vif", out1_vif) ||
          !uvm_config_db#(virtual stream_mon_if)::get(this, "", "in_mon_vif", in_mon_vif) ||
          !uvm_config_db#(virtual stream_mon_if)::get(this, "", "out0_mon_vif", out0_mon_vif) ||
          !uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", apb_vif))
        `uvm_fatal("NOVIF", "the top module didn't set every virtual interface")
      cfg = new();
      cfg.from_plusargs();
      e = new(cfg, in_vif, out0_vif, out1_vif, in_mon_vif, out0_mon_vif, apb_vif);
      body();
      if (e.n_errors() > 0)
        `uvm_error("TB", $sformatf("the testbench reported %0d error%s", e.n_errors(),
                                   e.n_errors() == 1 ? string'("") : string'("s")))
      phase.drop_objection(this);
    endtask

    virtual task body();
    endtask

    // Part 4: the two coverage holes, on output 0. ROUTE0 is enabled to
    // output 0 and the other three routes are disabled. With output 0's sink
    // stalled, packets for DST 0 whose lengths add up to exactly 8 fill it to
    // level 8, and then two packets follow:
    //
    //   1. a random packet for DST 0: decided at level 8, so admitted
    //      (out0_x_at_8, B08's bin), which takes the level to 9 to 16;
    //   2. a random packet for DST 1, a disabled route whose PORT is 0:
    //      NOROUTE with the level above 8 (noroute_x_at_9 or noroute_x_high,
    //      B07's bin). c_dst would keep it off a disabled route, so it is
    //      switched off for this one packet.
    //
    // Nothing more goes to output 0 while it holds more than 8 beats: the
    // router would drop it as FULL, and the scoreboard, which expects every
    // packet for an enabled route with PORT 0 to come out, would report it
    // missing. Nothing goes to output 1. The test checks DROP_CNT after this.
    virtual task close_holes();
      fill_plan   plan = new();
      rand_packet pkts[$];
      rand_packet p;
      string      lens = "";
      e.write_routes("0---");
      e.snk0.stall = 1;
      e.cycles(2);
      if (plan.randomize() == 0) `uvm_fatal("RAND", "fill_plan randomize() failed")
      foreach (plan.lens[i])
        if (plan.lens[i] != 0) begin
          pkts.push_back(rand_packet::make(2'd0, plan.lens[i]));
          lens = {lens, $sformatf(" %0d", plan.lens[i])};
        end
      p = e.gen.new_packet();
      if ((p.randomize() with { hdr_dst == 0; }) == 0) `uvm_fatal("RAND", "rand_packet randomize() failed")
      pkts.push_back(p);
      p = e.gen.new_packet();
      p.c_dst.constraint_mode(0);
      if ((p.randomize() with { hdr_dst == 1; }) == 0) `uvm_fatal("RAND", "rand_packet randomize() failed")
      pkts.push_back(p);
      $display("[HOLES] output 0 stalled and filled to 8 by packets of%s beats, then %0d beats for DST 0 and %0d for DST 1",
               lens, pkts[pkts.size() - 2].len, p.len);
      e.send(pkts);
      e.snk0.stall = 0;
      e.drain();
    endtask
  endclass

  class router_rand_test extends router_base_test;
    `uvm_component_utils(router_rand_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    // A random routing table, written as +ROUTES is, with at least one
    // disabled route and an enabled route to each output.
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

    virtual task body();
      int unsigned n = 200, n_phases = 4;
      string       routes;
      void'($value$plusargs("N=%d", n));
      void'($value$plusargs("PHASES=%d", n_phases));
      e.start();
      e.enable();
      for (int k = 1; k <= n_phases; k++) begin
        routes = random_routes();
        $display("[PHASE] %0d of %0d: routes %s, %0d packets", k, n_phases, routes, n);
        e.write_routes(routes);
        e.send_random(n);
        e.drain();
        e.check_drops();
        e.clear_drops();
      end
      close_holes();
      e.check_drops();
      e.report();
    endtask
  endclass

  class router_fill_test extends router_base_test;
    `uvm_component_utils(router_fill_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task body();
      e.start();
      e.enable();
      close_holes();
      e.check_drops();
      e.report();
    endtask
  endclass

  // Lab 02's test; env.run() now also checks DROP_CNT (check_drops()).
  class router_class_test extends router_base_test;
    `uvm_component_utils(router_class_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task body();
      e.run();
    endtask
  endclass
endpackage
