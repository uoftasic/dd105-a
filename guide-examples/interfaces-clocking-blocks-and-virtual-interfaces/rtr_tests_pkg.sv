// DD105-A guide example: the UVM tests that run each demonstration, as Lab
// 02's router_class_test runs its env. Pick one with +UVM_TESTNAME:
//
//   make run UVM_TESTNAME=edge_test
package rtr_tests_pkg;
  import uvm_pkg::*;
  import rtr_demo_pkg::*;
  `include "uvm_macros.svh"

  class edge_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(edge_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      virtual rtr_pins_if vif;
      edge_demo           d;
      if (!uvm_config_db#(virtual rtr_pins_if)::get(this, "", "pins_vif", vif))
        `uvm_fatal("NOVIF", "the top module didn't set pins_vif")
      d = new(vif);
      phase.raise_objection(this);
      d.run();
      phase.drop_objection(this);
    endtask
  endclass

  // Brings the router out of reset and sets CTRL.EN, with both monitors
  // printing what they sample at each edge from the end of reset on.
  class typedef_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(typedef_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      virtual rtr_pins_if vif;
      virtual rtr_mon_if  mvif;
      edge_demo           d;
      mon_full_type       m_full;
      mon_typedef         m_typed;
      if (!uvm_config_db#(virtual rtr_pins_if)::get(this, "", "pins_vif", vif) ||
          !uvm_config_db#(virtual rtr_mon_if)::get(this, "", "mon_vif", mvif))
        `uvm_fatal("NOVIF", "the top module didn't set every interface")
      d       = new(vif);
      m_full  = new(mvif);
      m_typed = new(mvif);
      phase.raise_objection(this);
      do @(vif.cb); while (!vif.cb.rst_n);
      fork
        m_full.run(4);
        m_typed.run(4);
        d.apb_write(8'h04, 32'h1);
      join
      phase.drop_objection(this);
    endtask
  endclass

  // The module task in the top module runs on +MODULE_TASK; this test only
  // keeps the run going while it does.
  class module_task_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(module_task_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      #100;
      phase.drop_objection(this);
    endtask
  endclass
endpackage
