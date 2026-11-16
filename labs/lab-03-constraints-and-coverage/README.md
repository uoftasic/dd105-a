# Lab 03: Constraints and coverage

Writeup: [`docs/labs/lab-03-constraints-and-coverage-overview.md`](../../docs/labs/lab-03-constraints-and-coverage-overview.md)

The class testbench from Lab 02 on the packet router, with the router's planted bugs behind a
run-time switch. You give it a covergroup, constrain its packet, and write the stimulus that
reaches two coverage holes.

Run it in the course image, from this folder:

```bash
make build                         # the simulator (about 95 s the first time)
make run                           # router_rand_test on the golden router
make cov                           # every coverage.dat under build/runs, merged, bin by bin
make traps                         # the constraint experiments in traps/traps.sv (under 15 s)
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
| `make run` | run `UVM_TESTNAME` (default `router_rand_test`) once and print a verdict |
| `make waves` | the same run, writing `build/runs/<run>/waves.fst` |
| `make tests` | list the tests: `router_rand_test`, `router_fill_test` |
| `make cov` | merge every `coverage.dat` under `build/runs` and list the covergroup bins |
| `make check` | the test must pass the golden router and fail on `BUG` (default `B07`) |
| `make check-all` | the same against B07 and B08 |
| `make seeds` | `UVM_TESTNAME` on seeds 1 to 10 (`SEEDS="1 2 3"` for others) |
| `make clean` | remove `build/` |
| `make help` | every target and the current variables |

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `UVM_TESTNAME` | `router_rand_test` | `router_rand_test`: four phases of random packets, then `close_holes()`; `router_fill_test`: `close_holes()` alone |
| `PLUSARGS` | empty | `+N=<n>` packets per phase (default 200), `+PHASES=<n>` (default 4) |
| `SEED` | `1` | the run's seed, for `make run` and `make traps` |
| `BUG` | empty | `B07` or `B08` (or any of `B01` to `B15`); empty runs the golden router |

[`../common/README.md`](../common/README.md) lists the rest.

## Files

| File | What it is |
|---|---|
| `tb/packet.svh` | the input packet and its randomization; Part 3 adds the constraints |
| `tb/coverage.svh` | the coverage class the scoreboard samples once per packet; Part 2 adds the covergroup |
| `tb/router_test_pkg.sv` | the tests and their helpers; Part 4 fills in `close_holes()` |
| `tb/items.svh` | what the monitors report, and `router_pkt_info`, one record per packet |
| `tb/drivers.svh` | the APB master, the source, and a sink with a `stall` knob for each output |
| `tb/monitors.svh` | a monitor for each stream, the APB bus, and reset and `irq` |
| `tb/model.svh` | the router as the specification describes it, one cycle at a time |
| `tb/scoreboard.svh` | runs the model on what the monitors saw and reports every difference |
| `tb/env.svh` | creates the pieces, connects their mailboxes and starts them |
| `tb/router_tb_pkg.sv` | the package that includes the `.svh` files above |
| `tb/apb_if.sv`, `tb/stream_if.sv`, `tb/router_sys_if.sv` | the interfaces and their clocking blocks |
| `tb/router_tb_top.sv` | the clock, the interfaces, the router and `run_test()` |
| `traps/traps.sv` | the constraint experiments behind `make traps` |
| `solutions/` | the reference solution; see [`solutions/README.md`](solutions/README.md) |
| `Makefile` | the lab's settings, `include ../common/uvm.mk`, and `make traps` |

The router itself, with every planted bug behind `+BUG`, is built from `../common/rtl/` by
`../common/inject.py` into `build/rtl/`.
