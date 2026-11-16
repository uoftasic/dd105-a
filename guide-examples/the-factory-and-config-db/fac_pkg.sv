// DD105-A guide example: The factory and config_db.
//
// Every test here builds the environment from the monitors example
// (../monitors-analysis-ports-and-scoreboards/mon_pkg.sv) without editing a
// line of it. Each one changes what gets built, or how it's configured, from
// the test alone:
//
//   fac_equal_test   a factory override: every alu_item the sequence makes
//                    becomes an alu_equal_item, which always has A == B
//   fac_flags_test   config_db: check_flags = 1 for the scoreboard, so it
//                    checks N and Z as well as ALUout
//   fac_typo_test    the same set, with the scoreboard's path misspelt
//   fac_prec_test    the test and the environment both set check_flags for
//                    the scoreboard; the environment's set comes later

package fac_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  import mon_pkg::*;
  `include "uvm_macros.svh"

  // An alu_item whose operands are always equal. Its constraint has the same
  // name as alu_item's c_same, so it replaces that one.
  class alu_equal_item extends alu_item;
    `uvm_object_utils(alu_equal_item)
    constraint c_same { same == 1; same -> B == A; }
    function new(string name = "alu_equal_item");
      super.new(name);
    endfunction
  endclass

  // An environment that sets its own default for the scoreboard's knob.
  class fac_env extends alu_env;
    `uvm_component_utils(fac_env)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      uvm_config_db#(bit)::set(this, "sb", "check_flags", 0);
      $display("[ENV] %s set check_flags = 0 for \"sb\"", get_full_name());
      super.build_phase(phase);
    endfunction
  endclass

  class fac_equal_test extends mon_base_test;
    `uvm_component_utils(fac_equal_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      alu_item::type_id::set_type_override(alu_equal_item::get_type());
      super.build_phase(phase);
    endfunction
    function void end_of_elaboration_phase(uvm_phase phase);
      uvm_factory::get().print(0);
    endfunction
  endclass

  class fac_flags_test extends mon_base_test;
    `uvm_component_utils(fac_flags_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      uvm_config_db#(bit)::set(this, "env.sb", "check_flags", 1);
      super.build_phase(phase);
    endfunction
  endclass

  class fac_typo_test extends mon_base_test;
    `uvm_component_utils(fac_typo_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      uvm_config_db#(bit)::set(this, "env.scoreboard", "check_flags", 1);
      super.build_phase(phase);
    endfunction
  endclass

  class fac_prec_test extends mon_base_test;
    `uvm_component_utils(fac_prec_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      alu_env::type_id::set_type_override(fac_env::get_type());
      uvm_config_db#(bit)::set(this, "env.sb", "check_flags", 1);
      $display("[TEST] %s set check_flags = 1 for \"env.sb\"", get_full_name());
      super.build_phase(phase);
    endfunction
  endclass
endpackage
