// DD105-A guide example: Functional coverage you can read.
//
// A covergroup on ALU vectors, and two small ones that show how Verilator
// 5.050 counts bins. There is no design in this build: the tests randomize
// vectors and sample them, which is all a covergroup needs.
//
//   cov_plain_test    300 vectors with A and B uniformly random
//   cov_biased_test   300 vectors, one in eight with A == B, and A at 00 or ff
//                     more often
//
// Each run writes coverage.dat (uvm.mk builds with --coverage-user), and
// `make cov` lists every bin with its count.
//
// Build with +define+CG_MEMBER to see the form of covergroup this simulator
// leaves out: one whose coverpoints read a member of the class it is in.

package cov_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  `include "uvm_macros.svh"

  // SimProc's six ALU operations, as in Lab 01.
  typedef enum bit [2:0] {ADD, SUB, OR, NAND, SHL, SHR} alu_op_e;

  // An ALU vector. c_bias makes one vector in eight have A == B, and puts A
  // at 00 or ff a quarter of the time; c_plain leaves A and B uniformly
  // random. Each test turns one of the two off.
  class alu_vec;
    rand alu_op_e  op;
    rand bit [7:0] A, B;
    rand bit       same;
    rand bit [1:0] a_kind;     // 0: A = 00, 1: A = ff, 2 or 3: anything
    constraint c_op    { op dist {[ADD:SHR] := 1}; }
    constraint c_link  { same -> B == A;
                         (a_kind == 0) -> A == 8'h00;
                         (a_kind == 1) -> A == 8'hFF; }
    constraint c_bias  { same dist {1 := 1, 0 := 7};
                         a_kind dist {0 := 1, 1 := 1, 2 := 3, 3 := 3}; }
    constraint c_plain { same == 0; a_kind inside {[2:3]}; }
  endclass

  // The covergroups, in a class, as a UVM subscriber would hold them.
  class alu_cov;
`ifdef CG_MEMBER
    // The form most examples use: the coverpoints read a member.
    alu_vec v;
    covergroup cg_alu;
      cp_op: coverpoint v.op;
    endgroup
`else
    // The form this course uses: the values arrive as arguments of sample().
    covergroup cg_alu with function sample(int op, bit [7:0] a, bit eq);
      cp_op: coverpoint op {
        bins add     = {0};
        bins sub     = {1};
        bins or_op   = {2};
        bins nand_op = {3};
        bins shl     = {4};
        bins shr     = {5};
      }
      cp_a: coverpoint a {
        bins zero  = {8'h00};
        bins ones  = {8'hFF};
        bins other = {[8'h01:8'hFE]};
      }
      cp_eq: coverpoint eq {
        bins differ = {0};
        bins equal  = {1};
      }
      x_op_eq: cross cp_op, cp_eq;
    endgroup
`endif

    // Two coverpoints with the same array of bins, one of them crossed.
    covergroup cg_arr with function sample(int v, int w);
      cp_alone:   coverpoint v { bins v[] = {[0:3]}; }
      cp_crossed: coverpoint w { bins w[] = {[0:3]}; }
      cp_half:    coverpoint v { bins lo = {[0:1]}; bins hi = {[2:3]}; }
      x_w_half:   cross cp_crossed, cp_half;
    endgroup

    // Eight bins, two of them ignored.
    covergroup cg_ign with function sample(int op);
      cp_op: coverpoint op { bins op[] = {[0:7]}; ignore_bins unused = {6, 7}; }
    endgroup

    function new();
      cg_alu = new();
      cg_arr = new();
      cg_ign = new();
    endfunction

    function void sample(alu_vec t);
`ifdef CG_MEMBER
      v = t;
      cg_alu.sample();
`else
      cg_alu.sample(int'(t.op), t.A, t.A == t.B);
`endif
      cg_arr.sample(int'(t.A[1:0]), int'(t.B[1:0]));
      cg_ign.sample(int'(t.op));
    endfunction
  endclass

  class cov_base_test extends dd105_base_test;
    `uvm_component_utils(cov_base_test)
    int unsigned n = 300;
    bit          bias;
    alu_cov      cov;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      alu_vec      v = new();
      int unsigned n_eq;
      phase.raise_objection(this);
      void'($value$plusargs("N=%d", n));
      cov = new();
      if (bias) v.c_plain.constraint_mode(0);
      else      v.c_bias.constraint_mode(0);
      repeat (n) begin
        if (!v.randomize()) `uvm_fatal("RAND", "randomize() failed")
        if (v.A == v.B) n_eq++;
        cov.sample(v);
      end
      $display("[COV] %0d vectors, %0d of them with A == B", n, n_eq);
      phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
      $display("[COV] cg_alu: get_inst_coverage() = %0.2f, get_coverage() = %0.2f",
               cov.cg_alu.get_inst_coverage(), cov.cg_alu.get_coverage());
      $display("[COV] cg_arr: get_inst_coverage() = %0.2f", cov.cg_arr.get_inst_coverage());
      $display("[COV] cg_ign: get_inst_coverage() = %0.2f", cov.cg_ign.get_inst_coverage());
    endfunction
  endclass

  class cov_plain_test extends cov_base_test;
    `uvm_component_utils(cov_plain_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
      bias = 0;
    endfunction
  endclass

  class cov_biased_test extends cov_base_test;
    `uvm_component_utils(cov_biased_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
      bias = 1;
    endfunction
  endclass
endpackage
