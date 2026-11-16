// DD105-A Lab 03: constraint experiments.
//
//   make traps            build this file and run it (seconds: no UVM, no router)
//   make traps SEED=2     the same with another seed
//
// Each experiment randomizes a small class many times and prints one line:
// how often each value came out, or how often randomize() failed. Before you
// run it, write down what the SystemVerilog standard says each line should
// show. The classes are the shapes the lab's packet class and its tests use.
// Change them and run again; the build takes a few seconds.

package traps_pkg;
  typedef enum bit [1:0] {LEN_ONE, LEN_MID, LEN_MAX, LEN_OVER} len_kind_e;

  // 1. A rand enum that no constraint names, as in tb/packet.svh.
  class t1_bare;
    rand bit [1:0]  dst;
    rand len_kind_e kind;
  endclass

  class t1_inside;
    rand bit [1:0]  dst;
    rand len_kind_e kind;
    constraint c_kind { kind inside {[LEN_ONE:LEN_OVER]}; }
  endclass

  // 2. Weights 20/50/20/10 on the enum, with the values written as names
  //    and as numbers.
  class t2_names;
    rand len_kind_e kind;
    constraint c_kind { kind dist {LEN_ONE := 20, LEN_MID := 50, LEN_MAX := 20, LEN_OVER := 10}; }
  endclass

  class t2_numbers;
    rand len_kind_e kind;
    constraint c_kind { kind dist {0 := 20, 1 := 50, 2 := 20, 3 := 10}; }
  endclass

  // 3. A dist on len and a second constraint on len; then the same weights
  //    on a selector, kind, with len solved from kind.
  class t3_len;
    rand int unsigned len;
    int unsigned      max_len = 10;
    constraint c_len { len dist {1 := 20, [2:7] :/ 50, 8 := 20, [9:12] :/ 10}; }
    constraint c_max { len <= max_len; }
  endclass

  class t3_sel;
    rand bit [1:0]    kind;
    rand int unsigned len;
    int unsigned      max_len = 10;
    constraint c_kind { kind dist {0 := 20, 1 := 50, 2 := 20, 3 := 10}; }
    constraint c_len  { (kind == 0) -> len == 1;
                        (kind == 1) -> len inside {[2:7]};
                        (kind == 2) -> len == 8;
                        (kind == 3) -> len inside {[9:12]}; }
    constraint c_max  { len <= max_len; }
  endclass

  // 4. solve...before: make half the packets 8 beats long.
  class t4_solve;
    rand bit          big;
    rand int unsigned len;
    constraint c { big -> len == 8; !big -> len inside {[1:7]}; solve big before len; }
  endclass

  class t4_plain;
    rand bit          big;
    rand int unsigned len;
    constraint c { big -> len == 8; !big -> len inside {[1:7]}; }
  endclass

  // 5. Packet lengths that add up to 8, in a dynamic array and in a fixed one
  //    (where a 0 means "no packet").
  class t5_dynamic;
    rand int unsigned lens[];
    constraint c { lens.size() inside {[1:8]};
                   foreach (lens[i]) lens[i] inside {[1:8]};
                   lens.sum() == 8; }
  endclass

  class t5_fixed;
    rand int unsigned lens[8];
    constraint c { foreach (lens[i]) lens[i] inside {[0:8]};
                   lens.sum() == 8; }
  endclass

  // 6. unique on an array, and on four separate variables.
  class t6_array;
    rand bit [3:0] a[4];
    constraint c { unique {a}; }
  endclass

  class t6_scalars;
    rand bit [3:0] w, x, y, z;
    constraint c { unique {w, x, y, z}; }
  endclass
endpackage

module traps;
  import traps_pkg::*;

  t1_bare    e1a = new();
  t1_inside  e1b = new();
  t2_names   e2a = new();
  t2_numbers e2b = new();
  t3_len     e3a = new();
  t3_sel     e3b = new();
  t4_solve   e4a = new();
  t4_plain   e4b = new();
  t5_dynamic e5a = new();
  t5_fixed   e5b = new();
  t6_array   e6a = new();
  t6_scalars e6b = new();

  int h1a[4], h1b[4], h2a[4], h2b[4];
  int f3a, f3b, f3c, f3d, n4a, n4b, f5a, f5b, ok5b, d6a, d6b, sum, ok;

  function automatic string counts(int h[4]);
    return $sformatf("LEN_ONE %4d  LEN_MID %4d  LEN_MAX %4d  LEN_OVER %4d", h[0], h[1], h[2], h[3]);
  endfunction

  initial begin
    repeat (1000) begin
      if (e1a.randomize() != 0) h1a[e1a.kind]++;
      if (e1b.randomize() != 0) h1b[e1b.kind]++;
      if (e2a.randomize() != 0) h2a[e2a.kind]++;
      if (e2b.randomize() != 0) h2b[e2b.kind]++;
      if (e3a.randomize() == 0) f3a++;
      if (e3b.randomize() == 0) f3b++;
      ok = e3b.randomize() with { len == 3; };
      if (ok == 0) f3c++;
      if (e4a.randomize() != 0 && e4a.big) n4a++;
      if (e4b.randomize() != 0 && e4b.big) n4b++;
      if (e6a.randomize() != 0 && (e6a.a[0] == e6a.a[1] || e6a.a[0] == e6a.a[2] || e6a.a[0] == e6a.a[3] ||
                                   e6a.a[1] == e6a.a[2] || e6a.a[1] == e6a.a[3] || e6a.a[2] == e6a.a[3])) d6a++;
      if (e6b.randomize() != 0 && (e6b.w == e6b.x || e6b.w == e6b.y || e6b.w == e6b.z ||
                                   e6b.x == e6b.y || e6b.x == e6b.z || e6b.y == e6b.z)) d6b++;
    end
    e3b.c_kind.constraint_mode(0);
    repeat (1000) begin
      ok = e3b.randomize() with { len == 3; };
      if (ok == 0) f3d++;
    end
    repeat (20) begin
      if (e5a.randomize() == 0) f5a++;
      if (e5b.randomize() == 0) f5b++;
      else begin
        sum = 0;
        foreach (e5b.lens[i]) sum += e5b.lens[i];
        if (sum == 8) ok5b++;
      end
    end

    $display("1  rand enum, no constraint names it        %s", counts(h1a));
    $display("1  the same, with kind inside {...}         %s", counts(h1b));
    $display("2  kind dist {LEN_ONE := 20, ...}           %s", counts(h2a));
    $display("2  kind dist {0 := 20, ...}                 %s", counts(h2b));
    $display("3  len dist {...} and len <= 10             randomize() failed %0d times in 1000", f3a);
    $display("3  kind dist {...}, len from kind, len <= 10  randomize() failed %0d times in 1000", f3b);
    $display("3  the same, with { len == 3; }             randomize() failed %0d times in 1000", f3c);
    $display("3  the same, c_kind.constraint_mode(0)      randomize() failed %0d times in 1000", f3d);
    $display("4  solve big before len                     big in %0d of 1000", n4a);
    $display("4  the same without solve...before          big in %0d of 1000", n4b);
    $display("5  lens.sum() == 8, dynamic array           randomize() failed %0d times in 20", f5a);
    $display("5  lens.sum() == 8, fixed array of 8        randomize() failed %0d times in 20; the sum was 8 in %0d", f5b, ok5b);
    $display("6  unique {a}, a is bit [3:0] a[4]          a value repeated in %0d of 1000", d6a);
    $display("6  unique {w, x, y, z}                      a value repeated in %0d of 1000", d6b);
    $finish;
  end
endmodule
