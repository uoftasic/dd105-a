// DD105-A guide example: The UVM skeleton.
//
// A test, an environment and two agents with one child each, every one of
// which prints a line when each of its phases runs. There is no design: the
// point is the order in which UVM calls things, and what ends the run.
//
//   sk_phase_test   the test holds an objection for 100 ns, the agent a1's
//                   child for 150 ns; a monitor-like loop runs forever
//   sk_noobj_test   the same environment, and nobody raises an objection
//   sk_error_test   the run reports one UVM_ERROR

package sk_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  `include "uvm_macros.svh"

  function automatic string pad(string s, int n);
    while (s.len() < n) s = {s, " "};
    return s;
  endfunction

  // "   0 ns  build_phase        uvm_test_top.env"
  function automatic void say(string what, uvm_component c);
    $display("%s ns  %s %s", pad($sformatf("%0d", $time), 4), pad(what, 26), c.get_full_name());
  endfunction

  // A component that prints a line in each of its phases. The others below
  // extend it, so every one of them does the same.
  class sk_comp extends uvm_component;
    `uvm_component_utils(sk_comp)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);              say("build_phase", this);              endfunction
    function void connect_phase(uvm_phase phase);            say("connect_phase", this);            endfunction
    function void end_of_elaboration_phase(uvm_phase phase); say("end_of_elaboration_phase", this); endfunction
    function void start_of_simulation_phase(uvm_phase phase);say("start_of_simulation_phase", this);endfunction
    function void extract_phase(uvm_phase phase);            say("extract_phase", this);            endfunction
    function void check_phase(uvm_phase phase);              say("check_phase", this);              endfunction
    function void report_phase(uvm_phase phase);             say("report_phase", this);             endfunction
    function void final_phase(uvm_phase phase);              say("final_phase", this);              endfunction
  endclass

  // The child of each agent. In a1 it holds an objection for hold ns.
  class sk_leaf extends sk_comp;
    `uvm_component_utils(sk_leaf)
    int unsigned hold;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      say("run_phase starts", this);
      if (hold > 0) begin
        phase.raise_objection(this);
        #(hold * 1ns);
        say($sformatf("drops after %0d ns", hold), this);
        phase.drop_objection(this);
      end
    endtask
  endclass

  // A component that loops forever, the way a monitor does.
  class sk_watcher extends sk_comp;
    `uvm_component_utils(sk_watcher)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        say("run_phase: still looping", this);
        #40ns;
      end
    endtask
  endclass

  class sk_agent extends sk_comp;
    `uvm_component_utils(sk_agent)
    sk_leaf child;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      child = sk_leaf::type_id::create("child", this);
    endfunction
  endclass

  class sk_env extends sk_comp;
    `uvm_component_utils(sk_env)
    sk_agent   a0, a1;
    sk_watcher mon;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // Made in this order on purpose: the printout shows the order UVM
      // builds them in.
      mon = sk_watcher::type_id::create("mon", this);
      a1  = sk_agent::type_id::create("a1", this);
      a0  = sk_agent::type_id::create("a0", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      a1.child.hold = 150;
    endfunction
  endclass

  // The test. dd105_base_test adds the solver check and the exit status, and
  // the test prints its own phases the way sk_comp does.
  class sk_phase_test extends dd105_base_test;
    `uvm_component_utils(sk_phase_test)
    sk_env       env;
    int unsigned hold = 100;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      say("build_phase", this);
      env = sk_env::type_id::create("env", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      say("connect_phase", this);
    endfunction
    function void end_of_elaboration_phase(uvm_phase phase);
      say("end_of_elaboration_phase", this);
      uvm_root::get().print_topology();
    endfunction
    function void start_of_simulation_phase(uvm_phase phase);
      say("start_of_simulation_phase", this);
    endfunction
    task run_phase(uvm_phase phase);
      say("run_phase starts", this);
      if (hold > 0) begin
        phase.raise_objection(this);
        phase.get_objection().set_drain_time(this, 20ns);
        #(hold * 1ns);
        say($sformatf("drops after %0d ns", hold), this);
        phase.drop_objection(this);
      end
    endtask
    function void extract_phase(uvm_phase phase);
      say("extract_phase", this);
    endfunction
    function void check_phase(uvm_phase phase);
      say("check_phase", this);
    endfunction
    function void report_phase(uvm_phase phase);
      say("report_phase", this);
    endfunction
    function void final_phase(uvm_phase phase);
      say("final_phase", this);
      super.final_phase(phase);
    endfunction
  endclass

  // Nobody raises an objection.
  class sk_noobj_test extends sk_phase_test;
    `uvm_component_utils(sk_noobj_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
      hold = 0;
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      env.a1.child.hold = 0;
    endfunction
    function void end_of_elaboration_phase(uvm_phase phase);
      say("end_of_elaboration_phase", this);
    endfunction
  endclass

  // One UVM_ERROR, at 50 ns.
  class sk_error_test extends sk_phase_test;
    `uvm_component_utils(sk_error_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void end_of_elaboration_phase(uvm_phase phase);
      say("end_of_elaboration_phase", this);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      #50ns;
      `uvm_error("CHECK", "a check failed at 50 ns")
      #50ns;
      phase.drop_objection(this);
    endtask
  endclass
endpackage
