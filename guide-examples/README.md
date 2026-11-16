# Guide examples

The examples the guide pages quote. Each folder holds one page's example: a small design of our
own, its testbench, and a `Makefile` that includes `labs/common/uvm.mk`, so it builds and runs
exactly like a lab (`make build`, `make run`, `make seeds`, `make lint`, `make clean`; see
[`labs/common/README.md`](../labs/common/README.md)). Run every command from the example's folder,
in the course image. The first build of each takes 1.5 to 2 minutes on 2 CPUs; after that, a run
takes well under a second.

The guide pages are for reading, and none of them asks you to run anything here. The folders are
for anyone who wants to check what a page says, or to change an example and see what happens.

`./run-all.sh`, run from this folder, rebuilds all five examples from a clean `build/` and runs
every command in the tables below, printing the lines the pages quote. It took 1 min 49 s
with a warm ccache; with an empty one, add the five cold builds of about 100 s each.

## assertions-for-interface-rules

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

A four-beat FIFO (`fifo4.sv`), a source agent, a sink driven by a knob, and `vs_demo_vseq`, which
runs on a virtual sequencer and steers both.

| Command | What the page quotes |
|---|---|
| `make run` | the `[VSEQ]` lines of all three steps and `[MON] 44 beats in, 44 out, 0 out of order` |

## register-models

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

## Cleaning up

`make clean` in each folder removes its `build/`. The ccache is shared with the labs, at the top of
the clone.
