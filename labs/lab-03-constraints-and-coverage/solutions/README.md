# Lab 03: reference solution

Open this after `make check-all` prints `2 of 2 caught.` with your own files, or when you're
stuck on a part.

| File | Replaces | What it adds |
|---|---|---|
| `coverage.svh` | `tb/coverage.svh` | `cg_pkt`, a covergroup written `with function sample`, and its `sample()` call (Part 2) |
| `packet.svh` | `tb/packet.svh` | weights 20/50/20/10 on `kind` as a `dist` with numbers, and `len` solved from `kind` (Part 3) |
| `router_test_pkg.sv` | `tb/router_test_pkg.sv` | `fill_plan` and `close_holes()` (Part 4) |

Everything else in `tb/` is the same as the starter. Compare a file with yours with, for example:

```bash
diff tb/packet.svh solutions/packet.svh
```

To run the solution, keep a copy of your files outside `tb/` and put the solution's in their place:

```bash
mkdir -p mine && cp tb/coverage.svh tb/packet.svh tb/router_test_pkg.sv mine/
cp solutions/coverage.svh solutions/packet.svh solutions/router_test_pkg.sv tb/
make check-all
cp mine/* tb/
```

Each swap rebuilds the simulator. With a warm ccache the solution built in 95 s and in 105 s, the two
times we measured on 2 CPUs.

## The covergroup

| Coverpoint | Bins |
|---|---|
| `cp_len` | `len1` to `len8`, `oversize` (9 or more beats accepted) |
| `cp_dst` | `dst0` to `dst3` |
| `cp_fate` | `noroute`, `full`, `out0`, `out1` |
| `cp_level` | `empty` (0), `low` (1 to 7), `at_8`, `at_9`, `high` (10 to 16) |
| `x_fate_level` | `cp_fate` crossed with `cp_level`: 20 bins |

Seven of the cross's bins can't be hit: a FULL drop happens only at a level of 9 or more
(`full_x_empty`, `full_x_low`, `full_x_at_8`), and a packet is admitted only at 8 or less
(`out0_x_at_9`, `out0_x_high`, `out1_x_at_9`, `out1_x_high`). So the most this covergroup can
report is 35 of 42 bins.

## `close_holes()`

For each output in turn: `ROUTE0` enabled to it and `ROUTE1` disabled with `PORT` naming it,
`INT_EN` = `0x2` (FULL only), its sink stalled, and then

| Packets | Fate in the golden router | Bin |
|---|---|---|
| a `fill_plan`: 1 to 8 packets for DST 0 whose lengths add up to 8, made with `packet::make()` | admitted at levels 0 to 7 | `out*_x_empty`, `out*_x_low` |
| one random packet for DST 0 | admitted at level 8 | `out0_x_at_8` or `out1_x_at_8` (B08's hole) |
| one random packet for DST 1 | NOROUTE at level 9 to 16 | `noroute_x_at_9` or `noroute_x_high` (B07's hole) |
| one random packet for DST 0 | FULL | `full_x_at_9` or `full_x_high` |

`STATUS`, `DROP_CNT` and `LEVEL` are read once the packets are in and again after the output
drains. The scoreboard checks those reads and `irq`, so `close_holes()` itself checks nothing.

## Results

Measured on the course image with 2 CPUs and 3 GB:

| Run | Result |
|---|---|
| `make seeds SEEDS="1 2 3 4 5"` | `5 ok  (5 runs)`, 1.4 s each |
| `make check-all`, seed 1 | golden `ok`; B07 caught with 6 `UVM_ERROR`, B08 with 15; `2 of 2 caught.` |
| `make check-all`, seeds 2 to 5 | `2 of 2 caught.` on each, with the same counts |
| `make run UVM_TESTNAME=router_fill_test` | `ok`, 0.07 s |
| `make cov` over `router_fill_test` and `router_rand_test`, seed 1 | `covergroup : 81.0% (34/42)`; the 8 empty bins are the 7 above and `noroute_x_at_8` |

The first check to fire on each bug, seed 1:

| Bug | First error |
|---|---|
| B07 | `irq is 1 from cycle 6155, but STATUS = 001 and INT_EN = 010 make it 0` |
| B08 | `irq is 1 from cycle 6152, but STATUS = 000 and INT_EN = 010 make it 0` |

Against the whole catalogue (`make check-all BUG_LIST="B01 ... B15"`, seed 1) the solution
catches 11 of 15; it misses B01, B03, B04 and B15. The starter catches 6 of 15: B02, B05, B06,
B09, B11 and B14.
