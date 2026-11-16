// DD105-A: the one class every lab's tests extend.
//
//   class my_test extends dd105_pkg::dd105_base_test;
//
// It adds two things to a plain uvm_test, and nothing else:
//
// 1. A solver check in build_phase. On Verilator 5.050 a constrained
//    randomize() needs an SMT solver. If Verilator can't start one, every
//    randomize() returns 0, the variables keep their old values, and the run
//    still passes. This check stops the run with UVM_FATAL [SOLVER] instead.
//
// 2. A real exit status. Verilator ends a UVM run with exit status 0 even after
//    UVM_ERROR or UVM_FATAL. At the end of the test this class prints the UVM
//    report summary and calls $fatal if UVM counted any error or fatal, so make
//    and the graders can trust the exit status. It hooks final_phase (a normal
//    end) and pre_abort (a UVM_FATAL, which skips final_phase).
//
// If you override final_phase or pre_abort, call super.final_phase(phase) or
// super.pre_abort() from yours, or you lose point 2.
//
// Drivers: drive the design's inputs through a clocking block,
//
//     vif.cb.valid <= 1;  @(vif.cb);  vif.cb.valid <= 0;
//
// rather than with plain nonblocking assignments such as vif.valid <= 1. On
// this simulator (5.050), a module task that does "x <= 1; @(posedge clk);
// x <= 0;" and is called in a loop keeps the 0 when the next call's 1 lands
// in the same time step, so beats go missing; the standard, and Icarus, keep
// the 1. Class code kept every assignment in every shape the selftest tries,
// but a clocking block works everywhere and is what the course teaches.
// labs/common/README.md ("Drive through a clocking block") has the cases.

package dd105_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // A constraint the solver must satisfy: x is 11 to 19, never 0.
  class dd105_solver_probe;
    rand bit [7:0] x;
    constraint c_window { x > 8'd10; x < 8'd20; }
  endclass

  // UVM_FATAL [SOLVER] unless a constrained randomize() really works.
  function automatic void dd105_check_solver();
    dd105_solver_probe p = new();
    int ok = p.randomize();
    if (ok != 1 || !(p.x inside {[8'd11:8'd19]}))
      `uvm_fatal("SOLVER", {"a constrained randomize() failed, so this run cannot ",
                 "randomize anything. Verilator needs VERILATOR_SOLVER=\"yices-smt2 ",
                 "--incremental\" in the environment. Run the test with make, which ",
                 "sets it, or export it before running the simulator by hand."})
  endfunction

  class dd105_base_test extends uvm_test;
    `uvm_component_utils(dd105_base_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      dd105_check_solver();
    endfunction

    virtual function void final_phase(uvm_phase phase);
      super.final_phase(phase);
      m_end_of_test(0);
    endfunction

    // UVM calls this when a UVM_FATAL (or +UVM_MAX_QUIT_COUNT) ends the run.
    virtual function void pre_abort();
      super.pre_abort();
      m_end_of_test(1);
    endfunction

    local function void m_end_of_test(bit aborting);
      uvm_report_server rs = uvm_report_server::get_server();
      int n_err = rs.get_severity_count(UVM_ERROR);
      int n_fat = rs.get_severity_count(UVM_FATAL);
      if (!aborting && n_err + n_fat == 0) begin
        $display("DD105: TEST PASSED");
        return;
      end
      // UVM prints the summary after final_phase and inside die(). $fatal stops
      // the run before either happens, so print it here.
      rs.report_summarize();
      $display("DD105: TEST FAILED (%0d UVM_ERROR, %0d UVM_FATAL)", n_err, n_fat);
      $fatal(1, "DD105: UVM counted errors, so the exit status is nonzero");
    endfunction
  endclass
endpackage
