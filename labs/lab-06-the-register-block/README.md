# Lab 06: The register block

Writeup: [`docs/labs/lab-06-the-register-block-overview.md`](../../docs/labs/lab-06-the-register-block-overview.md)

This package is our solution to Lab 05, with this lab's pieces added: a register model of the
router's ten registers with its adapter and predictor, a monitor that reports `rst_n` and `irq`
every cycle, and scoreboard checks on `STATUS` reads, on `PSLVERR` and on reads of bad addresses.
Five pieces are left for you, marked `TODO (Part n)`: the fields of four registers, the adapter, the
predictor's connections, the `irq` check, and this lab's virtual sequence. The router and its
planted bugs come from [`../common`](../common/README.md).

Run it in the course image, from this folder:

```bash
make build                                   # the simulator (127 s the first time, on 2 CPUs)
make run                                     # router_test on the golden router
make run BUG=B14                             # the same run with planted bug B14 on
make run UVM_TESTNAME=router_lab06_test      # your virtual sequence on its own
make run UVM_TESTNAME=router_backdoor_test   # what peek and poke do (Part 6)
make check-all                               # pass on the golden router, fail on B01, B02, B03, B04 and B14
make clean                                   # remove build/ (the ccache at the top of the clone stays)
```

The Makefile sets `PLUSARGS` to `+verilator+error+limit+100000`, so every failing assertion
prints and the run goes on. If you give `PLUSARGS` yourself, include that plusarg too.

`router_lab06_test` runs `router_lab06_vseq` alone. Until you write that sequence's steps it sends
nothing and reads nothing, so the test fails on the golden router ("nothing was checked"), and so
does `make regress`, which runs every test in `TESTS`.

## Tests

| Test | What it does |
|---|---|
| `router_test` | `router_lab06_vseq` (Parts 2 to 5), then `router_inject_test`, then `router_lab05_vseq`; `make check` and `make check-all` grade this one |
| `router_lab06_test` | `router_lab06_vseq` on its own: the first part of `router_test`, cycle for cycle |
| `router_backdoor_test` | peeks and pokes through the register model's HDL paths; `+BACKDOOR_READBACK` adds a front-door read of a poked register |
| `router_lab05_test` | Lab 05's: `router_lab05_vseq` on its own |
| `router_sink_test` | Lab 05's: `router_rand_test` with both sinks in `SNK_RANDOM` |
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
| `make lint` | the sources through Verilator's front end only: syntax errors in seconds, without a build |
| `make run` | run `UVM_TESTNAME` once and print a verdict |
| `make waves` | the same run, writing `build/runs/<run>/waves.fst` |
| `make check` | the test must pass the golden router and fail on `BUG` (default `B01`) |
| `make check-all` | the same against B01, B02, B03, B04 and B14 (`BUG_LIST`) |
| `make seeds` | `UVM_TESTNAME` on seeds 1 to 10 (`SEEDS="1 2 3 4 5"` for fewer) |
| `make regress` | every test on every seed in `SEEDS`, then their coverage |
| `make clean` | remove `build/` |
| `make help` | every target and the current variables |

## Files

| File | What it is | Edit it? |
|---|---|---|
| `tb/router_ral_pkg.sv` | the register model and its adapter | Part 2: the fields of `STATUS`, `DROP_CNT`, `LEVEL` and `ROUTEn`, and the adapter |
| `tb/router_env_pkg.sv` | the scoreboard, with its model of `STATUS` and `INT_EN`; the coverage; the virtual sequencer; the environment, which makes the register model, the adapter and the predictor | Part 3: the predictor's connections; Part 5: the `irq` check |
| `tb/router_vseq_pkg.sv` | `router_base_vseq` and its helpers, `router_lab05_vseq`, `router_lab06_vseq` and `router_backdoor_vseq` | Parts 2 to 5: `router_lab06_vseq::body()` |
| `tb/router_agents_pkg.sv` | the packet, the input, output and APB agents with their sequences, and the sys monitor | no |
| `tb/router_ifs.sv` | Lab 05's four interfaces, and `router_sys_if` for `rst_n` and `irq` | no |
| `tb/router_tests_pkg.sv` | Lab 02's to Lab 05's tests, `router_test`, and this lab's two | no |
| `tb/router_sva.sv`, `tb/router_sva_bind.sv` | Lab 05's assertions and the `bind` that puts them in the router | no |
| `tb/router_tb_top.sv` | the clock, the reset, the router, and `run_test()` | no |
| `tb/router_regs.vlt` | marks the five register signals the back door reaches as public, so VPI can find them | no |
| `src/loc.py` | the line counter behind `make loc` | no |
| `solutions/` | the three files with the TODOs filled in; see [`solutions/README.md`](solutions/README.md) | |
| `Makefile` | the lab's settings, `include ../common/uvm.mk`, and `make loc` | no |
