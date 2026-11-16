# Regressions and seeds

This page answers: *what does a seed fix, what does it leave free, and what does a regression over
many seeds tell you that one run doesn't?*

Every run in this course has a seed. `make run` passes `+verilator+seed+1` unless you give it
`SEED=`, and every "You should see" number in the labs is from seed 1. Labs 05 and 06 also end by
asking for `make seeds SEEDS="1 2 3 4 5"`, which runs the graded test on five seeds from the same
build and prints `5 ok  (5 runs)` when they all pass. In
[Lab 06, Part 1](../labs/lab-06-the-register-block-overview.md#part-1-the-lab-05-testbench-against-the-registers)
you'll see every count in `router_test` change although nothing you wrote changed, and in
[Lab 07, Part 3](../labs/lab-07-capstone-overview.md#part-3-a-seed-regression) you'll run eleven
tests on ten seeds each and find out what 110 passing runs do and don't prove. This page explains
both, with measurements from a small example of our own in
[`guide-examples/regressions-and-seeds/`](https://github.com/uoftasic/dd105-a/tree/main/guide-examples/regressions-and-seeds).

## What a seed fixes

The example's `random_test` forks two threads in its run phase. Thread A draws four values with
`$urandom` at time 0, and thread B draws four more a nanosecond later. On seed 1 it printed

```text
UVM_INFO guide-examples/regressions-and-seeds/seeds_tb.sv(143) @ 1000: uvm_test_top [RANDOM] thread A: 0bbddfb0 daff8fa1 bfb2d373 4a0f49df
UVM_INFO guide-examples/regressions-and-seeds/seeds_tb.sv(144) @ 1000: uvm_test_top [RANDOM] thread B: b0011fed 80a529cd c8e18eaf d407ae8b
```

On seed 1 again it printed the same eight values, and on seed 2 it printed eight different ones:

```text
UVM_INFO guide-examples/regressions-and-seeds/seeds_tb.sv(143) @ 1000: uvm_test_top [RANDOM] thread A: 6d5ed04a 79212f85 cac574d1 3eae46dd
UVM_INFO guide-examples/regressions-and-seeds/seeds_tb.sv(144) @ 1000: uvm_test_top [RANDOM] thread B: b1403e12 ca4b19dc 91ea6ece 9a0aa6d2
```

A seed fixes the whole run. Given the same simulator, the same plusargs and the same seed, every
random choice in every thread comes out the same, so a run that failed can be repeated exactly:
`make run SEED=7` reruns seed 7, and its folder, `build/runs/<test>-s7`, is named after the seed.
`SEED=random` picks a seed for you and records it the same way. When we ran
`make run UVM_TESTNAME=count_test SEED=random`, the run went into
`build/runs/count_test-s16616597`, so that seed can be run again by name.

## One more random call

"The same simulator" in that paragraph means the same build of the same code. To see why, each of
these runs adds one thing to thread A before it draws, all on seed 1:

| Plusarg | What thread A does first | Thread A's values | Thread B's values |
|---|---|---|---|
| none | nothing | `0bbddfb0 daff8fa1 bfb2d373 4a0f49df` | `b0011fed 80a529cd c8e18eaf d407ae8b` |
| `+EXTRA_DRAW` | one more `$urandom` | `daff8fa1 bfb2d373 4a0f49df 5f2fa507` | `2be22380 36bdaeeb b33e045a 78e0e61e` |
| `+EXTRA_NEW` | `new()` of a plain class with a `rand` member | `0bbddfb0 daff8fa1 bfb2d373 4a0f49df` | `b0011fed 80a529cd c8e18eaf d407ae8b` |
| `+EXTRA_SEQ` | `type_id::create()` of an empty UVM sequence | `03c400f3 7d776947 f2c8eda9 d78d5d6e` | `cca11dc6 fee8bd5a b5a1ea57 fd5d592f` |
| `+EXTRA_START` | creates that sequence and starts it | `e1b55258 15eacca0 ec923ff4 eb3f888a` | `291de991 9e00215f 4e3d822b 6575033c` |

The extra draw moved thread A along by one, as you'd expect: its first three values are the
original's second to fourth. It also changed all four of thread B's values, although B's code is
the same and B draws a nanosecond after A has finished. Making a UVM sequence changed every value in
both threads, and starting it changed them again. A plain `new()` changed nothing at all. (The
standard describes something different on two counts: each thread has its own generator, so B
shouldn't have moved, and `new()` seeds an object's generator from its thread's, so A should have.
These are measurements of Verilator 5.050, which is the simulator your runs use.)

So on this simulator, one more random call, or one more sequence, anywhere in a test can change the
random choices made after it everywhere else, in other threads as well as its own.

In Lab 06, Part 1 you'll see this happen to `router_test`, and be asked why. Lab 07 puts its new
sequence at the end of `router_test` for this reason, and we checked that with that sequence left
out, Lab 07's `router_test` printed Lab 06's lines number for number.

Three habits follow from this:

- Compare two runs on the same seed only when the code is the same. A seed is a name for a run of
  one build, not for a set of values.
- When a seed fails, keep the commit with it. After you change the testbench, that seed is a
  different run, and the failure may move or disappear without the bug being fixed.
- If a failure matters, turn it into a test that doesn't depend on the seed: a directed step in a
  sequence, which is what Labs 06 and 07 have you write for each bug you need to reach.

## Running many seeds

A **regression** runs a set of tests on a set of seeds, all from one build, and reports every run
and the coverage of all of them together. `make seeds` does it for one test and `make regress` for
every test in the lab's `TESTS`; both are `labs/common/regress.py`, and both classify each run with
the same verdict as `make run`, so a run that crashed or stopped on a `UVM_FATAL` shows as BROKEN,
never as a pass.

The example's second test, `count_test`, drives a 4-bit counter that should stop at 15, with random
`inc` in 60% of cycles and `clr` in 15%, for 300 cycles, and checks the count against a model in
every cycle. `make seeds UVM_TESTNAME=count_test SEEDS="1 2 3 4 5 6 7 8 9 10"` printed

```text
      ok  count_test                   seed 1      0 UVM_ERROR, 0 UVM_FATAL        0.0s
      ok  count_test                   seed 2      0 UVM_ERROR, 0 UVM_FATAL        0.0s
      ok  count_test                   seed 3      0 UVM_ERROR, 0 UVM_FATAL        0.0s
      ok  count_test                   seed 4      0 UVM_ERROR, 0 UVM_FATAL        0.0s
      ok  count_test                   seed 5      0 UVM_ERROR, 0 UVM_FATAL        0.0s
      ok  count_test                   seed 6      0 UVM_ERROR, 0 UVM_FATAL        0.0s
      ok  count_test                   seed 7      0 UVM_ERROR, 0 UVM_FATAL        0.0s
      ok  count_test                   seed 8      0 UVM_ERROR, 0 UVM_FATAL        0.0s
      ok  count_test                   seed 9      0 UVM_ERROR, 0 UVM_FATAL        0.0s
      ok  count_test                   seed 10     0 UVM_ERROR, 0 UVM_FATAL        0.0s
------------------------------------------------------------------------
  10 ok  (10 runs)
```

and then the coverage of all ten runs together, which included

```text
 verilator_coverage: covergroup : 100.0% (4/4)
```

All ten passed, and the four coverage bins (the count in 0 to 7, in 8 to 14, at 15, and incremented
at 15) were all hit. But the merged coverage is the union of ten runs. Each run's last line says
how often its counter was at 15:

| Seed | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Cycles at 15 | 0 | 6 | 20 | 0 | 0 | 0 | 0 | 4 | 3 | 24 |
| Incremented at 15 | 0 | 2 | 13 | 0 | 0 | 0 | 0 | 2 | 2 | 19 |
| `BUG=wrap` | MISSED | caught | caught | MISSED | MISSED | MISSED | MISSED | caught | caught | caught |

The last row is the same test with the planted bug `wrap` switched on, which makes the counter wrap
from 15 to 0. We ran it one seed at a time, with `make run SEED=n BUG=wrap`, because `make seeds`
doesn't pass `BUG` on to its runs. The wrap was caught on exactly the five seeds that incremented
the counter at 15, each time with `[COUNT] count is 0, expected 15`, and it passed on the other five.
A random clear in 15% of cycles makes a run of fifteen increments rare, so whether a seed reaches
the corner is a matter of luck, and seed 1, the one every "You should see" uses, is one of the
unlucky ones.

Each extra seed in a regression is another chance at the corners that the stimulus reaches only by
luck. When a corner matters, though, it's better not to leave it to luck at all, so Lab 07 has you
write a sequence that drives a drop counter to 255 on purpose rather than hoping random traffic gets
there.

## Corners no seed reaches

More seeds help only with corners the stimulus can reach. In Lab 07, Part 3, the starter's
regression of eleven tests on ten seeds printed

```text
  110 ok  (110 runs)
 verilator_coverage: covergroup : 81.7% (49/60)
```

and listed eleven coverage bins never hit, four of which a correct router can reach: a reset with
beats in a buffer, a reset in the middle of an input packet, and a drop while each counter is at 255.
No test in that package resets the router after time 0, so no number of seeds would hit the two
reset bins, and nothing in it sets out to drive a counter to 255 (every phase of
`router_inject_test` clears the counters). A hundred and ten passes say that no check fired in 110
runs. They say nothing about situations that none of those runs produced, and one of the fifteen
planted bugs shows only in such a situation.
[Verification plans and sign-off](verification-plans-and-sign-off.md) is about finding those
situations before a regression tells you everything is fine.

The 110 runs all used the simulator that `make build` made once. On 2 CPUs the whole regression
took 3 min 52 s, about two seconds a run, against about two minutes for the build, which is why the
course picks tests, seeds and bugs with plusargs at run time rather than with anything that needs a
rebuild.

## Check yourself

1. You ran `make run SEED=4` yesterday and it failed. Today, after adding one `$urandom_range` call
   at the start of your sequence, `SEED=4` passes. Is the bug fixed?

   <details>
   <summary>Answer</summary>

   You can't tell. On Verilator 5.050 one extra random call changes the values drawn after it,
   so seed 4 is now a different run with different stimulus, and it may simply no longer reach the
   bug. Run yesterday's commit on seed 4 to confirm the failure, then turn it into a directed step
   that fails without the seed.

   </details>

2. The counter's ten-seed regression reported `covergroup : 100.0% (4/4)`. Did any one seed hit
   all four bins, and does it matter?

   <details>
   <summary>Answer</summary>

   Yes: the seeds that incremented the counter at 15 also passed through 0 to 7 and 8 to 14. It
   matters less than which seeds missed the bin for 15: five of the ten did, and on those five the
   wrap bug passed. Merged coverage tells you a bin was hit somewhere, not that every run hit it.

   </details>

3. Lab 07's starter passed 110 runs and left `reset_with_beats` empty. Would 1,000 seeds have
   filled it?

   <details>
   <summary>Answer</summary>

   No. No sequence in the starter resets the router after time 0, so no seed can produce a reset
   with beats in a buffer. A seed changes the random choices a test makes, not which kinds of
   choices it has; the bin needs a new sequence, which is Lab 07, Part 5.

   </details>

## Further reading

- [Regression Testing & Seed Management](https://chipverify.com/verification/regression-testing-seed-management):
  regression tiers, why many seeds widen coverage, and keeping the seeds that found bugs.
  Correction: it gives `+ntb_random_seed`, which is VCS's option, for Xcelium too. On Verilator
  the run-time option is `+verilator+seed+N`.
- [Linear Random Testbench](https://chipverify.com/verification/linear-random-testbench): logging a
  seed and running many of them from a shell loop. Correction: `$get_initial_random_seed()` is a
  VCS function, not standard SystemVerilog, and the page's claim that `$random`'s sign bit skews its
  low four bits is wrong, since truncating keeps bits 3 to 0.
- [SystemVerilog Command Line Arguments](https://chipverify.com/systemverilog/systemverilog-command-line-input):
  `$test$plusargs` and `$value$plusargs`, which is how every test in the course reads its knobs.
- [Coverage Driven Verification](https://chipverify.com/verification/coverage-driven-verification):
  merging coverage across seeds and deciding what an empty bin means.

Next: [Lab 06: The register block](../labs/lab-06-the-register-block-overview.md).
