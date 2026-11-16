# Lab 03: reference solution

Open this after `make check-all` prints `2 of 2 caught.` with your own files, or when you're
stuck on a part.

| File | Replaces | What it adds |
|---|---|---|
| `coverage.svh` | `tb/coverage.svh` | `cg_pkt`, a covergroup written `with function sample`, built in `new()` and sampled in `sample_pkt()` (Part 2) |
| `packet.svh` | `tb/packet.svh` | in `rand_packet`: `len` made `rand`, weights `w_one`, `w_mid`, `w_max` of 25/50/25 in a `dist` on `kind` written with numbers, and `c_len`, which solves `len` from `kind` (Part 3) |
| `router_test_pkg.sv` | `tb/router_test_pkg.sv` | `fill_plan` and `close_holes()` (Part 4) |

Everything else in `tb/` is the same as the starter. To compare one of these files with yours,
run, for example:

```bash
diff tb/packet.svh solutions/packet.svh
```

To run the solution, keep a copy of your files outside `tb/` and put the solution's in their place:

```bash
mkdir -p mine && cp tb/coverage.svh tb/packet.svh tb/router_test_pkg.sv mine/
cp solutions/coverage.svh solutions/packet.svh solutions/router_test_pkg.sv tb/
make check-all
cp mine/* tb/
```

On 2 CPUs, swapping the solution into a starter build rebuilt in 99 s (92 s in a second
measurement), with a ccache that held no build of the solution. Swapping the starter files back
took 11 s (16 s in the second measurement), because the ccache still held the starter's build.

## The covergroup

| Coverpoint | Bins |
|---|---|
| `cp_len` | `len1` to `len8` |
| `cp_dst` | `dst0` to `dst3` |
| `cp_fate` | `noroute`, `full`, `out0`, `out1` (0 to 3, `fate_e` in `tb/tracker.svh`) |
| `cp_level` | `empty` (0), `low` (1 to 7), `at_8`, `at_9`, `high` (10 to 16) |
| `x_fate_level` | `cp_fate` crossed with `cp_level`: 20 bins |

That is 41 bins. Twelve can't be hit in this lab:

| Bins | Why |
|---|---|
| `full_x_empty`, `full_x_low`, `full_x_at_8`, `out0_x_at_9`, `out0_x_high`, `out1_x_at_9`, `out1_x_high` | the specification: a FULL drop happens only at a level of 9 or more, and a packet is admitted only at 8 or less |
| `out1_x_low`, `out1_x_at_8` | nothing watches output 1, so the tracker takes its level as 0 |
| `cp_fate.full`, `full_x_at_9`, `full_x_high` | no test in this lab drops a packet as FULL: Lab 02's scoreboard would expect it on output 0 (see `close_holes()` below) |

So 29 bins are reachable, and the solution's `router_rand_test` and `router_fill_test` together hit
24. The five reachable bins they leave empty are `cp_level.at_9`, `noroute_x_empty`,
`noroute_x_low`, `noroute_x_at_8` and `noroute_x_at_9`.

## `close_holes()`

`close_holes()` works on output 0 only. It enables `ROUTE0` to output 0 and disables `ROUTE1` to
`ROUTE3` with `PORT` 0 (`write_routes("0---")`), stalls output 0's sink, waits two cycles, and
then sends:

| Packets | Fate in the golden router | Bin |
|---|---|---|
| a `fill_plan`: 1 to 8 packets for DST 0 whose lengths add up to 8, made with `rand_packet::make()` | admitted at levels 0 to 7 | `out0_x_empty`, `out0_x_low` |
| one random packet for DST 0 | admitted at level 8 | `out0_x_at_8` (B08's hole) |
| one random packet for DST 1, with `c_dst.constraint_mode(0)` | NOROUTE at level 9 to 16 | `noroute_x_at_9` or `noroute_x_high` (B07's hole) |

Then the sink is released and the outputs drain, and `router_rand_test` reads `DROP_CNT`, which
should be `00000001`. Nothing goes to output 1, and nothing more goes to output 0 while it holds
more than 8 beats. One more packet for DST 0 at that point is dropped as FULL by the golden
router; the tracker predicts that, but Lab 02's scoreboard expects the packet on output 0 and fails the golden
run (`out0 never delivered dst 0, 7 beats: 05 97 b0 de 57 f7 62, which went in at 335 ns`, measured
with that packet added to `router_fill_test`).

## The `DROP_CNT` read that later labs keep

B07 changes no packet. It adds 1 to `FULL_CNT` (and sets `STATUS.FULL`) for a packet dropped as
NOROUTE while its output holds more than 8 beats, so no packet that comes out shows it. In this
lab the only check that sees it is the `DROP_CNT` read in `env.check_drops()` after
`close_holes()`. Every later lab's graded test has to keep a
`DROP_CNT` read after its fill step, checked against the expected count. The later labs'
`BUG_LIST`s don't include B07, so their graders wouldn't show the loss.

The files Lab 04's port starts from are `tb/` with these three files copied in.

## Results

Measured on the course image with 2 CPUs and 3 GB, with these files in `tb/`:

| Run | Result |
|---|---|
| `make seeds SEEDS="1 2 3 4 5"` | `5 ok  (5 runs)`, 1.1 s each |
| `make check-all`, seeds 1 to 5 | golden `ok`; B07 caught with `1 UVM_ERROR, 1 assertion`, B08 with `1 UVM_ERROR, 2 assertions`; `2 of 2 caught.` on each seed |
| `make check` | `VERDICT: PASS` (B07) |
| `make run UVM_TESTNAME=router_fill_test` | `ok`, 0.03 s |
| `make cov` over `router_rand_test` and `router_fill_test`, seed 1 | `covergroup : 58.5% (24/41)` |

The first checks to fire, seed 1, `router_rand_test`:

| Bug | Errors |
|---|---|
| B07 | `DROP_CNT read 00000101, expected 00000001 (FULL_CNT 0, NOROUTE_CNT 1)` |
| B08 | the same `DROP_CNT` line, then `out0 never delivered dst 0, 3 beats: 23 59 37, which went in at 53635 ns` |

Against the whole catalogue (`make check-all BUG_LIST="B01 B02 ... B15"`), on each of seeds 1, 2
and 3, with the golden router `ok` each time:

| | Caught | Missed |
|---|---|---|
| Starter | B05, B09: `2 of 15 caught.` | the other 13, B07 and B08 among them (B07 and B08 also on seeds 4 and 5) |
| Solution | B05, B07, B08, B09, B10: `5 of 15 caught.` | B01 to B04, B06, B11 to B15 |

B05 and B09 read `100 assertions` and no `UVM_ERROR` count: the scoreboard reports more than 100
mismatches in 800 packets, and the run stops at the 100th `$error` (the Makefile's
`+verilator+error+limit+100`), before the test's summary. The grader still counts the run as
caught. B10 was caught with 4, 5 and 3 assertions on seeds 1 to 3. It is Lab 05's bug, caught here
because `close_holes()` stalls output 0 while it holds more than one beat. Lab 03's page doesn't
mention it. Lab 05 starts from a testbench that already catches it, and has you write the
assertions that show the cycle in which the router goes wrong.
