# Lab 04: The same testbench in UVM

Writeup: [`docs/labs/lab-04-the-same-testbench-in-uvm-overview.md`](../../docs/labs/lab-04-the-same-testbench-in-uvm-overview.md)

Our solution to Lab 03, ported to UVM: an agent for the input stream, one for the APB port, and
one output agent class that the environment makes once per output, with a scoreboard (Lab 03's
scoreboard and tracker in one class) and Lab 03's covergroup as a subscriber, fed by analysis
ports. The packet's constraints, the covergroup, `fill_plan` and `close_holes()` are Lab 03's.
Four pieces are left for you, marked `TODO (Part n)`: the second output agent, two lines of the
scoreboard, the stall test and the factory override. The router and its planted bugs come from
[`../common`](../common/README.md).

Run it in the course image, from this folder:

```bash
make build                                   # the simulator (116 s the first time, on 2 CPUs)
make run                                     # router_inject_test on the golden router
make run UVM_TESTNAME=router_class_test      # another test, no rebuild
make check-all                               # pass on the golden router, fail on B06 and B13
make clean                                   # remove build/ (the ccache at the top of the clone stays)
```

## Tests

| Test | What it does |
|---|---|
| `router_inject_test` | `router_stall_test` with `router_noroute_pkt` swapped in by a factory override; `make check` and `make check-all` grade this one (Part 4) |
| `router_stall_test` | `router_rand_test` with one output stalled in each phase (Part 3) |
| `router_rand_test` | Lab 03's test: `CTRL.EN`, then four phases of 200 random packets, each with its own random routing table and a `DROP_CNT` check; then `close_holes()` and a last `DROP_CNT` check |
| `router_fill_test` | Lab 03's `close_holes()` on its own |
| `router_class_test` | Lab 02's test: 100 random packets on the routing table `+ROUTES` gives, and a `DROP_CNT` check |

Plusargs the tests read:

| Plusarg | Default | Meaning |
|---|---|---|
| `+N=<n>` | 200 (100 in `router_class_test`) | packets in each phase of `router_rand_test` and the tests built on it, or in all of `router_class_test` |
| `+PHASES=<n>` | 4 | phases, each with its own routing table |
| `+ROUTES=<abcd>` | `0110` | `router_class_test`'s routing table: `0` or `1` is the output, `-` is disabled |
| `+MAX_CYCLES=<n>` | 200000 | a watchdog: a test still running after this many cycles ends with `UVM_ERROR [WATCHDOG]` |

## Targets

This lab's own target:

| Target | What it does |
|---|---|
| `make loc` | lines and code lines in the testbench files; `FILES="..."` counts another testbench beside it |

and the targets from [`../common/uvm.mk`](../common/README.md) that the writeup uses:

| Target | What it does |
|---|---|
| `make build` | build the simulator if a source changed |
| `make run` | run `UVM_TESTNAME` once and print a verdict |
| `make waves` | the same run, writing `build/runs/<run>/waves.fst` |
| `make tests` | list the tests |
| `make check` | the test must pass the golden router and fail on `BUG` (default `B06`) |
| `make check-all` | the same against B06 and B13 (`BUG_LIST`) |
| `make seeds` | `UVM_TESTNAME` on seeds 1 to 10 (`NSEEDS=5`: 1 to 5) |
| `make regress` | every test on every seed in `SEEDS`, then their coverage |
| `make cov` | the coverage of every run in `build/runs` |
| `make clean` | remove `build/` |
| `make help` | every target and the current variables |

`make cov` merges every run in `build/runs`, including runs from before your last rebuild. If an
edit moved the covergroup's lines, the old runs show each bin a second time, so use
`make regress`, which reports only its own runs, or `rm -rf build/runs` first.

## Files

| File | What it is |
|---|---|
| `tb/router_ifs.sv` | the three interfaces: `apb_if`, `stream_src_if` (input), `stream_snk_if` (an output) |
| `tb/router_agents_pkg.sv` | the packet (`router_pkt`, Lab 03's `rand_packet` with its constraints), the input, output and APB agents, and their sequences |
| `tb/router_env_pkg.sv` | the scoreboard, the coverage and the environment; TODOs for Parts 2 and 3 |
| `tb/router_tests_pkg.sv` | Lab 03's `fill_plan`, the base test with `close_holes()` and the other steps a test calls, and the tests; TODOs for Parts 3 and 4 |
| `tb/router_tb_top.sv` | the clock, the reset, the router and `run_test()` |
| `src/loc.py` | the line counter behind `make loc` |
| `solutions/` | the two files with the TODOs filled in; see [`solutions/README.md`](solutions/README.md) |
| `Makefile` | the lab's settings, `include ../common/uvm.mk`, and `make loc` |
