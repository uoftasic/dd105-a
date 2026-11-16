# Verification plan: the packet router

The reference solution's plan, filled in for the environment in `solutions/`: the lab folder's
`tb/` with the two files in `solutions/tb/`. Every row names a check, a sequence and a bin that
exist in that environment, and the numbers in the sign-off criteria come from the runs in
`solutions/README.md`.

Design: the packet router, `labs/common/rtl/` (top module `router`)  
Specification: `docs/reference/router-spec.md`  
Environment: `labs/lab-07-capstone/` with `solutions/tb/`

## Scope

This plan covers what the specification says happens at the router's pins: the input stream,
both outputs, the APB port, every register, the interrupt and reset. It leaves out what the
specification doesn't describe (the state before the first reset, the values on `out_data` and
`out_last` while `out_valid` is 0) and anything below the pins. The simulator has two states, so
nothing here says anything about X.

## How the environment checks

| Checker | What it compares | Where |
|---|---|---|
| Scoreboard | Decides each packet's fate at its header from the routing table it has seen written and the levels it has counted, then checks every output beat against the next one it expects on that output, in order. It keeps `STATUS` and `INT_EN` cycle by cycle and checks `irq` in every cycle and every `STATUS` read; it checks `DROP_CNT` reads, `pslverr` on every transfer and the data of bad reads. At a reset it throws all of that away and starts again from the reset values. | `router_scoreboard` (`write_in`, `write_out`, `write_apb`, `write_sys`) in `tb/router_env_pkg.sv` |
| Register model | Checks every read of `ID`, `CTRL`, `INT_EN` and `ROUTE0` to `ROUTE3` against its mirror, which the predictor keeps from the APB monitor. The other three registers are volatile; the scoreboard checks `STATUS` and `DROP_CNT`, and nothing checks `LEVEL`. | `tb/router_ral_pkg.sv`; the predictor and `set_check_on_read(1)` in `router_env` |
| Assertions | One property per rule below, bound into the router, each with a failure counter that the scoreboard reports: I1, I2, I7, O1, O2, O4, O6, the first half of A4, and the Reset table's values. | `solutions/tb/router_sva.sv` |

## The rules

The `I`, `O` and `A` ids are the specification's own; the others are this plan's labels.

### Input stream

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| I1, I2 | (source) `in_valid` holds until the handshake; `in_data` and `in_last` hold while it waits | `a_I1`, `a_I2`, which check the source driver, not the router | a beat waits only while `in_ready` is 0, between packets with `CTRL.EN` at 0 or in a reset: `router_reset_vseq` offers three headers after the E8 reset, before `setup()` opens the input | no bin | done |
| I3 | (source) after a reset the first beat offered is a header | the source driver abandons its packet at a reset (`src_driver`); nothing checks it, because the router would take a stale beat as a header and so would the scoreboard | `router_reset_vseq` (E8), the resets in `router_lab07_vseq`'s phases | `cg_corner.reset_mid_packet` | done |
| I4 | `in_ready` doesn't depend on `in_valid`, `in_data` or `in_last` in the same cycle | nothing | | no bin | gap: open item 1 |
| I5 | between packets, `in_ready` equals `CTRL.EN` | nothing: the scoreboard models what the router takes, not when it is ready | | no bin | gap: open item 1 |
| I6 | from a packet's first handshake to its last, `in_ready` is 1 | nothing | | no bin | gap: open item 1 |
| I7 | `in_ready` is 0 while `rst_n` is 0 | `a_I7` | every reset, the one at time 0 included; `router_reset_vseq` resets with a beat on offer | no bin | done |

### Outputs

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| O1 | `out_valid` holds until the handshake | `a_O1` on each output | every stalled or slow sink: `router_inject_test`'s phases, and `backpressure()` in `router_lab05_vseq` and `router_lab07_vseq` | `cg_wait.x_port_wait`: `long_wait` and `stalled` on both outputs | done |
| O2 | `out_data` and `out_last` hold while the beat waits | `a_O2` on each output, and the scoreboard's data check | the same | the same | done |
| O3 | the outputs don't depend on `out_ready` or any other input in the same cycle | nothing | | no bin | gap: open item 1 |
| O4 | `out_valid` is 0 during reset, and stays 0 until a beat accepted after it arrives | `a_O4_rst`, `a_O4_after`, and the scoreboard (a beat when none is expected) | `router_reset_vseq`, E8: a reset with a beat waiting on a stalled output | `cg_corner.reset_with_beats` | done |
| O5 | beats come out in order, unchanged, never interleaved | the scoreboard compares every beat with the next one it expects on that output | every run | `cg_pkt.x_fate_level`, `out0` and `out1` at every level up to 8 | done |
| O6 | every output packet is 1 to 8 beats and ends with its only `out_last` | `a_O6`, and the scoreboard's expected `out_last` | `router_lab05_vseq`, step 3 (9 to 20 beats), and oversize packets in the random phases | `cg_pkt.cp_len.oversize` | done |
| O7 | each output depends only on its own `out_ready` | the scoreboard checks each output on its own; `a_O1` and `a_O2` on each output | `router_inject_test`'s phases stall one output at a time; `backpressure()` sets each sink's mode on its own | `cg_wait.x_port_wait` (doesn't show the two outputs disagreeing) | done |
| O8 | beat $k$ is on the pins from cycle $\max(t_k + 2, h_{k-1} + 1)$ until it's taken | nothing: the scoreboard checks the order and the data of the beats, not the cycle each one appears | | no bin | gap: open item 1 |

### Routing, drops and oversize packets

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| RT1 | the decision table: `EN` = 0 is NOROUTE, a level of 9 to 16 is FULL, 0 to 8 is written to output `PORT` | the scoreboard: `write_in` decides each packet's fate at its header, and `write_out`, `write_apb` and `write_sys` check the beats, the `DROP_CNT` and `STATUS` reads and `irq` against it | `router_inject_test`'s phases: random routing tables, packets to disabled routes, one output stalled | `cg_pkt.x_fate_level`: every fate at every level the specification allows | done |
| RT2 | the threshold itself: admitted at exactly 8, dropped at exactly 9 | the scoreboard's `level()` at each header | `close_holes()` fills output 0 to exactly 8; `router_saturate_vseq` fills it to 9 | `cg_pkt.x_fate_level`: `out0` at `at_8`, `full` at `at_9` | done |
| RT3 | a disabled route is NOROUTE whatever its `PORT`'s level, never FULL | the scoreboard | `close_holes()`: `DST` 1 disabled with `PORT` 0 while output 0 holds more than 8 | `cg_pkt.x_fate_level`: `noroute` at `at_9` or `high` | done |
| RT4 | a `ROUTE` or `CTRL` write affects headers from the cycle after it completes | the scoreboard applies a route write only to headers in later cycles (`pending`); nothing models `CTRL.EN` | `router_lab05_vseq`, step 4, and `random_config()` in the phases move routes while packets go in | no bin | done for `ROUTE`; gap for `CTRL`, open item 2 |
| RT5 | a dropped packet is still taken: `in_ready` stays 1 for all its beats | nothing checks `in_ready`; a dropped packet that stalled would only slow the source down | every multi-beat drop | `cg_pkt.x_fate_level`, `noroute` and `full` | gap: open item 1 |
| DR1 | a drop adds one to its counter and sets its `STATUS` bit, visible from the next cycle | the scoreboard: `DROP_CNT` reads between packets, `STATUS` reads, and `irq` every cycle | every drop | `cg_pkt.cp_fate`: `noroute` and `full` | done |
| DR2 | each counter stops at 255 | the scoreboard compares every `DROP_CNT` read with its counts, saturated at 255 | `router_saturate_vseq`: 260 NOROUTE drops and 261 FULL drops, read at 250, 254, 255 and 260 | `cg_corner.noroute_saturated`, `full_saturated` | done |
| OV1 | an oversize packet goes out cut to 8 beats, the 8th with `out_last`, and sets `STATUS.OVERSIZE` once | the scoreboard; `a_O6` | `router_lab05_vseq`, step 3; `router_lab06_vseq`, Part 5 | `cg_pkt.cp_len.oversize` | done |
| OV2 | an oversize packet that is also dropped counts as one drop and sets `OVERSIZE` too | the scoreboard (`OVERSIZE` at the 8th beat whatever the fate) | nothing aims at it; oversize packets go in among the random ones in `router_lab05_vseq`, step 4, and `router_lab07_vseq`'s phases while outputs stall and routes are disabled | no bin: `cg_pkt` doesn't cross length with fate | open: item 6 |
| EN1 | `CTRL.EN` stops and starts the input only between packets (E7), and doesn't affect the outputs | nothing | nothing clears `CTRL.EN` while packets go in | no bin | gap: open item 2 |

### APB and registers

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| A1, A2, A3 | (master) setup then access; address and data hold; `penable` is 0 after a transfer | nothing | every transfer | no bin | gap: open item 3 |
| A4 | (master) `psel` is 0 during reset; a transfer cut by reset has no effect | `a_A4`, which checks the APB driver; the scoreboard and the mirror check the reads after the reset | `router_reset_vseq`: a reset in the second read of a loop of reads and writes, which the APB driver abandons and starts again | no bin | done |
| A5, A6 | a write's first access cycle has `pready` 1; a read's has `pready` 0, then 1; nowhere else is it 0 | nothing; the APB driver waits for `pready` whenever it comes | every transfer | no bin | gap: open item 3 |
| A7 | `pslverr` is 1 exactly when a transfer to a bad address completes | the scoreboard: `write_apb` compares `pslverr` with the address at every completion; nothing looks at `pslverr` in the other cycles | `router_lab06_vseq`, Part 4: every bad address read and written | no bin | done for the completions; gap for the other cycles, open item 3 |
| A8 | a read returns the value in its first access cycle; `prdata` changes only then | the mirror and the scoreboard check what each read returns (`STATUS` as it was in the first access cycle); nothing checks when `prdata` changes | every read | no bin | done for the value; gap for the timing, open item 3 |
| A9 | each write takes effect by its field's access type; a bad write changes nothing | the mirror (the `RW` fields) and the scoreboard (`STATUS` and `DROP_CNT`) | the bit bash, and `router_lab06_vseq`'s writes to every bad address | no bin | done |
| RG1 | every register's reset value | `uvm_reg_hw_reset_seq` against the mirror (`ID`, `CTRL`, `INT_EN`, `ROUTEn`); the scoreboard for `STATUS` and `DROP_CNT`; nothing for `LEVEL` | `router_lab06_vseq`, Part 2, after the reset at time 0; `rd_all_regs()` after the E8 reset in `router_reset_vseq` | no bin | done except `LEVEL` |
| RG2 | `STATUS` is write-1-to-clear per bit, and an event in the clearing cycle wins | the scoreboard's cycle-by-cycle model of `STATUS` | `router_lab06_vseq`, Part 5 clears one bit at a time; nothing aims a clear at the cycle of an event | no bin | done for the clear; open for the same cycle, item 4 |
| RG3 | any write clears `DROP_CNT`; a drop in the same cycle is counted after the clear (E9) | the scoreboard clears its counts at the write; its check is right only between packets, so it can't follow E9 | every random phase ends with a clear; `router_saturate_vseq` writes `12345678` | no bin | done for the clear; gap for E9, open item 4 |
| RG4 | `LEVEL` reads both levels, and a beat accepted in the read's first access cycle isn't in it | nothing | `rd_all_regs()` reads it | no bin | gap: open item 5 |
| RG5 | bits that aren't fields read 0 and ignore writes; `ID` and `LEVEL` ignore writes | the bit bash against the mirror | `router_lab06_vseq`, Part 3 | no bin | done |
| IRQ1 | `irq` is the OR of `STATUS & INT_EN`, in the same cycle as the bit that changes it | the scoreboard, every cycle | `router_lab06_vseq`, Part 5 (each enable alone, then all three); random `INT_EN` in `router_lab07_vseq`'s phases | no bin | done |

### Reset

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| RS1 | the Reset table's values while `rst_n` is 0: `pready` 1, `pslverr` 0, `prdata` 0, `irq` 0 | `a_R_pready`, `a_R_pslverr`, `a_R_prdata`, `a_R_irq`; the scoreboard checks `irq` too | every reset | no bin | done |
| RS2 | a reset with beats in a buffer loses them, a waiting beat included, and nothing from before it comes out (E8) | the scoreboard (`reset_model()` empties both queues, so a beat after that has nothing to match), `a_O4_rst`, `a_O4_after` | `router_reset_vseq`; the resets in the random phases | `cg_corner.reset_with_beats` | done |
| RS3 | a reset in the middle of an input packet discards it, and the next beat accepted is a header | the scoreboard (`reset_model()` sets `in_beats` to 0) | `router_reset_vseq`, E8 | `cg_corner.reset_mid_packet` | done |

## Sign-off criteria

- `make regress` prints `130 ok  (130 runs)`: all 13 tests pass on seeds 1 to 10.
- The same run prints `covergroup : 88.3% (53/60)`, and the seven bins it never hits are the
  seven of `x_fate_level` that the specification rules out.
- `make check-all` prints `15 of 15 caught.` with the golden router `ok`, on seeds 1 to 5.
- Every row above is `done`, or its gap is written down under Open items.

## Open items

1. Nothing checks `in_ready` (I4, I5, I6, RT5), and nothing checks the cycle a beat appears or
   that the outputs come from flip-flops (O3, O8). Assertions for I5 and I6, with the `CTRL.EN`
   written over APB kept beside them, and a scoreboard check of each beat's first cycle against
   O8's formula would close them.
2. The scoreboard doesn't model `CTRL.EN` (RT4 for `CTRL`, EN1), and no sequence clears it while
   packets go in (example E7).
3. Nothing checks the APB rules A1 to A3, A5 and A6, or `pslverr` and `prdata` outside the
   cycles they are read (A7, A8). Each is a one- or two-cycle property, so they belong in
   `router_sva.sv`.
4. The same-cycle cases of `STATUS` and `DROP_CNT` (RG2, RG3, example E9) need a scoreboard that
   applies a `DROP_CNT` write at its cycle, as it does `STATUS` writes, and sequences that aim a
   write at the cycle of a drop.
5. Nothing checks `LEVEL` (RG4, and RG1's `LEVEL` row). The scoreboard already counts each
   output's level for its FULL decisions, so a check of `LEVEL` reads against those counts, as of
   the read's first access cycle, would close it.
6. Nothing shows that an oversize packet was ever dropped (OV2). A cross of `cp_len` with
   `cp_fate` in `cg_pkt` would.
