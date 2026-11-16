# Lab 07: reference solution

Open this after your own `make check-all` prints `15 of 15 caught.`

| File | Part | What it is |
|---|---|---|
| `tb/router_sva.sv` | 5 | `../tb/router_sva.sv` with `a_I7`, `a_O4_rst`, `a_O4_after` (with its flip-flops `seen1` and `seen2`), `a_A4`, and `a_R_pready`, `a_R_pslverr`, `a_R_prdata`, `a_R_irq` |
| `tb/router_vseq_pkg.sv` | 5, 6 | `../tb/router_vseq_pkg.sv` with `router_reset_vseq::body()`, `router_saturate_vseq::body()`, and in `router_lab07_vseq` the lines that run them and the resets in the random phases |
| `Makefile` | 5, 6 | builds the two files above with the rest of `../tb/`; `router_reset_test` and `router_saturate_test` in `TESTS`, 13 tests in all |
| `PLAN.md` | 2, 3 | the verification plan, filled in for this environment |
| `REPORT-EXAMPLE.md` | 4, 8 | a verification report, with the numbers from the runs below |

Apart from the header comments, only the code the `TODO`s mark differs from the lab folder's
files:

```bash
diff ../tb/router_sva.sv tb/router_sva.sv
diff ../tb/router_vseq_pkg.sv tb/router_vseq_pkg.sv
```

Run it from this folder; it needs no copy of the rest of the testbench:

```bash
make                 # build if needed, then run router_test
make regress         # all 13 tests on seeds 1 to 10
make check-all       # router_test against all 15 bugs
make clean
```

## What changed

| Part | Where | What |
|---|---|---|
| 5 | `router_sva_out` | `seen1` and `seen2`, cleared by `rst_n`, so that `seen2` is 1 from two cycles after the first input handshake since the reset; `a_O4_rst` (`!rst_n \|-> !valid`, no `disable iff`) and `a_O4_after` (`!seen2 \|-> !valid`, with `disable iff (!rst_n)`) |
| 5 | `router_sva` | `a_I7`, `a_A4` and the four `a_R_` assertions, each `!rst_n \|-> ...` with no `disable iff` |
| 5 | `router_reset_vseq::body()` | `setup()`; E8: output 0 stalled, a 2-beat packet waiting, an 8-beat packet whose third beat waits 3 cycles, and `reset(2)` 3 cycles after it starts; the sink made fast, 20 cycles, `rd_all_regs()`; three packets whose headers wait until `setup()`; a loop of 12 `STATUS` reads and `INT_EN` writes with `reset(1)` after `cycles(8)`, which lands in the second read; output 1 slow and part way through an 8-beat packet when `reset(3)` comes; `reset(2)` in the middle of 30 random packets |
| 5 | `router_lab07_vseq::body()` | `run()` of `router_reset_vseq`; in phases 2 to 4, half the time, a thread that waits 30 to 300 cycles, resets for 1 to 4 cycles and calls `random_config()` |
| 6 | `router_saturate_vseq::body()` | `reset(3)` and `ctrl(1)`; 250, 4, 1 and 5 one-beat packets for `DST` 0, whose route is disabled, with a `DROP_CNT` read after each burst; `ROUTE0` enabled, output 0 stalled, 9 packets to fill it, then 250, 5 and 5 FULL drops with a read after each; a write of `12345678` to `DROP_CNT`, a read, one more drop, a read, `drain()` and `rd_all_regs()` |
| 6 | `router_lab07_vseq::body()` | `run()` of `router_saturate_vseq` |

## Results

Measured in the course image (Verilator 5.050) with 2 CPUs and 3 GB, seed 1 and `router_test`
unless a row says otherwise.

| Run | Starter | Solution |
|---|---|---|
| `make run` | `ok: 0 UVM_ERROR, 0 UVM_FATAL   7.41 s`; `[SB] resets: 0 after the one at time 0, 0 expected beats lost; corners hit: reset_with_beats=0 reset_mid_packet=0 noroute_saturated=0 full_saturated=0` | `ok: 0 UVM_ERROR, 0 UVM_FATAL   7.79 s`; `[SB] resets: 8 after the one at time 0, 23 expected beats lost; corners hit: reset_with_beats=5 reset_mid_packet=4 noroute_saturated=5 full_saturated=5` |
| `make check-all` | `14 of 15 caught.`, B15 `MISSED` | `15 of 15 caught.` |
| `make check` (B15) | `VERDICT: FAIL -- your test passes B15_output_valid_survives_reset too.` | `VERDICT: PASS` |
| B15, `make check-all BUG_LIST=B15`, seeds 2 to 5 | `MISSED` on each | (in the full check-all below) |
| `make regress` | 11 tests: `110 ok  (110 runs)`, `covergroup : 81.7% (49/60)`, 3 min 57 s | 13 tests: `130 ok  (130 runs)`, `covergroup : 88.3% (53/60)`, 4 min 26 s |
| `make seeds SEEDS="1 2 3 4 5"` | | `5 ok  (5 runs)`, 8.0 to 8.6 s a run |
| `make lint` | 0 warnings | 0 warnings |
| `make run UVM_TESTNAME=router_reset_test` | fails: nothing was checked | `ok ... 0.35 s`; 4 resets, `reset_with_beats=3 reset_mid_packet=1` |
| `make run UVM_TESTNAME=router_saturate_test` | fails: nothing was checked | `ok ... 0.46 s`; `noroute_saturated=5 full_saturated=5` |

The regression's empty bins: the starter leaves the four `cg_corner` bins empty, and both leave
the seven bins of `x_fate_level` that the specification rules out (`full` at levels 0 to 8, and
`out0` and `out1` above 8), as in Labs 04 to 06.

`make check-all` with the solution, seeds 1 to 5, all 15 bugs. Every row ended `15 of 15 caught.`
with the golden router `ok`; only the counts that change from seed to seed are listed.

| Seed | golden | B15 | B02 | B14 |
|---|---|---|---|---|
| 1 | ok, 7.8 s | 50 UVM_ERROR, 45 assertions | 6 | 4, 23 assertions |
| 2 | ok, 7.8 s | 10 UVM_ERROR, 53 assertions | 4 | 4, 20 assertions |
| 3 | ok, 7.7 s | 5 UVM_ERROR, 23 assertions | 2 | 4, 13 assertions |
| 4 | ok, 8.3 s | 50 UVM_ERROR, 32 assertions | 4 | 4, 20 assertions |
| 5 | ok, 7.9 s | 50 UVM_ERROR, 33 assertions | 3 | (not kept) |

With Part 5 done and Part 6 not (`router_saturate_vseq` empty and not run), `make check-all` on
seed 1 already printed `15 of 15 caught.`, with B15 at `50 UVM_ERROR, 18 assertions`: Part 6
closes two coverage bins and catches no further bug.

## Against the whole catalogue

`make check-all`, seed 1, golden `ok` in every run. The Lab 06 column is from
`labs/lab-06-the-register-block/solutions/README.md`.

| Bug | Lab 06's solution | This starter | This solution |
|---|---|---|---|
| B01 | caught, 3 | caught, 3 | caught, 3 |
| B02 | caught, 1 | caught, 1 | caught, 6 |
| B03 | caught, 4 | caught, 5 | caught, 5 |
| B04, B05, B06 | caught, 50 | caught, 50 | caught, 50 |
| B07 | caught, 4 | caught, 7 | caught, 6 |
| B08, B09 | caught, 50 | caught, 50 | caught, 50 |
| B10 | caught, 50 and 256 assertions | caught, 50 and 256 | caught, 50 and 256 |
| B11 | caught, 22 and 19 assertions | caught, 50 and 46 | caught, 48 and 45 |
| B12 | caught, 50 and 3 assertions | caught, 50 and 3 | caught, 50 and 3 |
| B13 | caught, 50 and 1 assertion | caught, 50 and 1 | caught, 50 and 1 |
| B14 | caught, 2 | caught, 2 | caught, 4 and 23 assertions |
| B15 | MISSED | MISSED | caught, 50 and 45 assertions |
| total | `14 of 15 caught.` | `14 of 15 caught.` | `15 of 15 caught.` |

The starter catches the same fourteen bugs as Lab 06's solution. `router_test` runs
`router_lab07_vseq` after everything Lab 06's `router_test` ran, so the first part of the run is
Lab 06's: with the sequence skipped (a probe build with a plusarg guard round it, not shipped),
the starter printed Lab 06's lines number for number
(`1133 packets in: 282 to output 0, 226 to output 1, 195 NOROUTE, 430 FULL` and
`870 reads, 64 of STATUS checked; 492 transfers to bad addresses; irq checked in 14840 cycles, wrong in 0`)
and Lab 06's catch row, count for count. So the reset driver, the drivers' reset handling and the
scoreboard's reset path change nothing in a run without a reset. The counts that move (B03, B07,
B11) are errors the random phases add at the end.

## First checks on seed 1

| Bug | First check | From |
|---|---|---|
| B01 | `[IRQ] irq is 0 from cycle 5969, but STATUS = 110 and INT_EN = 111 make it 1` | the `irq` check, in `router_lab06_vseq`'s Part 5 step |
| B02 | `[IRQ] irq is 1 from cycle 5909, but STATUS = 001 and INT_EN = 000 make it 0` | the same |
| B03 | `[RegModel] Register "regs.ROUTE3" value read from DUT (0x0000000000000002) does not match mirrored value (0x0000000000000001) ...` | the predictor, during the bit bash |
| B04 | `[APB] a read of 01, completing in cycle 4145: pslverr is 0, but 01 is a bad address` | the scoreboard, in the bad-address sweep |
| B05 | `[IRQ] irq is 1 from cycle 6077, but STATUS = 000 and INT_EN = 111 make it 0` | the `irq` check |
| B06 | `[OUT] output 0: got 40 last in cycle 5910, and no beat was expected` | the scoreboard |
| B07 | `[DROP_CNT] read 00008f32, expected 00006132 (FULL_CNT 97, NOROUTE_CNT 50)` | the scoreboard, at the end of `router_inject_test`'s first phase |
| B08 | `[DROP_CNT] read 00000201, expected 00000101 (FULL_CNT 1, NOROUTE_CNT 1)` | the scoreboard |
| B09 | `[OUT] output 0: got 0a last in cycle 5995, expected 09 last` | the scoreboard |
| B10 | `u_out0.a_O2`: `O2: out_data or out_last changed while the beat waited` | Lab 05's assertion |
| B11 | `u_out0.a_O6`: `O6: an output packet is longer than 8 beats` | Lab 05's assertion |
| B12 | `[OUT] output 1: got 41 in cycle 6063, expected 12 last` | the scoreboard |
| B13 | `[STATUS] a read of 08, completing in cycle 5947 returned 00000005; it should return 00000007, STATUS in cycle 5946` | the scoreboard |
| B14 | `a_I7`: `I7: in_ready is 1 during reset`, at 15000 ps (cycle 2) | this lab's assertion, during the reset at time 0; the starter's first check is the register model's, at 115000 ps (cycle 12) |
| B15 | `u_out0.a_O4_rst`: `O4: out_valid is 1 during reset`, at 148695000 ps | this lab's assertion, in the E8 step; the scoreboard follows 3 cycles later with `[OUT] output 0: got 00 in cycle 14873, and no beat was expected` |

## Hunts on seed 1

| Where | Deal | `make hunt` | `make verdict` |
|---|---|---|---|
| starter | `make new BUGPICK=B02` | `caught`, 1 UVM_ERROR, 7.4 s | `VERDICT: PASS`, B02, 14.9 s |
| starter | `make new BUGPICK=B15` | `quiet`, `0 UVM_ERROR, 0 UVM_FATAL`, 7.4 s | not run; `make reveal` names B15 |
| solution | `make new BUGPICK=B15` | `caught`, 50 UVM_ERROR, 45 assertions | `VERDICT: PASS`, B15 |
| solution | `make new` | `caught`, 50 UVM_ERROR, 256 assertions | `VERDICT: PASS`, B10 |

## Build and run times

| What | Time |
|---|---|
| first build of the starter, empty ccache | 130 s (Verilator 130.147 s, `Hits: 0 / 38`); two more cold builds, each beside another build or regression on the same machine, took 125 s and 146 s |
| rebuilds in the lab folder: the Part 5 assertions, the Part 5 sequences, Part 6 | 118 s, 114 s, 116 s |
| first build of this folder, empty ccache | 143 s, beside the starter's first build |
| `router_test` | 7.2 to 7.9 s |
| `router_reset_test`, `router_saturate_test` | 0.35 s, 0.46 s |
| `make check-all` | 71 to 79 s |
| `make hunt`, `make verdict` | 7.5 s, 14.9 s |
| `make regress`: starter (110 runs), lab folder with these files (130 runs), this folder | 3 min 57 s, 4 min 12 s, 4 min 26 s |

## Differences from the first Lab 07

The first Lab 07 was `labs/ref` with this lab's parts cut out: a cycle-exact reference model, its
own agents, eleven directed sequences and `router_all_test`. A student who finished Lab 06 would
have been handed a different testbench. This one is the rebuilt Lab 06's solution with the pieces
a reset in flight needs added.

- The graded test is `router_test`, as in Labs 05 and 06. Lab 07's own sequence,
  `router_lab07_vseq`, runs last, so nothing it draws changes what runs before it.
- Lab 06 had no reset driver. The given pieces add one, and teach the source and APB drivers rules
  I3 and A4. The APB driver needs a cycle's warning that a reset is coming, which the reset driver
  gives it through `rst_soon`.
- The scoreboard isn't cycle-exact. It checks the order and data of the beats, not the cycle each
  one appears, and it checks a `DROP_CNT` read correctly only while no packet is coming in, so
  `router_saturate_vseq` reads between bursts. The ref's same-cycle clear of `DROP_CNT` (example
  E9) is left out.
- The coverage is Lab 06's (`cg_pkt`, `cg_wait`) with `cg_corner`'s four bins added, 60 bins in
  all, where the ref had 145. The seven bins of `x_fate_level` that the specification rules out
  stay empty, so the finished environment reaches 88.3%, not 100%.
- Many rows of the plan have no checker in this environment (`in_ready`, the cycle a beat
  appears, the APB master's rules, `LEVEL`). `PLAN.md` lists them as open items.
- `BUG_LIST` puts B15 first, so that `make check` fails on the starter.

There is no Lab 08. A later course that starts from this testbench would copy `../tb/` with the two
files here in place of their namesakes, the `Makefile` from this folder's parent with `TESTS` as
here, and `../src/loc.py`.
