# `labs/common`: the UVM build and the graders

Every DD105-A lab builds its UVM testbench with `uvm.mk` and is graded by the Python scripts here.
A lab's `Makefile` names its sources and includes `uvm.mk`. For the router, whose planted bugs
`inject.py` writes into one faulty copy of the RTL:

```make
TOP           := router_tb_top
DUT_F         := build/rtl/router.f
BUILD_DEPS    := build/rtl/router.f
TB_SRCS       := tb/router_if.sv tb/router_env_pkg.sv tb/router_tb_top.sv
TESTS         := router_smoke_test router_rand_test
BUG_CATALOGUE := ../common/bugs.py
include ../common/uvm.mk

build/rtl/router.f: $(wildcard ../common/rtl/*.sv) ../common/bugs.py ../common/inject.py
	python3 ../common/inject.py --all --out build/rtl
```

It runs in the course image (IIC-OSIC-TOOLS 2026.08) from a lab folder in your workspace clone
under `/foss/designs`, or in a bare container with the clone mounted anywhere, with `make` and no
other setup.

One build serves every test in a lab. The test, its plusargs, the seed and the planted bug are chosen
when you run, so changing them never rebuilds.

## Targets

| Target | What it does |
|---|---|
| `make` | build if needed, then run `UVM_TESTNAME` |
| `make build` | build the simulator if a source or a build setting changed |
| `make run` | run one test; prints the log and a one-line verdict |
| `make waves` | the same run, writing `waves.fst` into the run folder |
| `make tests` | list the lab's tests (`TESTS`) |
| `make regress` | every test in `TESTS` on every seed in `SEEDS`, then the coverage |
| `make seeds` | `UVM_TESTNAME` on every seed in `SEEDS` |
| `make cov` | merge every `coverage.dat` under `build/runs` and list the covergroup bins |
| `make lint` | the build's sources through Verilator's front end with the warnings the build turns off shown (seconds) |
| `make check` | your test must pass the golden design and fail on `BUG` |
| `make check-all` | the same against every bug in `BUG_LIST` (or the catalogue) |
| `make new` / `hunt` / `verdict` / `reveal` | the mystery-bug hunt |
| `make clean` | remove `build/` |
| `make clean-cache` | remove the ccache as well |
| `make cache` | how full the ccache is |
| `make help` | the targets and the current variables |

## Variables

Set these on the command line, for example `make run UVM_TESTNAME=router_rand_test SEED=7`.

| Variable | Default | Meaning |
|---|---|---|
| `UVM_TESTNAME` | first of `TESTS` | the test to run |
| `SEED` | `1` | passed as `+verilator+seed+N`; `SEED=random` picks one, and the run folder's name records it |
| `BUG` | empty | passed as `+BUG=<id>`; empty runs the golden design |
| `PLUSARGS` | the lab's | any other plusargs, for example `+N=500 +UVM_VERBOSITY=UVM_HIGH` |
| `VERBOSITY` | empty | shorthand for `+UVM_VERBOSITY=` |
| `SEEDS`, `NSEEDS` | `1` to `10` | the seeds `regress` and `seeds` use |
| `TESTS` | the lab's | the tests `regress` uses |
| `RUN_TIMEOUT` | `300` | seconds before a run is stopped (and graded BROKEN) |
| `VERBOSE` | empty | `VERBOSE=1` makes `check` and `hunt` print the simulator's log |
| `JOBS` | `2` | parallel g++ jobs; each needs up to 1.3 GB |
| `OUTPUT_GROUPS` | `8` | how many files Verilator concatenates its C++ into |
| `OPT_FAST` | `-O0` | g++ optimization for the simulator's hot code; `-Os` is Verilator's own default |
| `SLIM` | `1` | after a build keep only `build/sim`; `SLIM=0` keeps the 900 MB of generated C++ |
| `COVERAGE` | `1` | build with `--coverage-user`; each run writes `coverage.dat` |
| `TRACE` | `1` | build with VCD tracing, so `make waves` works |
| `TRACE_PKGS` | `0` | `1` puts the packages (the UVM library's statics among them) back in the waves |
| `BUILD_DIR` | `build` in the lab | where the simulator, runs and waves go |

A lab's `Makefile` also sets `TOP`, `DUT_F` (file lists, passed with `-F`), `DUT_SRCS`, `TB_SRCS`,
`INCDIRS`, `VLT`, `VFLAGS`, `BUILD_DEPS`, `TESTS`, `BUG_LIST`, `BUG_CATALOGUE`, `HUNT_POOL` and,
if its design prints one, `BUG_CONFIRM`. Paths are relative to the lab folder.

`VERILATOR_SOLVER` is `yices-smt2 --incremental` in every run's environment. Without it every
constrained `randomize()` returns 0 and the run still passes, so `make` stops with an error if it is
empty or names a solver that isn't installed. The build also bakes it into the simulator as the
default for a run started by hand. Verilator 5.050 bakes it wrongly when the value has a space (as
`yices-smt2\ --incremental`, which fails with exit status 127), so `uvm.mk` builds without the
variable and passes `-DVM_SOLVER_DEFAULT` itself; `build/sim` run by hand with no
`VERILATOR_SOLVER` randomizes correctly. If a solver still can't start, `dd105_base_test` stops the
run with `UVM_FATAL [SOLVER]`.

## Where things go

```
labs/<lab>/build/
  sim                 the simulator, about 50 MB
  build.log           the whole build log
  runs/<test>-s<seed>[-<bug>]/
      run.log  cmd  exit_status  seconds  coverage.dat  waves.fst
  grade/  hunt/       the graders' runs
  coverage/           make cov: merged.dat and bins.txt
<clone>/.ccache       the ccache, shared by every lab, capped at 2 GB
```

The ccache lives at the top of the course clone, which is in your workspace under `/foss/designs`,
so it survives a container restart. Without it every new container pays the full cold build. Its
entries don't depend on where the clone is mounted.

## Cleaning up

`make clean` in a lab removes its `build/` folder. The ccache stays, so the next build is a warm one;
`make clean-cache` removes it too. To free everything the course built:

```bash
for d in labs/*/; do make -C "$d" clean; done
rm -rf .ccache
```

## Build times

Measured on the ALU environment from the course research (UVM library, one agent, scoreboard,
covergroup), in the course image with 2 CPUs and 3 GB:

| Build | Time |
|---|---|
| cold (empty ccache) | 102 to 103 s |
| cold, Verilator's defaults (two C++ files at `-Os`) | 526 s: two g++ jobs of 2.6 GB each swap in 3 GB |
| cold, eight files at `-Os` | 175 s |
| one-line design edit, warm ccache | 24 to 26 s |
| one-line testbench edit, warm ccache | 25 to 26 s |
| nothing changed | 0.1 s |
| a source touched but not changed | 15 s (0.6 s with `SLIM=0`) |
| new container, clone mounted elsewhere, `build/` deleted, warm ccache | 15.5 s |

At `-O0` the simulator runs about 1.4 times slower than at `-Os`: 2,000 ALU items take 1.68 s
against 1.19 s. A run that changes only plusargs, the seed, the test or the bug starts in well under
a second. One cold build adds about 106 MB to the ccache.

## Verdict classes

`verdict.py` reads the log, not just the exit status, and puts each run in one class:

| Class | Means |
|---|---|
| pass | ran to UVM's report summary, exit status 0, and no UVM_ERROR, UVM_FATAL or failed assertion |
| caught | a check fired: a `uvm_error` from the lab's code, a register-model mismatch, or a failed assertion or `$error` |
| BROKEN | anything else: a failed build, any UVM_FATAL, a UVM_ERROR from the UVM library itself, a timeout, a crash or null handle, a `$fatal`, a failed `randomize()`, a missing solver, or a run that stopped before UVM's summary with no failed assertion or `$error` in its log |

A BROKEN run is never a pass and never a catch. The exception in the last case is there because
Verilator stops a run when it reaches its error limit (`+verilator+error+limit+N`, 1 by default),
and it counts each failed assertion and `$error` towards it. A run that stopped that way, before
UVM's summary, is caught if nothing else went wrong; Lab 03's B05 and B09 runs, which stop at their
100th `$error`, are graded that way. `make check` needs pass on the golden design and
caught on the bug, so a bug run that is a pass is MISSED.

## The bug switch

A lab's design carries every planted bug behind one run-time switch, so one build covers the golden
design and all the broken ones. The router's (from `inject.py --all`):

- no `+BUG`, or `+BUG=none`: the golden design;
- `+BUG=Bnn`: that bug on;
- any other `+BUG`: `$fatal` at time 0;
- `+BUG_ECHO`: also print which bug is on. The graders never pass it, so a mystery run's log
  doesn't name the bug.

The graders pass only `+BUG=<id>`, with an id from `BUG_LIST` or the catalogue, and nothing for the
golden run. They don't need the design to print anything. A lab whose design does print a line for
each bug can set `BUG_CONFIRM` to it, with `{id}` for the bug; the graders then grade a bug run
without that line as BROKEN, and a golden run with one as well.

`BUG_CATALOGUE` is the router's `bugs.py` (its `BUGS` dict and `ids()`), or a JSON file with the
same fields:

```json
{"B01": {"name": "sub_borrow_on_equal", "tier": 1,
         "hides_behind": "operands that are never equal",
         "teaches": "bias the stimulus toward corners such as a == b"}}
```

`check` and `hunt` fail a testbench that reads `+BUG` or a design's `*_bug_pkg::` variable, and the
waves leave packages out, so `make waves` doesn't show `router_bug_pkg::bug_id`.

## Drive through a clocking block

On Verilator 5.050, two nonblocking assignments to one signal in the same time step can be committed
in source order instead of the order they ran. The router's directed testbench found it:

```systemverilog
task automatic xfer(); a <= 1; @(posedge clk); a <= 0; endtask
initial begin @(posedge clk); repeat (3) xfer(); end   // a is high at 1 of 3 edges
```

Each call's `a <= 1` runs after the previous call's `a <= 0`, in the same time step, so by the
standard `a` stays high at all three edges; Icarus 14.0 agrees. These shapes, measured in the course
image (`selftest/nba/nba_repro.sv` and the selftest's UVM drivers), give:

| Shape | High at |
|---|---|
| a module task called in a `repeat` loop from an `initial` block | 1 of 3 |
| the same task, three calls written out | 3 of 3 |
| a class loop driving `vif.x <= 1; @(posedge vif.clk); vif.x <= 0;` | 3 of 3 |
| a class loop calling an interface task that does the same | 3 of 3 |
| an interface task that loops over its beats, called from a class | 3 of 3 |
| a UVM driver doing it once per item, or for two beats per item | every item arrives |

Of the shapes tried, only the module task called in a `repeat` loop lost assignments, and class
code, where a UVM driver lives, kept every assignment in every shape. Drive through a clocking
block all the same: it gave 3 of 3 everywhere, it is what the course teaches, and it doesn't depend
on the order in which Verilator commits two nonblocking assignments in one time step:

```systemverilog
vif.cb.valid <= 1; vif.cb.data <= req.data;
@(vif.cb);
vif.cb.valid <= 0;
```

In module code without a clocking block, drive with blocking assignments 1 ns after the clock edge,
as the router's directed testbench does. `make FULL=1` in `selftest/` fails if any of these numbers
changes.

## Files

| File | What it is |
|---|---|
| `uvm.mk` | the build and every target above; the only place a simulation is started |
| `uvm/dd105_pkg.sv` | `dd105_base_test`: the solver check, and an exit status that means something |
| `uvm/dd105_waves.sv` | dumps the design on `+WAVES=<file>`; bound into the lab's top module |
| `uvm/dd105_trace.vlt` | leaves packages out of the waves |
| `verdict.py` | pass, caught or BROKEN, from a run folder |
| `check.py` | `make check` and `make check-all` |
| `hunt.py` | `make new`, `hunt`, `verdict` and `reveal` |
| `regress.py` | `make regress` and `make seeds` |
| `covreport.py` | `make cov` |
| `selftest/` | proves each verdict class fires; see [`selftest/README.md`](selftest/README.md) |
