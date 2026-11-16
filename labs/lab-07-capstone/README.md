# Lab 07: Capstone

The writeup is [`docs/labs/lab-07-capstone-overview.md`](../../docs/labs/lab-07-capstone-overview.md).
This folder is the router's full UVM environment with the parts about reset with traffic in
flight, and about counter saturation, left for you to write. You also write a verification plan
and a verification report, from the two templates here, and keep all of it in a GitHub
repository of your own.

## Running it

From this folder, in the course image:

```bash
make                                      # build if needed, then run router_all_test
make regress                              # every test in TESTS on seeds 1 to 10, then the coverage
make new && make hunt && make verdict     # a mystery bug from all 15 in the catalogue
make run UVM_TESTNAME=router_reset_test   # your Part 5 sequence on its own
make check-all                            # router_all_test on the golden design and on all 15 bugs
make clean
```

The Makefile sets `PLUSARGS` to `+verilator+error+limit+100000`, so every failing assertion
prints and the run goes on (the simulator's default error limit is 1, which ends the run at the
first one). If you set `PLUSARGS` on the command line, put that plusarg in it too.

`router_reset_test` and `router_saturate_test` run sequences whose bodies are empty until you
write them, so they fail on the golden design with `nothing was checked`. They aren't in `TESTS`
until you add them.

## Make targets

`labs/common/README.md` has every target and variable. The ones this lab uses:

| Target | What it does |
|---|---|
| `make` | build if needed, then run `router_all_test` |
| `make run` | one run; `UVM_TESTNAME`, `SEED`, `BUG` and `PLUSARGS` pick it |
| `make waves` | the same run, writing `waves.fst` into the run folder |
| `make regress` | every test in `TESTS` on every seed in `SEEDS` (1 to 10), then the coverage of those runs |
| `make seeds` | `UVM_TESTNAME` on every seed in `SEEDS` |
| `make cov` | merge the `coverage.dat` of every run in `build/runs` and list the bins |
| `make new` | deal a mystery bug from the whole catalogue, sealed in `.hunt` |
| `make hunt` | `router_all_test` against the mystery bug; `VERBOSE=1` prints the log |
| `make verdict` | the hunt's grade: pass on the golden design, fail on the mystery bug |
| `make reveal` | give up, and be told which bug it was |
| `make check-all` | `router_all_test` against the golden design and every bug in the catalogue |
| `make clean` | remove `build/` (the ccache stays) |

## Files

| File | What it is | Edit it? |
|---|---|---|
| `Makefile` | the sources and `TESTS`; includes `../common/uvm.mk` | Parts 5 and 6: add two tests to `TESTS` |
| `PLAN-template.md` | the verification plan, with the specification's rules as rows | copy to `PLAN.md` (Part 2) |
| `REPORT-template.md` | the verification report | copy to `REPORT.md` (Part 4), fill in (Part 8) |
| `tb/router_sva.sv` | assertions for the stream and APB rules, each with a failure counter | Part 5: the reset rules |
| `tb/router_seq_pkg.sv` | the virtual sequences, and `router_all_vseq`, which runs them all | Part 5: `router_reset_vseq` and the random resets; Part 6: `router_saturate_vseq` |
| `tb/router_test_pkg.sv` | one test per virtual sequence, and the base test with its watchdog | no |
| `tb/router_env_pkg.sv` | the reset/irq agent, the reference model, the scoreboard, the coverage, the virtual sequencer, the environment | no |
| `tb/router_ral_pkg.sv` | the register model and its adapter | no |
| `tb/apb_pkg.sv`, `tb/stream_pkg.sv` | the APB agent; the source agent, the reactive sink agent and the stream monitor | no |
| `tb/apb_if.sv`, `tb/stream_if.sv`, `tb/router_sys_if.sv` | the interfaces and their clocking blocks | no |
| `tb/router_sva_bind.sv`, `tb/router_tb_top.sv` | the `bind` for the assertions; the clock, the interfaces, the router and `run_test()` | no |
| `solutions/` | the finished files, a filled-in plan and an example report; see `solutions/README.md` | |

Everything in `tb/` except the parts marked `TODO` is the course's reference environment
(`labs/ref`).
