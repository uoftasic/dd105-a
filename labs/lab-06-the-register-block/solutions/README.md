# Lab 06: reference solution

Open this after `make check-all` prints `5 of 5 caught.` with your own files.

| File | What it is |
|---|---|
| `tb/router_ral_pkg.sv` | `../tb/router_ral_pkg.sv` with the fields of `STATUS`, `DROP_CNT`, `LEVEL` and `ROUTEn` and the adapter written |
| `tb/router_env_pkg.sv` | `../tb/router_env_pkg.sv` with the predictor connected and the scoreboard's `irq` check written |
| `tb/router_seq_pkg.sv` | `../tb/router_seq_pkg.sv` with `router_lab06_vseq`'s steps written |
| `Makefile` | builds the lab's testbench with these three files in place of the ones in `../tb/` |

Apart from the header comments, only the code the `TODO`s mark differs from the shipped files:

```bash
diff ../tb/router_ral_pkg.sv tb/router_ral_pkg.sv
diff ../tb/router_env_pkg.sv tb/router_env_pkg.sv
diff ../tb/router_seq_pkg.sv tb/router_seq_pkg.sv
```

Run it from this folder, which has its own `build/`:

```bash
make check-all
make clean
```

## What it does

| Piece | How |
|---|---|
| the fields | `STATUS.*` `W1C`, volatile; `DROP_CNT.*` `WC`, volatile; `LEVEL.*` `RO`, volatile; `ROUTEn.EN` and `ROUTEn.PORT` `RW`; positions and widths from the register map |
| `reg2bus()` | one `apb_item`: `write` from `rw.kind`, `addr` the low 8 bits of `rw.addr`, `wdata` from `rw.data`, `idle` 0 to 2 at random |
| `bus2reg()` | `kind`, `addr`, `data` (`wdata` for a write, `rdata` for a read), and `UVM_NOT_OK` when `slverr` is 1 |
| the predictor | `map` and `adapter` set, `apb.drv.done_ap` connected to `bus_in`, `set_check_on_read(1)` on the map |
| the `irq` check | in every cycle out of reset, `s.irq` against `m.irq()`, one `uvm_error` for each stretch of wrong cycles; in a reset cycle, `irq` must be 0 |
| `router_lab06_vseq` | reset; `uvm_reg_hw_reset_seq`; `uvm_reg_bit_bash_seq`; the routing table and `CTRL.EN` set with raw writes and read back with `mirror(UVM_CHECK)`; every one of the 246 bad addresses read, then written with all ones, and every register read; all three `STATUS` bits set with `INT_EN` at 0, each enable on alone for two cycles, then the bits cleared one at a time with every enable on, `STATUS` read after each |

## Results

In the course image on 2 CPUs, seed 1 unless the row says otherwise.

| Run | Result |
|---|---|
| `make run` (golden) | `ok: 0 UVM_ERROR, 0 UVM_FATAL   5.29 s`; `[SB] 879 register reads checked, 857 writes, 492 to bad addresses; 0 assertion failures`; `[SB] irq checked in 10265 cycles, wrong in 0` |
| `make seeds NSEEDS=5` | `5 ok  (5 runs)`, 5.1 to 5.3 s each |
| `make regress NSEEDS=5` (the three tests) | `15 ok  (15 runs)` |
| `make check-all`, seeds 1 to 5 | `5 of 5 caught.` on each seed, with the same counts: B01 3, B02 3, B03 6, B04 50 and B14 3 `UVM_ERROR`s |
| `make check BUG=<id>` for each of the five | `VERDICT: PASS` |
| `make check-all` with `BUG_LIST` set to B01 to B15 | `14 of 15 caught.`; B15 (`output_valid_survives_reset`) is missed, and Lab 07 hunts it |
| `make run UVM_TESTNAME=router_backdoor_test` | `ok`; every poke of `CTRL`, `INT_EN` and `DROP_CNT` still reads back through `peek` two rising edges later |
| the same with `+BACKDOOR_READBACK` | `FAIL: 1 UVM_ERROR`: `[SB] a read of INT_EN (0c), completing in cycle 27 returned 00000006; it should return 00000000, the value in cycle 26 (its first access cycle)` |

The first check to fire on each bug, seed 1:

| Bug | First error | From |
|---|---|---|
| B01 | `[SB] irq is 0 from cycle 10203, but STATUS = 110 and INT_EN = 111 make it 1` | the `irq` check, after `STATUS` is written with `001` in the Part 5 step |
| B02 | `[SB] irq is 1 from cycle 22, but STATUS = 001 and INT_EN = 000 make it 0` | the `irq` check, in Lab 04's traffic |
| B03 | `[RegModel] Register "regs.ROUTE3" value read from DUT (0x0000000000000002) does not match mirrored value (0x0000000000000001)` | the predictor's check-on-read during the bit bash; the bit bash's own error and the scoreboard's follow |
| B04 | `[SB] a read of a bad address (01), completing in cycle 8883: pslverr is 0, but 01 is a bad address` | the scoreboard, in the bad-address sweep |
| B14 | `[RegModel] Register "regs.CTRL" value read from DUT (0x0000000000000001) does not match mirrored value (0x0000000000000000)` | the reset sequence's own check and the predictor's, then the scoreboard |

From this folder, with a ccache that already held the lab folder's builds, the solution built in
34 s.
