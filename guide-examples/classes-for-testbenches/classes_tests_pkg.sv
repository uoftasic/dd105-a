// DD105-A guide example: the UVM tests that run each demonstration in
// classes_demo_pkg.sv, as Lab 02's router_class_test runs its env. Pick one
// with
//
//   make run UVM_TESTNAME=handles_test
//
// The demonstrations themselves use no UVM.

package classes_tests_pkg;
  import uvm_pkg::*;
  import classes_demo_pkg::*;
  `include "uvm_macros.svh"

  class handles_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(handles_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      handles();
      phase.drop_objection(this);
    endtask
  endclass

  class reuse_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(reuse_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      reuse();
      phase.drop_objection(this);
    endtask
  endclass

  class dispatch_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(dispatch_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      dispatch();
      phase.drop_objection(this);
    endtask
  endclass

  class null_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(null_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      null_handle();
      phase.drop_objection(this);
    endtask
  endclass
endpackage
