# Verification plan: the packet router

The reference solution's plan, filled in for the environment in `solutions/`. Every row names a
check, a sequence and a bin that exist in that environment; the numbers in "Status" come from the
runs in `solutions/README.md`.

Design: the packet router, `labs/common/rtl/` (top module `router`)  
Specification: `docs/reference/router-spec.md`  
Environment: `labs/lab-07-capstone/` with `solutions/tb/`

## Scope

This plan covers everything the specification says happens at the router's pins, cycle by cycle:
the input stream, both outputs, the APB port, every register, the interrupt and reset. It leaves
out what the specification doesn't describe (the state before the first reset, the values on
`out_data` and `out_last` while `out_valid` is 0) and anything below the pins. The simulator has
two states, so nothing here says anything about X.

## How the environment checks

| Checker | What it compares | Where |
|---|---|---|
| Scoreboard | Runs `router_model`, a cycle-by-cycle model written from the specification, on what the monitors saw. It predicts every output beat's data, `out_last` and the cycle it appears; `in_ready` in every cycle a beat is offered; `irq` in every cycle; `pslverr`; and every register read, as of the read's first access cycle. | `router_scoreboard` in `tb/router_env_pkg.sv` |
| Register model | Checks every read of `ID`, `CTRL`, `INT_EN` and `ROUTE0` to `ROUTE3` against its mirror. The other three registers are volatile, and the scoreboard checks them. | `router_ral_pkg.sv`, `set_check_on_read(1)` in `router_env` |
| Assertions | One property per interface rule, bound into the router, each with a failure counter that the scoreboard reports. | `solutions/tb/router_sva.sv` |

## The rules

The `I`, `O` and `A` ids are the specification's own; the others are this plan's labels.

### Input stream

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| I1, I2 | (source) `in_valid` holds until the handshake; `in_data` and `in_last` hold while it waits | `a_I1`, `a_I2`, which check the source driver, not the router | a beat waits only when `in_ready` is 0, which is between packets with `CTRL.EN` = 0: `router_ctrl_vseq` offers headers then | no bin: `cg_wait` samples the outputs only | done |
| I3 | (source) after a reset the first beat offered is a header | the source driver drops its packet at reset (`stream_src_driver`); nothing checks it, because the router would treat a stale beat as a header and so would the model | `router_reset_vseq`, a reset with a packet half accepted | `C_RESET_MID_PACKET` | done |
| I4 | `in_ready` doesn't depend on `in_valid`, `in_data` or `in_last` in the same cycle | the scoreboard predicts `in_ready` from the model alone and checks it in every cycle a beat is offered | random packets wait for `in_ready` before raising `in_valid` one time in four (`wait_ready`) | no bin | done, partly: no check looks at `in_ready` between rising edges |
| I5 | between packets, `in_ready` equals `CTRL.EN` | `a_I5`, and the scoreboard's `in_ready` check | `router_ctrl_vseq`: headers offered with `CTRL.EN` = 0, and `CTRL` written while 1-beat packets go in | `C_CTRL_WRITE_WITH_HEADER` | done |
| I6 | from a packet's first handshake to its last, `in_ready` is 1 | `a_I6`, and the scoreboard's `in_ready` check | `router_ctrl_vseq`, E7: `CTRL.EN` cleared in the middle of a packet | `C_CTRL_OFF_MID_PACKET` | done |
| I7 | `in_ready` is 0 while `rst_n` is 0 | `a_I7`; the scoreboard reports any transfer a monitor sees in a reset cycle | every reset, and `router_reset_vseq` resets with a beat on offer | no bin (every run has resets: 15 in `router_all_test`, seed 1) | done |

### Outputs

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| O1 | `out_valid` holds until the handshake | `a_O1` on each output | every stalled or slow sink | `cg_wait.x_port_wait`: `long_wait` and `stalled` on both outputs | done |
| O2 | `out_data` and `out_last` hold while the beat waits | `a_O2` on each output, and the scoreboard's data check | the same | the same | done |
| O3 | the outputs don't depend on `out_ready` or any other input in the same cycle | the scoreboard's O8 check, which predicts `out_valid` from earlier cycles only | every run; the sink drives `out_ready` 1 ns after the edge | no bin | done, partly: no check looks at the outputs between rising edges |
| O4 | `out_valid` is 0 during reset, and stays 0 until a beat accepted after it arrives | `a_O4_rst`, `a_O4_after`, and the scoreboard (a beat with nothing expected) | `router_reset_vseq`, E8: a reset with a beat waiting on a stalled output | `C_RESET_WITH_BEATS` | done |
| O5 | beats come out in order, unchanged, never interleaved | the scoreboard compares every beat with the head of that output's queue | every run | `cg_pkt.x_len_act`, every length to both outputs | done |
| O6 | every output packet is 1 to 8 beats and ends with its only `out_last` | `a_O6`, and the scoreboard's expected `out_last` | `router_oversize_vseq`, and oversize packets in the random phases | `cg_pkt.cp_len.oversize` | done |
| O7 | each output depends only on its own `out_ready` | the scoreboard's per-output model (O8) and `a_O1`, `a_O2` on each output | `router_full_vseq`: output 1 runs while output 0 is stalled; the random phases set each sink's mode on its own | `cg_wait.x_port_wait` (doesn't show the two disagreeing) | done |
| O8 | beat $k$ is on the pins from cycle $\max(t_k + 2, h_{k-1} + 1)$ until it's taken | the scoreboard, for every output beat | every run | `cg_wait.cp_wait`: `none`, `short_wait`, `long_wait`, `stalled` | done |

### Routing, drops and oversize packets

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| RT1 | the decision table: `EN` = 0 is NOROUTE, a level of 9 to 16 is FULL, 0 to 8 is written to output `PORT` | the scoreboard's model decides every packet's fate, then checks every output beat and every `DROP_CNT` and `STATUS` read against it | `router_smoke_vseq`, `router_full_vseq`, the random phases | `cg_pkt.x_dst_act`, all 16 bins | done |
| RT2 | the threshold itself: admitted at exactly 8, dropped at exactly 9 | the scoreboard | `router_full_vseq`: nine 1-beat packets and a tenth (E5); two 8-beat packets | `C_ADMIT_AT_8`, `C_DROP_AT_9`, `cg_pkt.cp_level.at_8` and `at_9` | done |
| RT3 | a disabled route is NOROUTE whatever its `PORT`'s level, never FULL | the scoreboard (`DROP_CNT` and `STATUS` reads) | `router_full_vseq`: `ROUTE1` disabled with `PORT` = 0 while output 0 holds 9 beats | no bin: `cg_pkt` doesn't cross the fate with the level | done; open item 1 |
| RT4 | a `ROUTE` or `CTRL` write affects headers from the cycle after it completes | the scoreboard applies each write at the end of its completion cycle | `router_same_cycle_vseq` (`ROUTE1` written while its packets go in), `router_ctrl_vseq` | `C_ROUTE_WRITE_WITH_HEADER`, `C_CTRL_WRITE_WITH_HEADER` | done |
| RT5 | a dropped packet is still taken: `in_ready` stays 1 for all its beats | `a_I6`, and the scoreboard's `in_ready` check | every multi-beat drop | `cg_pkt.x_len_act`: lengths 2 to 8 crossed with `noroute` and `full` | done |
| DR1 | a drop adds one to its counter and sets its `STATUS` bit, visible from the next cycle | the scoreboard: `DROP_CNT` and `STATUS` reads, and `irq` every cycle | every drop | `cg_pkt.cp_act.noroute` and `full` | done |
| DR2 | each counter stops at 255 | the scoreboard (`DROP_CNT` reads) | `router_saturate_vseq`: 260 NOROUTE drops and 270 FULL drops | `C_NOROUTE_SATURATED`, `C_FULL_SATURATED` | done |
| OV1 | an oversize packet goes out cut to 8 beats, the 8th with `out_last`, and sets `STATUS.OVERSIZE` once | the scoreboard; `a_O6` | `router_oversize_vseq` (9 to 20 beats, E6) | `cg_pkt.cp_len.oversize`, crossed with `out0` and `out1` | done |
| OV2 | an oversize packet that is also dropped counts as one drop and sets `OVERSIZE` too | the scoreboard | `router_oversize_vseq`: oversize and NOROUTE; oversize while output 1 is full | `C_OVERSIZE_DROPPED` | done |
| EN1 | `CTRL.EN` stops and starts the input only between packets (E7), and doesn't affect the outputs | `a_I5`, `a_I6`, the scoreboard | `router_ctrl_vseq` | `C_CTRL_OFF_MID_PACKET` | done |

### APB and registers

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| A1, A2, A3 | (master) setup then access; address and data hold; `penable` is 0 after a transfer | `a_A1`, `a_A2`, `a_A3`, which check the APB driver | every transfer; `router_regs_vseq` runs 40 back to back | `C_APB_BACK_TO_BACK` | done |
| A4 | (master) `psel` is 0 during reset; a transfer cut by reset has no effect | `a_A4`; the scoreboard and the mirror check the reads after the reset | `router_reset_vseq`: a reset in the middle of register traffic | no bin | done |
| A5, A6 | a write's first access cycle has `pready` 1; a read's has `pready` 0, then 1; nowhere else is it 0 | `a_A5`, `a_A6_first`, `a_A6_second`, `a_A6_only` | every transfer | `cg_apb.x_reg_write`, all 24 bins | done |
| A7 | `pslverr` is 1 exactly when a transfer to a bad address completes | `a_A7_only`, `a_A7_bad`, and the scoreboard | `router_regs_vseq`: all 256 addresses read, every bad one written | `cg_apb.cp_reg.bad_aligned`, `bad_unaligned`; `cp_slverr.err` | done |
| A8 | a read returns the value in its first access cycle; `prdata` changes only then | `a_A8`, and the scoreboard (the model's registers in the first access cycle) | every read; `router_same_cycle_vseq` reads `LEVEL` while beats go in | `C_LEVEL_READ_WITH_BEAT` | done |
| A9 | each write takes effect by its field's access type; a bad write changes nothing | the scoreboard's model and the register model's mirror | `router_regs_vseq`: patterns through every register, writes to `ID`, `LEVEL` and every bad address | `cg_apb.x_reg_write` | done |
| RG1 | every register's reset value | the mirror after `regs.reset()`, and the scoreboard's model after its reset | `rd_all()` straight after the reset in `router_smoke_vseq`, `router_regs_vseq` and `router_reset_vseq` | no bin | done |
| RG2 | `STATUS` is write-1-to-clear per bit, and an event in the clearing cycle wins | the scoreboard | `router_irq_vseq` clears one bit at a time; `router_same_cycle_vseq` clears `NOROUTE` while drops go on | `C_STATUS_CLEAR_WITH_EVENT` | done |
| RG3 | any write clears `DROP_CNT`; a drop in the same cycle is counted after the clear (E9) | the scoreboard | `router_same_cycle_vseq`; `router_saturate_vseq` clears at 255 during drops | `C_CNT_CLEAR_WITH_DROP` | done |
| RG4 | `LEVEL` reads both levels, and a beat accepted in the read's first access cycle isn't in it | the scoreboard | `router_same_cycle_vseq` | `C_LEVEL_READ_WITH_BEAT` | done |
| RG5 | bits that aren't fields read 0 and ignore writes; `ID` and `LEVEL` ignore writes | the mirror (`ID`, `CTRL`, `INT_EN`, `ROUTE`), the scoreboard (the rest) | `router_regs_vseq`, eight patterns | no bin | done |
| IRQ1 | `irq` is the OR of `STATUS & INT_EN`, in the same cycle as the bit that changes it | the scoreboard, every cycle | `router_irq_vseq`: each bit against all eight `INT_EN` values | `C_IRQ_RISE`, `C_IRQ_FALL` | done |

### Reset

| Id | The rule | Checked by | Made to happen by | Seen in coverage | Status |
|---|---|---|---|---|---|
| RS1 | the Reset table's values while `rst_n` is 0: `pready` 1, `pslverr` 0, `prdata` 0, `irq` 0 | `a_R_pready`, `a_R_pslverr`, `a_R_prdata`, `a_R_irq`; the scoreboard checks `irq` too | every reset | no bin | done |
| RS2 | a reset with beats in a buffer loses them, a waiting beat included, and nothing from before it comes out (E8) | the scoreboard (its model empties both queues; a beat after that has nothing to match), `a_O4_rst`, `a_O4_after` | `router_reset_vseq`; resets in the random phases | `C_RESET_WITH_BEATS` | done |
| RS3 | a reset in the middle of an input packet discards it, and the next beat accepted is a header | the scoreboard | `router_reset_vseq` | `C_RESET_MID_PACKET` | done |

## Sign-off criteria

- `make regress` prints `110 ok  (110 runs)`: all 11 tests pass on seeds 1 to 10.
- The same run prints `covergroup : 100.0% (145/145)`.
- `make check-all` prints `15 of 15 caught.` with the golden design `ok`, on seeds 1 to 5.
- Every row above is `done`, or its gap is written down under Open items.

## Open items

1. RT3 has a check and a sequence but no bin. A cross of `cp_act` with `cp_level` in `cg_pkt`
   would show a NOROUTE drop at levels 9 to 16; as it stands, only the directed step in
   `router_full_vseq` says it happened.
2. I4 and O3 are checked only through the model's predictions. A check that samples the router's
   outputs just after an input changes, between rising edges, and confirms that they haven't moved
   would check them directly.
