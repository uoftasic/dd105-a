# Lab 04: reference solution

Open this after `make check-all` prints `2 of 2 caught.` with your own tests.

| File | What it is |
|---|---|
| `router_env_pkg.sv` | `tb/router_env_pkg.sv` with the Part 2 and Part 3 TODOs filled in |
| `router_tests_pkg.sv` | `tb/router_tests_pkg.sv` with the Part 3 and Part 4 TODOs filled in |

Compare them with the shipped files:

```bash
diff tb/router_env_pkg.sv solutions/router_env_pkg.sv
diff tb/router_tests_pkg.sv solutions/router_tests_pkg.sv
```

To run the solution, keep copies of your own files outside `tb/` and put the solution in their
place:

```bash
mkdir -p mine && cp tb/router_env_pkg.sv tb/router_tests_pkg.sv mine/
cp solutions/router_env_pkg.sv solutions/router_tests_pkg.sv tb/
make check-all
cp mine/* tb/
```

On 2 CPUs, swapping the solution into a starter build rebuilt in 111 s, with a ccache that held no
build of the solution, and swapping the starter files back took 15 s. Done one part at a time, the
edits rebuilt in 30 s and 31 s (Part 2), 105 s and 32 s (Part 3) and 105 s (Part 4).

## What changed

| Part | Where | Change |
|---|---|---|
| 2 | `router_env::build_phase`, `connect_phase` | `out[1]` made as `"out1"` and its monitor connected to `sb.out_export` |
| 2 | `router_scoreboard::write_in` | every forwarded beat queued on `expected[in_port]`, not only output 0's |
| 3 | `router_scoreboard::level` | the `if (p == 1) return 0;` that took output 1's level as 0, as Lab 03's tracker did, removed |
| 3 | `router_stall_test` | `set_sinks(k)`: output 0 ready in 5% of cycles in phases 1 and 3, output 1 in phases 2 and 4, the other output in 100% |
| 4 | `router_noroute_pkt` | a `router_pkt` whose `c_dst` (same name, so it replaces the parent's) sends one packet in four to a disabled route |
| 4 | `router_inject_test` | `router_pkt::type_id::set_type_override(router_noroute_pkt::get_type())` before `super.build_phase` |

## Results

Measured on the course image with 2 CPUs and 3 GB, `router_inject_test`:

| Run | Result |
|---|---|
| `make check-all`, seeds 1 to 5 | golden `ok`; B06 caught with 50 `UVM_ERROR`s and B13 with 50, on every seed; `2 of 2 caught.` |
| `make check` and `make check BUG=B13` | `VERDICT: PASS` |
| `make seeds SEEDS="1 2 3 4 5"` | `5 ok  (5 runs)`, 1.6 to 1.7 s a run |
| `make regress SEEDS="1 2 3 4 5"` | `25 ok  (25 runs)`, `covergroup : 82.9% (34/41)` |

The seven bins the regression leaves empty are the ones the specification rules out: a FULL drop
happens only at a level of 9 or more (`full_x_empty`, `full_x_low`, `full_x_at_8`), and a packet is
admitted only at 8 or less (`out0_x_at_9`, `out0_x_high`, `out1_x_at_9`, `out1_x_high`). The
starter's `make seeds SEEDS="1 2 3 4 5"` (`router_inject_test` alone) hits 26 of 41, and among the
bins it leaves empty are `cp_fate.full`, `full_x_at_9`, `full_x_high`, `out1_x_low` and
`out1_x_at_8`.

Against the whole catalogue (`make check-all BUG_LIST="B01 B02 ... B15"`, seed 1), with the golden
router `ok` both times:

| Bug | Starter | Solution |
|---|---|---|
| B01 to B04 | MISSED | MISSED |
| B05 | caught, 50 `UVM_ERROR`s | caught, 50 |
| B06 | MISSED (seeds 1 to 5) | caught, 50 |
| B07 | caught, 1 | caught, 3 |
| B08 | caught, 2 | caught, 50 |
| B09 | caught, 50 | caught, 50 |
| B10 | caught, 2 | caught, 50 |
| B11 | MISSED | MISSED |
| B12 | MISSED | caught, 50 |
| B13 | MISSED (seeds 1 to 5) | caught, 50 |
| B14, B15 | MISSED | MISSED |
| total | `5 of 15 caught.` | `8 of 15 caught.` |

The starter's column matches Lab 03's solution, which also catches B05, B07, B08, B09 and B10.
B07 rises from 1 error to 3 because the stall test's phases 1 and 3 hold output 0 above 8 while
`router_noroute_pkt` sends packets to disabled routes whose `PORT` is 0, so the `DROP_CNT` reads
after those phases fail as well as the one after `close_holes()`:

```text
[DROP_CNT] read 00004431, expected 00002031 (FULL_CNT 32, NOROUTE_CNT 49)
[DROP_CNT] read 00008d2c, expected 0000642c (FULL_CNT 100, NOROUTE_CNT 44)
[DROP_CNT] read 00000101, expected 00000001 (FULL_CNT 0, NOROUTE_CNT 1)
```

## Side catches

| Bug | Owner | Caught by | The solution's first error, seed 1 |
|---|---|---|---|
| B10 | Lab 05 | the starter already (Lab 03's `close_holes()` stalls output 0 with beats in it), and the stall test | `output 0: got 04 in cycle 56, expected 03` |
| B12 | Lab 05 | the stall test: output 1 carries traffic while the two `out_ready` signals differ | `output 1: got 80 in cycle 24, and no beat was expected`, then `got 80 in cycle 25, expected 14 last` and `got 80 in cycle 26` |

Lab 04's page mentions neither. Lab 05 starts from this testbench, which already catches both,
and has you write the assertions that show the cycle in which the router goes wrong. Under B12 output 1's buffer moves on
`out0_ready`, which is 1 in 5% of cycles in phase 1, while output 1's sink is always ready, so
output 1 holds the beat `80` and its monitor reports it again in each of cycles 24, 25 and 26.

We tried to keep B12 out of the solution, with a probe build that changed only the stall test. On
seeds 1 to 5, `make check-all BUG_LIST="B06 B12 B13 B10"`:

| Stall test | B12 | B06, B13, B10 | Seed 1 stall test, golden |
|---|---|---|---|
| as shipped: Lab 03's random routes, the stalled output ready in 5% of cycles and the other in 100% | caught on every seed; on seed 1 first in phase 1, cycle 24 | caught | 373 FULL of 805 packets; 1741 beats checked |
| every enabled route to the stalled output, the other output idle (5% and 100%) | caught on every seed; on seed 1 first in phase 2: `output 1: got 2b in cycle 1701, expected 88` | caught | 713 FULL; 352 beats checked |
| the same routes, both sinks at 0% | MISSED on every seed | caught (B06 with 35 to 50 errors, B10 with 12) | 790 FULL; 52 beats checked |

Keeping the other output idle doesn't keep B12 out: in phases 2 and 4 output 1 is stalled with
traffic while `out0_ready` is 1. Each `out_ready_driver` flips its own coin every cycle, so the
two signals stay equal only when both sinks are at 0% or both at 100%. With both stalled, the
stall test drops nearly every packet as FULL and checks 52 beats instead of 1741, and Part 3 would
have to ask for a stalled sink on an output that gets no packets. So the solution keeps the side
catch.

## `close_holes()` and the factory

`close_holes()` makes its two random packets with `new()` (`new_packet()` in the base test), not
through the factory. In a build that made them through the factory, `router_inject_test`'s
override reached them, and `randomize()` failed for the DST 1 packet (`UVM_FATAL [RAND]`) on 4 of
5 seeds. Switching `c_dst` off with `p.c_dst.constraint_mode(0)` through the `router_pkt` handle
left `router_noroute_pkt`'s own `c_dst` on in those runs, so when `to_disabled` was 0 the packet
had to go to an enabled route, and DST 1 was disabled.

## The `DROP_CNT` reads that later labs keep

`router_rand_test` reads `DROP_CNT` after each phase and after `close_holes()`, as Lab 03's test
did, and writes it to clear it after each phase. B07 changes only `FULL_CNT` and `STATUS.FULL`,
and `DROP_CNT` is the only register this testbench reads, so these reads are the only checks that
see it; the read after `close_holes()` is the one that catches it in
`router_rand_test`. The scoreboard expects `00000001` there.

Lab 05's starter is this lab's `tb/` with these two files copied in.
