# Lab 05: reference solution

Open this after `make check-all` prints `3 of 3 caught.` with your own files.

| File | Part | What it is |
|---|---|---|
| `router_sva.sv` | 2 | `tb/router_sva.sv` with `a_O1`, `a_O2` and `a_O6` in `router_sva_out` |
| `router_agents_pkg.sv` | 3 | `tb/router_agents_pkg.sv` with `out_ready_driver`'s countdown and its `rdy` decision |
| `router_vseq_pkg.sv` | 4 | `tb/router_vseq_pkg.sv` with `router_lab05_vseq::body()` |

Compare them with the shipped files:

```bash
diff tb/router_sva.sv solutions/router_sva.sv
diff tb/router_agents_pkg.sv solutions/router_agents_pkg.sv
diff tb/router_vseq_pkg.sv solutions/router_vseq_pkg.sv
```

To run the solution, keep copies of your own files outside `tb/` and put the solution in their
place:

```bash
mkdir -p mine && cp tb/router_sva.sv tb/router_agents_pkg.sv tb/router_vseq_pkg.sv mine/
cp solutions/router_sva.sv solutions/router_agents_pkg.sv solutions/router_vseq_pkg.sv tb/
make check-all
cp mine/* tb/
```

On 2 CPUs, in the course image, the starter built cold in 106 s (Verilator 106.395 s,
`Hits: 0 / 38`). Each part's file, copied in one after another, rebuilt in 103 s (Part 2), 107 s
(Part 3) and 105 s (Part 4), and copying the three starter files back over the finished build took
14 s.

## What changed

| Part | Where | Change |
|---|---|---|
| 2 | `router_sva_out` | `a_O1`: `valid && !ready \|=> valid`; `a_O2`: `valid && !ready \|=> $stable(data) && $stable(last)`; `a_O6`: `valid && ready && beats == 4'd7 \|-> last`; each with its counter and an `$error` |
| 3 | `out_ready_driver::run_phase` | while a beat waits: `if (!seen) seen = 1; else if (wait_left > 0) wait_left--;` |
| 3 | `out_ready_driver::run_phase` | `rdy = r != null && (r.pre_ready \|\| (seen && wait_left == 0));` |
| 4 | `router_lab05_vseq::body()` | every route enabled (DST 0 and 2 to output 0, 1 and 3 to output 1) and `CTRL.EN`; output 1 stalled with 4 three-beat packets to DST 0 and 2 to DST 1, then output 0 stalled the other way round, each drained; oversize packets of 9, 12, 10, 10 and 20 beats with both sinks in `SNK_RANDOM`; then one `fork` of `send_rand(300, 20, 15)`, `backpressure()`, and DST 1 and DST 2 moved to the other output and back with 150 cycles between the writes; then a drain and a `DROP_CNT` read |

## Results

Measured in the course image with 2 CPUs and 3 GB, `router_test` unless a row says otherwise.

| Run | Result |
|---|---|
| `make check-all`, seeds 1 to 5 | golden `ok` and `3 of 3 caught.` on every seed (table below) |
| `make check` (B11), `make check BUG=B10`, `make check BUG=B12` | `VERDICT: PASS` each |
| `make seeds SEEDS="1 2 3 4 5"`, then seeds 6 to 10 | `5 ok  (5 runs)` each; 2.8 to 2.9 s a run on seeds 1 to 5 |
| `make seeds UVM_TESTNAME=router_lab05_test`, seeds 1 to 10 | `10 ok  (10 runs)` |
| `make seeds UVM_TESTNAME=router_sink_test SEEDS="1 2 3 4 5"` | `5 ok  (5 runs)` |
| `make regress SEEDS="1 2 3 4 5"` (all eight tests) | `40 ok  (40 runs)` in 68 s, `covergroup : 87.5% (49/56)` |
| `make lint` | 0 warnings, on the starter and on the solution |

| Seed | B11 | B10 | B12 |
|---|---|---|---|
| 1 | 33 UVM_ERROR, 26 assertions | 50 UVM_ERROR, 244 assertions | 50 UVM_ERROR, 1 assertion |
| 2 | 34, 28 | 50, 191 | 50, 3 |
| 3 | 37, 29 | 50, 314 | 50, 3 |
| 4 | 32, 27 | 50, 169 | 50, 4 |
| 5 | 29, 23 | 50, 178 | 50, 3 |

The seven bins the regression leaves empty are the seven of `x_fate_level` that the specification
rules out (`full_x_empty`, `full_x_low`, `full_x_at_8`, `out0_x_at_9`, `out0_x_high`,
`out1_x_at_9`, `out1_x_high`), as in Lab 04. `cg_pkt` has 42 bins now (`cp_len.oversize` is new)
and `cg_wait` 14.

Against the whole catalogue (`make check-all BUG_LIST="B01 B02 ... B15"`, seed 1), with the golden
router `ok` both times:

| Bug | Starter | Solution |
|---|---|---|
| B01 to B04 | MISSED | MISSED |
| B05 | caught, 50 `UVM_ERROR`s | caught, 50 |
| B06 | caught, 50 | caught, 50 |
| B07 | caught, 3 | caught, 4 |
| B08 | caught, 50 | caught, 50 |
| B09 | caught, 50 | caught, 50 and 1 assertion |
| B10 | caught, 50 | caught, 50 and 244 assertions |
| B11 | MISSED (seeds 1 to 5) | caught, 33 and 26 assertions |
| B12 | caught, 50 | caught, 50 and 1 assertion |
| B13 | caught, 50 | caught, 50 |
| B14, B15 | MISSED | MISSED |
| total | `8 of 15 caught.` | `9 of 15 caught.` |

The starter's row is Lab 04's solution row, bug for bug and count for count: `router_test` runs
`router_inject_test` unchanged before its virtual sequence, and on seed 1 it prints Lab 04's
`[SB]` lines (`805 packets in: 144 to output 0, 190 to output 1, 194 NOROUTE, 277 FULL`). B07
rises from 3 errors to 4 because the virtual sequence's final `DROP_CNT` read fails as well. B01 to
B04 and B14 are Lab 06's bugs and B15 is Lab 07's: nothing in this testbench reads `ID`, `CTRL`,
`INT_EN`, `STATUS`, `LEVEL` or a `ROUTE` register, writes `STATUS` or `INT_EN`, checks `irq`, uses
a bad address, or resets the router after time 0.

## B11

Under B11 the 8th beat of a cut packet has no `out_last`. No Lab 04 test sends a packet of more
than 8 beats (`hides behind: sending only legal packets of 8 beats or fewer`), so the starter misses
it on seeds 1 to 5. The solution's step 3 sends oversize packets to every DST. On seed 1 the first
`a_O6` failure and the scoreboard's first error are in the same cycle:

```text
[62645000] %Error: router_sva.sv:55: Assertion failed in router_tb_top.dut.u_sva.u_out0.a_O6: O6: an output packet is longer than 8 beats
UVM_ERROR labs/lab-05-protocol-rules-and-backpressure/tb/router_env_pkg.sv(193) @ 62645000: uvm_test_top.env.sb [OUT] output 0: got a7 in cycle 6265, expected a7 last
```

Lab 04's scoreboard already queued the 8th beat of a forwarded packet with `last` set, but no Lab
04 test had sent one. The golden router passes with oversize packets on seeds 1 to 10.

## Side catches: B10 and B12

| Bug | First check in `router_test`, seed 1 | First assertion | How the page uses it |
|---|---|---|---|
| B10 | the scoreboard, `output 0: got 04 in cycle 56, expected 03`, in Lab 04's stall test (Lab 03's `close_holes()` reaches B10 too) | `u_out0.a_O2` at the edge that ends cycle 48 | Part 1 asks the student to predict the cycle the stalled beat `03` first changes; Part 2's `a_O2` confirms cycle 48, 8 cycles before the scoreboard; the two figures show cycles 45 to 58 |
| B12 | the scoreboard, `output 1: got 80 in cycle 24, and no beat was expected` (from Lab 04's stall test) | `u_out1.a_O6` at the edge that ends cycle 64; the run stops at 50 errors in cycle 73 | Part 2 asks why O6, not O1 or O2, fires: output 1 is always ready in phase 1, so its held beat is taken again and again. Part 4 runs B12 on `router_lab05_test`, which stalls output 1 first: `u_out1.a_O2` fails in cycle 40 and the scoreboard only in cycle 361. Finishing question 1 is about O7 |

Part 3's sink catches no new bug, and the page says so: `router_test` keeps its sinks in Lab 04's
`SNK_PCT` mode, so its stimulus doesn't change. On `router_sink_test` the sinks fill `short_wait`
(305 packets on seed 1, against 2 in all of `router_test`).

## Differences from the first Lab 05

- No reset step. Lab 04 resets once at time 0 and its scoreboard doesn't flush on a reset, and a
  reset with beats waiting would reach B15 (Lab 07's).
- No `STATUS` or `LEVEL` reads: the scoreboard checks only `DROP_CNT`.
- The route moves are kept. The scoreboard stamps each APB write with its cycle and applies a route
  write only to headers in later cycles, as the specification's Routing section says. Golden
  `router_test` and `router_lab05_test` pass on seeds 1 to 10 with the moves in.
- `cg_wait` is fed by the output monitors, which stamp each beat with its wait, through
  `router_wait_coverage`.
- The sink's driver keeps Lab 04's coin flip as its default mode, `SNK_PCT`, so `router_stall_test`'s
  5% and 100% mean what they meant. `close_holes()` stalls output 0 with `ready_pct = 0`, which
  only `SNK_PCT` reads, so `router_sink_test` switches back to `SNK_PCT` for it.
- `router_test` makes its virtual sequence after `router_inject_test`'s steps. Making an object
  draws from the random state of the thread that makes it: with the sequence made first, seed 1's
  first phase got the routing table `0-11` instead of Lab 04's `011-`, and every count after it
  changed.

## Files for Lab 06's starter

`tb/` with the three files above copied in, which makes eight files: `router_ifs.sv`,
`router_agents_pkg.sv`, `router_env_pkg.sv`, `router_vseq_pkg.sv`, `router_tests_pkg.sv`,
`router_sva.sv`, `router_sva_bind.sv` and `router_tb_top.sv`; then `Makefile` and `src/loc.py`.

Registers are still reached by raw APB (`apb_rw_seq`, the base test's `write_reg` and `read_reg`,
the virtual sequence's `wr` and `rd`), the scoreboard still checks only `DROP_CNT` and the output
beats, `irq` is wired in the top module and read by nothing, and there is no reset driver.
