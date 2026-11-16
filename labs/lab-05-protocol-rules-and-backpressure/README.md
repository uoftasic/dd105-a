# Lab 05: Protocol rules and backpressure

The writeup is [`docs/labs/lab-05-protocol-rules-and-backpressure-overview.md`](../../docs/labs/lab-05-protocol-rules-and-backpressure-overview.md).
This folder is the router testbench as Lab 04 leaves it, with three files to finish: the
assertions, the sink driver and a virtual sequence.

## Running it

From this folder, in the course image:

```bash
make                                      # build if needed, then run router_test
make run BUG=B10                          # the same run with planted bug B10 on
make run UVM_TESTNAME=router_lab05_test   # your Part 4 virtual sequence on its own
make check-all                            # router_test on the golden design and on B12, B10, B11
make clean
```

The Makefile sets `PLUSARGS` to `+verilator+error+limit+100000`, so every failing assertion
prints and the run goes on. The simulator's default error limit is 1, which ends the run at the
first failing assertion; `make run BUG=B10 PLUSARGS=` shows that.

`router_lab05_test` runs `router_lab05_vseq` alone. Until you write that sequence's body it sends
nothing, so the test fails on the golden design ("nothing was checked"), and so does `make regress`,
which runs every test in `TESTS`.

## Make targets

`labs/common/README.md` has every target and variable. The ones this lab uses:

| Target | What it does |
|---|---|
| `make` | build if needed, then run `router_test` |
| `make run` | one run; `UVM_TESTNAME`, `SEED`, `BUG` and `PLUSARGS` pick it |
| `make waves` | the same run, writing `waves.fst` into the run folder |
| `make cov` | merge the `coverage.dat` of every run in `build/runs` and list the bins |
| `make check` | `router_test` passes the golden design and fails on `BUG` (default B12) |
| `make check-all` | the same against B12, B10 and B11 |
| `make seeds` | `router_test` on seeds 1 to 10, or `SEEDS="..."` |
| `make clean` | remove `build/` (the ccache stays) |

## Files

| File | What it is | Edit it? |
|---|---|---|
| `Makefile` | the sources, the tests, `BUG_LIST` and `PLUSARGS`; includes `../common/uvm.mk` | no |
| `tb/router_sva.sv` | assertions for the stream rules, each with a failure counter | Part 2: O1, O2, O6 |
| `tb/router_sva_bind.sv` | the `bind` that puts `router_sva` into every `router` | no |
| `tb/stream_pkg.sv` | the source and sink agents, the stream monitor and their sequences | Part 3: the sink driver's decision |
| `tb/router_seq_pkg.sv` | the virtual sequences: helpers, Lab 04's steps, this lab's, and both together | Part 4: `router_lab05_vseq` |
| `tb/router_test_pkg.sv` | `router_test` and `router_lab05_test` | no |
| `tb/router_env_pkg.sv` | the reset agent, the reference model, the scoreboard, the coverage, the virtual sequencer, the environment | no |
| `tb/apb_pkg.sv` | the APB agent | no |
| `tb/apb_if.sv`, `tb/stream_if.sv`, `tb/router_sys_if.sv` | the interfaces and their clocking blocks | no |
| `tb/router_tb_top.sv` | the clock, the interfaces, the router and `run_test()` | no |
| `solutions/` | the three finished files; see `solutions/README.md` | |
