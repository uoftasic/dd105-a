// DD105-A Lab 01: the UVM testbench for SimProc's ALU.
//
// The same job as cocotb/test_alu.py, built the UVM way: a transaction class,
// sequences that make transactions, a driver that puts them on the pins, a
// monitor that reads the pins back into transactions, and a scoreboard that
// checks what the monitor saw. The test at the bottom is chosen at run time
// with +UVM_TESTNAME, so one build serves both tests.
//
//   alu_item           one vector, and what the ALU answered
//   alu_rand_seq       N random vectors (+N=, default 2000)
//   alu_directed_seq   DD104 Lab 03's six directed vectors
//   alu_driver         drives each vector through the interface's clocking block
//   alu_monitor        turns every cycle with valid high back into an alu_item
//   alu_agent          the sequencer, the driver and the monitor
//   alu_scoreboard     checks each alu_item against a model of the ALU
//   alu_env            the agent and the scoreboard, connected
//   alu_base_test      builds the env; alu_rand_test and alu_directed_test

package alu_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  `include "uvm_macros.svh"

  // SimProc's opcodes, the same encoding as the RTL's aluop_t. 6 and 7 are
  // unassigned, and these tests don't send them.
  typedef enum bit [2:0] {ADD, SUB, OR, NAND, SHL, SHR} alu_op_e;

  // ── the transaction ───────────────────────────────────────────────────────

  class alu_item extends uvm_sequence_item;
    `uvm_object_utils(alu_item)

    // The stimulus: randomized by the sequence.
    rand alu_op_e  op;
    rand bit [7:0] A, B;
    rand bit       same;            // A == B in this vector

    // The response: filled in by the monitor from the pins.
    bit [7:0] ALUout;
    bit       N, Z;

    // The course names every rand enum in a constraint, because on Verilator
    // 5.050 an enum that no constraint names can come out skewed, with no
    // warning: an eight-value enum gave its first value 1778 times in 2000.
    // For these six values `op inside {[ADD:SHR]}` isn't even either (it gave
    // SHL and SHR about twice the share of the other four), so this is a
    // dist with equal weights, which gave each operation about a sixth.
    constraint c_op { op dist {[ADD:SHR] := 1}; }

    // One vector in eight has A == B, because SUB rX, rX and NAND rX, rX are
    // how SimProc programs clear a register and write NOT, and uniform random
    // operands would give A == B once in 256. The dist is on `same` rather
    // than on A or B, because on Verilator 5.050 a dist on a variable that
    // another constraint also names can make randomize() fail.
    constraint c_same { same dist {1 := 1, 0 := 7}; same -> B == A; }

    function new(string name = "alu_item");
      super.new(name);
    endfunction

    // A plain %s for the name: on Verilator 5.050, a %-4s here made every
    // %02h after it drop its leading zero.
    function string convert2string();
      return $sformatf("%s A=%02h B=%02h -> ALUout=%02h N=%0b Z=%0b",
                       op.name(), A, B, ALUout, N, Z);
    endfunction
  endclass

  // ── the sequences ─────────────────────────────────────────────────────────

  class alu_rand_seq extends uvm_sequence #(alu_item);
    `uvm_object_utils(alu_rand_seq)
    int unsigned n = 2000;

    function new(string name = "alu_rand_seq");
      super.new(name);
    endfunction

    virtual task body();
      repeat (n) begin
        req = alu_item::type_id::create("req");
        start_item(req);
        if (!req.randomize()) `uvm_fatal("RAND", "randomize() failed")
        finish_item(req);
      end
    endtask
  endclass

  // DD104 Lab 03's t01: one vector per operation, each with two different
  // operands, because SUB(x, x) and NAND(x, x) are exactly the vectors a
  // swapped subtractor and a NAND that computes NOR both get right.
  class alu_directed_seq extends uvm_sequence #(alu_item);
    `uvm_object_utils(alu_directed_seq)

    function new(string name = "alu_directed_seq");
      super.new(name);
    endfunction

    task send(alu_op_e op, bit [7:0] a, bit [7:0] b);
      req = alu_item::type_id::create("req");
      start_item(req);
      req.op = op;
      req.A  = a;
      req.B  = b;
      finish_item(req);
    endtask

    virtual task body();
      send(ADD,  200,   60);
      send(SUB,  200,   60);
      send(OR,   8'hF0, 8'h0F);
      send(NAND, 8'hC3, 8'h1D);
      send(SHL,  8'h21, 2);
      send(SHR,  8'hF8, 3);
    endtask
  endclass

  // ── the agent: driver, monitor, sequencer ────────────────────────────────

  class alu_driver extends uvm_driver #(alu_item);
    `uvm_component_utils(alu_driver)
    virtual alu_if.DRV vif;
    int unsigned n_sent;            // vectors driven; alu_env checks the count

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual alu_if.DRV)::get(this, "", "drv_vif", vif))
        `uvm_fatal("NOVIF", "drv_vif is not in config_db")
    endfunction

    // One vector per clock cycle, with valid low in a cycle that has none.
    // try_next_item() comes before the wait for the clock edge: it returns
    // late in its time step, and a vector driven after it would land a
    // cycle late.
    task run_phase(uvm_phase phase);
      vif.drv_cb.valid <= 0;
      forever begin
        seq_item_port.try_next_item(req);
        @(vif.drv_cb);
        if (req == null) begin
          vif.drv_cb.valid <= 0;
        end else begin
          vif.drv_cb.valid <= 1;
          vif.drv_cb.ALUop <= req.op;
          vif.drv_cb.A     <= req.A;
          vif.drv_cb.B     <= req.B;
          n_sent++;
          seq_item_port.item_done();
        end
      end
    endtask
  endclass

  // Reads every signal on the interface and knows nothing about what the
  // answer should be; deciding that is the scoreboard's job.
  class alu_monitor extends uvm_monitor;
    `uvm_component_utils(alu_monitor)
    virtual alu_if.MON vif;
    uvm_analysis_port #(alu_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      ap = new("ap", this);
      if (!uvm_config_db#(virtual alu_if.MON)::get(this, "", "mon_vif", vif))
        `uvm_fatal("NOVIF", "mon_vif is not in config_db")
    endfunction

    task run_phase(uvm_phase phase);
      alu_item t;
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.valid) begin
          t = alu_item::type_id::create("t");
          t.op     = alu_op_e'(vif.mon_cb.ALUop);
          t.A      = vif.mon_cb.A;
          t.B      = vif.mon_cb.B;
          t.ALUout = vif.mon_cb.ALUout;
          t.N      = vif.mon_cb.N;
          t.Z      = vif.mon_cb.Z;
          ap.write(t);
        end
      end
    endtask
  endclass

  class alu_agent extends uvm_agent;
    `uvm_component_utils(alu_agent)
    uvm_sequencer #(alu_item) sqr;
    alu_driver  drv;
    alu_monitor mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      sqr = uvm_sequencer#(alu_item)::type_id::create("sqr", this);
      drv = alu_driver::type_id::create("drv", this);
      mon = alu_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ── the scoreboard ────────────────────────────────────────────────────────

  // Checks every vector the monitor saw against predict(), a model of the ALU
  // written from SimProc's instruction set rather than from the RTL. As
  // shipped, it checks ALUout and nothing else.
  class alu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(alu_scoreboard)
    uvm_analysis_imp #(alu_item, alu_scoreboard) imp;

    int unsigned n_checked;
    int unsigned n_bad_value;
    int unsigned bad_value[6];      // value mismatches, per operation

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      imp = new("imp", this);
    endfunction

    // What the ALU should answer. The shifts use B[1:0] only, so they shift
    // by 0 to 3. N is bit 7 of the result, and Z is set when the result is
    // zero; SimProc has no carry or overflow flag.
    function void predict(alu_item t, output bit [7:0] out, output bit n, output bit z);
      case (t.op)
        ADD:     out = t.A + t.B;
        SUB:     out = t.A - t.B;
        OR:      out = t.A | t.B;
        NAND:    out = ~(t.A & t.B);
        SHL:     out = t.A << t.B[1:0];
        SHR:     out = t.A >> t.B[1:0];
        default: out = 8'h00;
      endcase
      n = out[7];
      z = (out == 8'h00);
    endfunction

    // The monitor calls this once for every vector it sees.
    function void write(alu_item t);
      bit [7:0] out;
      bit       n, z;
      predict(t, out, n, z);
      n_checked++;
      if (t.ALUout != out) begin
        n_bad_value++;
        bad_value[t.op]++;
        `uvm_error("VALUE", $sformatf("%s, expected ALUout=%02h", t.convert2string(), out))
      end
      // TODO (Lab 01, Part 5): predict() has already worked out n and z, and
      // the monitor has filled in t.N and t.Z. Compare them too. Count flag
      // mismatches separately from value mismatches, as DD104 Lab 03's t02
      // does, report each one with `uvm_error under its own ID ("FLAGS"), and
      // add the count to the line report_phase prints.
    endfunction

    // The nonzero counts, as " (OP n, OP n)", or "" when every count is 0.
    function string per_op(int unsigned counts[6]);
      string   s;
      alu_op_e op;
      s = "";
      for (int i = 0; i < 6; i++) begin
        op = alu_op_e'(i);
        if (counts[i] != 0)
          s = {s, (s == "") ? "" : ", ", $sformatf("%s %0d", op.name(), counts[i])};
      end
      return (s == "") ? "" : {" (", s, ")"};
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SB", $sformatf("%0d vectors checked: %0d value mismatches%s",
                                n_checked, n_bad_value, per_op(bad_value)), UVM_NONE)
    endfunction
  endclass

  // ── the environment ───────────────────────────────────────────────────────

  class alu_env extends uvm_env;
    `uvm_component_utils(alu_env)
    alu_agent      agt;
    alu_scoreboard sb;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      agt = alu_agent::type_id::create("agt", this);
      sb  = alu_scoreboard::type_id::create("sb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      agt.mon.ap.connect(sb.imp);
    endfunction

    // A scoreboard that checked nothing passes, so check that it checked
    // every vector the driver sent.
    function void check_phase(uvm_phase phase);
      if (sb.n_checked == 0)
        `uvm_error("COUNT", "the scoreboard checked no vectors")
      else if (agt.drv.n_sent != sb.n_checked)
        `uvm_error("COUNT", $sformatf("the driver sent %0d vectors and the scoreboard checked %0d",
                                      agt.drv.n_sent, sb.n_checked))
    endfunction
  endclass

  // ── the tests ─────────────────────────────────────────────────────────────

  // dd105_base_test turns any UVM_ERROR into a nonzero exit status; without
  // it, a run that reports errors on this simulator still exits 0.
  class alu_base_test extends dd105_base_test;
    `uvm_component_utils(alu_base_test)
    alu_env env;
    virtual alu_if.DRV vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = alu_env::type_id::create("env", this);
      if (!uvm_config_db#(virtual alu_if.DRV)::get(this, "", "drv_vif", vif))
        `uvm_fatal("NOVIF", "drv_vif is not in config_db")
    endfunction

    virtual task stimulus();
    endtask

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      stimulus();
      repeat (3) @(vif.drv_cb);     // let the last vector reach the scoreboard
      phase.drop_objection(this);
    endtask
  endclass

  // N random vectors: +N=500 changes N without a rebuild.
  class alu_rand_test extends alu_base_test;
    `uvm_component_utils(alu_rand_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task stimulus();
      alu_rand_seq seq = alu_rand_seq::type_id::create("seq");
      void'($value$plusargs("N=%d", seq.n));
      seq.start(env.agt.sqr);
    endtask
  endclass

  class alu_directed_test extends alu_base_test;
    `uvm_component_utils(alu_directed_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual task stimulus();
      alu_directed_seq seq = alu_directed_seq::type_id::create("seq");
      seq.start(env.agt.sqr);
    endtask
  endclass
endpackage
