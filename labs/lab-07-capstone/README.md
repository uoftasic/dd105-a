# Lab 07: Capstone

Writeup: [`docs/labs/lab-07-capstone-overview.md`](../../docs/labs/lab-07-capstone-overview.md)

Our solution to Lab 06, with this lab's pieces added: a reset driver, a source driver and an APB
driver that know what to do when a reset interrupts them, a scoreboard that follows a reset with
traffic in flight, and four corners in the coverage. Four pieces are left for you, marked
`TODO (Part n)`: the assertions for the rules about reset, the sequence that resets the router
with traffic in flight, the resets in `router_lab07_vseq`'s random phases, and the sequence that
takes both drop counters to 255. You also write a verification plan and a verification report from
the two templates here, and keep all of it in a GitHub repository of your own. The router and its
planted bugs come from [`../common`](../common/README.md).

Run it in the course image, from this folder:

```bash
make build                                   # the simulator (130 s the first time, on 2 CPUs)
make run                                     # router_test on the golden router
make regress                                 # every test in TESTS on seeds 1 to 10, then the coverage
make new && make hunt && make verdict        # a mystery bug from all 15 in the catalogue
make run UVM_TESTNAME=router_reset_test      # your Part 5 sequence on its own
make check-all                               # router_test on the golden router and on all 15 bugs
make clean                                   # remove build/ (the ccache at the top of the clone stays)
```

The Makefile sets `PLUSARGS` to `+verilator+error+limit+100000`, so every failing assertion
prints and the run goes on. If you give `PLUSARGS` yourself, include that plusarg too.

`BUG_LIST` has all 15 bugs, with B15 first, because `make check` grades the first bug in the
list. `make check-all` and the hunts use the whole list.

`router_reset_test` and `router_saturate_test` run sequences whose bodies are empty until you
write them, so they fail on the golden router ("nothing was checked"). They aren't in `TESTS`
until you add them.

## Tests

| Test | What it does |
|---|---|
| `router_test` | `router_lab06_vseq`, then `router_inject_test`'s steps, then `router_lab05_vseq`, then `router_lab07_vseq`; `make check`, `make check-all` and the hunts grade this one |
| `router_lab07_test` | `router_lab07_vseq` on its own: your two sequences (once you add them), then four random phases |
| `router_reset_test` | `router_reset_vseq` on its own (Part 5) |
| `router_saturate_test` | `router_saturate_vseq` on its own (Part 6) |
| `router_lab06_test` | Lab 06's: `router_lab06_vseq` on its own |
| `router_backdoor_test` | Lab 06's: peek and poke through the register model's HDL paths |
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
| `make regress` | every test in `TESTS` on every seed in `SEEDS` (1 to 10), then the coverage of those runs |
| `make seeds` | `UVM_TESTNAME` on every seed in `SEEDS` |
| `make cov` | merge the `coverage.dat` of every run in `build/runs` and list the bins |
| `make check` | the test must pass the golden router and fail on `BUG` (default `B15`) |
| `make check-all` | the same against all 15 bugs (`BUG_LIST`) |
| `make new` | deal a mystery bug from all 15, sealed in `.hunt` |
| `make hunt` | `router_test` against the mystery bug; `VERBOSE=1` prints the log |
| `make verdict` | the hunt's grade: pass on the golden router, fail on the mystery bug |
| `make reveal` | give up, and be told which bug it was |
| `make clean` | remove `build/` |
| `make help` | every target and the current variables |

## Files

| File | What it is | Edit it? |
|---|---|---|
| `PLAN-template.md` | the verification plan, with the specification's rules as rows | copy to `PLAN.md` (Part 2) |
| `REPORT-template.md` | the verification report | copy to `REPORT.md` (Part 4), fill in (Part 8) |
| `tb/router_sva.sv` | Lab 05's assertions, with the APB port and `irq` added and a counter for each rule about reset | Part 5: the reset rules |
| `tb/router_vseq_pkg.sv` | `router_base_vseq` and its helpers, with `reset()`; Lab 05's and Lab 06's sequences; `router_reset_vseq`, `router_saturate_vseq` and `router_lab07_vseq` | Part 5: `router_reset_vseq::body()` and the random resets; Part 6: `router_saturate_vseq::body()`; both: the lines in `router_lab07_vseq` that run them |
| `Makefile` | the lab's settings, `include ../common/uvm.mk`, and `make loc` | Parts 5 and 6: two tests in `TESTS` |
| `tb/router_env_pkg.sv` | the scoreboard, with its reset handling and its four corners; the coverage; the virtual sequencer; the environment | no |
| `tb/router_agents_pkg.sv` | the packet, the input, output and APB agents with their sequences, and the sys agent, which has the reset driver | no |
| `tb/router_ral_pkg.sv` | Lab 06's register model and its adapter | no |
| `tb/router_ifs.sv` | Lab 06's five interfaces; `router_sys_if` has the reset driver's signals | no |
| `tb/router_tests_pkg.sv` | Lab 02's to Lab 06's tests, `router_test`, and this lab's three | no |
| `tb/router_sva_bind.sv` | the `bind` that puts the assertions in the router | no |
| `tb/router_tb_top.sv` | the clock, the reset at time 0, the router, and `run_test()` | no |
| `tb/router_regs.vlt` | the five register signals the back door reaches, marked public for VPI | no |
| `src/loc.py` | the line counter behind `make loc` | no |
| `solutions/` | the finished files, a filled-in plan and an example report; see [`solutions/README.md`](solutions/README.md) | |
