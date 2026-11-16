// DD105-A reference environment: the tests.
//
// Every test extends router_base_test, which extends dd105_base_test (the
// solver check and an exit status that means something). The base test
// builds the environment, starts a sink sequence on each output that runs
// for the whole test, and runs one virtual sequence, which each test names.
//
//   router_all_test         every directed sequence, then random traffic
//   router_smoke_test       one configuration, a few dozen packets
//   router_rand_test        random everything (+N=<packets>, +PHASES=<n>)
//   router_full_test        the admission threshold, independent outputs
//   router_oversize_test    packets longer than 8 beats
//   router_ctrl_test        CTRL.EN at packet boundaries
//   router_same_cycle_test  a write and an event in the same cycle
//   router_saturate_test    both drop counters to 255
//   router_regs_test        reset values, access policies, all 256 addresses
//   router_reset_test       reset with packets and transfers in flight
//   router_irq_test         the interrupt against every INT_EN setting
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
      return router_smoke_vseq::type_id::create("vseq");
    endfunction

    task run_phase(uvm_phase phase);
      router_base_vseq v = make_vseq();
      stream_snk_seq   ss[2];
      phase.raise_objection(this);
      foreach (ss[p]) begin
        ss[p] = stream_snk_seq::type_id::create($sformatf("snk%0d_seq", p));
        ss[p].cfg = env.snk_c[p];
      end
      fork
        ss[0].start(env.snk[0].sqr);
        ss[1].start(env.snk[1].sqr);
      join_none
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
      phase.drop_objection(this);
    endtask
  endclass

  class router_all_test extends router_base_test;
    `uvm_component_utils(router_all_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_all_vseq::type_id::create("vseq");
    endfunction
  endclass

  class router_smoke_test extends router_base_test;
    `uvm_component_utils(router_smoke_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class router_rand_test extends router_base_test;
    `uvm_component_utils(router_rand_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_rand_vseq::type_id::create("vseq");
    endfunction
  endclass

  class router_full_test extends router_base_test;
    `uvm_component_utils(router_full_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_full_vseq::type_id::create("vseq");
    endfunction
  endclass

  class router_oversize_test extends router_base_test;
    `uvm_component_utils(router_oversize_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_oversize_vseq::type_id::create("vseq");
    endfunction
  endclass

  class router_ctrl_test extends router_base_test;
    `uvm_component_utils(router_ctrl_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_ctrl_vseq::type_id::create("vseq");
    endfunction
  endclass

  class router_same_cycle_test extends router_base_test;
    `uvm_component_utils(router_same_cycle_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_same_cycle_vseq::type_id::create("vseq");
    endfunction
  endclass

  class router_saturate_test extends router_base_test;
    `uvm_component_utils(router_saturate_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_saturate_vseq::type_id::create("vseq");
    endfunction
  endclass

  class router_regs_test extends router_base_test;
    `uvm_component_utils(router_regs_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_regs_vseq::type_id::create("vseq");
    endfunction
  endclass

  class router_reset_test extends router_base_test;
    `uvm_component_utils(router_reset_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_reset_vseq::type_id::create("vseq");
    endfunction
  endclass

  class router_irq_test extends router_base_test;
    `uvm_component_utils(router_irq_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function router_base_vseq make_vseq();
      return router_irq_vseq::type_id::create("vseq");
    endfunction
  endclass
endpackage
