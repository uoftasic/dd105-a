// DD105-A guide example: Monitors, analysis ports and scoreboards.
//
// SimProc's ALU from Lab 01 with a complete agent: the driver from the
// sequences example, a monitor that turns every cycle with valid high back
// into an alu_item and writes it to an analysis port, and three subscribers
// on that one port: a scoreboard, a coverage collector and a history that
// keeps every handle it is given.
//
//   mon_rand_test    200 random vectors (+N= changes the count)
//   mon_alias_test   the same, with a monitor that reuses one alu_item for
//                    every write, swapped in by a factory override
//
// make run BUG=A01 runs the same test on the ALU with SUB's operands swapped.
// The factory and config_db example (../the-factory-and-config-db) builds
// this environment too, and changes it from its tests alone.

package mon_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  `include "uvm_macros.svh"

  typedef enum bit [2:0] {ADD, SUB, OR, NAND, SHL, SHR} alu_op_e;

  // ── the item ──────────────────────────────────────────────────────────────
  class alu_item extends uvm_sequence_item;
    `uvm_object_utils(alu_item)
    rand alu_op_e  op;
    rand bit [7:0] A, B;
    rand bit       same;           // A == B in this vector
    bit [7:0]      ALUout;         // filled in by the monitor
    bit            N, Z;
    constraint c_op   { op dist {[ADD:SHR] := 1}; }
    constraint c_same { same dist {1 := 1, 0 := 7}; same -> B == A; }

    function new(string name = "alu_item");
      super.new(name);
    endfunction

    function string convert2string();
      return $sformatf("%s A=%02h B=%02h -> ALUout=%02h N=%0b Z=%0b", op.name(), A, B, ALUout, N, Z);
    endfunction
  endclass

  class alu_rand_seq extends uvm_sequence #(alu_item);
    `uvm_object_utils(alu_rand_seq)
    int unsigned n = 200;
    function new(string name = "alu_rand_seq");
      super.new(name);
    endfunction
    task body();
      repeat (n) begin
        req = alu_item::type_id::create("req");
        start_item(req);
        if (!req.randomize()) `uvm_fatal("RAND", "randomize() failed")
        finish_item(req);
      end
    endtask
  endclass

  // ── the agent ─────────────────────────────────────────────────────────────
  // The driver from the sequences example: one cycle per vector, then a
  // cycle with valid low.
  class alu_driver extends uvm_driver #(alu_item);
    `uvm_component_utils(alu_driver)
    virtual mon_alu_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual mon_alu_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "alu_driver has no virtual mon_alu_if")
    endfunction
    task run_phase(uvm_phase phase);
      vif.drv_cb.valid <= 1'b0;
      forever begin
        seq_item_port.get_next_item(req);
        @(vif.drv_cb);
        vif.drv_cb.valid <= 1'b1;
        vif.drv_cb.ALUop <= req.op;
        vif.drv_cb.A     <= req.A;
        vif.drv_cb.B     <= req.B;
        @(vif.drv_cb);
        vif.drv_cb.valid <= 1'b0;
        seq_item_port.item_done();
      end
    endtask
  endclass

  // The monitor reads the pins and nothing else: it doesn't know what the
  // driver sent or what the answer should be. It makes a new alu_item for
  // every vector, because every subscriber gets the same handle.
  class alu_monitor extends uvm_monitor;
    `uvm_component_utils(alu_monitor)
    uvm_analysis_port #(alu_item) ap;
    virtual mon_alu_if vif;
    int unsigned n_seen;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual mon_alu_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "alu_monitor has no virtual mon_alu_if")
    endfunction

    // The item this vector goes into. A subclass can change where it comes from.
    virtual function alu_item next_item();
      return alu_item::type_id::create("seen");
    endfunction

    task run_phase(uvm_phase phase);
      alu_item t;
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.valid) begin
          t        = next_item();
          t.op     = alu_op_e'(vif.mon_cb.ALUop);
          t.A      = vif.mon_cb.A;
          t.B      = vif.mon_cb.B;
          t.ALUout = vif.mon_cb.ALUout;
          t.N      = vif.mon_cb.N;
          t.Z      = vif.mon_cb.Z;
          n_seen++;
          ap.write(t);
        end
      end
    endtask
  endclass

  // The mistake: one alu_item, filled in again for every vector.
  class alu_reuse_monitor extends alu_monitor;
    `uvm_component_utils(alu_reuse_monitor)
    alu_item only;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function alu_item next_item();
      if (only == null) only = alu_item::type_id::create("seen");
      return only;
    endfunction
  endclass

  class alu_agent extends uvm_agent;
    `uvm_component_utils(alu_agent)
    uvm_sequencer #(alu_item) sqr;
    alu_driver                drv;
    alu_monitor               mon;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = uvm_sequencer#(alu_item)::type_id::create("sqr", this);
      drv = alu_driver::type_id::create("drv", this);
      mon = alu_monitor::type_id::create("mon", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ── the subscribers ───────────────────────────────────────────────────────
  // The scoreboard: a model of the ALU written from SimProc's instruction set,
  // and a comparison. write() is called once per vector, from the monitor's
  // run_phase, and returns at once; the scoreboard has no thread of its own.
  // check_flags (from config_db, 0 by default) adds N and Z to the check.
  class alu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(alu_scoreboard)
    uvm_analysis_imp #(alu_item, alu_scoreboard) imp;
    bit          check_flags;
    int unsigned n_checked, n_bad;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      imp = new("imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      void'(uvm_config_db#(bit)::get(this, "", "check_flags", check_flags));
    endfunction

    function bit [7:0] predict(alu_item t);
      case (t.op)
        ADD:     return t.A + t.B;
        SUB:     return t.A - t.B;
        OR:      return t.A | t.B;
        NAND:    return ~(t.A & t.B);
        SHL:     return t.A << t.B[1:0];
        SHR:     return t.A >> t.B[1:0];
        default: return 8'h00;
      endcase
    endfunction

    virtual function void write(alu_item t);
      bit [7:0] want = predict(t);
      bit       bad  = (t.ALUout != want);
      if (check_flags) bad |= (t.N != want[7]) || (t.Z != (want == 8'h00));
      n_checked++;
      if (bad) begin
        n_bad++;
        `uvm_error("SB", $sformatf("%s, expected ALUout=%02h N=%0b Z=%0b", t.convert2string(),
                   want, want[7], want == 8'h00))
      end
    endfunction

    function void check_phase(uvm_phase phase);
      if (n_checked == 0) `uvm_error("SB", "no vector was checked")
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SB", $sformatf("%0d vectors checked%s: %0d wrong", n_checked,
                check_flags ? string'(" with N and Z") : string'(""), n_bad), UVM_LOW)
    endfunction
  endclass

  // Coverage: which operations ran with equal and with unequal operands.
  class alu_coverage extends uvm_subscriber #(alu_item);
    `uvm_component_utils(alu_coverage)
    covergroup cg with function sample(int op, bit eq);
      cp_op: coverpoint op { bins add = {0}; bins sub = {1}; bins or_op = {2};
                             bins nand_op = {3}; bins shl = {4}; bins shr = {5}; }
      cp_eq: coverpoint eq { bins differ = {0}; bins equal = {1}; }
      x_op_eq: cross cp_op, cp_eq;
    endgroup
    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg = new();
    endfunction
    function void write(alu_item t);
      cg.sample(int'(t.op), t.A == t.B);
    endfunction
    function void report_phase(uvm_phase phase);
      `uvm_info("COV", $sformatf("cg: %0.1f%% of its bins hit", cg.get_inst_coverage()), UVM_LOW)
    endfunction
  endclass

  // Keeps every handle it is given, and at the end looks at what they hold.
  class alu_history extends uvm_subscriber #(alu_item);
    `uvm_component_utils(alu_history)
    alu_item kept[$];
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void write(alu_item t);
      kept.push_back(t);
    endfunction
    function void report_phase(uvm_phase phase);
      int unsigned distinct = 0;
      foreach (kept[i]) begin
        bit seen;
        seen = 0;
        for (int j = 0; j < i; j++) if (kept[j] == kept[i]) seen = 1;
        if (!seen) distinct++;
      end
      `uvm_info("HIST", $sformatf("kept %0d handles to %0d different objects", kept.size(), distinct), UVM_LOW)
      for (int i = 0; i < 3 && i < kept.size(); i++)
        `uvm_info("HIST", $sformatf("vector %0d: %s", i, kept[i].convert2string()), UVM_LOW)
    endfunction
  endclass

  // ── the environment ───────────────────────────────────────────────────────
  // One analysis port, three subscribers. The monitor doesn't know any of
  // them are there.
  class alu_env extends uvm_env;
    `uvm_component_utils(alu_env)
    alu_agent      agent;
    alu_scoreboard sb;
    alu_coverage   cov;
    alu_history    hist;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = alu_agent::type_id::create("agent", this);
      sb    = alu_scoreboard::type_id::create("sb", this);
      cov   = alu_coverage::type_id::create("cov", this);
      hist  = alu_history::type_id::create("hist", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      agent.mon.ap.connect(sb.imp);
      agent.mon.ap.connect(cov.analysis_export);
      agent.mon.ap.connect(hist.analysis_export);
    endfunction
  endclass

  // ── the tests ─────────────────────────────────────────────────────────────
  class mon_base_test extends dd105_base_test;
    `uvm_component_utils(mon_base_test)
    alu_env      env;
    int unsigned n = 200;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      void'($value$plusargs("N=%d", n));
      env = alu_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      alu_rand_seq s = alu_rand_seq::type_id::create("s");
      phase.raise_objection(this);
      s.n = n;
      s.start(env.agent.sqr);
      phase.drop_objection(this);
    endtask
    function void report_phase(uvm_phase phase);
      `uvm_info("MON", $sformatf("the monitor wrote %0d items", env.agent.mon.n_seen), UVM_LOW)
    endfunction
  endclass

  class mon_rand_test extends mon_base_test;
    `uvm_component_utils(mon_rand_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class mon_alias_test extends mon_base_test;
    `uvm_component_utils(mon_alias_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      alu_monitor::type_id::set_type_override(alu_reuse_monitor::get_type());
      super.build_phase(phase);
    endfunction
  endclass
endpackage
