// DD105-A Lab 03: the tests.
//
// A test is the one UVM class in this testbench. It extends dd105_base_test,
// which checks that the constraint solver works and makes the exit status
// nonzero when anything reported an error, and UVM picks it by name at run
// time (+UVM_TESTNAME). It creates the class testbench, router_env, starts
// it, and runs its stimulus from run_phase.
//
//   router_rand_test   random routing tables and random packets, in phases,
//                      then close_holes(); `make check` grades this one
//   router_fill_test   close_holes() on its own, for a short run and its waves
//
// Plusargs: +N=<n> packets per phase (default 200), +PHASES=<n> (default 4).

package router_test_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  import router_tb_pkg::*;
  `include "uvm_macros.svh"

  // Register addresses.
  localparam bit [7:0] A_ID = 8'h00, A_CTRL = 8'h04, A_STATUS = 8'h08, A_INT_EN = 8'h0C,
                       A_DROP_CNT = 8'h10, A_LEVEL = 8'h14, A_ROUTE0 = 8'h20;

  // Part 4 (Lab 03's solution): packet lengths that add up to target. A 0 is
  // "no packet", so the plan has 1 to 8 packets. The array has a fixed size
  // because sum() on a dynamic array can't be solved here (traps line 5).
  class fill_plan;
    rand int unsigned lens[8];
    int unsigned      target = 8;
    constraint c_sum { foreach (lens[i]) lens[i] inside {[0:8]};
                       lens.sum() == target; }
  endclass

  class router_base_test extends dd105_base_test;
    `uvm_component_utils(router_base_test)

    router_env            env;
    virtual router_sys_if sys_vif;
    int unsigned          n_pkts = 200;
    int unsigned          n_phases = 4;
    int unsigned          n_sent = 0;     // packets this test has sent, for their tags

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      virtual apb_if        a;
      virtual stream_src_if s;
      virtual stream_snk_if k0, k1;
      super.build_phase(phase);
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", a))
        `uvm_fatal("NOVIF", "no apb_if in config_db")
      if (!uvm_config_db#(virtual stream_src_if)::get(this, "", "src_vif", s))
        `uvm_fatal("NOVIF", "no stream_src_if in config_db")
      if (!uvm_config_db#(virtual stream_snk_if)::get(this, "", "snk0_vif", k0))
        `uvm_fatal("NOVIF", "no stream_snk_if for output 0 in config_db")
      if (!uvm_config_db#(virtual stream_snk_if)::get(this, "", "snk1_vif", k1))
        `uvm_fatal("NOVIF", "no stream_snk_if for output 1 in config_db")
      if (!uvm_config_db#(virtual router_sys_if)::get(this, "", "sys_vif", sys_vif))
        `uvm_fatal("NOVIF", "no router_sys_if in config_db")
      void'($value$plusargs("N=%d", n_pkts));
      void'($value$plusargs("PHASES=%d", n_phases));
      // A scoreboard that has lost step with the router would print an error
      // for every beat; stop after 50.
      uvm_report_server::get_server().set_max_quit_count(50);
      env = new(a, s, k0, k1, sys_vif);
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      env.start();
      reset_dut();
      body();
      cycles(4);
      phase.drop_objection(this);
    endtask

    virtual task body();
    endtask

    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      env.sb.final_check();
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      env.sb.report();
    endfunction

    // ── time and reset ───────────────────────────────────────────────────────
    task cycles(int n);
      repeat (n) @(sys_vif.mon_cb);
    endtask

    task reset_dut(int n = 3);
      sys_vif.cb.rst_n <= 1'b0;
      repeat (n) @(sys_vif.cb);
      sys_vif.cb.rst_n <= 1'b1;
      @(sys_vif.cb);
    endtask

    // ── registers ────────────────────────────────────────────────────────────
    // The scoreboard checks every read, so these return nothing.
    task wr(bit [7:0] addr, bit [31:0] data);
      env.apb.write(addr, data);
    endtask

    task rd(bit [7:0] addr);
      bit [31:0] data;
      env.apb.read(addr, data);
    endtask

    task route(int n, bit en, bit port);
      wr(A_ROUTE0 + 8'(4 * n), {30'b0, port, en});
    endtask

    task read_all();
      rd(A_ID);
      rd(A_CTRL);
      rd(A_STATUS);
      rd(A_INT_EN);
      rd(A_DROP_CNT);
      rd(A_LEVEL);
      for (int n = 0; n < 4; n++) rd(A_ROUTE0 + 8'(4 * n));
    endtask

    // STATUS, DROP_CNT and LEVEL: what the drops did, and how full the outputs are.
    task read_events();
      rd(A_STATUS);
      rd(A_DROP_CNT);
      rd(A_LEVEL);
    endtask

    task clear_events();
      wr(A_STATUS, 32'h7);
      wr(A_DROP_CNT, 32'h0);
    endtask

    // ── packets ──────────────────────────────────────────────────────────────
    // Queue a packet for the source. Its tag becomes a count of the packets
    // this test has sent, so each header on a waveform is easy to find.
    task send(packet p);
      p.tag = 6'(n_sent++);
      p.data[0] = {p.dst, p.tag};
      env.src.pkts.put(p);
    endtask

    task send_random(int n);
      for (int k = 0; k < n; k++) begin
        packet p = new();
        if (!p.randomize()) `uvm_fatal("RAND", "packet randomize() failed")
        send(p);
      end
    endtask

    // Wait until the source has sent everything it was given.
    task wait_sent(int budget = 100000);
      int n = 0;
      while (!env.src.idle() && n < budget) begin
        cycles(1);
        n++;
      end
      if (!env.src.idle())
        `uvm_error("TEST", $sformatf("the source still had packets to send after %0d cycles", budget))
    endtask

    // ── the sinks ────────────────────────────────────────────────────────────
    // stall(p, 1) holds out_ready of output p at 0 from the next rising edge.
    task stall(int port, bit on);
      env.snk[port].stall = on;
    endtask

    // Let both outputs empty: no stalls, then wait until the model expects no
    // beat anywhere for a few cycles in a row.
    task drain(int budget = 3000);
      int quiet = 0, n = 0;
      stall(0, 0);
      stall(1, 0);
      while (quiet < 4 && n < budget) begin
        cycles(1);
        n++;
        quiet = env.sb.idle() ? quiet + 1 : 0;
      end
      if (quiet < 4)
        `uvm_error("DRAIN", $sformatf("after %0d cycles with both sinks ready, beats are still waiting to come out", budget))
    endtask

    // ── stimulus ─────────────────────────────────────────────────────────────
    // One phase: a random routing table (each route enabled 3 times in 4),
    // random interrupt enables, n random packets, then the event registers
    // read and cleared once the router is empty.
    task random_phase(int n);
      for (int r = 0; r < 4; r++) route(r, $urandom_range(3) != 0, 1'($urandom_range(1)));
      wr(A_INT_EN, 32'($urandom_range(7)));
      wr(A_CTRL, 32'h1);
      send_random(n);
      wait_sent();
      drain();
      read_events();
      clear_events();
    endtask

    // Part 4 (Lab 03's solution): the two coverage holes, on each output in
    // turn. With the output's sink stalled, packets for DST 0 whose lengths
    // add up to exactly 8 fill it to level 8, and then three packets follow:
    //
    //   1. for DST 0, enabled to this output: decided at level 8, so admitted
    //      (fate out0 or out1, level at_8);
    //   2. for DST 1, disabled, with PORT naming this output: NOROUTE with
    //      the level above 8 (noroute, at_9 or high);
    //   3. for DST 0 again: a FULL drop (full, at_9 or high).
    //
    // INT_EN has only FULL set, so irq rises at the one FULL drop, and the
    // event registers are read once the packets are in and again once the
    // output has drained.
    virtual task close_holes();
      for (int port = 0; port < 2; port++) begin
        fill_plan plan = new();
        packet    p[3];
        string    lens = "";
        route(0, 1'b1, 1'(port));
        route(1, 1'b0, 1'(port));
        wr(A_INT_EN, 32'h2);
        wr(A_CTRL, 32'h1);
        stall(port, 1'b1);
        cycles(2);
        if (!plan.randomize()) `uvm_fatal("RAND", "fill_plan randomize() failed")
        foreach (plan.lens[i])
          if (plan.lens[i] != 0) begin
            send(packet::make(2'd0, plan.lens[i]));
            lens = {lens, $sformatf(" %0d", plan.lens[i])};
          end
        foreach (p[k]) begin
          p[k] = new();
          if (!p[k].randomize() with { dst == ((k == 1) ? 2'd1 : 2'd0); })
            `uvm_fatal("RAND", "packet randomize() failed")
          send(p[k]);
        end
        `uvm_info("HOLES", $sformatf("output %0d stalled and filled to 8 by packets of%s beats, then packets of %0d, %0d and %0d beats for DST 0, 1 and 0",
                  port, lens, p[0].len, p[1].len, p[2].len), UVM_LOW)
        wait_sent();
        cycles(4);
        read_events();
        drain();
        read_events();
        clear_events();
      end
    endtask
  endclass

  class router_rand_test extends router_base_test;
    `uvm_component_utils(router_rand_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual task body();
      read_all();
      repeat (n_phases) random_phase(n_pkts);
      close_holes();
      read_all();
    endtask
  endclass

  class router_fill_test extends router_base_test;
    `uvm_component_utils(router_fill_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual task body();
      read_all();
      wr(A_CTRL, 32'h1);
      close_holes();
      read_all();
    endtask
  endclass
endpackage
