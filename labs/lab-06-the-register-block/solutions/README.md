# Lab 06: reference solution

Open this after `make check-all` prints `5 of 5 caught.` with your own files.

| File | Part | What it is |
|---|---|---|
| `router_ral_pkg.sv` | 2 | `tb/router_ral_pkg.sv` with the fields of `STATUS`, `DROP_CNT`, `LEVEL` and `ROUTEn` and the adapter |
| `router_env_pkg.sv` | 3, 5 | `tb/router_env_pkg.sv` with the predictor's connections and the scoreboard's `irq` check |
| `router_vseq_pkg.sv` | 2 to 5 | `tb/router_vseq_pkg.sv` with `router_lab06_vseq::body()` |

Apart from the header comments, only the code the `TODO`s mark differs from the shipped files:

```bash
diff tb/router_ral_pkg.sv solutions/router_ral_pkg.sv
diff tb/router_env_pkg.sv solutions/router_env_pkg.sv
diff tb/router_vseq_pkg.sv solutions/router_vseq_pkg.sv
```

To run the solution, keep copies of your own files outside `tb/` and put the solution in their
place:

```bash
mkdir -p mine && cp tb/router_ral_pkg.sv tb/router_env_pkg.sv tb/router_vseq_pkg.sv mine/
cp solutions/router_ral_pkg.sv solutions/router_env_pkg.sv solutions/router_vseq_pkg.sv tb/
make check-all
cp mine/* tb/
```

On 2 CPUs, in the course image, the starter built cold in 130 s (Verilator 128.696 s,
`Hits: 0 / 38`). Filling in each part's `TODO`s in place, as the writeup asks, rebuilt in 111 s
(Part 2), 104 s and 112 s (Part 3, before and after the predictor), 57 s (Part 4), and 111 s and
28 s (Part 5).

## What changed

| Part | Where | Change |
|---|---|---|
| 2 | `router_reg_status`, `router_reg_drop_cnt`, `router_reg_level`, `router_reg_route` | `STATUS.*` `W1C`, volatile; `DROP_CNT.*` `WC`, volatile; `LEVEL.*` `RO`, volatile; `ROUTEn.EN` and `ROUTEn.PORT` `RW`, `is_rand` 1; positions and widths from the register map |
| 2 | `router_reg_adapter` | `reg2bus()`: one `apb_item`, `write` from `rw.kind`, `addr` the low 8 bits of `rw.addr`, `wdata` the low 32 bits of `rw.data`. `bus2reg()`: `kind`, `addr`, `data` (`wdata` for a write, `rdata` for a read), and `UVM_NOT_OK` when `slverr` is 1 |
| 2 | `router_lab06_vseq::body()` | `uvm_reg_hw_reset_seq` on `regs` |
| 3 | `router_lab06_vseq::body()` | `uvm_reg_bit_bash_seq` on `regs`; raw `route(0, 1, 0)`, `route(1, 1, 1)`, `route(2, 0, 1)`, `route(3, 1, 1)`, `ctrl(1)`; `check_reg()` on `CTRL` and the four `ROUTEn` |
| 3 | `router_env::connect_phase` | `predictor.map`, `predictor.adapter`, `apb.mon.ap` to `predictor.bus_in`, `set_check_on_read(1)` on the map |
| 4 | `router_lab06_vseq::body()` | `rd()` of every address `good_addr()` rejects, then `wr()` of `32'hFFFF_FFFF` to each, then `rd_all_regs()` |
| 5 | `router_scoreboard::write_sys` | in a reset cycle, `irq` must be 0; in every other cycle `irq` must equal `irq()`, with one `uvm_error` per stretch of wrong cycles |
| 5 | `router_lab06_vseq::body()` | `DST` 1 disabled, both sinks `SNK_FAST`; a NOROUTE packet, a 9-beat packet, a drain, output 0 stalled and ten 1-beat packets to `DST` 0; a `STATUS` read; each `INT_EN` bit alone for two cycles; `INT_EN` `'b111`, then `STATUS` written with `'b001`, `'b100` and `'b010`, read after each; a drain and `rd_all_regs()` |

## Results

Measured in the course image with 2 CPUs and 3 GB, `router_test` unless a row says otherwise.

| Run | Result |
|---|---|
| `make run` | `ok: 0 UVM_ERROR, 0 UVM_FATAL   4.73 s`; `[SB] 1133 packets in: 282 to output 0, 226 to output 1, 195 NOROUTE, 430 FULL`; `[SB] registers: 870 reads, 64 of STATUS checked; 492 transfers to bad addresses; irq checked in 14840 cycles, wrong in 0` |
| `make check-all`, seeds 1 to 5 | golden `ok` and `5 of 5 caught.` on every seed, with the same counts: B01 3, B02 1, B03 4, B04 50, B14 2 `UVM_ERROR`s |
| `make check`, and `make check BUG=` B02, B03, B04, B14 | `VERDICT: PASS` each |
| `make seeds SEEDS="1 2 3 4 5"` | `5 ok  (5 runs)` |
| `make seeds` (seeds 1 to 10) | `10 ok  (10 runs)`, 4.5 to 4.8 s a run |
| `make seeds UVM_TESTNAME=router_lab06_test SEEDS="1 2 3 4 5"` | `5 ok  (5 runs)` |
| `make regress SEEDS="1 2 3 4 5"` (all ten tests) | `50 ok  (50 runs)`, `covergroup : 87.5% (49/56)` |
| `make lint` | 0 warnings, on the starter and on the solution |
| `make run UVM_TESTNAME=router_backdoor_test` | `ok: 0 UVM_ERROR, 0 UVM_FATAL   0.09 s`; every poke of `CTRL`, `INT_EN` and `DROP_CNT` still reads back through `peek` two rising edges later |
| the same with `+BACKDOOR_READBACK` | `FAIL: 1 UVM_ERROR`: `[DROP_CNT] read 00000505, expected 00000001 (FULL_CNT 0, NOROUTE_CNT 1)` |

The seven bins the regression leaves empty are the seven of `x_fate_level` that the specification
rules out, as in Labs 04 and 05.

The first check to fire on each bug, seed 1:

| Bug | First error | From |
|---|---|---|
| B01 | `[IRQ] irq is 0 from cycle 5969, but STATUS = 110 and INT_EN = 111 make it 1` | the `irq` check, after `STATUS` is written with `'b001` in the Part 5 step; two `[STATUS]` read errors follow |
| B02 | `[IRQ] irq is 1 from cycle 5909, but STATUS = 001 and INT_EN = 000 make it 0` | the `irq` check, in the Part 5 step |
| B03 | `[RegModel] Register "regs.ROUTE3" value read from DUT (0x0000000000000002) does not match mirrored value (0x0000000000000001)` | the predictor's check-on-read during the bit bash; the bit bash's own error follows |
| B04 | `[APB] a read of 01, completing in cycle 4145: pslverr is 0, but 01 is a bad address` | the scoreboard, in the bad-address sweep |
| B14 | `[RegModel] Register "regs.CTRL" value read from DUT (0x0000000000000001) does not match mirrored value (0x0000000000000000)` | the reset sequence's `mirror()`, then the predictor's check of the same read |

## Against the whole catalogue

`make check-all BUG_LIST="B01 B02 ... B15"`, seed 1, with the golden router `ok` every time. The
Lab 05 column is from `labs/lab-05-protocol-rules-and-backpressure/solutions/README.md`.

| Bug | Lab 05's solution | This starter | This solution |
|---|---|---|---|
| B01 to B04 | MISSED | MISSED | caught: 3, 1, 4 and 50 `UVM_ERROR`s |
| B05, B06 | caught, 50 | caught, 50 | caught, 50 |
| B07 | caught, 4 | caught, 4 | caught, 4 |
| B08 | caught, 50 | caught, 50 | caught, 50 |
| B09 | caught, 50 and 1 assertion | caught, 50 | caught, 50 |
| B10 | caught, 50 and 244 assertions | caught, 50 and 330 | caught, 50 and 256 |
| B11 | caught, 33 and 26 assertions | caught, 40 and 32 | caught, 22 and 19 |
| B12 | caught, 50 and 1 assertion | caught, 50 and 2 | caught, 50 and 3 |
| B13 | caught, 50 | caught, 50 | caught, 50 and 1 assertion |
| B14 | MISSED | MISSED | caught, 2 |
| B15 | MISSED | MISSED | MISSED |
| total | `9 of 15 caught.` | `9 of 15 caught.` | `14 of 15 caught.` |

The starter catches the same nine bugs as Lab 05's solution. The counts move because
`router_test` now starts `router_lab06_vseq` before `router_inject_test`'s steps, and starting a
sequence draws from the test's random state, so every routing table, packet and coin flip after
it differs. With the sequence left out, this `router_test` printed Lab 05's `[SB]` lines number
for number (`1122 packets in: 240 to output 0, 270 to output 1, 194 NOROUTE, 418 FULL`;
`1108` and `1219` beats), so nothing else this lab adds changes the stimulus. The starter misses
all five of this lab's bugs on seeds 1 to 5, and `make check` says
`VERDICT: FAIL -- your test passes B01_status_write_clears_all too.` B15 is Lab 07's: the router is
reset only at time 0.

## Differences from the first Lab 06

The first Lab 06 was built on a different Lab 05, with a cycle-exact reference model, a reset
agent and an APB driver that finished each transfer at the falling edge. This one is built on the
rebuilt Lab 05's solution.

- The predictor listens to the monitor. The first Lab 06 added `done_ap` to the APB driver,
  because with its falling-edge driver a predictor on the monitor failed the bit bash. Lab 05's
  driver finishes a transfer at the same rising edge at which the monitor reports it, and with the
  predictor on `apb.mon.ap` the bit bash passed on the golden router, so Lab 05's APB agent ships
  unchanged and the page's question about `done_ap` is gone.
- There is no reset driver. `router_test` runs `router_lab06_vseq` first, while the registers still
  hold their reset values from the reset at time 0. The scoreboard's reset handling covers
  `STATUS` and `INT_EN` only.
- The register model checks reads of `ID`, `CTRL`, `INT_EN` and
  `ROUTEn` (check-on-read and `mirror()`); the scoreboard checks `STATUS` and `DROP_CNT` reads,
  `PSLVERR` on every transfer, reads of bad addresses, and `irq`. Nothing checks `LEVEL`.
- The back-door read-back reads `DROP_CNT`, which the scoreboard checks, rather than `INT_EN`,
  which it doesn't. `router_backdoor_vseq` writes `CTRL` with a raw transfer, so the test runs
  before the adapter is written.
- On this router a poke sticks: `CTRL`, `INT_EN` and `DROP_CNT` read back the poked value two
  rising edges later. That is what we measured here; the page makes no claim about other designs.

## Files for Lab 07's starter

`tb/` with the three files above copied in, which makes ten files: `router_ifs.sv`,
`router_agents_pkg.sv`, `router_ral_pkg.sv`, `router_env_pkg.sv`, `router_vseq_pkg.sv`,
`router_tests_pkg.sv`, `router_sva.sv`, `router_sva_bind.sv`, `router_tb_top.sv` and
`router_regs.vlt`; then `Makefile` and `src/loc.py`.

There is still no reset driver: the top module resets the router once, at time 0. The
scoreboard's `write_sys()` resets only its `STATUS` and `INT_EN` model in a reset cycle, and
nothing in it throws away the beats it expects, so a reset with traffic in flight (B15) needs
both.
