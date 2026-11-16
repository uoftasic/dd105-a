# Lab 05: the solution

The three files the lab asks for, finished. The `Makefile` here builds them with every other file
from `../tb/`, so this folder needs no copy of the rest of the testbench.

| File | Part | What it adds to the starter |
|---|---|---|
| `tb/router_sva.sv` | 2 | `a_O1`, `a_O2` and `a_O6` in `router_sva_out`, one instance per output |
| `tb/stream_pkg.sv` | 3 | the sink driver's wait countdown and its `rdy` decision |
| `tb/router_seq_pkg.sv` | 4 | `router_lab05_vseq::body()` |

```bash
make                 # build if needed, then run router_test
make check-all       # router_test against B12, B10 and B11
make clean
```

## Results

Measured in the course image (Verilator 5.050) with 2 CPUs and 3 GB, seed 1 unless a row says
otherwise.

`make check-all`, seeds 1 to 5:

| Seed | golden | B12 | B10 | B11 |
|---|---|---|---|---|
| 1 | ok, 3.0 s | 50 UVM_ERROR, 37 assertions | 50 UVM_ERROR, 45 assertions | 23 UVM_ERROR, 19 assertions |
| 2 | ok, 3.2 s | 50 UVM_ERROR, 8 assertions | 50 UVM_ERROR, 26 assertions | 35 UVM_ERROR, 29 assertions |
| 3 | ok, 3.0 s | 50 UVM_ERROR, 39 assertions | 50 UVM_ERROR, 71 assertions | 27 UVM_ERROR, 21 assertions |
| 4 | ok, 3.0 s | 50 UVM_ERROR, 47 assertions | 50 UVM_ERROR, 35 assertions | 27 UVM_ERROR, 22 assertions |
| 5 | ok, 3.0 s | 50 UVM_ERROR, 48 assertions | 50 UVM_ERROR, 39 assertions | 23 UVM_ERROR, 18 assertions |

Every row ended `3 of 3 caught.` The first check that fired on seed 1:

| Bug | First check | Cycle |
|---|---|---|
| B12 `out1_uses_out0_ready` | `u_out1.a_O1` (the scoreboard follows in cycle 91) | 33 |
| B10 `output_reloads_while_stalled` | `u_out0.a_O2`, and the scoreboard in the same cycle | 56 |
| B11 `cut_packet_has_no_last` | `u_out0.a_O6`, and the scoreboard in the same cycle | 2258 |

`make seeds` (router_test, golden, seeds 1 to 10): `10 ok  (10 runs)`, 2.9 to 3.4 s each.
`make regress SEEDS="1 2 3 4 5"` (both tests): `10 ok  (10 runs)`.

Every bug in the catalogue, `make check-all BUG_LIST="B01 ... B15"`, seed 1:

| Bug | Starter | Solution |
|---|---|---|
| B01 to B04 | MISSED | MISSED |
| B05, B06, B08, B09 | caught, 50 UVM_ERROR | caught, 50 UVM_ERROR |
| B07 | caught, 2 UVM_ERROR (two `DROP_CNT` reads) | caught, 2 UVM_ERROR |
| B10 | caught, 50 UVM_ERROR | caught, 50 UVM_ERROR, 45 assertions |
| B11 | MISSED | caught, 23 UVM_ERROR, 19 assertions |
| B12 | MISSED | caught, 50 UVM_ERROR, 37 assertions |
| B13 | caught, 27 UVM_ERROR | caught, 50 UVM_ERROR |
| B14, B15 | MISSED | MISSED |

The starter catches 7 of 15 and the solution 9 of 15. B01 to B04 and B14 are Lab 06's bugs and
B15 is Lab 07's. Nothing in this testbench reads `ID`, `CTRL`, `INT_EN` or a `ROUTE` register,
writes `STATUS` or `INT_EN`, checks `irq`, uses a bad address, or resets with traffic in flight.

## Build and run times

| What | Time |
|---|---|
| cold build, empty ccache | 124 s |
| first build of the starter | 118 s |
| rebuild after adding the assertions (`router_sva.sv`) | 119 s |
| rebuild after finishing the sink driver (`stream_pkg.sv`) | 34 s |
| rebuild after writing the virtual sequence (`router_seq_pkg.sv`) | 115 s |
| rebuild after adding one line (and its comment) to `router_test_pkg.sv` | 30 s |
| `router_test`, starter / solution | 1.5 s / 3.0 s |
| `make check-all`, starter / solution | 10.3 s / 7.1 s |
