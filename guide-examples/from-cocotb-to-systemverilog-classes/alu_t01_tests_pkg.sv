// DD105-A guide example: the UVM tests that run alu_t01_pkg.sv's code, as
// Lab 02's router_class_test runs its env. The class code uses no UVM.
//
//   make run UVM_TESTNAME=t01_test               the golden ALU
//   make run UVM_TESTNAME=t01_test BUG=A01       bug A01 switched on
package alu_t01_tests_pkg;
  import uvm_pkg::*;
  import alu_t01_pkg::*;
  `include "uvm_macros.svh"

  class t01_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(t01_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      virtual alu_pins_if vif;
      alu_t01             t;
      if (!uvm_config_db#(virtual alu_pins_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "the top module didn't set vif")
      t = new(vif);
      phase.raise_objection(this);
      t.t01_one_vector_per_operation();
      phase.drop_objection(this);
    endtask
  endclass

  class widths_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(widths_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      widths();
      literals();
      phase.drop_objection(this);
    endtask
  endclass
endpackage
