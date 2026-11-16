# Lab 07: the solution

The finished files for Parts 5 and 6, a filled-in plan, and an example report. The `Makefile`
here builds the two `.sv` files in `tb/` with every other file from `../tb/`, so this folder needs
no copy of the rest of the testbench.

| File | Part | What it adds to the starter |
|---|---|---|
| `tb/router_sva.sv` | 5 | `a_I7`, `a_O4_rst`, `a_O4_after` (with the flip-flops `seen1` and `seen2`), `a_A4`, and `a_R_pready`, `a_R_pslverr`, `a_R_prdata`, `a_R_irq` |
| `tb/router_seq_pkg.sv` | 5, 6 | `router_reset_vseq::body()`, the reset thread in `router_rand_vseq`, `router_saturate_vseq::body()`, and both sequences in `router_all_vseq` |
| `Makefile` | 5, 6 | `router_reset_test` and `router_saturate_test` in `TESTS`, 11 tests in all |
| `PLAN.md` | 2, 3 | the verification plan, filled in for this environment |
| `REPORT-EXAMPLE.md` | 4, 8 | a verification report, with the numbers from the runs below |

The two `.sv` files are `labs/ref`'s, with only their header comments changed. The starter is
`labs/ref` with these parts taken out.

```bash
make                 # build if needed, then run router_all_test
make regress         # all 11 tests on seeds 1 to 10
make check-all       # router_all_test against every bug in the catalogue
make clean
```

## Results

Measured on ieee-asic-1 in the course image (Verilator 5.050) with 2 CPUs and 3 GB, seed 1 unless
a row says otherwise.

| | Starter, as shipped | With these files |
|---|---|---|
| `make check-all` | `14 of 15 caught.`, B15 `MISSED` | `15 of 15 caught.` |
| `make regress` | `90 ok  (90 runs)`, 9 tests | `110 ok  (110 runs)`, 11 tests |
| covergroup, from `make regress` | `97.2% (141/145)`; never hit: corners 5, 6, 11, 12 | `100.0% (145/145)` |
| `router_all_test` | 11028 cycles, 8 resets, each with `0 expected beats are lost` | 11981 cycles, 15 resets |

`make check-all` in this folder, seeds 1 to 5. Every row ended `15 of 15 caught.`

| Seed | golden | B15 |
|---|---|---|
| 1 | ok, 6.2 s | 46 UVM_ERROR, 49 assertions |
| 2 | ok, 6.4 s | 4 UVM_ERROR, 24 assertions |
| 3 | ok, 6.5 s | 5 UVM_ERROR, 43 assertions |
| 4 | ok, 6.1 s | 4 UVM_ERROR, 14 assertions |
| 5 | ok, 5.9 s | 4 UVM_ERROR, 14 assertions |

Seed 1's error and assertion counts, bug by bug, match the table in `labs/ref/README.md`. `make seeds SEEDS="1 2 3 4 5"`
(`router_all_test`, golden): `5 ok  (5 runs)`, 6.1 to 6.5 s each.

The first check that fired on each bug, seed 5 (`build/grade/<bug>/run.log`):

| Bug | First check |
|---|---|
| B01 | `[SB] irq is 0 from cycle 6717, but STATUS = 110 and INT_EN = 010 make it 1` |
| B02 | `[SB] irq is 1 from cycle 4490, but STATUS = 001 and INT_EN = 010 make it 0` |
| B03 | the register model's mirror: `[RegModel] Register "regs.ROUTE3" value read from DUT (0x0000000000000002) does not match mirrored value (0x0000000000000001) ...`; the scoreboard follows a cycle later with `[SB] a read of ROUTE3 (2c), completing in cycle 451 returned 00000002; it should return 00000001, ...` |
| B04 | `a_A7_bad`: `A7: a transfer to bad address 01 completed without pslverr` |
| B05 | `[SB] irq is 1 from cycle 70, but STATUS = 000 and INT_EN = 111 make it 0` |
| B06 | `[SB] output 1 delivered 84 (offered from cycle 80, taken in cycle 90), but no beat was waiting for it there` |
| B07 | `[SB] irq is 1 from cycle 4490, but STATUS = 001 and INT_EN = 010 make it 0` |
| B08 | `[SB] output 0 delivered d2 with out_last = 0 in cycle 218; it should be d1 with out_last = 0 (accepted in cycle 203)` |
| B09 | `[SB] output 0 delivered 01 with out_last = 0 in cycle 113; it should be 61 with out_last = 0 (accepted in cycle 111)` |
| B10 | `u_out0.a_O2`: `O2: out_data or out_last changed while the beat waited` |
| B11 | `u_out0.a_O6`: `O6: an output packet is longer than 8 beats` |
| B12 | `u_out1.a_O1`: `O1: out_valid fell without a handshake` |
| B13 | `[SB] output 0 delivered 01 (offered from cycle 98, taken in cycle 98), but no beat was waiting for it there` |
| B14 | `a_I7`: `I7: in_ready is 1 during reset` |
| B15 | `u_out0.a_O4_rst`: `O4: out_valid is 1 during reset` |

B14 and B15 are first caught by assertions this lab adds. The starter catches B14 without them
(`11 UVM_ERROR, 1515 assertions` on seed 1); it misses B15. With Part 5 done and Part 6 not
(the starter's empty `router_saturate_vseq`), `make check-all` on seed 1 already printed
`15 of 15 caught.`, B15 at `9 UVM_ERROR, 55 assertions`: Part 6 closes coverage and catches no
further bug.

The hunts behind the example report's table, all on seed 1:

| Where | Deal | `make hunt` | `make verdict` |
|---|---|---|---|
| starter | `make new BUGPICK=B02` | `caught`, 21 UVM_ERROR | `VERDICT: PASS`, B02 |
| starter | `make new BUGPICK=B15` | `quiet`, `0 UVM_ERROR, 0 UVM_FATAL` | not run |
| this folder | `make new BUGPICK=B15` | `caught`, 46 UVM_ERROR, 49 assertions | `VERDICT: PASS`, B15 |
| this folder | `make new` | `caught`, 50 UVM_ERROR | `VERDICT: PASS`, B08 |

## Build and run times

| What | Time |
|---|---|
| first build of the starter, empty ccache | 135 s |
| rebuild of the starter after adding the Part 5 assertions | 141 s |
| rebuild after the Part 5 sequences | 133 s |
| rebuild after the Part 6 sequence | 129 s |
| first build of this folder, ccache warm from the lab folder | 31 s |
| `router_all_test` | 5.8 to 6.5 s |
| `router_reset_test`, `router_saturate_test` | 0.46 s, 0.40 s |
| `make regress`: starter (90 runs), lab folder with these files (110 runs), this folder | 2 min 33 s, 2 min 44 s, 2 min 43 s |
| `make check-all`: starter, with these files | 62 s; 58 to 66 s |
| `make hunt`, `make verdict` | about 6 s, about 12 s |
