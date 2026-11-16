# Guide examples

The SystemVerilog examples that the guide pages under `docs/guide/` quote. Each folder belongs to
one page and is named after it. Every folder builds with the course's
[`labs/common/uvm.mk`](../labs/common/README.md), like the labs: Verilator 5.050 and the vendored
UVM library in `third_party/uvm`, in the course image. Every output a page quotes came from
these commands, run in a folder with no `build/` (the cold builds took 85 to 129 s on 2 CPUs;
the run commands take under a second each).

Run the commands from the example's folder, and finish with `make clean`.

## constrained-random-on-verilator

Page: [Constrained random on Verilator](../docs/guide/constrained-random-on-verilator.md).
Small classes built on SimProc's ALU operations, randomized many times; no design.

```bash
cd guide-examples/constrained-random-on-verilator
make build
make run UVM_TESTNAME=cr_item_test            # ends in BROKEN on purpose: one randomize() fails
make run UVM_TESTNAME=cr_item_test SEED=2
make run UVM_TESTNAME=cr_enum_test
make run UVM_TESTNAME=cr_dist_test            # ends in BROKEN on purpose: the failures it counts
make run UVM_TESTNAME=cr_solve_test
make run UVM_TESTNAME=cr_item_test VERILATOR_SOLVER="z3 --in"    # make refuses: no z3
( cd build && VERILATOR_SOLVER="z3 --in" ./sim +UVM_TESTNAME=cr_item_test )   # UVM_FATAL [SOLVER]
make clean
```

The page also quotes Lab 03's `make traps` (in `labs/lab-03-constraints-and-coverage`), which
printed the same lines as the lab's writeup.

## functional-coverage-you-can-read

Page: [Functional coverage you can read](../docs/guide/functional-coverage-you-can-read.md).
A covergroup on ALU vectors, and two small covergroups that show how Verilator counts bins.

```bash
cd guide-examples/functional-coverage-you-can-read
make build
make run UVM_TESTNAME=cov_plain_test
make cov                                      # 82.9% (34/41), and the 7 empty bins
rm -rf build/runs
make run UVM_TESTNAME=cov_biased_test
make cov                                      # x_op_eq 12 of 12
make build VFLAGS=+define+CG_MEMBER BUILD_DIR=$PWD/build/member   # stops with COVERIGN
make clean
```

`scripts/figures/functional_coverage_cross.py` draws the two runs' `x_op_eq` counts from
`build/coverage/bins.txt`.

## the-uvm-skeleton

Page: [The UVM skeleton](../docs/guide/the-uvm-skeleton.md).
A test, an environment and two agents that print a line in each phase; no design.

```bash
cd guide-examples/the-uvm-skeleton
make build
make run UVM_TESTNAME=sk_phase_test           # the phase order, objections, drain time
make run UVM_TESTNAME=sk_noobj_test           # no objection: the run phase ends at 0 ns
make run UVM_TESTNAME=sk_error_test           # one UVM_ERROR: FAIL, exit status 1
make run UVM_TESTNAME=sk_phase_tset           # a misspelt test: BROKEN, exit status 0
make clean
```

## sequences-sequencers-and-drivers

Page: [Sequences, sequencers and drivers](../docs/guide/sequences-sequencers-and-drivers.md).
SimProc's ALU (Lab 01's `rtl/alu.sv`) driven by a sequence, a sequencer and a driver that print
each step of the handshake.

```bash
cd guide-examples/sequences-sequencers-and-drivers
make build
make run UVM_TESTNAME=sq_timeline_test
make run UVM_TESTNAME=sq_two_test
make run UVM_TESTNAME=sq_nested_test
make waves UVM_TESTNAME=sq_timeline_test
make clean
```

The page's waveform is `make waves`' `build/runs/sq_timeline_test-s1/waves.fst`, taken with
`scripts/screenshots/shoot.sh surfer <waves.fst> -s sq_top.clk,aif.valid,u_alu.ALUop,u_alu.A,u_alu.B,u_alu.ALUout --from 0ns --to 55ns --time-unit ns`.

## monitors-analysis-ports-and-scoreboards

Page: [Monitors, analysis ports and scoreboards](../docs/guide/monitors-analysis-ports-and-scoreboards.md).
The ALU with a full agent: a monitor whose analysis port feeds a scoreboard, a coverage collector
and a history that keeps every handle.

```bash
cd guide-examples/monitors-analysis-ports-and-scoreboards
make build
make run UVM_TESTNAME=mon_rand_test
make run UVM_TESTNAME=mon_rand_test BUG=A01   # caught: the scoreboard's errors
make run UVM_TESTNAME=mon_alias_test          # one object for every write
make check-all UVM_TESTNAME=mon_rand_test     # 2 of 3 caught: A03 is missed
make clean
```

## the-factory-and-config-db

Page: [The factory and config_db](../docs/guide/the-factory-and-config-db.md).
The environment from `monitors-analysis-ports-and-scoreboards`, built from that folder's files
without changes, with tests that change it through the factory and `config_db`.

```bash
cd guide-examples/the-factory-and-config-db
make build
make run UVM_TESTNAME=fac_equal_test                       # the factory's override table
make check-all UVM_TESTNAME=fac_equal_test                 # 0 of 3 caught
make check-all UVM_TESTNAME=fac_flags_test                 # 3 of 3 caught
make run UVM_TESTNAME=fac_typo_test PLUSARGS=+UVM_CONFIG_DB_TRACE
make run UVM_TESTNAME=fac_prec_test
make run UVM_TESTNAME=mon_rand_test BUG=A01 PLUSARGS=+uvm_set_type_override=alu_item,alu_equal_item
make clean
```
