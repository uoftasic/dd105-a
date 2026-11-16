// SELFTEST -- the environment and the fixture tests. Not an example to copy.
//
// st_good_test is a working test. Every other test here is broken on purpose,
// and its comment names the verdict it must provoke. selftest.py runs each one
// through the graders and fails if the verdict has drifted.
package st_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  `include "uvm_macros.svh"

  typedef enum bit [2:0] {ADD, SUB, AND, OR, XOR, SHL, SHR, PASSB} st_op_e;

  class st_item extends uvm_sequence_item;
    `uvm_object_utils(st_item)
    rand st_op_e   op;
    rand bit [7:0] a, b;
    rand bit       eq;
    bit [7:0] result;
    bit       carry;
    constraint c_op { op inside {[ADD:PASSB]}; }
    constraint c_eq { eq dist {1 := 1, 0 := 3}; eq -> b == a; }
    function new(string name = "st_item"); super.new(name); endfunction
    function string convert2string();
      return $sformatf("%s a=%02h b=%02h -> r=%02h c=%0b", op.name(), a, b, result, carry);
    endfunction
  endclass

  class st_rand_seq extends uvm_sequence #(st_item);
    `uvm_object_utils(st_rand_seq)
    int unsigned n = 300;
    function new(string name = "st_rand_seq"); super.new(name); endfunction
    virtual task body();
      repeat (n) begin
        req = st_item::type_id::create("req");
        start_item(req);
        if (!req.randomize()) `uvm_fatal("RAND", "randomize() failed")
        finish_item(req);
      end
    endtask
  endclass

  class st_driver extends uvm_driver #(st_item);
    `uvm_component_utils(st_driver)
    virtual st_if.DRV vif;
    int unsigned n_sent;                     // items driven, checked against the scoreboard
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual st_if.DRV)::get(this, "", "drv_vif", vif))
        `uvm_fatal("NOVIF", "drv_vif not set")
    endfunction
    task run_phase(uvm_phase phase);
      vif.drv_cb.in_valid <= 0;
      forever begin
        seq_item_port.try_next_item(req);
        @(vif.drv_cb);
        if (req == null) vif.drv_cb.in_valid <= 0;
        else begin
          vif.drv_cb.in_valid <= 1; vif.drv_cb.op <= req.op;
          vif.drv_cb.a <= req.a;    vif.drv_cb.b <= req.b;
          n_sent++;
          seq_item_port.item_done();
        end
      end
    endtask
  endclass

  class st_monitor extends uvm_monitor;
    `uvm_component_utils(st_monitor)
    virtual st_if.MON vif;
    uvm_analysis_port #(st_item) ap;
    st_item pending[$];
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      ap = new("ap", this);
      if (!uvm_config_db#(virtual st_if.MON)::get(this, "", "mon_vif", vif))
        `uvm_fatal("NOVIF", "mon_vif not set")
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        @(vif.mon_cb);
        if (!vif.mon_cb.rst_n) begin pending.delete(); continue; end
        if (vif.mon_cb.out_valid && pending.size() > 0) begin
          st_item t = pending.pop_front();
          t.result = vif.mon_cb.result; t.carry = vif.mon_cb.carry;
          ap.write(t);
        end
        if (vif.mon_cb.in_valid) begin
          st_item t = st_item::type_id::create("t");
          t.op = st_op_e'(vif.mon_cb.op); t.a = vif.mon_cb.a; t.b = vif.mon_cb.b;
          pending.push_back(t);
        end
      end
    endtask
  endclass

  class st_agent extends uvm_agent;
    `uvm_component_utils(st_agent)
    uvm_sequencer #(st_item) sqr;
    st_driver  drv;
    st_monitor mon;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      sqr = uvm_sequencer#(st_item)::type_id::create("sqr", this);
      drv = st_driver::type_id::create("drv", this);
      mon = st_monitor::type_id::create("mon", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // Checks result and carry. The zero flag is left to the assertion in
  // st_sva.sv, so bug B02 can only be caught by an assertion.
  class st_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(st_scoreboard)
    uvm_analysis_imp #(st_item, st_scoreboard) imp;
    int unsigned n_ok, n_bad;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase); imp = new("imp", this); endfunction
    function void write(st_item t);
      bit [8:0] w;
      case (t.op)
        ADD:     w = {1'b0, t.a} + {1'b0, t.b};
        SUB:     w = {t.a < t.b, t.a - t.b};
        AND:     w = {1'b0, t.a & t.b};
        OR:      w = {1'b0, t.a | t.b};
        XOR:     w = {1'b0, t.a ^ t.b};
        SHL:     w = {1'b0, t.a} << t.b[2:0];
        SHR:     w = {1'b0, t.a >> t.b[2:0]};
        default: w = {1'b0, t.b};
      endcase
      if (t.result == w[7:0] && t.carry == w[8]) n_ok++;
      else begin n_bad++; mismatch(t, w[7:0], w[8]); end
    endfunction
    virtual function void mismatch(st_item t, bit [7:0] r, bit c);
      `uvm_error("SB", $sformatf("MISMATCH %s, expected r=%02h c=%0b", t.convert2string(), r, c))
    endfunction
    function void report_phase(uvm_phase phase);
      `uvm_info("SB", $sformatf("checked %0d transactions: %0d ok, %0d mismatches",
                                n_ok + n_bad, n_ok, n_bad), UVM_NONE)
    endfunction
  endclass

  class st_coverage extends uvm_subscriber #(st_item);
    `uvm_component_utils(st_coverage)
    covergroup cg with function sample(st_op_e op, bit eq);
      cp_op : coverpoint op;
      cp_eq : coverpoint eq;
      x_op_eq : cross cp_op, cp_eq;
    endgroup
    function new(string name, uvm_component parent); super.new(name, parent); cg = new; endfunction
    function void write(st_item t); cg.sample(t.op, t.a == t.b); endfunction
  endclass

  class st_env extends uvm_env;
    `uvm_component_utils(st_env)
    st_agent      agt;
    st_scoreboard sb;
    st_coverage   cov;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      agt = st_agent::type_id::create("agt", this);
      sb  = st_scoreboard::type_id::create("sb", this);
      cov = st_coverage::type_id::create("cov", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      agt.mon.ap.connect(sb.imp);
      agt.mon.ap.connect(cov.analysis_export);
    endfunction
    // Every item the driver sent must come out of the design.
    function void check_phase(uvm_phase phase);
      if (agt.drv.n_sent != sb.n_ok + sb.n_bad)
        `uvm_error("COUNT", $sformatf("the driver sent %0d items and the scoreboard saw %0d",
                                      agt.drv.n_sent, sb.n_ok + sb.n_bad))
    endfunction
  endclass

  class st_base_test extends dd105_base_test;
    `uvm_component_utils(st_base_test)
    st_env env;
    virtual st_if.DRV vif;
    int unsigned n = 300;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = st_env::type_id::create("env", this);
      if (!uvm_config_db#(virtual st_if.DRV)::get(this, "", "drv_vif", vif))
        `uvm_fatal("NOVIF", "drv_vif not set")
      void'($value$plusargs("N=%d", n));
    endfunction
    task reset_dut();
      vif.rst_n <= 0; repeat (3) @(vif.drv_cb); vif.rst_n <= 1; @(vif.drv_cb);
    endtask
    virtual task stimulus();
      st_rand_seq seq = st_rand_seq::type_id::create("seq");
      seq.n = n;
      seq.start(env.agt.sqr);
    endtask
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      reset_dut();
      stimulus();
      repeat (3) @(vif.drv_cb);
      phase.drop_objection(this);
    endtask
  endclass

  // ── the fixtures ─────────────────────────────────────────────────────────

  // WORKS. Golden: ok. B01: caught (UVM_ERROR [SB]). B02: caught (assertion).
  // B03: MISSED (one operand pair in 65,536).
  class st_good_test extends st_base_test;
    `uvm_component_utils(st_good_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  // Sends nothing. Passes on everything: MISSED on every bug.
  class st_empty_test extends st_base_test;
    `uvm_component_utils(st_empty_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual task stimulus(); endtask
  endclass

  // Sends 300 items but never randomizes them, so every one is ADD 00 + 00.
  // Passes on everything: MISSED on every bug.
  class st_fixed_seq extends st_rand_seq;
    `uvm_object_utils(st_fixed_seq)
    function new(string name = "st_fixed_seq"); super.new(name); endfunction
    virtual task body();
      repeat (n) begin
        req = st_item::type_id::create("req");
        start_item(req);
        finish_item(req);
      end
    endtask
  endclass
  class st_fixed_test extends st_base_test;
    `uvm_component_utils(st_fixed_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual task stimulus();
      st_fixed_seq seq = st_fixed_seq::type_id::create("seq");
      seq.n = n;
      seq.start(env.agt.sqr);
    endtask
  endclass

  // Plain UVM: extends uvm_test, not dd105_base_test, and throws away what
  // randomize() returns. With the solver: ok on golden, caught on B01 with
  // exit status 0 (the grader reads the log). With no solver at run time it
  // sends ADD 00 + 00 three hundred times and would pass on everything; the
  // grader must call that BROKEN.
  class st_lax_seq extends st_rand_seq;
    `uvm_object_utils(st_lax_seq)
    function new(string name = "st_lax_seq"); super.new(name); endfunction
    virtual task body();
      repeat (n) begin
        req = st_item::type_id::create("req");
        start_item(req);
        void'(req.randomize());
        finish_item(req);
      end
    endtask
  endclass
  class st_plain_test extends uvm_test;
    `uvm_component_utils(st_plain_test)
    st_env env;
    virtual st_if.DRV vif;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      env = st_env::type_id::create("env", this);
      void'(uvm_config_db#(virtual st_if.DRV)::get(this, "", "drv_vif", vif));
    endfunction
    task run_phase(uvm_phase phase);
      st_lax_seq seq = st_lax_seq::type_id::create("seq");
      phase.raise_objection(this);
      vif.rst_n <= 0; repeat (3) @(vif.drv_cb); vif.rst_n <= 1; @(vif.drv_cb);
      seq.start(env.agt.sqr);
      repeat (3) @(vif.drv_cb);
      phase.drop_objection(this);
    endtask
  endclass

  // Asks config_db for a name nobody set: UVM_FATAL [NOVIF]. BROKEN everywhere.
  class st_null_vif_test extends st_base_test;
    `uvm_component_utils(st_null_vif_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual st_if.DRV)::get(this, "", "dvr_vif", vif))
        `uvm_fatal("NOVIF", "virtual interface 'dvr_vif' not found in config_db")
    endfunction
  endclass

  // Correct until a mismatch, then the code that reports it dereferences a
  // null handle. ok on golden, BROKEN on B01: a crash is not a catch.
  class st_crash_scoreboard extends st_scoreboard;
    `uvm_component_utils(st_crash_scoreboard)
    st_item first_bad;                       // never assigned
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual function void mismatch(st_item t, bit [7:0] r, bit c);
      `uvm_error("SB", $sformatf("MISMATCH again, first was %s", first_bad.convert2string()))
    endfunction
  endclass
  class st_crash_test extends st_base_test;
    `uvm_component_utils(st_crash_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      st_scoreboard::type_id::set_type_override(st_crash_scoreboard::get_type());
      super.build_phase(phase);
    endfunction
  endclass

  // Reports a mismatch with uvm_fatal. ok on golden, BROKEN on B01: a fatal
  // is how a testbench gives up, not how it checks.
  class st_fatal_scoreboard extends st_scoreboard;
    `uvm_component_utils(st_fatal_scoreboard)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual function void mismatch(st_item t, bit [7:0] r, bit c);
      `uvm_fatal("SB", $sformatf("MISMATCH %s", t.convert2string()))
    endfunction
  endclass
  class st_fatal_check_test extends st_base_test;
    `uvm_component_utils(st_fatal_check_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      st_scoreboard::type_id::set_type_override(st_fatal_scoreboard::get_type());
      super.build_phase(phase);
    endfunction
  endclass

  // Waits for an event that never comes. BROKEN: stopped by RUN_TIMEOUT, or
  // by UVM_FATAL [PH_TIMEOUT] when the run has +UVM_TIMEOUT.
  class st_hang_test extends st_base_test;
    `uvm_component_utils(st_hang_test)
    event never;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual task stimulus(); @(never); endtask
  endclass

  // Connects the scoreboard backwards (imp.connect(port)): a UVM_ERROR from
  // the UVM library, on the golden design too. BROKEN, never a catch.
  class st_misconnect_env extends st_env;
    `uvm_component_utils(st_misconnect_env)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void connect_phase(uvm_phase phase);
      sb.imp.connect(agt.mon.ap);
      agt.mon.ap.connect(cov.analysis_export);
    endfunction
  endclass
  class st_misconnect_test extends st_base_test;
    `uvm_component_utils(st_misconnect_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      st_env::type_id::set_type_override(st_misconnect_env::get_type());
      super.build_phase(phase);
    endfunction
  endclass

  // Controls for the Verilator 5.050 NBA trap (see ../../nba/nba_repro.sv).
  // Both drivers write the pins directly with nonblocking assignments: raise
  // in_valid, wait for the clock, lower it. st_nba_item_driver does it once
  // per item; st_nba_beat_driver sends each item as two beats (a, b, then
  // b, a) from a loop inside the item, the way a packet driver sends its
  // beats. A module-task loop written this way loses every beat after the
  // first, but class code keeps them all: both tests pass on the golden
  // design, and st_env's count check confirms every beat arrived. If a new
  // simulator release changes that, these turn red. Golden: ok. B01: caught.
  class st_pin_driver extends st_driver;
    `uvm_component_utils(st_pin_driver)
    virtual st_if pins;
    int unsigned beats = 1;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual st_if)::get(this, "", "pin_vif", pins))
        `uvm_fatal("NOVIF", "pin_vif not set")
    endfunction
    task run_phase(uvm_phase phase);
      pins.in_valid <= 0;
      forever begin
        seq_item_port.get_next_item(req);
        for (int i = 0; i < beats; i++) begin
          pins.in_valid <= 1; pins.op <= req.op;
          pins.a <= (i % 2) ? req.b : req.a;
          pins.b <= (i % 2) ? req.a : req.b;
          @(posedge pins.clk);
          pins.in_valid <= 0;
          n_sent++;
        end
        seq_item_port.item_done();
      end
    endtask
  endclass
  class st_nba_item_driver extends st_pin_driver;
    `uvm_component_utils(st_nba_item_driver)
    function new(string name, uvm_component parent); super.new(name, parent); beats = 1; endfunction
  endclass
  class st_nba_beat_driver extends st_pin_driver;
    `uvm_component_utils(st_nba_beat_driver)
    function new(string name, uvm_component parent); super.new(name, parent); beats = 2; endfunction
  endclass
  class st_nba_item_test extends st_base_test;
    `uvm_component_utils(st_nba_item_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      st_driver::type_id::set_type_override(st_nba_item_driver::get_type());
      super.build_phase(phase);
    endfunction
  endclass
  class st_nba_beat_test extends st_base_test;
    `uvm_component_utils(st_nba_beat_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      st_driver::type_id::set_type_override(st_nba_beat_driver::get_type());
      super.build_phase(phase);
    endfunction
  endclass

  // A contradictory inline constraint, with randomize()'s result thrown away:
  // UNSATCONSTR on every item. BROKEN.
  class st_unsat_seq extends st_rand_seq;
    `uvm_object_utils(st_unsat_seq)
    function new(string name = "st_unsat_seq"); super.new(name); endfunction
    virtual task body();
      repeat (n) begin
        req = st_item::type_id::create("req");
        start_item(req);
        void'(req.randomize() with { op == ADD; op == SUB; });
        finish_item(req);
      end
    endtask
  endclass
  class st_unsat_test extends st_base_test;
    `uvm_component_utils(st_unsat_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    virtual task stimulus();
      st_unsat_seq seq = st_unsat_seq::type_id::create("seq");
      seq.n = 20;
      seq.start(env.agt.sqr);
    endtask
  endclass
endpackage
