# Lab 02: A class testbench without UVM

Writeup: [`docs/labs/lab-02-a-class-testbench-without-uvm-overview.md`](../../docs/labs/lab-02-a-class-testbench-without-uvm-overview.md)

This package is a testbench for the router's input and output 0, written as plain SystemVerilog
classes that talk through mailboxes. The generator, driver, sinks, APB writer and environment are shipped; you write
the monitor (`tb/monitor.svh`) and the scoreboard (`tb/scoreboard.svh`), and catch B05 and B09.

Run it in the course image, from this folder:

```bash
make build                                   # the simulator (about 90 s the first time)
make run                                     # router_class_test on the golden router
make run PLUSARGS="+SHOW=5"                  # the same, printing the first 5 packets on each stream
make run BUG=B09 PLUSARGS="+DSTS=0 +LEN=1 +N=16"
make check-all                               # the golden router, then B05 and B09
make clean                                   # remove build/ (the ccache at the top of the clone stays)
```

## Targets

The targets come from [`../common/uvm.mk`](../common/README.md). The ones this lab uses:

| Target | What it does |
|---|---|
| `make build` | build the simulator if a source changed |
| `make lint` | the sources through Verilator's front end only: syntax errors in seconds, without a build |
| `make run` | run `router_class_test` once and print a verdict |
| `make waves` | the same run, writing `build/runs/<run>/waves.fst` |
| `make seeds` | the test on seeds 1 to 10 (`NSEEDS=5` for 1 to 5) |
| `make check` | the test must pass the golden router and fail on `BUG` (default `B05`) |
| `make check-all` | the same against B05 and B09 |
| `make clean` | remove `build/` |
| `make help` | every target and the current variables |

## Variables and plusargs

| Variable | Default | Meaning |
|---|---|---|
| `BUG` | empty | `B05` or `B09` (or any id in `../common/bugs.py`); empty runs the golden router |
| `SEED` | `1` | the seed; it changes every random choice the generator makes |
| `PLUSARGS` | empty | the test's knobs, below |

The Makefile adds `+verilator+error+limit+100` to every run, so a run goes on after the
scoreboard's first `$error` (Verilator's default limit is 1) and stops at the 100th.

| Plusarg | Default | Meaning |
|---|---|---|
| `+N=<n>` | `100` | packets to send |
| `+DSTS=<digits>` | `0123` | the `DST` values the generator picks from, for example `+DSTS=0` |
| `+ROUTES=<abcd>` | `0110` | `ROUTE0` to `ROUTE3`, one character each: `0` or `1` is the output, `-` is disabled |
| `+LEN=<n>` | `0` | every packet `n` beats long (1 to 8); `0` picks each length from 1 to 8 |
| `+SHOW=<n>` | `0` | each monitor prints the first `n` packets it sees |

[`../common/README.md`](../common/README.md) lists the rest.

## Files

| File | What it is |
|---|---|
| `tb/stream_if.sv` | three stream interfaces: `stream_src_if` (the input; the testbench drives `valid`), `stream_snk_if` (an output; it drives `ready`) and `stream_mon_if` (any stream, every signal an input, for monitors) |
| `tb/apb_if.sv` | the APB port and its clocking block |
| `tb/router_tb_pkg.sv` | the package that holds the classes below |
| `tb/packet.svh` | `packet`, the transaction, and `router_cfg`, the knobs above |
| `tb/generator.svh` | `generator`: makes the packets |
| `tb/driver.svh` | `driver` (input stream), `sink` (outputs, always ready) and `apb_master` |
| `tb/monitor.svh` | `monitor`: turns a stream's handshakes into packets. You write `run()`. |
| `tb/scoreboard.svh` | `scoreboard`: predicts output 0 and checks it. You write `run()`, `predict()`, `check()` and the checks in `report()`. |
| `tb/env.svh` | `env`: builds the pieces, connects them with mailboxes, and runs the test |
| `tb/router_test_pkg.sv` | `router_class_test`, the one UVM class: it makes the `env` and runs it, so `make` and the graders work as in every lab |
| `tb/router_tb_top.sv` | the clock, the reset, the interfaces, the router and `run_test()` |
| `solutions/` | a reference monitor and scoreboard; see [`solutions/README.md`](solutions/README.md) |
| `Makefile` | the lab's settings and `include ../common/uvm.mk` |

The input and the outputs use different interface types so that each signal has one driver: on
the input the testbench drives `valid` and the router drives `ready`, and on an output it's the
other way round. Monitors get a third type, whose signals are all inputs, so one `monitor` class
watches the input and output 0 alike and can't drive either.
