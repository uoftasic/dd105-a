# Lab 05: Protocol rules and backpressure

Writeup: [`docs/labs/lab-05-protocol-rules-and-backpressure-overview.md`](../../docs/labs/lab-05-protocol-rules-and-backpressure-overview.md)

Our solution to Lab 04, with this lab's pieces added: assertions bound into the router, an output
agent whose driver can answer each beat from a sequence, a virtual sequencer and its sequences,
and an oversize length kind in the packet, switched off until a sequence gives it a weight. Three
pieces are left for you, marked `TODO (Part n)`: three assertions, the sink driver's answer to a
beat, and the virtual sequence's body. The router and its planted bugs come from
[`../common`](../common/README.md).

Run it in the course image, from this folder:

```bash
make build                                   # the simulator (106 s the first time, on 2 CPUs)
make run                                     # router_test on the golden router
make run BUG=B10                             # the same run with planted bug B10 on
make run UVM_TESTNAME=router_lab05_test      # your Part 4 virtual sequence on its own
make check-all                               # pass on the golden router, fail on B11, B10 and B12
make clean                                   # remove build/ (the ccache at the top of the clone stays)
```

The Makefile sets `PLUSARGS` to `+verilator+error+limit+100000`, so every failing assertion
prints and the run goes on. The simulator's default error limit is 1, which ends the run at the
first failing assertion; `make run BUG=B10 PLUSARGS=` shows that.

`router_lab05_test` runs `router_lab05_vseq` alone. Until you write that sequence's body it sends
nothing, so the test fails on the golden router ("nothing was checked"), and so does
`make regress`, which runs every test in `TESTS`.

## Tests

| Test | What it does |
|---|---|
| `router_test` | `router_inject_test`, then `router_lab05_vseq` (Part 4); `make check` and `make check-all` grade this one |
| `router_lab05_test` | `router_lab05_vseq` on its own |
| `router_sink_test` | `router_rand_test` with both sinks in `SNK_RANDOM`, each beat answered by an item (Part 3) |
| `router_inject_test` | Lab 04's: `router_stall_test` with `router_noroute_pkt` swapped in by a factory override |
| `router_stall_test` | Lab 04's: `router_rand_test` with one output stalled in each phase |
| `router_rand_test` | Lab 03's: `CTRL.EN`, four phases of 200 random packets with a `DROP_CNT` check each, then `close_holes()` and a last check |
| `router_fill_test` | Lab 03's `close_holes()` on its own |
| `router_class_test` | Lab 02's: 100 random packets on the routing table `+ROUTES` gives |

The plusargs are Lab 04's: `+N`, `+PHASES`, `+ROUTES` and `+MAX_CYCLES`; `tb/router_tests_pkg.sv`
lists them with their defaults.

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
| `make cov` | the coverage of every run in `build/runs`; `rm -rf build/runs` first to see one run's |
| `make check` | the test must pass the golden router and fail on `BUG` (default `B11`) |
| `make check-all` | the same against B11, B10 and B12 (`BUG_LIST`) |
| `make seeds` | `UVM_TESTNAME` on seeds 1 to 10 (`SEEDS="1 2 3 4 5"` for fewer) |
| `make regress` | every test on every seed in `SEEDS`, then their coverage |
| `make clean` | remove `build/` |
| `make help` | every target and the current variables |

## Files

| File | What it is | Edit it? |
|---|---|---|
| `tb/router_sva.sv` | the assertions for the stream rules, each with a failure counter | Part 2: `a_O1`, `a_O2`, `a_O6` |
| `tb/router_sva_bind.sv` | the `bind` that puts `router_sva` into every `router` | no |
| `tb/router_ifs.sv` | Lab 04's three interfaces, and `router_sva_if` for the assertions' failure count | no |
| `tb/router_agents_pkg.sv` | the packet, and the input, output and APB agents with their sequences | Part 3: `out_ready_driver` |
| `tb/router_env_pkg.sv` | the scoreboard, the coverage (`cg_pkt`, `cg_wait`), the virtual sequencer and the environment | no |
| `tb/router_vseq_pkg.sv` | `router_base_vseq`, the steps a virtual sequence uses, and `router_lab05_vseq` | Part 4: `router_lab05_vseq::body()` |
| `tb/router_tests_pkg.sv` | Lab 02's, Lab 03's and Lab 04's tests, and this lab's three | no |
| `tb/router_tb_top.sv` | the clock, the reset, the router, the assertion count and `run_test()` | no |
| `src/loc.py` | the line counter behind `make loc` | no |
| `solutions/` | the three files with the TODOs filled in; see [`solutions/README.md`](solutions/README.md) | |
| `Makefile` | the lab's settings, `include ../common/uvm.mk`, and `make loc` | no |
