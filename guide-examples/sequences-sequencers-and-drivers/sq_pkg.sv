// DD105-A guide example: Sequences, sequencers and drivers.
//
// SimProc's ALU from Lab 01, driven by a sequence through a sequencer and a
// driver. Every step of the handshake prints a line with the time, so you can
// see who waits for whom:
//
//   sq_timeline_test   one sequence of three random vectors
//   sq_two_test        two sequences on the same sequencer at once
//   sq_nested_test     a sequence that starts two other sequences
//
// There is no monitor or scoreboard here; the next page's example adds them.

package sq_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  `include "uvm_macros.svh"

  typedef enum bit [2:0] {ADD, SUB, OR, NAND, SHL, SHR} alu_op_e;

  function automatic string pad(string s, int n);
    while (s.len() < n) s = {s, " "};
    return s;
  endfunction

  // "  25 ns  [seq a]  start_item returned"
  function automatic void say(string who, string what);
    $display("%s ns  %s %s", pad($sformatf("%0d", $time), 4), pad({"[", who, "]"}, 8), what);
  endfunction

  // ── the item ──────────────────────────────────────────────────────────────
  class alu_item extends uvm_sequence_item;
    `uvm_object_utils(alu_item)
    rand alu_op_e  op;
    rand bit [7:0] A, B;
    string         tag;        // which sequence made it, for the printout
    constraint c_op { op dist {[ADD:SHR] := 1}; }

    function new(string name = "alu_item");
      super.new(name);
    endfunction

    function string convert2string();
      return $sformatf("%s%s A=%02h B=%02h", tag == "" ? string'("") : {tag, ": "}, op.name(), A, B);
    endfunction
  endclass

  // ── the sequences ─────────────────────────────────────────────────────────
  // n random vectors. Each one is made, handed to start_item(), randomized
  // once the driver has asked for it, and sent with finish_item().
  class alu_rand_seq extends uvm_sequence #(alu_item);
    `uvm_object_utils(alu_rand_seq)
    int unsigned n = 3;
    string       tag = "a";

    function new(string name = "alu_rand_seq");
      super.new(name);
    endfunction

    task body();
      for (int k = 0; k < n; k++) begin
        req = alu_item::type_id::create("req");
        req.tag = tag;
        say({"seq ", tag}, "start_item(req): waiting for the sequencer");
        start_item(req);
        say({"seq ", tag}, "start_item returned; randomize()");
        if (!req.randomize()) `uvm_fatal("RAND", "randomize() failed")
        finish_item(req);
        say({"seq ", tag}, {"finish_item returned: ", req.convert2string(), " is done"});
      end
    endtask
  endclass

  // Two directed vectors, SUB with equal and with unequal operands.
  class alu_sub_seq extends uvm_sequence #(alu_item);
    `uvm_object_utils(alu_sub_seq)
    function new(string name = "alu_sub_seq");
      super.new(name);
    endfunction
    task send(bit [7:0] a, bit [7:0] b);
      req = alu_item::type_id::create("req");
      req.tag = "sub";
      start_item(req);
      req.op = SUB;
      req.A  = a;
      req.B  = b;
      finish_item(req);
      say("seq sub", {"sent ", req.convert2string()});
    endtask
    task body();
      send(8'h5A, 8'h5A);
      send(8'h5A, 8'h21);
    endtask
  endclass

  // A sequence that starts two others, one after the other, on its own
  // sequencer: two random vectors, then the two SUBs.
  class alu_nested_seq extends uvm_sequence #(alu_item);
    `uvm_object_utils(alu_nested_seq)
    function new(string name = "alu_nested_seq");
      super.new(name);
    endfunction
    task body();
      alu_rand_seq r = alu_rand_seq::type_id::create("r");
      alu_sub_seq  s = alu_sub_seq::type_id::create("s");
      r.n   = 2;
      r.tag = "r";
      r.start(m_sequencer, this);
      s.start(m_sequencer, this);
    endtask
  endclass

  // ── the driver ────────────────────────────────────────────────────────────
  // Puts each vector on the ALU's pins for one clock cycle, through the
  // interface's clocking block, then a cycle with valid low.
  class alu_driver extends uvm_driver #(alu_item);
    `uvm_component_utils(alu_driver)
    virtual sq_alu_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual sq_alu_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "alu_driver has no virtual sq_alu_if")
    endfunction

    task run_phase(uvm_phase phase);
      vif.drv_cb.valid <= 1'b0;
      forever begin
        say("drv", "get_next_item: waiting for an item");
        seq_item_port.get_next_item(req);
        say("drv", {"get_next_item returned ", req.convert2string()});
        @(vif.drv_cb);                       // drive from a clock edge
        vif.drv_cb.valid <= 1'b1;
        vif.drv_cb.ALUop <= req.op;
        vif.drv_cb.A     <= req.A;
        vif.drv_cb.B     <= req.B;
        @(vif.drv_cb);                       // the vector holds for one cycle
        vif.drv_cb.valid <= 1'b0;
        say("drv", {"item_done, ALUout was ", $sformatf("%02h", vif.drv_cb.ALUout)});
        seq_item_port.item_done();
      end
    endtask
  endclass

  // ── the agent and the environment ─────────────────────────────────────────
  class alu_agent extends uvm_agent;
    `uvm_component_utils(alu_agent)
    uvm_sequencer #(alu_item) sqr;
    alu_driver                drv;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = uvm_sequencer#(alu_item)::type_id::create("sqr", this);
      drv = alu_driver::type_id::create("drv", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ── the tests ─────────────────────────────────────────────────────────────
  class sq_base_test extends dd105_base_test;
    `uvm_component_utils(sq_base_test)
    alu_agent agent;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = alu_agent::type_id::create("agent", this);
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      body();
      say("test", "body() returned; dropping the objection");
      phase.drop_objection(this);
    endtask

    virtual task body();
    endtask
  endclass

  class sq_timeline_test extends sq_base_test;
    `uvm_component_utils(sq_timeline_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task body();
      alu_rand_seq s = alu_rand_seq::type_id::create("s");
      s.start(agent.sqr);
    endtask
  endclass

  // Two sequences on one sequencer. The sequencer grants their requests in
  // the order they arrived (UVM_SEQ_ARB_FIFO, the default).
  class sq_two_test extends sq_base_test;
    `uvm_component_utils(sq_two_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task body();
      alu_rand_seq a = alu_rand_seq::type_id::create("a");
      alu_rand_seq b = alu_rand_seq::type_id::create("b");
      a.tag = "a";
      b.tag = "b";
      a.n   = 2;
      b.n   = 2;
      fork
        a.start(agent.sqr);
        b.start(agent.sqr);
      join
    endtask
  endclass

  class sq_nested_test extends sq_base_test;
    `uvm_component_utils(sq_nested_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task body();
      alu_nested_seq s = alu_nested_seq::type_id::create("s");
      s.start(agent.sqr);
    endtask
  endclass
endpackage
