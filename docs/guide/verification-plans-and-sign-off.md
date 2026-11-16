# Verification plans and sign-off

This page answers: *your regression passes on every seed. Is the testbench finished, and how would
anyone know?*

Here is the regression you'll start [Lab 07](../labs/lab-07-capstone-overview.md) with, which is
your Lab 06 testbench with the capstone's additions, run with `make regress`: eleven tests, each on
seeds 1 to 10.

```text
  110 ok  (110 runs)
```

and here is `make check-all` on the same package, the graded test against all fifteen planted bugs:

```text
  MISSED  tier 6  B15_output_valid_survives_reset  0 UVM_ERROR, 0 UVM_FATAL        8.6s
```

followed, after the other fourteen rows, by

```text
 14 of 15 caught.
 Still hiding from this test:
   B15_output_valid_survives_reset
      hides behind: resetting only at time 0, when every buffer is already empty
```

The regression ran the golden router, and every check in all 110 runs passed. `make check-all`
shows that the same graded test also passes on a router with B15 switched on, which breaks rule O4
of the specification. What the line `110 ok` can't tell you is which of the specification's rules
those checks cover, and which situations the stimulus ever produced. Answering those two questions
is the job of a **verification plan**, and in Lab 07, Part 2 you'll write one for the router
before you go looking for what the environment misses.

## One row for each rule

The plan template in `labs/lab-07-capstone/PLAN-template.md` has one row for every rule in the
[router specification](../reference/router-spec.md). The input, output and APB rules keep the
specification's own numbers (I1 to I7, O1 to O8, A1 to A9), and the rules the specification states
in prose get labels of their own (RT1 for the routing table's decision, DR2 for a counter that
stops at 255, RS2 for a reset with beats in a buffer, and so on). A plan built this way starts from
what the design promises, not from what the testbench happens to do, so a rule nobody thought to
test still gets a row, and an empty row is visible.

Each row has four columns after the rule itself:

- **Checked by**: the check that fires if the router breaks the rule. In this environment that is
  an assertion, a scoreboard function, the register model's mirror, or nothing.
- **Made to happen by**: the sequence, and the step in it, that creates the situation the rule
  talks about.
- **Seen in coverage**: the coverage bin that shows the situation really happened in a run.
- **Status**: `done`, `open` (you mean to close it), or `gap` (you won't, and you say why).

The template fills in three rows as examples. Here is the one for O1:

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| O1 | `out_valid` holds until the handshake | `a_O1` on each output | every stalled or slow sink: `router_inject_test`'s phases, and `backpressure()` in `router_lab05_vseq` | `cg_wait.x_port_wait`: `long_wait` and `stalled` on both outputs | done |

## Bugs that hid behind an empty column

The three middle columns answer different questions, and a rule is verified only when all three
have an answer. Each of them has let a bug through somewhere in this course.

| Bug | Lab | Hides behind | What was missing |
|---|---|---|---|
| B11 | 05 | sending only legal packets of 8 beats or fewer | *Made to happen*. The scoreboard already expected a cut packet, but no test sent one, and `cp_len.oversize` was 0 |
| B02 | 06 | turning on every interrupt enable before looking at irq | *Checked by*: until Lab 06, Part 5 nothing checked `irq`. After that, *made to happen* the wrong way: with every enable on, the bug changes nothing |
| B15 | 07 | resetting only at time 0, when every buffer is already empty | *Made to happen*: the only reset came at time 0, and the assertions for the reset rules were still to be written |

The "hides behind" strings are the catalogue's own, from `labs/common/bugs.py`, and each one names
a gap in a column. A check with no stimulus is the case that's easiest to miss, because the check
exists and passes. [Assertions for interface rules](assertions-for-interface-rules.md) shows it on
a small design: a bug that drops a waiting beat, under a sink that is always ready, passes an
assertion written exactly for it. B02 shows a subtler version of the same thing: Lab 06's own
`STATUS` step ends with `INT_EN` at `'b111`, and once every enable is on, a router that ignores the
enables behaves exactly like one that doesn't, so the traffic after that step can't catch it. The
plan's "made to happen" column has to describe the situation the rule needs, not just name a test
that runs near it.

## Coverage against the plan

The third column is where the regression's coverage comes in. The starter's regression ended with

```text
 verilator_coverage: covergroup : 81.7% (49/60)
```

and a list of the eleven bins it never hit. Seven of them are crosses of a packet's fate with its
output's level that the specification rules out: a packet is FULL only at a level of 9 or more, and
written to an output only at 8 or less, so `full_x_low` or `out0_x_high` can never be hit by a
correct router. The other four are the bins of `cg_corner`, which count a reset with beats in a
buffer, a reset in the middle of an input packet, and a drop while each counter is already at 255.
Any of those four could happen, and none did.

So 100% isn't the target, and it couldn't be. The target is that every empty bin is explained:
either the specification rules it out, which you write down, or it's a hole the stimulus has to
close. After your work in Parts 5 and 6, the reference solution's regression of thirteen tests
printed

```text
 verilator_coverage: covergroup : 88.3% (53/60)
```

with only the seven impossible bins left, which meets that target. (On
Verilator 5.050 the percentages don't follow the standard's formula anyway, as Lab 03 shows, which
is one more reason to read the bins rather than the total.)

Coverage and the plan check each other. In Lab 07 you'll find the reset and saturation rows empty
twice: once by reading the sequences in Part 2, and once by counting bins in Part 3. A row that a
plan calls done and the coverage calls empty is a mistake in one of the two, and it's worth finding
out which.

## Sign-off criteria

Sign-off is the point at which you say the design does what the plan says, under the conditions the
plan lists. In Part 3 you'll write the criteria for it, and the template asks for each criterion as
a command and the output it must print, for example:

```text
make regress prints ... ok (... runs) with no other class, on seeds ...
```

Writing it this way does two things. Anyone can check it, including you a week later, by running
the command and comparing one line. And it forces you to say exactly which seeds, which tests and
which build you mean, which "the regression passes" doesn't. A good set of criteria covers each
column of the plan: the regression's summary line (the checks passed), its coverage line with the
empty bins named (the situations happened), `make check-all` on more than one seed (the checks can
fail), and a statement that every row is `done` or has its gap written down.

`make check-all` is in that list for a reason the regression can't cover. A regression on the
golden router can only show that your checks stay quiet when they should; the planted bugs show
that they speak up when they should. Fifteen catches are still evidence about fifteen bugs, though,
not about the router. A bug unlike all of them, in a rule with no checker, would pass every
criterion on the list, so the plan's open items go into the report.

## A quiet hunt

In Part 4 you'll deal mystery bugs with `make new` and run the graded test against each with
`make hunt`. When the starter was dealt B15, the hunt printed

```text
   quiet  the mystery bug                          0 UVM_ERROR, 0 UVM_FATAL        7.7s
------------------------------------------------------------------------
 Nothing your test drives tells this design from a correct one. The
 bug is in there; your stimulus or your checks have not reached it.
```

A quiet hunt is a result about the environment, not about the router, and the plan is how you turn
it into something useful: the rows that could hide a bug from `router_test` are the ones with an
empty column. That's the list you work through in Parts 5 and 6.

## Check yourself

1. A row of your plan says *Checked by*: `a_O6`; *Made to happen by*: `router_test`; *Seen in
   coverage*: no bin; *Status*: done. What could still be wrong with it?

   <details>
   <summary>Answer</summary>

   Nothing shows that `router_test` ever sent a packet whose 8th beat wasn't its last, which is
   the only situation in which O6 can fail. That's exactly how B11 hid from Lab 04's tests. A bin
   such as `cp_len.oversize` above 0 is the evidence the row needs.

   </details>

2. The starter's regression hit 49 of 60 bins. Why is 60 of 60 the wrong target, and what is the
   right one?

   <details>
   <summary>Answer</summary>

   Seven of the bins are crosses that the specification makes impossible on a correct router, so a
   regression that hit them would have found a bug, not finished the job. The right target is that
   every empty bin is either ruled out by the specification, with the reason written in the plan,
   or closed by new stimulus.

   </details>

3. Why does a sign-off criterion name a command and the exact line it must print, rather than say
   "the regression passes"?

   <details>
   <summary>Answer</summary>

   So that someone else can check it without your help, by running the command and comparing the
   line. It also pins down which tests, which seeds and which build the claim is about, which
   "the regression passes" leaves open.

   </details>

## Further reading

- [Verification Plan](https://chipverify.com/verification/verification-plan): what a plan
  contains, from scope and features to sign-off criteria, with a worked entry.
- [Identifying Features & Corner Cases](https://chipverify.com/verification/identifying-features-corner-cases):
  turning a specification's wording into rows, and finding the corners between them.
- [Pass Fail Criteria & Scoreboards](https://chipverify.com/verification/pass-fail-criteria-scoreboards):
  what has to be true for a test to count as a pass.
- [Coverage Driven Verification](https://chipverify.com/verification/coverage-driven-verification):
  the loop of running seeds, merging coverage and closing holes, and how to tell a hole from a bin
  that can't be hit.
- [Sign-Off Criteria](https://chipverify.com/verification/sign-off-criteria): the gates an
  industrial project uses, of which Lab 07's criteria are a small version. Its coverage gates assume
  a commercial simulator's metrics; on Verilator, count bins in `coverage.dat`.

Next: [Writing the verification report](../guide/writing-the-verification-report.md).
