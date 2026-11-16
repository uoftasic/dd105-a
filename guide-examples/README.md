# Guide examples

The SystemVerilog examples that the guide pages in `docs/guide/` quote. Each folder belongs to one
page, has the page's name, and builds with the labs' shared makefile
([`labs/common/uvm.mk`](../labs/common/README.md)) and the UVM library in `third_party/uvm`, so it
needs the course image and nothing else. The demonstrations themselves are plain SystemVerilog;
each one runs inside a small UVM test (`+UVM_TESTNAME` picks it) only so that `make run` works as in
the labs. One build serves every test in a folder.

The guide pages are reading only, so nothing here is a lab step. These are the commands that
produced each output a page quotes. Run them in the course image, from the folder named:

## `classes-for-testbenches/`

| Command | What the page quotes |
|---|---|
| `make build` | |
| `make run UVM_TESTNAME=handles_test` | `a is null` ... `a == b is 1, a == c is 0, pkt::n_made is 1` |
| `make run UVM_TESTNAME=reuse_test` | the six `one pkt, reused:` and `a new pkt each:` lines |
| `make run UVM_TESTNAME=dispatch_test` | `through a base_test handle:` and the five lines after it |
| `make run UVM_TESTNAME=null_test` | `%Error: ...classes_demo_pkg.sv:112: Null pointer dereferenced`, `Aborting...` |
| `make lint VFLAGS="--timescale 1ns/1ps +define+FUNCTION_WAITS"` | `%Error-FUNCTIMECTL: ... Functions cannot contain time-controlling statements` |

## `from-cocotb-to-systemverilog-classes/`

The design is Lab 01's ALU, `labs/lab-01-one-alu-two-testbenches/rtl/alu.sv`, with its `+BUG` switch.

| Command | What the page quotes |
|---|---|
| `make build` | |
| `make run UVM_TESTNAME=t01_test` | `t01: 6 directed vectors checked` |
| `make run UVM_TESTNAME=t01_test BUG=A01` | `[2000] %Error: ... SUB(0xc8, 0x3c) gave out=0x74 ...`, `Verilog $stop`, `Aborting...` |
| `make run UVM_TESTNAME=widths_test` | `sum8 = a + b -> 4`, `sum9 = a + b -> 260`, `$display(a + b) -> 4`, `[1 beat ]`, `[1 beat]` |

## `interfaces-clocking-blocks-and-virtual-interfaces/`

The design is the golden router, `labs/common/rtl`.

| Command | What the page quotes |
|---|---|
| `make build` | |
| `make run UVM_TESTNAME=edge_test` | the `edge:` lines from 65 ns to 115 ns, `in_valid pin changes`, `handshake on beat` |
| `make run UVM_TESTNAME=typedef_test` | the eight lines from 45 ns to 75 ns |
| `make run UVM_TESTNAME=module_task_test PLUSARGS=+MODULE_TASK` | `high at 1 of 3 edges`, `high at 3 of 3 edges` |
| `make waves UVM_TESTNAME=edge_test` | the waves for the figure below |

The figure `docs/assets/img/dd105-router-clocking-block.png` is a screenshot of that run's waves,
taken from the top of the repo with
[`scripts/screenshots/shoot.sh`](../scripts/screenshots/README.md):

```bash
scripts/screenshots/shoot.sh surfer guide-examples/interfaces-clocking-blocks-and-virtual-interfaces/build/runs/edge_test-s1/waves.fst \
  -s rtr_top.clk,pins.psel,pins.penable,pins.in_ready,pins.in_valid,pins.in_data,pins.out0_valid,pins.out0_data \
  --from 60ns --to 120ns --time-unit ns -o docs/assets/img/dd105-router-clocking-block.png
```

## `threads-mailboxes-and-events/`

| Command | What the page quotes |
|---|---|
| `make build` | |
| `make run UVM_TESTNAME=fork_test` | the seventeen lines from `0 ns: fork...join` to `90 ns: wait fork returns` |
| `make run UVM_TESTNAME=capture_test` | `i = 3` three times, then `j = 0`, `1`, `2` |
| `make run UVM_TESTNAME=static_loop_test PLUSARGS=+STATIC_LOOP` | `j = 0` three times, then `0`, `1`, `2` |
| `make lint` | `%Warning-IMPLICITSTATIC: ... threads_top.sv` |
| `make run UVM_TESTNAME=mailbox_test` | `mailbox bound 0 (unbounded)` and the nine lines after it |
| `make run UVM_TESTNAME=mailbox_test PLUSARGS=+BOUND=1` | `mailbox bound 1` and the nine lines after it |
| `make run UVM_TESTNAME=event_test` | `10 ns: ->done`, `wait (done.triggered) returns`, `30 ns: end of the demo` |
| `make run UVM_TESTNAME=disable_test` | the four lines from 25 ns to 150 ns |

## Getting started and What a framework buys you

These two pages have no examples of their own. *What a framework buys you* quotes Lab 01's
writeup. *Getting started* quotes a run of Lab 01's own targets in
`labs/lab-01-one-alu-two-testbenches`, starting from an empty compiler cache:

```bash
make clean-cache && make clean
make build                          # the first build, 126 s
make run                            # ok: 0 UVM_ERROR, 0 UVM_FATAL   1.18 s
make check-all                      # 2 of 3 caught, then make's error line
make cocotb                         # build 0.4 s, run 23.0 s
make clean
```

and the version checks from Lab 01, Part 1. The two rebuild times came from two one-line edits to
`tb/alu_pkg.sv` in a scratch copy, each undone afterwards: `repeat (3)` changed to `repeat (4)` in
`alu_base_test::run_phase()` (27 s), and an `int unsigned n_extra;` member added to
`alu_scoreboard` (108 s).

## Figures

The diagrams on these pages are drawn by the scripts in [`scripts/figures/`](../scripts/figures/):
`lab01_uvm_structure.py`, `handles.py` and `lab02_threads.py`. See `circuit_style.py` there for how
to run them.

## Cleaning up

`make clean` in each folder removes its `build/`. The examples share the course's compiler cache in
`.ccache` at the top of the repo, which `make clean-cache` removes.
