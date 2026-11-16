# Verification report: the packet router

An example of the report Part 8 asks for, written for the reference solution. Every number in it
comes from the runs in `solutions/README.md`. The hunt rows are three deals from those runs. The
first was dealt on the starter; the second was dealt with `make new BUGPICK=B15`, once on the
starter and once on the finished environment, which is what keeping it sealed through Parts 5 and
6 would have given; the third was a random deal on the finished environment.

Design: the packet router, `labs/common/rtl/`  
Specification: `docs/reference/router-spec.md`  
Plan: [`PLAN.md`](PLAN.md)  
Environment: `labs/lab-07-capstone/` with `solutions/tb/`

## 1. Summary

The router was verified against the 39 rows of `PLAN.md` with a UVM environment that checks it
three ways: a scoreboard, the register model's mirror, and assertions bound into the design. All
13 tests pass on seeds 1 to 10, 53 of the 60 coverage bins are hit and the other seven are ones
the specification rules out, and the graded test catches all 15 planted bugs on seeds 1 to 5.
That meets every sign-off criterion in the plan. The plan's open items are the larger part of
this report, though: 10 of its rows have no checker at all in this environment, and section 7
lists them.

## 2. The environment

| Component | What it does | File | Written in this lab? |
|---|---|---|---|
| Source agent | drives packets with idle cycles; abandons its packet at a reset (rule I3) | `tb/router_agents_pkg.sv` | no |
| Output agents, one per output | a reactive sink: always ready, slow, random or stalled, set while the test runs | `tb/router_agents_pkg.sv` | no |
| APB agent | drives one transfer at a time; keeps `psel` at 0 during a reset and starts an interrupted transfer again (rule A4); its monitor reports each completed transfer | `tb/router_agents_pkg.sv` | no |
| Sys agent | drives the reset; its monitor reports `rst_n` and `irq` every cycle | `tb/router_agents_pkg.sv` | no |
| Register model | the ten registers, with an adapter and a predictor on the APB monitor; checks reads of the non-volatile ones | `tb/router_ral_pkg.sv` | no |
| Scoreboard | predicts each packet's fate and checks every output beat in order; models `STATUS` and `INT_EN` cycle by cycle and checks `irq`, `STATUS` and `DROP_CNT` reads, `pslverr`, and bad reads; starts again from the reset values at a reset | `tb/router_env_pkg.sv` | no |
| Coverage | packets by length, `DST`, fate and level; how long output beats wait; four corners the scoreboard counts | `tb/router_env_pkg.sv` | no |
| Assertions | I1, I2, O1, O2, O6, and the rules about reset | `tb/router_sva.sv` | the reset rules: I7, O4, A4, the reset values |
| Sequences | Lab 05's and Lab 06's, `router_reset_vseq`, `router_saturate_vseq`, and `router_lab07_vseq`'s random phases | `tb/router_vseq_pkg.sv` | `router_reset_vseq`, `router_saturate_vseq`, the resets in the random phases |
| Tests | `router_test` is the graded one; one test per sequence, and Labs 02 to 04's tests | `tb/router_tests_pkg.sv` | no |

## 3. The plan's status

The plan has 39 rows. 22 are `done`. Six are done in part: RT4 (route writes are followed, `CTRL`
isn't), A7 and A8 (the value at each completion is checked, the other cycles aren't), RG1 (every
register but `LEVEL`), and RG2 and RG3 (the clears are checked, the same-cycle cases aren't).
Ten rows have no checker: I4, I5, I6, O3, O8, RT5, EN1, A1 to A3, A5 and A6, and RG4. OV2 has a
checker but no sign that it was ever made to happen. Each of these is an open item in the plan.
Of the rows that are done, I1, I2, I7, A4, A9, RG5, IRQ1 and RS1 have no coverage bin; for each,
the plan names the sequence that makes it happen instead.

## 4. Regression

`make regress` in `solutions/`: 13 tests on seeds 1 to 10, 4 min 26 s of wall clock.

```text
  130 ok  (130 runs)
```

The first build of `solutions/`, with an empty ccache, took 143 s; the lab folder's first build,
also with an empty one, took 130 s.

## 5. Coverage

```text
 verilator_coverage: covergroup : 88.3% (53/60)
```

The seven bins never hit are `full_x_at_8`, `full_x_empty`, `full_x_low`, `out0_x_at_9`,
`out0_x_high`, `out1_x_at_9` and `out1_x_high` in `cg_pkt.x_fate_level`. The specification rules
all seven out: a packet is FULL only at a level of 9 or more, and written to an output only at 8
or less.

Before this lab's work, the same regression with 11 tests hit 49 of the 60. The four it missed
were the bins of `cg_corner`: `noroute_saturated` and `full_saturated`, now hit by
`router_saturate_vseq` (5 times each on seed 1), and `reset_with_beats` and `reset_mid_packet`,
now hit by `router_reset_vseq` (3 times and once in `router_reset_test` on seed 1).

Coverage numbers from Verilator 5.050 don't follow the standard's formula (type-level
`get_coverage()` returns 0, `ignore_bins` stay in the denominator, `option.weight` is ignored),
so this report counts bins from `coverage.dat`, whose per-bin counts are right.

## 6. Bugs

### Mystery hunts

| Deal | The first check that fired (copied) | Diagnosis | Verdict | Which sequence made it show |
|---|---|---|---|---|
| 1 | `UVM_ERROR [IRQ] irq is 1 from cycle 5909, but STATUS = 001 and INT_EN = 000 make it 0` | IRQ1: `irq` is raised by a `STATUS` bit whose enable is 0, so the mask is missing; `router_regs.sv` | B02_irq_ignores_int_en | `router_lab06_vseq`, its `STATUS` step, which drops a packet while `INT_EN` is 0 |
| 2 | none on the starter, where `make hunt` printed `quiet` and `0 UVM_ERROR, 0 UVM_FATAL`. On the finished environment: `UVM_ERROR [OUT] output 0: got 00 in cycle 14873, and no beat was expected` | quiet while the plan's rows RS2, RS3 and DR2 had no stimulus and I7, O4 and A4 no assertion; on the finished environment, a beat from before a reset delivered after it: RS2 and O4, `router_fifo.sv` | B15_output_valid_survives_reset | `router_reset_vseq`, example E8 |
| 3 | `UVM_ERROR [STATUS] a read of 08, completing in cycle 5947 returned 00000005; it should return 00000007, STATUS in cycle 5946`; in the log (`make hunt VERBOSE=1`), `a_O2` had failed first, at 59285000 ps: `O2: out_data or out_last changed while the beat waited` | O2: a beat on a stalled output changed before it was taken, so beats were lost and the levels behind the FULL decisions went wrong; `router_fifo.sv` | B10_output_reloads_while_stalled | `router_lab06_vseq`, its `STATUS` step, which stalls output 0 |

### The catalogue

`make check-all` printed `15 of 15 caught.` on each of seeds 1 to 5, with the golden design `ok`.
Seed 1:

```text
      ok  the golden design                        0 UVM_ERROR, 0 UVM_FATAL        7.8s
------------------------------------------------------------------------
  caught  tier 6  B15_output_valid_survives_reset  50 UVM_ERROR, 45 assertions     6.8s
  caught  tier 1  B01_status_write_clears_all      3 UVM_ERROR                     7.8s
  caught  tier 1  B02_irq_ignores_int_en           6 UVM_ERROR                     7.8s
  caught  tier 1  B03_route3_readback_swapped      5 UVM_ERROR                     7.8s
  caught  tier 1  B04_misaligned_address_accepted  50 UVM_ERROR                    1.3s
  caught  tier 2  B05_dst_field_off_by_one         50 UVM_ERROR                    1.7s
  caught  tier 2  B06_disabled_route_forwards      50 UVM_ERROR                    1.9s
  caught  tier 2  B07_full_counted_on_disabled_route 6 UVM_ERROR                     7.9s
  caught  tier 3  B08_admission_off_by_one         50 UVM_ERROR                    1.9s
  caught  tier 3  B09_write_pointer_power_of_two   50 UVM_ERROR                    1.7s
  caught  tier 4  B10_output_reloads_while_stalled 50 UVM_ERROR, 256 assertions    1.9s
  caught  tier 4  B11_cut_packet_has_no_last       48 UVM_ERROR, 45 assertions     7.8s
  caught  tier 5  B12_out1_uses_out0_ready         50 UVM_ERROR, 3 assertions      1.6s
  caught  tier 5  B13_admission_checks_other_output 50 UVM_ERROR, 1 assertion       1.8s
  caught  tier 6  B14_enable_resets_to_one         4 UVM_ERROR, 23 assertions      7.8s
------------------------------------------------------------------------
 15 of 15 caught.
```

## 7. What this doesn't show

- Ten rows have no checker (section 3). A router whose `in_ready` ignored `CTRL.EN` between
  packets, whose beats came out a cycle late, or whose `LEVEL` read wrong would pass every test
  here, unless the fault happened to change something a check does look at.
- The scoreboard checks a `DROP_CNT` read correctly only while no packet is coming in, so the
  tests read `DROP_CNT` only between bursts, and example E9, a clear in the cycle of a drop, is
  never tried.
- The simulator has two states, so nothing here says anything about X: an uninitialized register
  starts at 0 on Verilator, and the specification says not to rely on it.
- The regression ran seeds 1 to 10 and the catalogue seeds 1 to 5. B15 was caught on every one of
  those five, with as few as 5 UVM_ERRORs and 23 assertion failures (seed 3), all from the same
  directed E8 step, so a reset sequence without that step could miss it.
- Catching the 15 planted bugs shows the environment finds those 15. A bug unlike all of them, in
  a rule the plan has no checker for, would go unseen.
- `router_test` never uses the register model's back door. Lab 06 measured that a poke of
  `CTRL`, `INT_EN` or `DROP_CNT` sticks on this router, but no check here depends on it.

## 8. Sign-off

This router follows its specification at its pins in every situation the plan's rows describe and
has a checker for, on seeds 1 to 10 of 13 tests; the rows without a checker are listed in the
plan's open items and in section 7. To check it:

```bash
cd labs/lab-07-capstone/solutions
make regress          # 130 ok  (130 runs), covergroup : 88.3% (53/60)
make check-all        # 15 of 15 caught.  (and SEED=2 to SEED=5)
```
