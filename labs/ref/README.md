# `labs/ref`: the router's reference UVM environment

This is a complete UVM testbench for the packet router, written from the specification
([`docs/reference/router-spec.md`](../../docs/reference/router-spec.md)) alone, without reading the
router's RTL or the list of planted bugs. It builds with `labs/common/uvm.mk` like every DD105-A
lab, and the graders in `labs/common` run it.

It has an APB agent, a source agent for the input stream, a reactive sink agent with random
backpressure on each output, a register model with an adapter and an explicit predictor, a
scoreboard whose reference model follows the specification cycle by cycle, functional coverage,
assertions for the valid/ready and APB rules in a file of their own attached with `bind`, and
virtual sequences that drive all of it at once.

## Running it

From this folder, in the course image:

```bash
make                                   # build if needed, then run router_all_test
make run UVM_TESTNAME=router_rand_test SEED=7 PLUSARGS="+N=3000"
make regress                           # every test on seeds 1 to 10, then the coverage
make check-all                         # router_all_test on the golden design and on each planted bug
make clean
```

The Makefile sets `PLUSARGS` to `+verilator+error+limit+100000`, so every failing assertion prints
and the run goes on (the simulator's default error limit is 1, which ends the run at the first
one). If you give `PLUSARGS` on the command line, add that plusarg to it yourself if you want the
same behaviour.

`labs/common/README.md` has the full list of targets and variables. The ones this folder adds are
plusargs read by the tests:

| Plusarg | Default | Meaning |
|---|---|---|
| `+N=<n>` | 1200 | packets sent by `router_rand_test` |
| `+PHASES=<n>` | 6 | phases of `router_rand_test`, each with its own configuration and backpressure |
| `+MAX_CYCLES=<n>` | 400000 | a watchdog: a test still running after this many cycles ends with `UVM_ERROR [WATCHDOG]` |

A run also stops after 50 `UVM_ERROR`s (`set_max_quit_count(50)` in the base test), so a scoreboard
that has lost step with the router doesn't print thousands of lines.

## Tests

Every test extends `router_base_test`, which extends `dd105_base_test`. Each one runs a single
virtual sequence from `tb/router_seq_pkg.sv`, and each of those starts with a reset.

| Test | What it does |
|---|---|
| `router_all_test` | every directed sequence below, one after another, then 600 random packets in 4 phases; `make check` and `make check-all` grade this one |
| `router_smoke_test` | one routing table, four directed packets and 40 random ones, every register read before and after |
| `router_rand_test` | random routing tables, packets, idle cycles, backpressure, register traffic (including bad addresses) and resets, all at once |
| `router_full_test` | the admission threshold from both sides (example E5, and the specification's two 8-beat packets), headers decided in the cycle the sink starts taking beats again, a disabled route whose `PORT` names a full output, and output 1 running while output 0 is stalled |
| `router_oversize_test` | packets of 9 to 20 beats, cut to 8 (E6), forwarded, dropped as NOROUTE and dropped as FULL |
| `router_ctrl_test` | `CTRL.EN` cleared in the middle of a packet (E7), and toggled while 1-beat packets go in back to back |
| `router_same_cycle_test` | a `DROP_CNT` write in the cycle of a drop (E9), a `STATUS` clear in the cycle of an event, a `ROUTE` write in the cycle of a header, `LEVEL` read while beats go in |
| `router_saturate_test` | both drop counters driven past 255, and cleared |
| `router_regs_test` | reset values, every one of the 256 addresses read, every bad address written, patterns through the read-write registers and `ID` and `LEVEL`, back-to-back transfers |
| `router_reset_test` | reset with a beat waiting on a stalled output (E8), with a packet half accepted, in the middle of APB transfers, and with a packet half delivered |
| `router_irq_test` | each `STATUS` bit against all eight `INT_EN` settings, cleared one bit at a time |

## Checks

None of the sequences checks anything itself. Three things watch every cycle of every test:

- The scoreboard (`router_scoreboard` in `tb/router_env_pkg.sv`) runs `router_model` on what the
  monitors saw. Every monitor stamps its transactions with the cycle number, and the reset/irq
  monitor sends one sample per cycle, which the scoreboard uses as its clock. It predicts which
  output each packet goes to, every beat's data and `out_last` (an oversize packet's 8th beat
  included), the cycle each output beat appears (rule O8), `in_ready` in every cycle a beat is
  offered (I5, I6), `irq` in every cycle, `pslverr`, and the value of every register read,
  `STATUS`, `DROP_CNT` and `LEVEL` included, as it was in the read's first access cycle (A8).
- The register model checks every read of `ID`, `CTRL`, `INT_EN` and `ROUTE0` to `ROUTE3` against its
  mirror (`set_check_on_read(1)`); the other three registers are volatile, and UVM doesn't compare
  them, which is why the scoreboard does.
- The assertions in `tb/router_sva.sv` check I1, I2, I5, I6, I7, O1, O2, O4, O6 and A1 to A8, and the
  reset values of `pready`, `pslverr`, `prdata` and `irq`. Each one counts its own failures in a
  variable named after its rule (`n_I5`, `u_out0.n_O2`, ...), and `n_fail` is their sum, which the
  scoreboard reports at the end of the test. The file has no UVM in it, so another testbench, a
  pyuvm one included, can bind it the same way (`tb/router_sva_bind.sv`); the counters are ordinary
  variables in the bound instance. Only this SV environment has been run with it.

The coverage (`router_coverage`) records every packet's length, `DST`, fate and the level of its
output when its header was decided; every APB transfer by register and direction; how long output
beats waited; and the corners the scoreboard saw happen, such as a `DROP_CNT` clear in the cycle of a
drop. `make cov` lists the bins. In `make regress` (11 tests on seeds 1 to 10) all 145 bins were hit.

## Results

All 11 tests pass on the golden design on seeds 1 to 10, 110 runs in all:

```
  110 ok  (110 runs)
```

The graded test, `router_all_test`, took 5.8 to 6.4 s per run over those ten seeds. On seed 1 it
runs for 11,981 cycles:

```
[SB] 11981 cycles, 15 resets; 4721 input beats in 1712 packets: 645 forwarded, 543 NOROUTE, 524 FULL, 63 oversize; 2153 output beats
[SB] 1143 register reads checked, 811 writes, 994 to bad addresses; irq wrong in 0 cycles
```

`make check-all` on seed 1 (64.2 s in all):

```
      ok  the golden design                        0 UVM_ERROR, 0 UVM_FATAL        6.2s
------------------------------------------------------------------------
  caught  tier 1  B01_status_write_clears_all      17 UVM_ERROR                    6.1s
  caught  tier 1  B02_irq_ignores_int_en           22 UVM_ERROR                    6.1s
  caught  tier 1  B03_route3_readback_swapped      20 UVM_ERROR                    6.2s
  caught  tier 1  B04_misaligned_address_accepted  50 UVM_ERROR, 40 assertions     0.7s
  caught  tier 2  B05_dst_field_off_by_one         50 UVM_ERROR                    0.2s
  caught  tier 2  B06_disabled_route_forwards      50 UVM_ERROR                    0.3s
  caught  tier 2  B07_full_counted_on_disabled_route 33 UVM_ERROR                    6.2s
  caught  tier 3  B08_admission_off_by_one         50 UVM_ERROR                    5.0s
  caught  tier 3  B09_write_pointer_power_of_two   50 UVM_ERROR                    0.2s
  caught  tier 4  B10_output_reloads_while_stalled 50 UVM_ERROR, 35 assertions     0.2s
  caught  tier 4  B11_cut_packet_has_no_last       38 UVM_ERROR, 30 assertions     6.2s
  caught  tier 5  B12_out1_uses_out0_ready         50 UVM_ERROR, 28 assertions     2.9s
  caught  tier 5  B13_admission_checks_other_output 50 UVM_ERROR, 1 assertion       5.0s
  caught  tier 6  B14_enable_resets_to_one         25 UVM_ERROR, 1793 assertions    6.1s
  caught  tier 6  B15_output_valid_survives_reset  46 UVM_ERROR, 49 assertions     6.2s
------------------------------------------------------------------------
 15 of 15 caught.
```

Seeds 2, 3 and 4 gave `15 of 15 caught.` as well. Run against each test on its own (seed 1), the
counts are smoke 10, rand 15, full 9, oversize 8, ctrl 5, same_cycle 9, saturate 7, regs 3, reset 9
and irq 9, so only the random test catches every bug by itself.

The grader prints each bug's name, so after the first `check-all` this testbench was no longer
written blind. That first run caught 15 of 15 on seed 1 as well. One directed step was added after
it: the `router_full_test` step with a disabled route whose `PORT` names a full output, which the
specification's Routing section describes. Until then only the random traffic had caught
`B07_full_counted_on_disabled_route`.

## Build and run times

Measured on ieee-asic-1 in the course image with 2 CPUs and 3 GB, with `uvm.mk`'s defaults. The
first build, with an empty ccache, took 128 s. Rebuilds after edits to the testbench files took
between 30 s and 134 s, and six of the eight took more than 100 s. A run that needs no rebuild
(a new seed, test or plusarg) started and finished `router_smoke_test` in 0.5 s, and
`router_all_test` takes about 6 s.

## Verilator 5.050 workarounds

The course's list of Verilator 5.050 limits shaped the stimulus and the checks: the base test turns
`UVM_ERROR` into a failing exit status, coverpoints are written `with function sample`, the
Makefile raises the error limit for the assertions, and the register model uses no back door. Four
more turned up while this environment was written. Each has a probe in `probes/` (`bash run.sh`
there, in the course image, builds and runs all four), and the output below is from that script.

**Clocking-block inputs read through a typedef of a virtual interface read 0.** A class in a
package that reaches an interface through `typedef virtual pif pif_vif;` reads 0 from every
clocking-block input, at every edge, with no warning; the same class reading through
`virtual pif` sees the right values. So the packages here write the interface types out in full.

```
edge 1: through virtual pif, mon_a.cycle = 1; through the typedef, mon_b.cycle = 0
edge 2: through virtual pif, mon_a.cycle = 2; through the typedef, mon_b.cycle = 0
```

**A clocking-block drive issued after an NBA-region wait lands a cycle late.** `try_next_item()`
waits for the NBA region before it returns. A drive through the clocking block issued after that
wait, in the same time step as the edge, takes effect at the next edge plus the skew instead of
this one:

```
5000: drive r
6000: r is 1
15000: drive s, after an NBA wait
26000: s is 1
```

So the three drivers here work in two steps per cycle: at the falling edge they look at the pins
(did the beat move? did the transfer complete?), ask the sequencer for the next item, and decide
what the next cycle holds; right after the rising edge they drive it. This is also what lets the
APB driver run transfers back to back: `router_regs_test` on seed 1 started 835 transfers in the
cycle after the previous one completed.

**An array of bins on a crossed coverpoint becomes one bin.** `bins a[] = {[0:3]}` gives four bins
on a coverpoint that isn't crossed, and one bin, named `a`, on one that is:

```
__vlAnonCG_cg.cp_crossed.a 8
__vlAnonCG_cg.cp_alone.b[0] 2
```

So every coverpoint in a cross here has its bins written out one by one.

**`dist` gets the distribution wrong when its values are named constants.** With weights 20/50/20/10
on a selector, 1,000 draws each:

```
enum values, dist:       0 0 0 1000
localparam values, dist: 73 557 356 14
literal values, dist:    206 492 201 101
randcase:                182 526 184 108
```

So the packet length kind and the sink's delay range are drawn with `randcase` in
`pre_randomize()`, and the solver picks the length and delay from the chosen range.

## Files

| File | What it is |
|---|---|
| `Makefile` | the lab's sources and tests; includes `../common/uvm.mk` |
| `tb/apb_if.sv` | the APB interface and its clocking blocks |
| `tb/stream_if.sv` | the input-stream interface (the testbench drives `valid`) and the output-stream one (it drives `ready`) |
| `tb/router_sys_if.sv` | `rst_n`, `irq`, the assertion count, and the cycle number of a scheduled reset |
| `tb/apb_pkg.sv` | the APB agent and a raw-transfer sequence |
| `tb/stream_pkg.sv` | the source agent, the reactive sink agent, the stream monitor and their sequences |
| `tb/router_ral_pkg.sv` | the register model and the adapter |
| `tb/router_env_pkg.sv` | the reset/irq agent, the reference model, the scoreboard, the coverage, the virtual sequencer and the environment |
| `tb/router_seq_pkg.sv` | the virtual sequences |
| `tb/router_test_pkg.sv` | the tests |
| `tb/router_sva.sv` | the assertions, with a failure counter each |
| `tb/router_sva_bind.sv` | the `bind` that puts them into every `router` |
| `tb/router_tb_top.sv` | the clock, the interfaces, the router and `run_test()` |
| `probes/` | the four simulator probes above, and `run.sh` |
