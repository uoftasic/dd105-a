// DD105-A guide example: the UVM tests that run each demonstration in
// threads_demo_pkg.sv. Each one raises an objection, runs one class's run()
// and drops it, as Lab 02's router_class_test does with its env. Pick one with
//
//   make run UVM_TESTNAME=fork_test
//
// The demonstrations themselves use no UVM.

package threads_tests_pkg;
  import uvm_pkg::*;
  import threads_demo_pkg::*;
  `include "uvm_macros.svh"

  class fork_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(fork_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      fork_demo d = new();
      phase.raise_objection(this);
      d.run();
      phase.drop_objection(this);
    endtask
  endclass

  // +BOUND=1 gives the mailbox room for one item; the default is unbounded.
  class mailbox_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(mailbox_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      mailbox_demo d;
      int bound = 0;
      void'($value$plusargs("BOUND=%d", bound));
      d = new(bound);
      phase.raise_objection(this);
      $display("mailbox bound %0d%s", bound, bound == 0 ? string'(" (unbounded)") : string'(""));
      d.run();
      phase.drop_objection(this);
    endtask
  endclass

  class capture_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(capture_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      capture_demo d = new();
      phase.raise_objection(this);
      d.run();
      phase.drop_objection(this);
    endtask
  endclass

  // The loop runs in threads_top's initial block, on +STATIC_LOOP; this
  // test only keeps the run going while it does.
  class static_loop_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(static_loop_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      #20;
      phase.drop_objection(this);
    endtask
  endclass

  class event_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(event_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      event_demo d = new();
      phase.raise_objection(this);
      d.run();
      phase.drop_objection(this);
    endtask
  endclass

  class disable_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(disable_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      disable_demo d = new();
      phase.raise_objection(this);
      d.run(0);
      d.run(1);
      phase.drop_objection(this);
    endtask
  endclass
endpackage
