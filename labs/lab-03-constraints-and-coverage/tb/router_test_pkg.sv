// DD105-A Lab 03: the tests, the one piece of UVM in this lab.
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
//                      It fails until close_holes() sends something, because
//                      the scoreboard reports a test that checked no packet.
//   router_class_test  Lab 02's test: +N packets (default 100) on +ROUTES.

package router_test_pkg;
  import uvm_pkg::*;
  import router_tb_pkg::*;
  `include "uvm_macros.svh"

  // TODO (Part 4): a class fill_plan, whose randomize() picks packet lengths
  // that add up to 8.

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

    // TODO (Part 4): stimulus that reaches the two coverage holes.
    virtual task close_holes();
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

  // Lab 02's test, unchanged in what it does.
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
