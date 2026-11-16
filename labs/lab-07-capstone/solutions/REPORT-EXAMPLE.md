# Verification report: the packet router

An example of the report Part 8 asks for, written for the reference solution. Every number in it
comes from the runs in `solutions/README.md`. The hunt rows are three deals from those runs; the
second was dealt with `make new BUGPICK=B15`, once on the starter and once on the finished
environment, which is what keeping it sealed through Parts 5 and 6 would have given.

Design: the packet router, `labs/common/rtl/`  
Specification: `docs/reference/router-spec.md`  
Plan: [`PLAN.md`](PLAN.md)  
Environment: `labs/lab-07-capstone/` with `solutions/tb/`

## 1. Summary

The router was verified against the 39 rows of `PLAN.md` with a UVM environment that checks it
three ways: a cycle-exact scoreboard, the register model's mirror, and assertions bound into the
design. All 11 tests pass on seeds 1 to 10, every one of the 145 coverage bins is hit, and the
graded test catches all 15 planted bugs on seeds 1 to 5. That meets every sign-off criterion in
the plan. Two rows (I4 and O3) are checked only through the model's predictions, and one (RT3) has
no coverage bin.

## 2. The environment

| Component | What it does | File | Written in this lab? |
|---|---|---|---|
| APB agent | drives transfers, back to back when asked; its monitor reports each completed transfer | `tb/apb_pkg.sv` | no |
| Source agent | drives packets with idle cycles; drops its packet at reset (rule I3) | `tb/stream_pkg.sv` | no |
| Sink agents, one per output | reactive: fast, slow, random or stalled, set while the test runs | `tb/stream_pkg.sv` | no |
| Reset/irq agent | drives `rst_n`; samples `rst_n` and `irq` every cycle | `tb/router_env_pkg.sv` | no |
| Register model | the ten registers, with an adapter and an explicit predictor; checks reads of the non-volatile ones | `tb/router_ral_pkg.sv` | no |
| Scoreboard | runs a cycle-by-cycle model of the specification and checks every port against it | `tb/router_env_pkg.sv` | no |
| Coverage | packets, APB transfers, output waits, and 17 corners the scoreboard sees | `tb/router_env_pkg.sv` | no |
| Assertions | one per interface rule, with a failure counter each | `tb/router_sva.sv` | the reset rules: I7, O4, A4, the reset values |
| Sequences | one per section of the specification, a random one, and `router_all_vseq` | `tb/router_seq_pkg.sv` | `router_reset_vseq`, `router_saturate_vseq`, the random resets |
| Tests | one per sequence; `router_all_test` is the graded one | `tb/router_test_pkg.sv` | no |

## 3. The plan's status

The plan has 39 rows. All are `done`. Two are done only partly: I4 and O3 say that a signal doesn't
depend on an input in the same cycle, and they are checked only because the scoreboard predicts
those signals from earlier cycles; no check looks at them between rising edges. Row RT3 (a
disabled route is never FULL) has a check and a directed step but no bin, so only that step's
comment says the situation happened. Rows I1, I2, I4, I7, O3, A4, RG1, RG5 and RS1 have no bin
either; for each of them the plan names the sequence that makes it happen instead.

## 4. Regression

`make regress` in `solutions/`: 11 tests on seeds 1 to 10, 2 min 43 s of wall clock.

```text
  110 ok  (110 runs)
```

The simulator it used was built in 31 s with a warm ccache; the first build of the lab, with an
empty one, took 135 s.

## 5. Coverage

```text
 verilator_coverage: covergroup : 100.0% (145/145)
```

Before this lab's work the same regression, with 9 tests, hit 141 of the 145. The four it missed
were all in `cg_corner`: `C_NOROUTE_SATURATED` and `C_FULL_SATURATED`, now hit by
`router_saturate_vseq` (13 and 15 times on seed 1), and `C_RESET_WITH_BEATS` and
`C_RESET_MID_PACKET`, now hit by `router_reset_vseq` (3 and 2 times on seed 1).

Coverage numbers from Verilator 5.050 don't follow the standard's formula (type-level
`get_coverage()` returns 0, `ignore_bins` stay in the denominator, `option.weight` is ignored),
so this report counts bins from `coverage.dat`, whose per-bin counts are right.

## 6. Bugs

### Mystery hunts

| Deal | The first check that fired (copied) | Diagnosis | Verdict | Which sequence made it show |
|---|---|---|---|---|
| 1 | `UVM_ERROR [SB] irq is 1 from cycle 4436, but STATUS = 001 and INT_EN = 010 make it 0` | IRQ1: `irq` is raised by a `STATUS` bit whose enable is 0, so the mask is missing; `router_regs.sv` | B02_irq_ignores_int_en | `router_full_vseq`, which enables only the FULL interrupt |
| 2 | none on the starter, where `make hunt` printed `quiet` and `0 UVM_ERROR, 0 UVM_FATAL`. On the finished environment: `UVM_ERROR [SB] output 0 delivered 01 (offered from cycle 6988, taken in cycle 6989), but no beat was waiting for it there` | quiet while the plan's rows RS2, RS3 and DR2 had no stimulus and I7, O4 and A4 no assertion; on the finished environment, a beat from before a reset delivered after it: RS2 and O4, `router_fifo.sv` | B15_output_valid_survives_reset | `router_reset_vseq`, example E8 |
| 3 | `UVM_ERROR [SB] output 0 delivered 25 with out_last = 0 in cycle 347; it should be e4 with out_last = 0 (accepted in cycle 322)` | a packet the model admitted to output 0 never came out, so the router dropped it or sent it elsewhere: RT1 or RT2, the admission decision, `router_ingress.sv` | B08_admission_off_by_one | `router_smoke_vseq` |

### The catalogue

`make check-all` printed `15 of 15 caught.` on each of seeds 1 to 5, with the golden design `ok`.
Seed 1:

```text
      ok  the golden design                        0 UVM_ERROR, 0 UVM_FATAL        6.2s
------------------------------------------------------------------------
  caught  tier 1  B01_status_write_clears_all      17 UVM_ERROR                    6.3s
  caught  tier 1  B02_irq_ignores_int_en           22 UVM_ERROR                    6.2s
  caught  tier 1  B03_route3_readback_swapped      20 UVM_ERROR                    6.2s
  caught  tier 1  B04_misaligned_address_accepted  50 UVM_ERROR, 40 assertions     0.8s
  caught  tier 2  B05_dst_field_off_by_one         50 UVM_ERROR                    0.2s
  caught  tier 2  B06_disabled_route_forwards      50 UVM_ERROR                    0.3s
  caught  tier 2  B07_full_counted_on_disabled_route 33 UVM_ERROR                    6.3s
  caught  tier 3  B08_admission_off_by_one         50 UVM_ERROR                    5.1s
  caught  tier 3  B09_write_pointer_power_of_two   50 UVM_ERROR                    0.2s
  caught  tier 4  B10_output_reloads_while_stalled 50 UVM_ERROR, 35 assertions     0.2s
  caught  tier 4  B11_cut_packet_has_no_last       38 UVM_ERROR, 30 assertions     6.3s
  caught  tier 5  B12_out1_uses_out0_ready         50 UVM_ERROR, 28 assertions     3.0s
  caught  tier 5  B13_admission_checks_other_output 50 UVM_ERROR, 1 assertion       5.0s
  caught  tier 6  B14_enable_resets_to_one         25 UVM_ERROR, 1793 assertions    6.3s
  caught  tier 6  B15_output_valid_survives_reset  46 UVM_ERROR, 49 assertions     6.4s
------------------------------------------------------------------------
 15 of 15 caught.
```

## 7. What this doesn't show

- I4 and O3 are checked only through the model, as section 3 says. A router whose `in_ready` or
  `out_valid` depended on an input within a cycle would be caught only if the dependence changed
  a value at a sampling point.
- The simulator has two states, so nothing here says anything about X: an uninitialized register
  starts at 0 on Verilator, and the specification says not to rely on it.
- The regression ran seeds 1 to 10 and the catalogue seeds 1 to 5. B15 was caught on every one of
  those five, but with as few as 4 UVM_ERRORs on seeds 2, 4 and 5, so a weaker reset sequence
  could miss it on some seeds.
- Catching the 15 planted bugs shows the environment finds those 15. A bug unlike all of them, in
  a rule whose row says "no bin", would be found only if its checker happened to be shown it.
- Every register access in these tests goes through the APB port. The register model's back door
  isn't used, because on Verilator 5.050 a back-door write doesn't stick (back-door reads work).

## 8. Sign-off

This router follows its specification at its pins in every situation the 39 rows of the plan
describe, on seeds 1 to 10 of 11 tests, except that rules I4 and O3 are checked only through a
model's predictions. To check it:

```bash
cd labs/lab-07-capstone/solutions
make regress          # 110 ok  (110 runs), covergroup : 100.0% (145/145)
make check-all        # 15 of 15 caught.  (and SEED=2 to SEED=5)
```
