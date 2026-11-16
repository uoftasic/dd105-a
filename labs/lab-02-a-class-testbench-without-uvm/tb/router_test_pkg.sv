// DD105-A Lab 02: the one piece of UVM in this lab.
//
// router_class_test does what the `initial` block of a classic SystemVerilog
// testbench does: it makes the environment, hands it the interfaces, and
// calls env.run(). It's a UVM test, extending dd105_base_test, only so that
// this lab runs like every other one in the course: `make` picks it with
// +UVM_TESTNAME, and the graders read UVM's report summary at the end of the
// log. It adds one check of its own: if the testbench reported any errors,
// it reports one UVM_ERROR saying how many, and dd105_base_test turns that
// into a failing exit status.
//
// You don't need to change this file.

package router_test_pkg;
  import uvm_pkg::*;
  import router_tb_pkg::*;
  `include "uvm_macros.svh"

  class router_class_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(router_class_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      router_cfg            cfg;
      env                   e;
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
      e.run();
      if (e.n_errors() > 0)
        `uvm_error("TB", $sformatf("the testbench reported %0d error%s", e.n_errors(),
                                   e.n_errors() == 1 ? string'("") : string'("s")))
      phase.drop_objection(this);
    endtask
  endclass
endpackage
