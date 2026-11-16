# Lab 03: Constraints and coverage

Writeup: [`docs/labs/lab-03-constraints-and-coverage-overview.md`](../../docs/labs/lab-03-constraints-and-coverage-overview.md)

This is the class testbench from Lab 02, with Lab 02's solution in `tb/monitor.svh` and
`tb/scoreboard.svh` and new pieces around it: packets that `randomize()` makes, a sink that can
stall, an APB read, a tracker that follows output 0's level and predicts each packet's fate, and a
check that compares `DROP_CNT` with the tracker. You write a covergroup, constrain the packet, and
write the stimulus that reaches two coverage holes, where B07 and B08 hide.

Run it in the course image, from this folder:

```bash
make build                         # the simulator (94 to 110 s the first time, on 2 CPUs)
make run                           # router_rand_test on the golden router
make cov                           # every coverage.dat under build/runs, merged, bin by bin
make traps                         # the constraint experiments in traps/traps.sv (under 10 s)
make check-all                     # router_rand_test on the golden router, B07 and B08
make clean                         # remove build/ (the ccache at the top of the clone stays)
```

## Targets

This lab's own target:

| Target | What it does |
|---|---|
| `make traps` | builds and runs `traps/traps.sv` with plain Verilator, no UVM; prints one line per experiment and the number of UNSATCONSTR warnings, which go to `build/traps/run.log` |

and the targets from [`../common/uvm.mk`](../common/README.md), the ones this lab uses:

| Target | What it does |
|---|---|
| `make build` | build the simulator if a source changed |
| `make lint` | the sources through Verilator's front end only: syntax errors in seconds, without a build |
| `make run` | run `UVM_TESTNAME` (default `router_rand_test`) once and print a verdict |
| `make waves` | the same run, writing `build/runs/<run>/waves.fst` |
| `make tests` | list the tests |
| `make cov` | merge every `coverage.dat` under `build/runs` and list the covergroup bins |
| `make check` | the test must pass the golden router and fail on `BUG` (default `B07`) |
| `make check-all` | the same against B07 and B08 |
| `make seeds` | `UVM_TESTNAME` on seeds 1 to 10 (`SEEDS="1 2 3"` for others) |
| `make clean` | remove `build/` |
| `make help` | every target and the current variables |

## Tests, variables and plusargs

| Test | What it does |
|---|---|
| `router_rand_test` | `CTRL.EN`, then four phases of 200 random packets, each with its own random routing table and a `DROP_CNT` check; then `close_holes()` and a last `DROP_CNT` check. `make check` grades this one. |
| `router_fill_test` | `close_holes()` on its own. Until you write `close_holes()` it sends nothing, and it fails on the golden router, because the scoreboard reports a test that checked no packet. |
| `router_class_test` | Lab 02's test: 100 random packets on the routing table `+ROUTES` gives, and a `DROP_CNT` check |

| Variable | Default | Meaning |
|---|---|---|
| `UVM_TESTNAME` | `router_rand_test` | one of the tests above |
| `SEED` | `1` | the run's seed, for `make run` and `make traps` |
| `BUG` | empty | `B07` or `B08` (or any of `B01` to `B15`); empty runs the golden router |
| `PLUSARGS` | empty | the knobs below |

The Makefile adds `+verilator+error+limit+100` to every run, as Lab 02's did, so a run goes on
after the first `$error` and stops at the 100th.

| Plusarg | Default | Meaning |
|---|---|---|
| `+N=<n>` | `200` in `router_rand_test` (per phase), `100` in `router_class_test` | packets to send |
| `+PHASES=<n>` | `4` | `router_rand_test`'s phases |
| `+ROUTES=<abcd>` | `0110` | `router_class_test`'s routing table: `0` or `1` is the output, `-` is disabled |
| `+SHOW=<n>` | `0` | each monitor prints the first `n` packets it sees |

Lab 02's `+DSTS` and `+LEN` are gone: the packet's constraints choose the DST and the length.

[`../common/README.md`](../common/README.md) lists the rest.

## Files

| File | What it is |
|---|---|
| `tb/packet.svh` | `packet` and `router_cfg` from Lab 02, and `rand_packet`, whose DST and length come from `randomize()`. Part 3 adds its constraints. |
| `tb/generator.svh` | `generator`: randomizes `rand_packet`s and gives each header its sequence number |
| `tb/driver.svh` | Lab 02's `driver`, `sink` and `apb_master`, with a `stall` knob on the sink and `apb_master.read()` |
| `tb/monitor.svh`, `tb/scoreboard.svh` | Lab 02's solution, unchanged; your own Lab 02 files work here too |
| `tb/tracker.svh` | `tracker`: output 0's level, each packet's fate, and the drops `DROP_CNT` should count; `pkt_fate`, the record it hands to the coverage |
| `tb/coverage.svh` | `router_coverage`, which the tracker samples once per packet. Part 2 adds its covergroup. |
| `tb/env.svh` | `env`: builds the pieces and runs the steps a test calls, `check_drops()` among them |
| `tb/router_tb_pkg.sv` | the package that includes the `.svh` files above |
| `tb/router_test_pkg.sv` | the three tests. Part 4 adds `fill_plan` and `close_holes()`. |
| `tb/apb_if.sv`, `tb/stream_if.sv`, `tb/router_tb_top.sv` | Lab 02's interfaces and top module |
| `traps/traps.sv` | the constraint experiments behind `make traps` |
| `solutions/` | the reference solution; see [`solutions/README.md`](solutions/README.md) |
| `Makefile` | the lab's settings, `include ../common/uvm.mk`, and `make traps` |

The router itself, with every planted bug behind `+BUG`, is built from `../common/rtl/` by
`../common/inject.py` into `build/rtl/`.
