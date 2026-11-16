// DD105-A guide example, "Regressions and seeds": the testbench.
//
// count_test   random inc and clr for CYCLES cycles (default 300), each cycle
//              checked against a model; a covergroup records which levels the
//              counter reached and whether it was incremented at 15.
//              +INC_PCT=n and +CLR_PCT=n (defaults 60 and 15) set how often
//              each input is 1.
// random_test  prints the first four values that two threads draw with
//              $urandom, so you can see what a seed fixes. Before thread A
//              draws, it can do one more thing:
//                +EXTRA_DRAW   draw one value more
//                +EXTRA_NEW    make an object of a plain class with new()
//                +EXTRA_SEQ    make a UVM sequence with type_id::create()
//                +EXTRA_START  make a UVM sequence and start it; its body is empty

interface cnt_if (input logic clk, input logic rst_n);
  logic       inc, clr;
  logic [3:0] count;
  clocking cb @(posedge clk);
    default input #1step output #1;
    output inc, clr;
    input  count;
  endclocking
endinterface

package seeds_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class count_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(count_test)
    virtual cnt_if vif;
    int unsigned   n_cycles = 300, inc_pct = 60, clr_pct = 15;
    int unsigned   n_top, n_inc_top, n_bad;

    covergroup cg_count with function sample(bit [3:0] c, bit inc_at_top);
      cp_level: coverpoint c {
        bins low  = {[0:7]};
        bins high = {[8:14]};
        bins top  = {15};
      }
      cp_inc_at_top: coverpoint inc_at_top {
        bins yes = {1};
      }
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg_count = new();
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual cnt_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "no virtual cnt_if in config_db")
      void'($value$plusargs("CYCLES=%d", n_cycles));
      void'($value$plusargs("INC_PCT=%d", inc_pct));
      void'($value$plusargs("CLR_PCT=%d", clr_pct));
    endfunction

    task run_phase(uvm_phase phase);
      bit       inc = 0, clr = 0;   // the inputs in the cycle that just ended
      bit [3:0] model = 0;          // what the counter should hold in that cycle
      bit [3:0] got;
      phase.raise_objection(this);
      @(posedge vif.rst_n);
      repeat (n_cycles) begin
        @(vif.cb);
        got = vif.cb.count;
        if (got != model) begin
          n_bad++;
          `uvm_error("COUNT", $sformatf("count is %0d, expected %0d", got, model))
          model = got;                // follow the design, so one fault is one error
        end
        if (got == 4'd15) n_top++;
        if (got == 4'd15 && inc && !clr) n_inc_top++;
        cg_count.sample(got, got == 4'd15 && inc && !clr);
        if (clr)                       model = 4'd0;
        else if (inc && model != 4'd15) model = model + 4'd1;
        inc = ($urandom_range(99) < inc_pct);
        clr = ($urandom_range(99) < clr_pct);
        vif.cb.inc <= inc;
        vif.cb.clr <= clr;
      end
      phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("COUNT", $sformatf("%0d cycles: at 15 in %0d, incremented at 15 in %0d; %0d wrong",
                n_cycles, n_top, n_inc_top, n_bad), UVM_LOW)
    endfunction
  endclass

  class thing;
    rand bit [7:0] x;
  endclass

  class empty_seq extends uvm_sequence;
    `uvm_object_utils(empty_seq)
    function new(string name = "empty_seq");
      super.new(name);
    endfunction
    task body();
    endtask
  endclass

  class random_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(random_test)
    uvm_sequencer #(uvm_sequence_item) sqr;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = uvm_sequencer#(uvm_sequence_item)::type_id::create("sqr", this);
    endfunction
    function string draws(int n);
      string s = "";
      for (int i = 0; i < n; i++) s = {s, $sformatf(" %08h", $urandom)};
      return s;
    endfunction
    task run_phase(uvm_phase phase);
      string    a, b;
      thing     t;
      empty_seq s;
      phase.raise_objection(this);
      fork
        begin                                       // thread A
          if ($test$plusargs("EXTRA_DRAW"))  void'($urandom);
          if ($test$plusargs("EXTRA_NEW"))   t = new();
          if ($test$plusargs("EXTRA_SEQ"))   s = empty_seq::type_id::create("s");
          if ($test$plusargs("EXTRA_START")) begin
            s = empty_seq::type_id::create("s");
            s.start(sqr);
          end
          a = draws(4);
        end
        begin                                       // thread B
          #1 b = draws(4);
        end
      join
      `uvm_info("RANDOM", {"thread A:", a}, UVM_LOW)
      `uvm_info("RANDOM", {"thread B:", b}, UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass
endpackage

module seeds_tb_top;
  import uvm_pkg::*;
  import seeds_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst_n = 1'b0;
  initial begin
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;
  end

  cnt_if cif (clk, rst_n);
  satcnt dut (.clk(clk), .rst_n(rst_n), .inc(cif.inc), .clr(cif.clr), .count(cif.count));

  initial begin
    uvm_config_db#(virtual cnt_if)::set(null, "uvm_test_top", "vif", cif);
    run_test();
  end
endmodule
