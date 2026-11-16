# Lab 06: The register block

Writeup: [`docs/labs/lab-06-the-register-block-overview.md`](../../docs/labs/lab-06-the-register-block-overview.md)

The router's UVM testbench as Lab 05 leaves it, with a register model added. You write the
register model's fields and its adapter, connect its predictor, run UVM's built-in reset and
bit-bash sequences, test the addresses outside the register map, and make the scoreboard check
`irq` against `STATUS` and `INT_EN`. That catches B01, B02, B03, B04 and B14.

Run it in the course image, from this folder:

```bash
make build                                    # the simulator (136 s with an empty ccache)
make run                                      # router_test on the golden router
make run UVM_TESTNAME=router_lab06_test       # this lab's steps on their own
make check BUG=B14                            # golden must pass, B14 must fail
make check-all                                # the golden router, then B01, B02, B03, B04 and B14
make run UVM_TESTNAME=router_backdoor_test    # what peek and poke do
make clean                                    # remove build/ (the ccache at the top of the clone stays)
```

## Targets

The targets come from [`../common/uvm.mk`](../common/README.md). The ones this lab uses:

| Target | What it does |
|---|---|
| `make build` | build the simulator if a source changed |
| `make lint` | the sources through Verilator's front end only: syntax errors in seconds, without a build |
| `make run` | run one test (`router_test` unless `UVM_TESTNAME` says otherwise) and print a verdict |
| `make waves` | the same run, writing `build/runs/<run>/waves.fst` |
| `make seeds` | `router_test` on seeds 1 to 10 (`NSEEDS=5` for 1 to 5) |
| `make check` | `router_test` must pass the golden router and fail on `BUG` |
| `make check-all` | the same against B01, B02, B03, B04 and B14 |
| `make tests` | the three tests below |
| `make clean` | remove `build/` |
| `make help` | every target and the current variables |

## Tests

| Test | What it runs |
|---|---|
| `router_test` | Lab 04's steps, Lab 05's, then Lab 06's (`router_main_vseq`); `make check` and `make check-all` grade this one |
| `router_lab06_test` | Lab 06's steps on their own (`router_lab06_vseq`) |
| `router_backdoor_test` | peeks and pokes through the register model's HDL paths (`router_backdoor_vseq`); `+BACKDOOR_READBACK` adds a front-door read of a poked register |

The Makefile sets `PLUSARGS` to `+verilator+error+limit+100000`, so every failing assertion prints
and the run goes on. If you give `PLUSARGS` yourself, include that plusarg too.
`+MAX_CYCLES=<n>` (default 400000) is the tests' watchdog, and a run stops after 50 `UVM_ERROR`s.

## Files

| File | What it is |
|---|---|
| `tb/router_ral_pkg.sv` | the register model and the adapter. You write the fields of `STATUS`, `DROP_CNT`, `LEVEL` and `ROUTEn`, and the adapter's `reg2bus()` and `bus2reg()` (Part 2). |
| `tb/router_env_pkg.sv` | the reset/irq agent, the reference model, the scoreboard, the coverage, the virtual sequencer and the environment. You connect the predictor (Part 3) and write the scoreboard's `irq` check (Part 5). |
| `tb/router_seq_pkg.sv` | the virtual sequences. You write `router_lab06_vseq` (Parts 2 to 5). |
| `tb/router_regs.vlt` | marks the five register signals the back door reaches as public, so VPI can find them |
| `tb/apb_pkg.sv` | the APB agent; its driver reports each finished transfer on `done_ap`, for the predictor |
| `tb/stream_pkg.sv` | the source agent, the reactive sink agent and the stream monitor |
| `tb/router_test_pkg.sv` | the three tests |
| `tb/router_sva.sv`, `tb/router_sva_bind.sv` | Lab 05's assertions and the `bind` that attaches them |
| `tb/apb_if.sv`, `tb/stream_if.sv`, `tb/router_sys_if.sv` | the interfaces |
| `tb/router_tb_top.sv` | the clock, the interfaces, the router and `run_test()` |
| `solutions/` | the three files you edit, finished; see [`solutions/README.md`](solutions/README.md) |
| `Makefile` | the lab's settings and `include ../common/uvm.mk` |
