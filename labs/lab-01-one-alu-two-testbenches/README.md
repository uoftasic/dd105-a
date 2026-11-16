# Lab 01: One ALU, two testbenches

Writeup: [`docs/labs/lab-01-one-alu-two-testbenches-overview.md`](../../docs/labs/lab-01-one-alu-two-testbenches-overview.md)

SimProc's ALU from DD104, with DD104's three ALU bugs behind a run-time switch, and two
testbenches for it: the cocotb test from DD104 Lab 03 and a UVM testbench in SystemVerilog.

Run it in the course image, from this folder:

```bash
make cocotb            # the cocotb test on the correct ALU (Icarus, about 25 s)
make build             # the UVM simulator (about 100 s the first time)
make run               # alu_rand_test on the correct ALU
make check BUG=A03     # pass on the correct ALU, fail on A03
make clean             # remove build/ (the ccache at the top of the clone stays)
```

## Targets

This lab's own targets:

| Target | What it does |
|---|---|
| `make cocotb` | the cocotb test on the correct ALU, or on `BUG`; prints the build and run times |
| `make cocotb-all` | the cocotb test on the correct ALU and on each of A01 to A03, summarized |
| `make loc` | lines and code lines in `cocotb/$(TB).py` and in the UVM files |

and the UVM targets from [`../common/uvm.mk`](../common/README.md), the ones this lab uses:

| Target | What it does |
|---|---|
| `make build` | build the UVM simulator if a source changed |
| `make run` | run `UVM_TESTNAME` (default `alu_rand_test`) once and print a verdict |
| `make waves` | the same run, writing `build/runs/<run>/waves.fst` |
| `make tests` | list the tests: `alu_rand_test`, `alu_directed_test` |
| `make check` | the test must pass the correct ALU and fail on `BUG` (default `A03`, the first in `BUG_LIST`) |
| `make check-all` | the same against A03, A01 and A02 |
| `make clean` | remove `build/` |
| `make help` | every target and the current variables |

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `BUG` | empty | `A01`, `A02` or `A03`; empty runs the correct ALU |
| `TB` | `test_alu` | the cocotb test module in `cocotb/`, for `make cocotb` and `make loc` |
| `COCOTB_SIM` | `icarus` | the simulator for `make cocotb`: `icarus` or `verilator` |
| `UVM_TESTNAME` | `alu_rand_test` | the UVM test for `make run` and `make check` |
| `PLUSARGS` | empty | for example `+N=500`, the number of vectors `alu_rand_test` sends (default 2000) |
| `SEED` | `1` | the UVM run's seed |

[`../common/README.md`](../common/README.md) lists the rest.

## Files

| File | What it is |
|---|---|
| `rtl/alu.sv` | the ALU (`module ALU`, from DD104's `simproc_system.sv`) and the bug switch: `+BUG=A01`, `A02` or `A03` |
| `bugs.json` | the bug catalogue `make check` reads |
| `cocotb/test_alu.py` | DD104 Lab 03's reference cocotb test |
| `cocotb/Makefile` | runs the cocotb test; `make cocotb` calls it |
| `tb/alu_if.sv` | the ALU's pins with a clock, a `valid` signal and two clocking blocks |
| `tb/alu_pkg.sv` | the UVM testbench: item, sequences, driver, monitor, agent, scoreboard, environment, tests |
| `tb/alu_tb_top.sv` | the top module |
| `src/loc.py` | the line counter behind `make loc` |
| `solutions/` | a scoreboard that checks the flags; see [`solutions/README.md`](solutions/README.md) |
| `Makefile` | the lab's settings, `include ../common/uvm.mk`, and the cocotb targets |
