// DD105-A guide example: Constrained random on Verilator.
//
// Each test below randomizes a few small classes and prints what came out.
// The classes use SimProc's ALU operations, the design of Lab 01, but there
// is no design in this build: nothing here drives a pin.
//
//   cr_item_test    randomize(), randomize() with {...}, a call that fails,
//                   and constraint_mode()
//   cr_enum_test    how often each value of a rand enum comes out, with and
//                   without a constraint that names it
//   cr_dist_test    a dist written with enum names and with numbers; a dist
//                   together with another constraint on the same variable
//   cr_solve_test   solve...before

package cr_pkg;
  import uvm_pkg::*;
  import dd105_pkg::*;
  `include "uvm_macros.svh"

  // SimProc's six ALU operations: six names in three bits, as in Lab 01.
  typedef enum bit [2:0] {ADD, SUB, OR, NAND, SHL, SHR} alu_op_e;

  // Enums whose names fill their bits (four in two, eight in three) and
  // one that doesn't (three in two), for cr_enum_test.
  typedef enum bit [1:0] {N3_A, N3_B, N3_C} e3_t;
  typedef enum bit [1:0] {N4_A, N4_B, N4_C, N4_D} e4_t;
  typedef enum bit [2:0] {N8_A, N8_B, N8_C, N8_D, N8_E, N8_F, N8_G, N8_H} e8_t;

  // What one operand of an ALU vector looks like, as a selector.
  typedef enum bit [1:0] {K_ZERO, K_ONES, K_SAME, K_ANY} kind_e;

  // Pad a label to n characters. (On Verilator 5.050 a %-Ns in a format
  // string upset the %02h after it, so this file pads by hand.)
  function automatic string pad(string s, int n);
    while (s.len() < n) s = {s, " "};
    return s;
  endfunction

  // ── the classes ───────────────────────────────────────────────────────────

  // An ALU vector. The shifts use B[1:0] only, so B is kept below 4 for them.
  class alu_vec;
    rand alu_op_e  op;
    rand bit [7:0] A, B;
    constraint c_op    { op inside {[ADD:SHR]}; }
    constraint c_shift { (op inside {SHL, SHR}) -> B < 8'd4; }
    function string str();
      return $sformatf("%s A=%02h B=%02h", op.name(), A, B);
    endfunction
  endclass

  // A rand enum that no constraint names, beside a rand bit [1:0], as in
  // Lab 03's experiments.
  class free3; rand bit [1:0] dst; rand e3_t     v; endclass
  class free4; rand bit [1:0] dst; rand e4_t     v; endclass
  class free6; rand bit [1:0] dst; rand alu_op_e v; endclass
  class free8; rand bit [1:0] dst; rand e8_t     v; endclass

  // The three-name enum again, in a parameterized class.
  class free_param #(type T = e3_t);
    rand bit [1:0] dst;
    rand T         v;
  endclass

  // The ALU operation with a constraint that names it, two ways.
  class op_inside;
    rand alu_op_e op;
    constraint c_op { op inside {[ADD:SHR]}; }
  endclass

  class op_dist;
    rand alu_op_e op;
    constraint c_op { op dist {[ADD:SHR] := 1}; }
  endclass

  // The four-name enum with a constraint that names all four values.
  class e4_inside;
    rand bit [1:0] dst;
    rand e4_t      v;
    constraint c_v { v inside {[N4_A:N4_D]}; }
  endclass

  // Weights 10/20/30/40 on the operand kind, written with names and with
  // numbers. Both mean the same thing to the standard.
  class kind_names;
    rand kind_e kind;
    constraint c_kind { kind dist {K_ZERO := 10, K_ONES := 20, K_SAME := 30, K_ANY := 40}; }
  endclass

  class kind_numbers;
    rand kind_e kind;
    constraint c_kind { kind dist {0 := 10, 1 := 20, 2 := 30, 3 := 40}; }
  endclass

  // A vector whose operation has a dist with one entry per value, ADD five
  // times as likely as each of the others ...
  class vec_dist_each;
    rand alu_op_e  op;
    rand bit [7:0] A, B;
    constraint c_op { op dist {0 := 5, 1 := 1, 2 := 1, 3 := 1, 4 := 1, 5 := 1}; }
  endclass

  // ... and one whose dist is a single range, the way Lab 01's alu_item
  // spreads its operations evenly.
  class vec_dist_range;
    rand alu_op_e  op;
    rand bit [7:0] A, B;
    constraint c_op { op dist {[ADD:SHR] := 1}; }
  endclass

  // A dist on a selector, kind, and implications that choose A from it.
  class vec_kind;
    rand kind_e    kind;
    rand bit [7:0] A, B;
    constraint c_kind { kind dist {0 := 10, 1 := 20, 2 := 30, 3 := 40}; }
    constraint c_A    { (kind == K_ZERO) -> A == 8'h00;
                        (kind == K_ONES) -> A == 8'hFF;
                        (kind == K_SAME) -> A == B; }
  endclass

  // solve...before: pick shifts half the time.
  class pick_solve;
    rand bit      is_shift;
    rand alu_op_e op;
    constraint c { is_shift  -> op inside {SHL, SHR};
                   !is_shift -> op inside {ADD, SUB, OR, NAND};
                   solve is_shift before op; }
  endclass

  class pick_plain;
    rand bit      is_shift;
    rand alu_op_e op;
    constraint c { is_shift  -> op inside {SHL, SHR};
                   !is_shift -> op inside {ADD, SUB, OR, NAND}; }
  endclass

  // The same with a dist on is_shift instead of solve...before.
  class pick_dist;
    rand bit      is_shift;
    rand alu_op_e op;
    constraint c { is_shift  -> op inside {SHL, SHR};
                   !is_shift -> op inside {ADD, SUB, OR, NAND};
                   is_shift dist {0 := 1, 1 := 1}; }
  endclass

  // ── the tests ─────────────────────────────────────────────────────────────

  class cr_base_test extends dd105_base_test;
    `uvm_component_utils(cr_base_test)
    int unsigned n = 1000;      // draws per experiment

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      void'($value$plusargs("N=%d", n));
      body();
      phase.drop_objection(this);
    endtask

    virtual task body();
    endtask

    // "label  ADD 171  SUB 162 ..." for a histogram of the ALU operations.
    function string ops(int unsigned h[6]);
      string s = "";
      for (int i = 0; i < 6; i++) s = {s, $sformatf("  %s %4d", alu_op_e'(i), h[i])};
      return s;
    endfunction
  endclass

  // randomize(), randomize() with {...}, a call that can't be satisfied, and
  // constraint_mode().
  class cr_item_test extends cr_base_test;
    `uvm_component_utils(cr_item_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task body();
      alu_vec v = new();
      int     ok;
      repeat (4) begin
        ok = v.randomize();
        $display("[ITEM] randomize() returned %0d: %s", ok, v.str());
      end
      repeat (2) begin
        ok = v.randomize() with { op == SUB; A == B; };
        $display("[ITEM] with { op == SUB; A == B; } returned %0d: %s", ok, v.str());
      end
      // c_shift keeps B below 4 for a shift, so this can't be satisfied.
      $display("[ITEM] before: %s", v.str());
      ok = v.randomize() with { op == SHL; B == 8'd5; };
      $display("[ITEM] with { op == SHL; B == 5; } returned %0d: %s", ok, v.str());
      v.c_shift.constraint_mode(0);
      ok = v.randomize() with { op == SHL; B == 8'd5; };
      $display("[ITEM] the same with c_shift off returned %0d: %s", ok, v.str());
    endtask
  endclass

  // How often each value of a rand enum comes out.
  class cr_enum_test extends cr_base_test;
    `uvm_component_utils(cr_enum_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    // n draws of class C, whose rand enum is v with K names.
    `define CR_HIST(C, K, LABEL) \
      begin \
        C b = new(); \
        int unsigned h[8], f, named; \
        string s; \
        repeat (n) if (b.randomize() != 0) h[int'(b.v)]++; else f++; \
        s = pad({"[ENUM] ", LABEL}, 44); \
        for (int i = 0; i < K; i++) begin s = {s, $sformatf(" %4d", h[i])}; named += h[i]; end \
        if (n - f > named) s = {s, $sformatf("   and %0d values that aren't names", n - f - named)}; \
        if (f > 0) s = {s, $sformatf("   randomize() returned 0 %0d times", f)}; \
        $display("%s", s); \
      end

    task body();
      int unsigned h[6];
      `CR_HIST(free3, 3, "3 names in 2 bits, no constraint:")
      `CR_HIST(free4, 4, "4 names in 2 bits, no constraint:")
      `CR_HIST(free6, 6, "6 names in 3 bits, no constraint:")
      `CR_HIST(free8, 8, "8 names in 3 bits, no constraint:")
      `CR_HIST(e4_inside, 4, "4 names, v inside {[N4_A:N4_D]}:")
      `CR_HIST(free_param #(e3_t), 3, "3 names, in a parameterized class:")
      begin
        op_inside b = new();
        h = '{default: 0};
        repeat (n) if (b.randomize() != 0) h[int'(b.op)]++;
        $display("%s%s", pad("[ENUM] op inside {[ADD:SHR]}:", 40), ops(h));
      end
      begin
        op_dist b = new();
        h = '{default: 0};
        repeat (n) if (b.randomize() != 0) h[int'(b.op)]++;
        $display("%s%s", pad("[ENUM] op dist {[ADD:SHR] := 1}:", 40), ops(h));
      end
    endtask
  endclass

  // A dist written with names and with numbers, and a dist with a second
  // constraint on the same variable.
  class cr_dist_test extends cr_base_test;
    `uvm_component_utils(cr_dist_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task body();
      kind_names     a = new();
      kind_numbers   b = new();
      vec_dist_each  e = new();
      vec_dist_range r = new();
      vec_kind       k = new();
      int unsigned   ha[4], hb[4], hk[4], he[6];
      int unsigned   fail_e, fail_e_off, fail_r, fail_k, fail_k_off;
      int            ok;
      repeat (n) begin
        if (a.randomize() != 0) ha[int'(a.kind)]++;
        if (b.randomize() != 0) hb[int'(b.kind)]++;
        if (e.randomize() != 0) he[int'(e.op)]++;
      end
      $display("[DIST] weights 10/20/30/40 by name:    K_ZERO %4d  K_ONES %4d  K_SAME %4d  K_ANY %4d",
               ha[0], ha[1], ha[2], ha[3]);
      $display("[DIST] weights 10/20/30/40 by number:  K_ZERO %4d  K_ONES %4d  K_SAME %4d  K_ANY %4d",
               hb[0], hb[1], hb[2], hb[3]);
      $display("[DIST] op dist {0 := 5, 1 := 1, ...}: %s", ops(he));
      // The dist on op, and an inline constraint on op.
      repeat (n) begin
        ok = e.randomize() with { op == SUB; };
        if (ok == 0) fail_e++;
      end
      e.c_op.constraint_mode(0);
      repeat (n) begin
        ok = e.randomize() with { op == SUB; };
        if (ok == 0) fail_e_off++;
      end
      repeat (n) begin
        ok = r.randomize() with { op == SUB; };
        if (ok == 0) fail_r++;
      end
      $display("[DIST] op dist {0 := 5, 1 := 1, ...}, then with { op == SUB; }: randomize() failed %0d times in %0d", fail_e, n);
      $display("[DIST] the same with c_op.constraint_mode(0):              randomize() failed %0d times in %0d", fail_e_off, n);
      $display("[DIST] op dist {[ADD:SHR] := 1}, then with { op == SUB; }:  randomize() failed %0d times in %0d", fail_r, n);
      // The dist on the selector, and an inline constraint on A.
      repeat (n) begin
        ok = k.randomize() with { A < 8'h10; };
        if (ok == 0) fail_k++;
        else hk[int'(k.kind)]++;
      end
      k.c_kind.constraint_mode(0);
      repeat (n) begin
        ok = k.randomize() with { A < 8'h10; };
        if (ok == 0) fail_k_off++;
      end
      $display("[DIST] kind dist, then with { A < 8'h10; }:                   randomize() failed %0d times in %0d", fail_k, n);
      $display("[DIST]   the calls that worked: K_ZERO %0d  K_ONES %0d  K_SAME %0d  K_ANY %0d",
               hk[0], hk[1], hk[2], hk[3]);
      $display("[DIST] the same with c_kind.constraint_mode(0):                randomize() failed %0d times in %0d", fail_k_off, n);
    endtask
  endclass

  // solve...before.
  class cr_solve_test extends cr_base_test;
    `uvm_component_utils(cr_solve_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task body();
      pick_solve   a = new();
      pick_plain   b = new();
      pick_dist    c = new();
      int unsigned ha[6], hb[6], hc[6], sa, sb, sc;
      repeat (n) begin
        if (a.randomize() != 0) begin ha[int'(a.op)]++; sa += a.is_shift; end
        if (b.randomize() != 0) begin hb[int'(b.op)]++; sb += b.is_shift; end
        if (c.randomize() != 0) begin hc[int'(c.op)]++; sc += c.is_shift; end
      end
      $display("[SOLVE] solve is_shift before op:  is_shift in %0d of %0d; %s", sa, n, ops(ha));
      $display("[SOLVE] without solve...before:    is_shift in %0d of %0d; %s", sb, n, ops(hb));
      $display("[SOLVE] is_shift dist {0:=1, 1:=1}: is_shift in %0d of %0d; %s", sc, n, ops(hc));
    endtask
  endclass
endpackage
