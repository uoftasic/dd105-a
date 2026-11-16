# Lab 04: The same testbench in UVM

Writeup: [`docs/labs/lab-04-the-same-testbench-in-uvm-overview.md`](../../docs/labs/lab-04-the-same-testbench-in-uvm-overview.md)

Lab 03's class testbench for the router, ported to UVM: an agent for the input stream, one for
the APB port, and one output agent class that the environment makes once per output, with a
scoreboard and a coverage subscriber fed by analysis ports. Four pieces are left for you, marked
`TODO (Part n)`: the second output agent, two lines of the scoreboard, the stall test and the
factory override. The router and its planted bugs come from [`../common`](../common/README.md).

Run it in the course image, from this folder:

```bash
make build                                   # the simulator (about 100 s the first time)
make run                                     # router_inject_test on the golden router
make run UVM_TESTNAME=router_smoke_test      # another test, no rebuild
make check-all                               # pass on the golden router, fail on B06 and B13
make clean                                   # remove build/ (the ccache at the top of the clone stays)
```

## Tests

| Test | What it does |
|---|---|
| `router_inject_test` | `router_stall_test` with `router_noroute_pkt` swapped in by a factory override; `make check` and `make check-all` grade this one (Part 4) |
| `router_stall_test` | `router_rand_test` with one output stalled in each phase (Part 3) |
| `router_rand_test` | Lab 03's test: four phases of random routing tables and packets, then Lab 03's two directed steps |
| `router_smoke_test` | Lab 02's test: five packets by hand |

Plusargs the tests read:

| Plusarg | Default | Meaning |
|---|---|---|
| `+N=<n>` | 60 | packets in each phase of `router_rand_test` and the tests built on it |
| `+PHASES=<n>` | 4 | phases, each with its own routing table |
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
| `tb/router_agents_pkg.sv` | the packet, the input, output and APB agents, and their sequences |
| `tb/router_env_pkg.sv` | the scoreboard, the coverage and the environment; TODOs for Parts 2 and 3 |
| `tb/router_tests_pkg.sv` | the tests; TODOs for Parts 3 and 4 |
| `tb/router_tb_top.sv` | the clock, the reset, the router and `run_test()` |
| `src/loc.py` | the line counter behind `make loc` |
| `solutions/` | the two files with the TODOs filled in; see [`solutions/README.md`](solutions/README.md) |
| `Makefile` | the lab's settings, `include ../common/uvm.mk`, and `make loc` |
