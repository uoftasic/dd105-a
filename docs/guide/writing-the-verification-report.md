# Writing the verification report

This page answers: *you've run the regression and closed the holes your plan found. What do you
hand over, so that someone else can check your claim without redoing your work?*

DD104's capstone ended with a [bug report](https://uoftasic.com/dd104/guide/writing-the-bug-report.html),
and its deliverable was a test: one bug, one reproducer, one command. DD105's capstone ends with a
**verification report**, which makes a bigger claim. It says that a whole design follows its
specification, as far as a written plan describes it, and it gives the evidence for that and the
limits of it. In [Lab 07, Part 8](../labs/lab-07-capstone-overview.md#part-8-the-report) you'll fill
in `labs/lab-07-capstone/REPORT-template.md` for the router, and you'll start its hunt table in
Part 4.

The reader of a report like this is someone who has to rely on the design without having run your
tests: whoever builds it into a chip, or reviews it before that happens. They will believe exactly
what they can check. So everything in the report is either a line a tool printed, next to the
command that printed it, or a statement with its limits written beside it.

## A short report for the counter

The router's report runs to eight sections and a few pages, so it's easier to see how one works on
something small. [Regressions and seeds](regressions-and-seeds.md) uses a 4-bit counter that is
meant to stop at 15, with a planted bug, `wrap`, that makes it wrap to 0 instead, and a test,
`count_test`, that drives random `inc` and `clr` for 300 cycles and checks the count in every
cycle against a model. Here is the core of a report for it, in the template's sections, with every
number from our runs of
[`guide-examples/regressions-and-seeds/`](https://github.com/uoftasic/dd105-a/tree/main/guide-examples/regressions-and-seeds):

```markdown
## 1. Summary

The counter in satcnt.sv was verified against three rules: clr sets it to 0, inc adds
one, and at 15 it stays at 15. count_test checks the count in every cycle against a
model. It passed on seeds 1 to 10, and it caught the planted wrap bug, but only five of
the ten seeds got the counter to 15, so the rule about 15 was tried on those five only.

## 4. Regression

make seeds UVM_TESTNAME=count_test SEEDS="1 2 3 4 5 6 7 8 9 10"

    10 ok  (10 runs)

## 5. Coverage

    verilator_coverage: covergroup : 100.0% (4/4)

The four bins are the merge of all ten runs. Run by run (the [COUNT] line at the end of
each log), the counter reached 15 on seeds 2, 3, 8, 9 and 10, and never on seeds 1, 4,
5, 6 and 7.

## 6. Bugs

make run UVM_TESTNAME=count_test SEED=n BUG=wrap, for n = 1 to 10: caught on seeds 2,
3, 8, 9 and 10, MISSED on seeds 1, 4, 5, 6 and 7. The first error on seed 2:

    UVM_ERROR guide-examples/regressions-and-seeds/seeds_tb.sv(72) @ 1975000: uvm_test_top [COUNT] count is 0, expected 15

## 7. What this doesn't show

- On half the seeds the counter never reached 15, so the rule that matters most was
  tried on five seeds of ten. A run on one of the other five would have passed the
  wrap bug.
- The coverage line is 100%, but it is the union of ten runs, and five of them never
  hit the bin for 15.
- Nothing here resets the counter after time 0, so a clear and a reset are never seen
  in the same cycle, and nothing checks the count while rst_n is 0.
- The simulator has two states, so nothing here says anything about X.

## 8. Sign-off

This counter holds at 15, clears on clr and counts on inc, in every cycle of count_test
on seeds 1 to 10, which got it to 15 and incremented it there on seeds 2, 3, 8, 9 and
10. To check it:

    make seeds UVM_TESTNAME=count_test SEEDS="1 2 3 4 5 6 7 8 9 10"   # 10 ok  (10 runs)
```

Sections 2 and 3, which describe the environment and the plan's status, are left out here because
the counter's environment is one test, and its plan is three rows.

## Numbers and the commands behind them

Every number in that report comes from the output of a command the report names, and the lines in
the indented blocks are pasted character for character. That's what makes a report checkable, and
it's easy to lose by summarising.
"The regression passed" could mean any number of tests on any seeds, with or without a run that
crashed. `10 ok  (10 runs)` under the command that printed it says how many runs there were, that
all ten passed, and that none was BROKEN, and a reader can run the same command and compare one
line.

The template's comment says the same thing, and Lab 07 helps you keep to it: Parts 6 and 7 send the
regression and the three `make check-all` runs through `tee` into `results/`, and Part 8 copies that
folder into your repository with the report. The "Environment" line at the top of the template
asks for the commit your report describes, because a seed reproduces a run only with the same code
(Regressions and seeds shows how little it takes to change every random choice). Part 8's last step
is the test of all of this: open the repository on GitHub and check that a reader who has only that
page could find the command behind every number.

## The sign-off sentence

Section 8 of the template asks for one sentence that starts "This router..." and keeps going until
it's true. The counter's version shows why it comes out long. "This counter saturates at 15" is
what you'd like to say, but the evidence covers only `count_test`, only seeds 1 to 10, and only
the five seeds that got the counter there, so the sentence names all three. A sentence that has to
stay true forces you to write down every condition your evidence depends on, and a reader can then
decide whether those conditions are good enough for what they need.

## What the report doesn't show

"What this doesn't show" is the section people leave short, and it's the one a reader who has to
rely on your claim needs most, because it's the only place they can find out where your evidence
stops. In the counter's report it holds the fact that half the seeds never tested the rule the bug
breaks. For the router, the list comes from your own work:

- the rows of your plan with no checker, or with a checker that no sequence ever exercises, which
  you listed as open items in Part 2;
- coverage bins that stayed empty, and why;
- the seeds you ran, and the ones you didn't;
- what a two-state simulator can't show: Verilator has no X, and the specification warns that the
  router's state before its first reset is undefined, although on Verilator it happens to start at
  zero;
- what the planted bugs prove: that your environment catches those fifteen, and nothing about a bug
  unlike all of them.

A reader can work with a limited claim whose limits are written down. A claim with no stated
limits, they have to either take on trust or check from scratch.

## The hunt table

Section 6 has a table with one row for each mystery bug you were dealt in Part 4, and its columns
are in the order you fill them: the first check that fired, copied from `make hunt`; your diagnosis,
which is the rule the router broke and the file in `labs/common/rtl/` you'd look in; and only then
the verdict, with the bug's name, from `make verdict`. You write the diagnosis before you see the
answer because it records how well a failure message from your environment leads to the fault,
which is what an environment is for, and it's a habit you'll need when there is no `make verdict`
to ask.

A hunt that comes back `quiet` gets a row too. It says that nothing `router_test` drives tells that design from a correct one, and the row should say which
rows of your plan could be hiding it. In our runs, B15 came back quiet on the starter environment,
which is where Lab 07's reset work comes from.

## Check yourself

1. A report's summary says "the regression passes and coverage is 100%". Name three things a reader
   can't tell from that sentence.

   <details>
   <summary>Answer</summary>

   Which tests and seeds ran, and how many runs that was; which command produced the result, so
   that they could run it themselves; and whether any single run hit every bin, or which bins only
   some seeds reached. The counter's coverage was 100% over ten seeds while five of them never
   reached 15. They also can't tell which build the claim is about.

   </details>

2. Your Lab 07 report's section 7 is empty. Name two things from the lab that belong there.

   <details>
   <summary>Answer</summary>

   Any two of: the plan's open items (rows with no checker), the seeds you didn't run, the bins
   that stayed empty and why, the fact that a two-state simulator says nothing about X, and the
   fact that catching fifteen planted bugs says nothing about a sixteenth unlike them.

   </details>

3. Why does the hunt table ask for your diagnosis before the verdict?

   <details>
   <summary>Answer</summary>

   Because the diagnosis is the result being measured: how directly your environment's first
   failure message leads to the rule the design broke and the block it's in. Written after the
   verdict, it would only repeat the bug's name.

   </details>

## Further reading

- [Writing the bug report](https://uoftasic.com/dd104/guide/writing-the-bug-report.html), in
  DD104: the other kind of report, for one bug, built around a test that reproduces it.
- [Bug Lifecycle](https://chipverify.com/verification/bug-lifecycle): what a useful bug report
  contains (the seed, the commit, expected against observed) and how a bug moves from open to
  closed. Its command lines are for one commercial simulator; on Verilator the seed is
  `+verilator+seed+N`.
- [Sign-Off Criteria](https://chipverify.com/verification/sign-off-criteria): the gates a report
  usually has to show were met.
- [Verification Metrics](https://chipverify.com/verification/verification-metrics): coverage, bug
  rates and escapes as measures of how far verification has got.
