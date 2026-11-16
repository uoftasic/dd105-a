# Constrained random on Verilator

This page answers: *how do I get the random stimulus I asked for on this simulator, and how do I
know I got it?*

Lab 02's generator chose each packet's DST and length itself, with calls to `$urandom_range`
written into its loop. In [Lab 03](../labs/lab-03-constraints-and-coverage-overview.md) the
packet becomes a class with `rand` fields and constraints, and the generator calls
`randomize()`, which hands the constraints to a solver and lets it choose. That moves the
decisions about what the stimulus looks like out of the generator's code and into one class,
where a test can change them. It also means the values now depend on how the simulator's solver
chooses among the values your constraints allow, and Verilator 5.050 doesn't always choose the
way the SystemVerilog standard says it should.

This page explains what the standard says `randomize()` does, where Verilator 5.050 does the
same and where it doesn't, and why you count what came out instead of trusting the constraints.
The examples are small classes built on SimProc's ALU operations, in
[`guide-examples/constrained-random-on-verilator/`](https://github.com/uoftasic/dd105-a/tree/main/guide-examples/constrained-random-on-verilator),
and they build with the course's `uvm.mk` like every lab. You'll run the same kind of experiment
on the router's packet in
[Lab 03, Part 3](../labs/lab-03-constraints-and-coverage-overview.md#part-3-constraints-the-simulator-honours).

## rand fields, constraints and randomize()

A class marks the fields it wants chosen with `rand`, and states the rules they must follow in
named `constraint` blocks. Here is an ALU vector:

```systemverilog
typedef enum bit [2:0] {ADD, SUB, OR, NAND, SHL, SHR} alu_op_e;

class alu_vec;
  rand alu_op_e  op;
  rand bit [7:0] A, B;
  constraint c_op    { op inside {[ADD:SHR]}; }
  constraint c_shift { (op inside {SHL, SHR}) -> B < 8'd4; }
endclass
```

SimProc's shifts use only `B[1:0]`, so `c_shift` keeps `B` below 4 whenever the operation is a
shift, and leaves it free otherwise. A call to `v.randomize()` asks for values of `op`, `A` and
`B` that satisfy every constraint block that is switched on, all at once, and returns 1 if it
found some. A call can add constraints of its own with `with { ... }`, which apply to that call
only and are added to the class's constraints rather than replacing them. A block can be
switched off with `constraint_mode(0)`. The standard also says how the values are chosen: every
combination of values that satisfies the constraints is equally likely.

`cr_item_test` randomizes one `alu_vec` a few times:

```text
[ITEM] randomize() returned 1: SHR A=cc B=02
[ITEM] randomize() returned 1: SHR A=43 B=03
[ITEM] randomize() returned 1: SHL A=2f B=00
[ITEM] randomize() returned 1: SHL A=65 B=03
[ITEM] with { op == SUB; A == B; } returned 1: SUB A=f4 B=f4
[ITEM] with { op == SUB; A == B; } returned 1: SUB A=35 B=35
[ITEM] before: SUB A=35 B=35
[ITEM] with { op == SHL; B == 5; } returned 0: SUB A=e5 B=35
[ITEM] the same with c_shift off returned 1: SHL A=10 B=05
```

The call with `{ op == SHL; B == 5; }` can't be satisfied, because `c_shift` says a shift has
`B` below 4. It returned 0, and the run printed an `UNSATCONSTR` warning
naming both constraints. The standard says a failed call leaves the variables as they were, but
here `A` changed from `35` to `e5`, so after a failed call the object holds a mixture you didn't
ask for. With `c_shift` switched off, the same call succeeds.

That's why every `randomize()` in this course's code checks what it returned, usually as
`` if (!p.randomize()) `uvm_fatal("RAND", ...) ``, and why the course's `make run` treats a
failed call as a broken run even when the test itself passed. This run's verdict was:

```text
 BROKEN: randomize() failed   0.02 s   log: build/runs/cr_item_test-s1/run.log
```

## The solver

Verilator doesn't solve constraints itself. It writes them out in the SMT-LIB language for a
separate solver program, which the environment variable `VERILATOR_SOLVER` names. The course
image has `yices-smt2`, and the course's `uvm.mk` sets `VERILATOR_SOLVER` to
`yices-smt2 --incremental` for every build and every run. Before it runs anything, `make` checks
that the solver it names is installed. Asked to use `z3`, which the image doesn't have, it stops
with:

```text
 VERILATOR_SOLVER is "z3 --in", and z3 is not on PATH.
========================================================================
 Without a solver every constrained randomize() returns 0, nothing is
 randomized, and the run still passes. Are you in the course image?
```

As a last guard, `dd105_base_test` randomizes a small probe class in its `build_phase`. Here is
the simulator run by hand, without `make`, with `VERILATOR_SOLVER` naming `z3`:

```text
VlRProcess::open: execvp(z3): No such file or directory
UVM_INFO @ 0: reporter [RNTST] Running test cr_item_test...
%Warning: Subprocess command `z3 --in' failed: exit status 127
%Warning: Unable to communicate with SAT solver, please check its installation or specify a different one in VERILATOR_SOLVER environment variable.
 ... Tried: $ z3 --in
UVM_FATAL labs/common/uvm/dd105_pkg.sv(51) @ 0: reporter [SOLVER] a constrained randomize() failed, so this run cannot randomize anything. Verilator needs VERILATOR_SOLVER="yices-smt2 --incremental" in the environment. Run the test with make, which sets it, or export it before running the simulator by hand.
```

Verilator's runtime (`verilated_random.cpp` in the image) turns the solver's answer into a random
one like this. It picks a random target value for every bit of every `rand` variable and asks the
solver for a solution that matches all of those bits. If the targets break a constraint, it gives
up one bit's target and asks again, until the constraints can be met. A target that lands on an
allowed value comes out as it is. A target that lands on a forbidden value comes out as an allowed
value a bit or two away from it, so the allowed values next to forbidden ones come out more often
than the others. (A class with an array in it goes through a different method in the same file.)
`alu_op_e` has six names in three bits, so two of its eight codes, `110` and `111`, are forbidden.
With `op inside {[ADD:SHR]}` and 1,000 draws (`cr_enum_test`):

```text
[ENUM] op inside {[ADD:SHR]}:             ADD  127  SUB  109  OR  148  NAND  124  SHL  234  SHR  258
```

The constraint was obeyed every time: no draw came out as 6 or 7. But the standard would give
each operation about 167, and `SHL` (`100`) and `SHR` (`101`) got about twice the share of the
others. Those are the codes one bit away from `110` and `111`, so the draws that aimed at the
forbidden codes landed there. A constraint says which values are allowed; on this simulator it
doesn't promise how often each one comes out.

## Shapes that come out differently here

Lab 03's experiments (`make traps`) and the examples here found five shapes of constraint that
don't do on Verilator 5.050 what the standard says. Each has a way around it that the labs use.

### A rand enum that no constraint names

The standard makes an unconstrained `rand` enum uniform over its names. On this simulator that
holds for some enums and not others:

```text
[ENUM] 3 names in 2 bits, no constraint:      317  347  336
[ENUM] 4 names in 2 bits, no constraint:      813   66   63   58
[ENUM] 6 names in 3 bits, no constraint:      160  167  179  163  146  185
[ENUM] 8 names in 3 bits, no constraint:      890   14   12   15   18   10   22   19
[ENUM] 4 names, v inside {[N4_A:N4_D]}:       245  237  247  271
```

The enums whose names fill every code of their bits (four names in two bits, eight in three)
came out as their first name 813 and 890 times in 1,000, with no warning. Lab 03's line 1 gives
809 for its four-name enum. The three-name and six-name enums were even. So the course names
every `rand` enum in a constraint. For an enum whose names fill its bits, `inside` with every
name is enough, as the last line shows. For one whose names don't, `inside` makes the spread
uneven, as the previous section showed, and what gave an even spread was a `dist` with one range
and equal weights, which is how Lab 01's `alu_item` writes it:

```text
[ENUM] op dist {[ADD:SHR] := 1}:          ADD  161  SUB  166  OR  163  NAND  173  SHL  176  SHR  161
```

The same test printed one more line, for a shape that no lab writes. When the enum's type is a
parameter of the class (`class free_param #(type T = e3_t); rand T v;`), the three-name enum
took the unused code 3 in 256 draws of 1,000:

```text
[ENUM] 3 names, in a parameterized class:     235  247  262   and 256 values that aren't names
```

`randomize()` returned 1 every time, so nothing failed and nothing was printed.

### A dist written with enum names

A `dist` gives each value or range a weight. Under the standard it makes no difference whether
you write the values as enum names or as numbers, but on this simulator it does:

```text
[DIST] weights 10/20/30/40 by name:    K_ZERO  229  K_ONES  256  K_SAME  267  K_ANY  248
[DIST] weights 10/20/30/40 by number:  K_ZERO   93  K_ONES  212  K_SAME  291  K_ANY  404
```

Written with the names, the weights were lost; written as the numbers 0 to 3, they landed where
they were written. Lab 03's line 2 shows the same thing with weights of 25, 50 and 25, where the
50 went to the wrong name. So the course writes `dist` values as numbers, as in
`kind dist {0 := w_one, 1 := w_mid, 2 := w_max}`.

### A dist and another constraint on the same variable

To the standard, a `dist` is one more constraint, solved together with all the others. Verilator
5.050 behaves as if it first picks one entry of the `dist` list by weight, and only then solves
the rest. If the other constraints rule out the entry it picked, the call fails:

```text
[DIST] op dist {0 := 5, 1 := 1, ...}:   ADD  513  SUB   96  OR   92  NAND  102  SHL   94  SHR  103
[DIST] op dist {0 := 5, 1 := 1, ...}, then with { op == SUB; }: randomize() failed 921 times in 1000
[DIST] the same with c_op.constraint_mode(0):              randomize() failed 0 times in 1000
[DIST] op dist {[ADD:SHR] := 1}, then with { op == SUB; }:  randomize() failed 0 times in 1000
```

The weights themselves came out right. But asking for `SUB` with the `dist` switched on failed
921 times in 1,000, about the nine draws in ten that picked an entry other than `SUB`. Lab 01's
single-range `dist` has only one entry, and asking it for `SUB` failed 0 times in 1,000.

The same happens through a second variable. This class puts the `dist` on a selector, `kind`,
and lets implications choose `A` from it, which is the pattern the labs use:

```systemverilog
class vec_kind;
  rand kind_e    kind;
  rand bit [7:0] A, B;
  constraint c_kind { kind dist {0 := 10, 1 := 20, 2 := 30, 3 := 40}; }
  constraint c_A    { (kind == K_ZERO) -> A == 8'h00;
                      (kind == K_ONES) -> A == 8'hFF;
                      (kind == K_SAME) -> A == B; }
endclass
```

```text
[DIST] kind dist, then with { A < 8'h10; }:                   randomize() failed 199 times in 1000
[DIST]   the calls that worked: K_ZERO 114  K_ONES 0  K_SAME 305  K_ANY 382
[DIST] the same with c_kind.constraint_mode(0):                randomize() failed 0 times in 1000
```

`A < 8'h10` rules out `K_ONES`, which has a fifth of the weight, and a fifth of the calls failed.
A selector is still the right place for a `dist`, because the data constraints stay ordinary
constraints. For a call that pins the data, switch the `dist` off with `constraint_mode(0)`, or
build the item without the solver. Lab 03's `close_holes()` builds its fill packets with
`rand_packet::make()` for that reason: with the packet's weights on, `randomize() with { len == 3; }`
failed 478 times in 1,000 (line 3 of its experiments).

### solve...before

`solve big before len` asks the solver to choose `big` first, which changes how often each value
of `big` comes out without changing which values are legal. In Lab 03's experiment the standard
gives `big` about 500 times in 1,000 with it and about 125 without, and Verilator gave 33 and 41,
as if the line weren't there. `cr_solve_test` tries a different shape, where `is_shift` chooses
between the two shifts and the four other operations:

```text
[SOLVE] solve is_shift before op:  is_shift in 665 of 1000;   ADD   51  SUB   77  OR   74  NAND  133  SHL  223  SHR  442
[SOLVE] without solve...before:    is_shift in 512 of 1000;   ADD   69  SUB  178  OR   58  NAND  183  SHL   64  SHR  448
```

The standard gives about 500 and 333. Verilator's runtime has a separate pass for
`solve...before`, and in this shape the count moved, but in neither experiment did it come out
at the standard's numbers, so don't use `solve...before` to shape a distribution on this
simulator. If you want `is_shift` half the time, say so with a `dist`, which it does honour:

```text
[SOLVE] is_shift dist {0:=1, 1:=1}: is_shift in 502 of 1000;   ADD   56  SUB   53  OR  196  NAND  193  SHL   59  SHR  443
```

The operations within each half still aren't even (`SHR` 443 against `SHL` 59), for the reason
given under "The solver" above, so if that matters, give `op` its own `dist` too.

### unique and sum() on arrays

`unique {a}` on an array is accepted and not enforced: in Lab 03's line 6, four random 4-bit
values repeated a value in 315 draws of 1,000, which is about what no constraint at all gives.
On separate variables, `unique {w, x, y, z}`, it works. And `lens.sum() == 8` on a dynamic array
can't be solved at all (20 failures in 20), while the same constraint on a fixed-size array
works, which is why Lab 03's `fill_plan` has `lens[8]` with a 0 meaning "no packet".

## Seeds

Every run starts the random number generators from a seed, which `make` passes as
`+verilator+seed+N` from its `SEED` variable (1 unless you say otherwise). The same seed gives
the same values: running `cr_item_test` twice with seed 1 printed the same nine lines both times,
and seed 2 gave a different first line, `SHR A=2d B=02`. That's what lets you rerun a failing
test and watch the same failure, and what lets `make seeds` try ten different ones.

A seed reproduces a run of the same testbench. Lab 03 warns that your own constraints may give
different counts from ours with the same seed, because a different class asks the solver
different questions.

## Counting what came out

Every finding on this page came from counting what came out. The four-name enum that came out
as its first name 813 times broke no constraint and printed no warning, and the run passed, so
a check on the design's answers had nothing to report. In Lab 03 you count with a covergroup
instead of a histogram in the test, and its first run shows about a third of the router's
packets 1 beat long and a third 8 beats long, because the packet's length comes from a
three-name enum that nobody had weighted.
[Functional coverage you can read](functional-coverage-you-can-read.md) explains how to read
those counts.

## Check yourself

1. A transaction has `rand bit [1:0] dst;` and `rand mode_e mode;`, where `mode_e` has four
   names in two bits, and no constraint mentions `mode`. What do you expect 1,000 draws to give,
   and what do you add?

   <details>
   <summary>Answer</summary>

   The first name about four times in five (813 and 809 in the runs above), with no warning. Add
   a constraint that names `mode`. With four names in two bits, `mode inside {...}` with all four
   gave an even spread; for an enum whose names don't fill their bits, a `dist` with one range and
   equal weights, as Lab 01's `alu_item` has.

   </details>

2. An ALU item has `constraint c_op { op dist {0 := 2, 1 := 1, 2 := 1, 3 := 1, 4 := 1, 5 := 1}; }`.
   A directed sequence calls `req.randomize() with { op == NAND; }`. What happens, and what are
   two ways to fix it?

   <details>
   <summary>Answer</summary>

   Most calls fail: the simulator picks an entry of the `dist` first, and only the entry for 3
   (`NAND`), with a seventh of the weight, satisfies `op == NAND`. Either switch the `dist` off
   for the call with `req.c_op.constraint_mode(0)`, or set `op` by hand without calling
   `randomize()`, as Lab 01's directed sequence does.

   </details>

3. A run of Lab 03's test passes, and the log has one `UNSATCONSTR` warning in it. Why does
   `make run` call it BROKEN rather than ok?

   <details>
   <summary>Answer</summary>

   A failed `randomize()` means at least one item wasn't what the test asked for, and on this
   simulator its fields may even have changed (`A` went from `35` to `e5` above). A pass then says
   only that the router handled whatever was sent, which isn't the stimulus the test describes.

   </details>

## Further reading

ChipVerify's SystemVerilog pages cover each construct here with longer examples. Their output
comes from commercial simulators, so where Verilator 5.050 differs, trust the counts on this page
and in Lab 03.

- [SystemVerilog Randomization](https://chipverify.com/systemverilog/systemverilog-randomization)
- [Constraint Blocks](https://chipverify.com/systemverilog/systemverilog-constraint-blocks)
- [Inline Constraints](https://chipverify.com/systemverilog/systemverilog-inline-constraints).
  On Verilator 5.050, an inline constraint on a variable that has a `dist` fails whenever the
  `dist` picked an entry the inline constraint rules out; see above.
- [Constraints](https://chipverify.com/systemverilog/systemverilog-constraints). Its `dist`
  example names a variable `priority`, which is a keyword, so it doesn't compile; on Verilator,
  write `dist` values as numbers.
- [solve before](https://chipverify.com/systemverilog/systemverilog-solve-before) explains what
  the standard means correctly. Verilator 5.050 doesn't produce those distributions.
- [Soft Constraints](https://chipverify.com/systemverilog/systemverilog-soft-constraints). It
  says the solver decides which of two conflicting soft constraints wins; the standard fixes the
  order (a later one beats an earlier one, a derived class beats its base, and an inline `with`
  beats the class).
- [Disable Constraints](https://chipverify.com/systemverilog/systemverilog-disable-constraints),
  for `constraint_mode()`.

Next: [Functional coverage you can read](../guide/functional-coverage-you-can-read.md).
