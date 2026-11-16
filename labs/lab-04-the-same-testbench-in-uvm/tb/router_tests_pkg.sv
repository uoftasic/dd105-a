// DD105-A Lab 04: the tests. Every one is in the same simulator, and
// +UVM_TESTNAME picks one when the simulator starts:
//
//   router_inject_test  router_stall_test, with router_noroute_pkt swapped
//                       in for router_pkt by a factory override (Part 4);
//                       make check and make check-all grade this one
//   router_stall_test   router_rand_test, with one output stalled in each
//                       phase while the other runs (Part 3)
//   router_rand_test    Lab 03's test: random routing tables and packets,
//                       then its two directed steps
//   router_smoke_test   Lab 02's test: a few packets, by hand
//
// Plusargs: +N=<packets per phase> (60), +PHASES=<n> (4), +MAX_CYCLES=<n> (200000).
//
// router_stall_test and router_inject_test start out empty: Parts 3 and 4
// of the lab fill them in.

package router_tests_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  import router_agents_pkg::*;
  import router_env_pkg::*;
  `include "uvm_macros.svh"

  // ── the base test ─────────────────────────────────────────────────────────
  // Lab 02's test module did three things in an initial block: build the
  // environment, run the stimulus, and say whether it passed. Here
  // build_phase builds, run_phase runs, and dd105_base_test turns any
  // UVM_ERROR into a failing exit status.
  class router_base_test extends dd105_base_test;
    `uvm_component_utils(router_base_test)

    router_env     env;
    out_cfg        ocfg[2];       // each output agent's knobs; the test keeps the handles
    virtual apb_if vif;           // for its clock and reset
    bit [3:0]      route_en;      // the routing table written last
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

    // Lab 02's apb_write() and apb_read(), as one-item sequences on the APB agent.
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

    // One packet, built by hand.
    task send_pkt(bit [1:0] dst, int unsigned len, bit [5:0] tag = 0);
      router_one_seq s = router_one_seq::type_id::create("one");
      s.pkt = router_pkt::make(dst, len, tag);
      s.start(env.src.sqr);
    endtask

    // Write ROUTE0 to ROUTE3. Bit r of en and port is ROUTEr.EN and ROUTEr.PORT.
    task write_routes(bit [3:0] en, bit [3:0] port);
      route_en = en;
      for (int r = 0; r < 4; r++) write_reg(A_ROUTE0 + 8'(4 * r), {30'b0, port[r], en[r]});
    endtask

    // Make both outputs ready and wait until the scoreboard expects nothing
    // more, or 300 cycles.
    task drain();
      foreach (ocfg[p]) ocfg[p].ready_pct = 100;
      for (int i = 0; i < 300 && env.sb.outstanding() > 0; i++) @(vif.cb);
      repeat (4) @(vif.cb);
    endtask
  endclass

  // ── Lab 02 ────────────────────────────────────────────────────────────────
  class router_smoke_test extends router_base_test;
    `uvm_component_utils(router_smoke_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task body();
      bit [31:0] d;
      write_routes(4'b0011, 4'b0010);     // DST 0 to output 0, DST 1 to output 1
      write_reg(A_CTRL, 32'h1);
      send_pkt(0, 3, 6'h01);
      send_pkt(0, 1, 6'h02);
      send_pkt(0, 8, 6'h03);
      send_pkt(1, 2, 6'h04);
      send_pkt(0, 5, 6'h05);
      drain();
      read_reg(A_DROP_CNT, d);
    endtask
  endclass

  // ── Lab 03 ────────────────────────────────────────────────────────────────
  class router_rand_test extends router_base_test;
    `uvm_component_utils(router_rand_test)
    int unsigned n = 60, phases = 4;
    bit [3:0]    route_port;      // the PORT bits written last, for the log

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      void'($value$plusargs("N=%d", n));
      void'($value$plusargs("PHASES=%d", phases));
    endfunction

    task body();
      bit [31:0]      d;
      router_rand_seq s;
      write_reg(A_CTRL, 32'h1);
      for (int k = 0; k < phases; k++) begin
        s = router_rand_seq::type_id::create("rand");
        configure_routes(k);
        set_sinks(k);
        `uvm_info("TEST", $sformatf("phase %0d: ROUTE EN %4b PORT %4b; output 0 ready %0d%%, output 1 ready %0d%%",
                  k, route_en, route_port, ocfg[0].ready_pct, ocfg[1].ready_pct), UVM_LOW)
        s.n         = n;
        s.route_en  = route_en;
        s.first_tag = k * n;
        s.start(env.src.sqr);
      end
      drain();
      lab03_steps();
      read_reg(A_DROP_CNT, d);
    endtask

    // A random routing table with a disabled route and an enabled route to
    // each output, so both outputs get traffic.
    virtual task configure_routes(int k);
      bit [3:0] en, port;
      do begin
        en   = 4'($urandom);
        port = 4'($urandom);
      end while (en == 4'hF || (en & ~port) == 4'h0 || (en & port) == 4'h0);
      route_port = port;
      write_routes(en, port);
    endtask

    // How ready each output is in phase k. In Lab 03 both always were.
    virtual function void set_sinks(int k);
      ocfg[0].ready_pct = 100;
      ocfg[1].ready_pct = 100;
    endfunction

    // The two coverage holes Lab 03 closed by hand, on a stalled output 0:
    // a packet admitted at a level of exactly 8, and a packet for a disabled
    // route whose PORT names a full output. The scoreboard checks the
    // packets, and the DROP_CNT read at the end of body() checks the counts.
    task lab03_steps();
      ocfg[0].ready_pct = 0;                // stall output 0 (it's empty after drain())
      write_routes(4'b0001, 4'b0000);       // DST 0 enabled, DST 1 disabled; both name output 0
      send_pkt(0, 8, 6'h30);                // level 0 to 8
      send_pkt(0, 1, 6'h31);                // admitted at exactly 8; level 9
      send_pkt(1, 2, 6'h32);                // NOROUTE, with output 0 full
      drain();
    endtask
  endclass

  // ── Lab 04 ────────────────────────────────────────────────────────────────
  // TODO (Part 3): stall one output at a time. Override set_sinks() so that in
  // each phase one output is ready in 5% of cycles and the other in 100%:
  // output 0 stalls in even phases, output 1 in odd ones.
  class router_stall_test extends router_rand_test;
    `uvm_component_utils(router_stall_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  // TODO (Part 4): write router_noroute_pkt here, a router_pkt that goes to a
  // disabled route one time in four.

  // TODO (Part 4): make this test router_stall_test with every router_pkt the
  // factory makes replaced by a router_noroute_pkt.
  class router_inject_test extends router_stall_test;
    `uvm_component_utils(router_inject_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass
endpackage
