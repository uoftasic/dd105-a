// DD105-A Lab 06: the tests.
//
// Every test extends router_base_test, which extends dd105_base_test (the
// solver check and an exit status that means something). The base test
// builds the environment, starts a sink sequence on each output that runs
// for the whole test, and runs one virtual sequence, which each test names.
//
//   router_test           Lab 04's steps, then Lab 05's, then Lab 06's
//                         (router_main_vseq); make check and make check-all
//                         grade this one
//   router_lab06_test     Lab 06's steps on their own (router_lab06_vseq)
//   router_backdoor_test  peek and poke (router_backdoor_vseq)
//
// A watchdog ends a test that runs longer than +MAX_CYCLES=<n> clock cycles
// (default 400000) with a UVM_ERROR, so a router that stops answering is a
// failed check rather than a hang. The run also stops after 50 UVM_ERRORs.

package router_test_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  import stream_pkg::*;
  import router_env_pkg::*;
  import router_seq_pkg::*;
  `include "uvm_macros.svh"

  class router_base_test extends dd105_base_test;
    `uvm_component_utils(router_base_test)
    router_env   env;
    int unsigned max_cycles = 400000;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = router_env::type_id::create("env", this);
      void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_report_server::get_server().set_max_quit_count(50);
    endfunction

    // The virtual sequence this test runs.
    virtual function router_base_vseq make_vseq();
      return router_main_vseq::type_id::create("vseq");
    endfunction

    task run_phase(uvm_phase phase);
      router_base_vseq v = make_vseq();
      stream_snk_seq   ss[2];
      phase.raise_objection(this);
      // The sinks' sequences make one item per beat, forever, so they're
      // started in the background and never waited for.
      foreach (ss[p]) begin
        ss[p] = stream_snk_seq::type_id::create($sformatf("snk%0d_seq", p));
        ss[p].cfg = env.snk_c[p];
      end
      fork
        ss[0].start(env.snk[0].sqr);
        ss[1].start(env.snk[1].sqr);
      join_none
      // The virtual sequence runs on the virtual sequencer, against a watchdog.
      fork
        begin
          fork
            v.start(env.vsqr);
            begin
              repeat (max_cycles) @(env.vif.mon_cb);
              `uvm_error("WATCHDOG", $sformatf("the test was still running after %0d cycles (+MAX_CYCLES)",
                         max_cycles))
            end
          join_any
          disable fork;
        end
      join
      // A sequence's last register read finishes when its driver lets go,
      // half a cycle before the rising edge that completes it. Two more
      // cycles let the monitors see that edge, so the read is checked too.
      repeat (2) @(env.vif.mon_cb);
      phase.drop_objection(this);
    endtask
  endclass

  class router_test extends router_base_test;
    `uvm_component_utils(router_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class router_lab06_test extends router_base_test;
    `uvm_component_utils(router_lab06_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_lab06_vseq::type_id::create("vseq");
    endfunction
  endclass

  class router_backdoor_test extends router_base_test;
    `uvm_component_utils(router_backdoor_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_backdoor_vseq::type_id::create("vseq");
    endfunction
  endclass
endpackage
