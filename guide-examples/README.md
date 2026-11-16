# Guide examples

The SystemVerilog examples that the guide pages in `docs/guide/` quote. Each folder belongs to one
page and has the page's name. Every folder has a `Makefile` that includes the labs' shared
[`labs/common/uvm.mk`](../labs/common/README.md), so it builds with Verilator 5.050 and the UVM
library in `third_party/uvm`, needs the course image and nothing else, and has the same targets as a
lab (`make build`, `make run`, `make seeds`, `make lint`, `make clean` and the rest). One build
serves every test in a folder, and `UVM_TESTNAME` picks the test when you run.

The guide pages are for reading, and none of them asks you to run anything here. The sections below
give the commands that produced each output a page quotes, so the folders are for anyone who wants
to check what a page says, or to change an example and see what happens. Every quoted output came
from a run in a folder with no `build/`. Run each command from the example's folder, in the course
image, and finish with `make clean`.

On 2 CPUs, the first build of one of the six examples from `constrained-random-on-verilator` to
`the-factory-and-config-db` took 85 to 129 s with little in the ccache, and 13 to 32 s after
`make clean` with the ccache warm. The first builds of the five from
`assertions-for-interface-rules` on took 1.5 to 2 minutes. A run takes under two seconds.

## Getting started and What a framework buys you

These two pages have no examples of their own. *What a framework buys you* quotes Lab 01's
writeup. *Getting started* quotes a run of Lab 01's own targets in
`labs/lab-01-one-alu-two-testbenches`, starting from an empty compiler cache:

```bash
make clean-cache && make clean
make build                          # the first build, 126 s
make run                            # ok: 0 UVM_ERROR, 0 UVM_FATAL   1.18 s
make check-all                      # 2 of 3 caught, then make's error line
make cocotb                         # build 0.4 s, run 23.0 s
make clean
```

and the version checks from Lab 01, Part 1. The two rebuild times came from two one-line edits to
`tb/alu_pkg.sv` in a scratch copy, each undone afterwards: `repeat (3)` changed to `repeat (4)` in
`alu_base_test::run_phase()` (27 s), and an `int unsigned n_extra;` member added to
`alu_scoreboard` (108 s).

## from-cocotb-to-systemverilog-classes

Page: [From cocotb to SystemVerilog classes](../docs/guide/from-cocotb-to-systemverilog-classes.md).
The design is Lab 01's ALU, `labs/lab-01-one-alu-two-testbenches/rtl/alu.sv`, with its `+BUG` switch.

| Command | What the page quotes |
|---|---|
| `make build` | |
| `make run UVM_TESTNAME=t01_test` | `t01: 6 directed vectors checked` |
| `make run UVM_TESTNAME=t01_test BUG=A01` | `[2000] %Error: ... SUB(0xc8, 0x3c) gave out=0x74 ...`, `Verilog $stop`, `Aborting...` |
| `make run UVM_TESTNAME=widths_test` | `sum8 = a + b -> 4`, `sum9 = a + b -> 260`, `$display(a + b) -> 4`, `[1 beat ]`, `[1 beat]` |

## classes-for-testbenches

Page: [Classes for testbenches](../docs/guide/classes-for-testbenches.md). The demonstrations are
plain SystemVerilog classes; each runs inside a small UVM test only so that `make run` works as it
does in the labs.

| Command | What the page quotes |
|---|---|
| `make build` | |
| `make run UVM_TESTNAME=handles_test` | `a is null` ... `a == b is 1, a == c is 0, pkt::n_made is 1` |
| `make run UVM_TESTNAME=reuse_test` | the six `one pkt, reused:` and `a new pkt each:` lines |
| `make run UVM_TESTNAME=dispatch_test` | `through a base_test handle:` and the five lines after it |
| `make run UVM_TESTNAME=null_test` | `%Error: ...classes_demo_pkg.sv:112: Null pointer dereferenced`, `Aborting...` |
| `make lint VFLAGS="--timescale 1ns/1ps +define+FUNCTION_WAITS"` | `%Error-FUNCTIMECTL: ... Functions cannot contain time-controlling statements` |

## interfaces-clocking-blocks-and-virtual-interfaces

Page: [Interfaces, clocking blocks and virtual interfaces](../docs/guide/interfaces-clocking-blocks-and-virtual-interfaces.md).
The design is the golden router, `labs/common/rtl`.

| Command | What the page quotes |
|---|---|
| `make build` | |
| `make run UVM_TESTNAME=edge_test` | the `edge:` lines from 65 ns to 115 ns, `in_valid pin changes`, `handshake on beat` |
| `make run UVM_TESTNAME=typedef_test` | the eight lines from 45 ns to 75 ns |
| `make run UVM_TESTNAME=module_task_test PLUSARGS=+MODULE_TASK` | `high at 1 of 3 edges`, `high at 3 of 3 edges` |
| `make waves UVM_TESTNAME=edge_test` | the waves for the figure below |

The figure `docs/assets/img/dd105-router-clocking-block.png` is a screenshot of that run's waves,
taken from the top of the repo with
[`scripts/screenshots/shoot.sh`](../scripts/screenshots/README.md):

```bash
scripts/screenshots/shoot.sh surfer guide-examples/interfaces-clocking-blocks-and-virtual-interfaces/build/runs/edge_test-s1/waves.fst \
  -s rtr_top.clk,pins.psel,pins.penable,pins.in_ready,pins.in_valid,pins.in_data,pins.out0_valid,pins.out0_data \
  --from 60ns --to 120ns --time-unit ns -o docs/assets/img/dd105-router-clocking-block.png
```

## threads-mailboxes-and-events

Page: [Threads, mailboxes and events](../docs/guide/threads-mailboxes-and-events.md).

| Command | What the page quotes |
|---|---|
| `make build` | |
| `make run UVM_TESTNAME=fork_test` | the seventeen lines from `0 ns: fork...join` to `90 ns: wait fork returns` |
| `make run UVM_TESTNAME=capture_test` | `i = 3` three times, then `j = 0`, `1`, `2` |
| `make run UVM_TESTNAME=static_loop_test PLUSARGS=+STATIC_LOOP` | `j = 0` three times, then `0`, `1`, `2` |
| `make lint` | `%Warning-IMPLICITSTATIC: ... threads_top.sv` |
| `make run UVM_TESTNAME=mailbox_test` | `mailbox bound 0 (unbounded)` and the nine lines after it |
| `make run UVM_TESTNAME=mailbox_test PLUSARGS=+BOUND=1` | `mailbox bound 1` and the nine lines after it |
| `make run UVM_TESTNAME=event_test` | `10 ns: ->done`, `wait (done.triggered) returns`, `30 ns: end of the demo` |
| `make run UVM_TESTNAME=disable_test` | the four lines from 25 ns to 150 ns |

## constrained-random-on-verilator

Page: [Constrained random on Verilator](../docs/guide/constrained-random-on-verilator.md).
Small classes built on SimProc's ALU operations, randomized many times; no design.

```bash
cd guide-examples/constrained-random-on-verilator
make build
make run UVM_TESTNAME=cr_item_test            # ends in BROKEN on purpose: one randomize() fails
make run UVM_TESTNAME=cr_item_test SEED=2
make run UVM_TESTNAME=cr_enum_test
make run UVM_TESTNAME=cr_dist_test            # ends in BROKEN on purpose: the failures it counts
make run UVM_TESTNAME=cr_solve_test
make run UVM_TESTNAME=cr_item_test VERILATOR_SOLVER="z3 --in"    # make refuses: no z3
( cd build && VERILATOR_SOLVER="z3 --in" ./sim +UVM_TESTNAME=cr_item_test )   # UVM_FATAL [SOLVER]
make clean
```

The page also quotes Lab 03's `make traps` (in `labs/lab-03-constraints-and-coverage`), which
printed the same lines as the lab's writeup.

## functional-coverage-you-can-read

Page: [Functional coverage you can read](../docs/guide/functional-coverage-you-can-read.md).
A covergroup on ALU vectors, and two small covergroups that show how Verilator counts bins.

```bash
cd guide-examples/functional-coverage-you-can-read
make build
make run UVM_TESTNAME=cov_plain_test
make cov                                      # 82.9% (34/41), and the 7 empty bins
rm -rf build/runs
make run UVM_TESTNAME=cov_biased_test
make cov                                      # x_op_eq 12 of 12
make build VFLAGS=+define+CG_MEMBER BUILD_DIR=$PWD/build/member   # stops with COVERIGN
make clean
```

`scripts/figures/functional_coverage_cross.py` draws the two runs' `x_op_eq` counts from
`build/coverage/bins.txt`.

## the-uvm-skeleton

Page: [The UVM skeleton](../docs/guide/the-uvm-skeleton.md).
A test, an environment and two agents that print a line in each phase; no design.

```bash
cd guide-examples/the-uvm-skeleton
make build
make run UVM_TESTNAME=sk_phase_test           # the phase order, objections, drain time
make run UVM_TESTNAME=sk_noobj_test           # no objection: the run phase ends at 0 ns
make run UVM_TESTNAME=sk_error_test           # one UVM_ERROR: FAIL, exit status 1
make run UVM_TESTNAME=sk_phase_tset           # a misspelt test: BROKEN, exit status 0
make clean
```

## sequences-sequencers-and-drivers

Page: [Sequences, sequencers and drivers](../docs/guide/sequences-sequencers-and-drivers.md).
SimProc's ALU (Lab 01's `rtl/alu.sv`) driven by a sequence, a sequencer and a driver that print
each step of the handshake.

```bash
cd guide-examples/sequences-sequencers-and-drivers
make build
make run UVM_TESTNAME=sq_timeline_test
make run UVM_TESTNAME=sq_two_test
make run UVM_TESTNAME=sq_nested_test
make waves UVM_TESTNAME=sq_timeline_test
make clean
```

The page's waveform is `make waves`' `build/runs/sq_timeline_test-s1/waves.fst`, taken with
`scripts/screenshots/shoot.sh surfer <waves.fst> -s sq_top.clk,aif.valid,u_alu.ALUop,u_alu.A,u_alu.B,u_alu.ALUout --from 0ns --to 55ns --time-unit ns`.

## monitors-analysis-ports-and-scoreboards

Page: [Monitors, analysis ports and scoreboards](../docs/guide/monitors-analysis-ports-and-scoreboards.md).
The ALU with a full agent: a monitor whose analysis port feeds a scoreboard, a coverage collector
and a history that keeps every handle.

```bash
cd guide-examples/monitors-analysis-ports-and-scoreboards
make build
make run UVM_TESTNAME=mon_rand_test
make run UVM_TESTNAME=mon_rand_test BUG=A01   # caught: the scoreboard's errors
make run UVM_TESTNAME=mon_alias_test          # one object for every write
make check-all UVM_TESTNAME=mon_rand_test     # 2 of 3 caught: A03 is missed
make clean
```

## the-factory-and-config-db

Page: [The factory and config_db](../docs/guide/the-factory-and-config-db.md).
The environment from `monitors-analysis-ports-and-scoreboards`, built from that folder's files
without changes, with tests that change it through the factory and `config_db`. It needs that
folder next to it.

```bash
cd guide-examples/the-factory-and-config-db
make build
make run UVM_TESTNAME=fac_equal_test                       # the factory's override table
make check-all UVM_TESTNAME=fac_equal_test                 # 0 of 3 caught
make check-all UVM_TESTNAME=fac_flags_test                 # 3 of 3 caught
make run UVM_TESTNAME=fac_typo_test PLUSARGS=+UVM_CONFIG_DB_TRACE
make run UVM_TESTNAME=fac_prec_test
make run UVM_TESTNAME=mon_rand_test BUG=A01 PLUSARGS=+uvm_set_type_override=alu_item,alu_equal_item
make clean
```

## assertions-for-interface-rules

Page: [Assertions for interface rules](../docs/guide/assertions-for-interface-rules.md).
A one-beat valid/ready stage (`stage.sv`), its three rules as assertions (`stage_sva.sv`, bound
into the stage), and `stage_test`, which drives random beats and a random `out_ready`. `+BUG=drop`
and `+BUG=bubble` switch on the two planted bugs.

| Command | What the page quotes |
|---|---|
| `make run` | the golden stage: `[STAGE] 89 beats in, 88 out; a beat waited in 90 cycles (cover property: 90)`, `ok` |
| `make run BUG=drop PLUSARGS=` | the default error limit: the first `%Error`, `Verilog $stop`, `Aborting...`; `caught: 1 assertion`; `exit_status` 1 |
| `make run BUG=drop` | four `a_S1` failures, the `[SVA]` error, `caught: 1 UVM_ERROR, 4 assertions` |
| `make run BUG=drop PLUSARGS="+verilator+error+limit+1000 +IGNORE_SVA"` | the same four failures, then `DD105: TEST PASSED`; `exit_status` 0 |
| `make run BUG=drop PLUSARGS="+verilator+error+limit+1000 +READY_PCT=100"` | `a beat waited in 0 cycles (cover property: 0)`, `MISSED` |
| `make run BUG=bubble` | `a_S3` failures, `caught: 1 UVM_ERROR, 28 assertions` |

## reactive-agents-and-backpressure

Page: [Reactive agents and backpressure](../docs/guide/reactive-agents-and-backpressure.md).
`beat_src.sv` decides when each beat appears; the sink agent in `sink_tb.sv` takes them either by
flipping a coin every cycle or by answering each beat with an item from its sequence. The test
prints how long the 2,000 beats waited.

| Command | What the page quotes |
|---|---|
| `make run PLUSARGS="+MODE=coin +READY_PCT=5"` | the `[WAIT]` and `[HIST]` lines for a coin flip at 5% |
| `make run PLUSARGS="+MODE=coin +READY_PCT=50"` | the same at 50% |
| `make run PLUSARGS="+MODE=coin +READY_PCT=95"` | the same at 95% |
| `make run PLUSARGS="+MODE=beat +MAX_DELAY=12"` and the same with `SEED=2` | per-beat delays from `randomize()` |
| `make run PLUSARGS="+MODE=beat +MAX_DELAY=12 +URANDOM"` | per-beat delays from `$urandom_range` |

`scripts/figures/reactive_wait_histograms.py` draws the page's figure from the `[HIST]` lines.

## virtual-sequences

Page: [Virtual sequences](../docs/guide/virtual-sequences.md).
A four-beat FIFO (`fifo4.sv`), a source agent, a sink driven by a knob, and `vs_demo_vseq`, which
runs on a virtual sequencer and steers both.

| Command | What the page quotes |
|---|---|
| `make run` | the `[VSEQ]` lines of all three steps and `[MON] 44 beats in, 44 out, 0 out of order` |

## register-models

Page: [Register models](../docs/guide/register-models.md).
Four registers on a one-cycle bus (`regblk.sv`), their register model, an adapter and a predictor
(`regblk_tb.sv`). `+PREDICT=predictor|auto|none` picks how the mirror follows the design.
`+BUG=en_reset_1` and `+BUG=mode_stuck` switch on the planted bugs.

| Command | What the page quotes |
|---|---|
| `make run UVM_TESTNAME=reg_reset_test` | `Verifying reset value of register` for `ID` and `CTRL` only |
| `make run UVM_TESTNAME=reg_reset_test BUG=en_reset_1` | the `[RegModel]` mismatch on `CTRL` |
| `make run UVM_TESTNAME=reg_bitbash_test` | `Verifying bits in register` for all four |
| `make run UVM_TESTNAME=reg_bitbash_test BUG=mode_stuck` | `Writing a 1 in bit #3 of register "regs.CTRL" ...` |
| `make run UVM_TESTNAME=reg_mirror_test` | the `[RAL]` lines with the predictor |
| `make run UVM_TESTNAME=reg_mirror_test PLUSARGS=+PREDICT=auto` | the mirror missing the raw write, and the `[RegModel]` error |
| `make run UVM_TESTNAME=reg_mirror_test PLUSARGS=+PREDICT=none` | the mirror missing both writes |

## regressions-and-seeds

Page: [Regressions and seeds](../docs/guide/regressions-and-seeds.md).
A 4-bit saturating counter (`satcnt.sv`) and two tests. `count_test` drives random `inc` and `clr`
and checks every cycle against a model; `+BUG=wrap` makes the counter wrap at 15. `random_test`
prints the first values two threads draw, so you can see what a seed fixes.

| Command | What the page quotes |
|---|---|
| `make seeds UVM_TESTNAME=count_test SEEDS="1 2 3 4 5 6 7 8 9 10"` | `10 ok  (10 runs)`, the merged coverage, and each run's `[COUNT]` line |
| `make run UVM_TESTNAME=count_test SEED=n BUG=wrap`, for n from 1 to 10 | which seeds catch the wrap |
| `make run UVM_TESTNAME=random_test SEED=1`, then `SEED=2` | the two threads' values |
| `make run UVM_TESTNAME=random_test SEED=1 PLUSARGS=+EXTRA_DRAW` (and `+EXTRA_NEW`, `+EXTRA_SEQ`, `+EXTRA_START`) | what one more draw, object or sequence changes |
| `make run UVM_TESTNAME=count_test SEED=random` | a run folder named after the seed it picked |

`make seeds` and `make regress` don't pass `BUG` on to the runs, which is why the wrap bug is run
one seed at a time.

*Writing the verification report* quotes the same runs in its worked report.

## Verification plans and sign-off

This page has no example of its own. It quotes runs of Lab 07's starter package in
`labs/lab-07-capstone`: `make regress`, `make check-all` and a `make hunt` that was dealt B15.

## run-all.sh

`./run-all.sh`, run from this folder, covers the last five examples above, from
`assertions-for-interface-rules` to `regressions-and-seeds`. It rebuilds each of them from a clean
`build/` and runs every command in their tables, printing the lines the pages quote. It took 1 min
49 s with a warm ccache; with an empty one, add the five cold builds of about 100 s each.

## Figures

The diagrams on the guide pages are drawn by the scripts in
[`scripts/figures/`](../scripts/figures/README.md), which lists each script, the figure it writes
and the page that uses it.

## Cleaning up

`make clean` in each folder removes its `build/`. The examples share the course's compiler cache in
`.ccache` at the top of the clone with the labs, and `make clean-cache` removes it.
