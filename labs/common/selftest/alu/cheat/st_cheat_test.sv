// SELFTEST FIXTURE -- a test that asks the simulator which bug is on, and so
// "catches" every bug without checking anything. check.py and hunt.py must
// refuse it before they build or run anything. It is never compiled.
package st_cheat_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  class st_cheat_test extends st_pkg::st_good_test;
    `uvm_component_utils(st_cheat_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void final_phase(uvm_phase phase);
      if ($test$plusargs("BUG")) `uvm_error("GOTCHA", "a bug is on")
      if (st_bug_pkg::bug_id != 0) `uvm_error("GOTCHA", "a bug is on")
      super.final_phase(phase);
    endfunction
  endclass
endpackage
