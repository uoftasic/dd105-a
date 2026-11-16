# `selftest/`: checking the graders

```bash
cd labs/common/selftest
make              # the classifier on recorded logs, and the source audit. About a second.
make FULL=1       # ... and every grader end to end on alu/. One build, then a few minutes.
make capture      # re-record logs/ from real runs (after an image or UVM library change)
```

DD104's rule applies here too: a grader that says PASS when it did nothing is worse than no grader.
DD104 shipped one, and it told a student `3 of 3 ALU bugs caught` about a testbench that raised
`NameError` on every core.

A UVM run on Verilator 5.050 can fail quietly in more ways than a cocotb test can. UVM_ERROR and
UVM_FATAL both end with exit status 0, a missing solver makes every `randomize()` return 0 while the
run still passes, and a null handle in a scoreboard's mismatch path crashes only on a broken design.
`../verdict.py` is the one place that tells a check that fired from a run that broke. This folder
proves it still does.

## Files

| Path | What it is |
|---|---|
| `selftest.py` | the three parts below, and `--capture` |
| `alu/` | a small ALU with three planted bugs behind `+BUG=`, and an environment built with `../uvm.mk`. Not course material. |
| `alu/rtl/st_alu.sv` | the ALU, with `st_bug_pkg::bug_id` set the way the router's faulty build sets its own, and a `DD105-BUG: <id> enabled` line that `alu/Makefile` checks through `BUG_CONFIRM` |
| `alu/tb/st_pkg.sv` | the environment and the fixture tests; each test's comment names the verdict it must provoke. `st_env` checks that every item the driver sent reached the scoreboard. |
| `alu/tb/st_sva.sv` | an assertion bound to the ALU; the only check on the zero flag, so bug B02 can only be caught by an assertion |
| `alu/cheat/st_cheat_test.sv` | a test that reads `+BUG` and `st_bug_pkg::bug_id`; never compiled |
| `alu/broken/st_syntax_error.sv` | a file that does not compile |
| `nba/nba_repro.sv` | the Verilator 5.050 nonblocking-assignment trap: a module task in a loop loses it, three class and interface shapes don't. Built on its own. |
| `logs/<scenario>/` | `run.log` and `exit_status` from a real run of each scenario, recorded in `asic-edu/gui-rig:2026.08` |

## The fixtures

| Fixture | Broken how | On the golden design | On a bug |
|---|---|---|---|
| `st_good_test` | not broken: the reference | ok | B01 caught (UVM_ERROR), B02 caught (assertion), B03 MISSED |
| `st_empty_test` | sends nothing | ok | MISSED |
| `st_fixed_test` | sends 300 items and never randomizes them | ok | MISSED |
| `st_plain_test` | extends `uvm_test`, not `dd105_base_test`, and ignores what `randomize()` returns | ok | caught, with exit status 0 |
| `st_plain_test`, no solver | the run has `VERILATOR_SOLVER="z3 --in"` (not installed) | BROKEN | BROKEN, though no check fired |
| `st_good_test`, no solver | the same | BROKEN (UVM_FATAL [SOLVER]) | |
| `st_good_test`, `VERILATOR_SOLVER` unset | run by hand, so only the default built into the simulator is left | ok | |
| `st_nba_item_test`, `st_nba_beat_test` | not broken: controls. Their drivers drive the pins with plain `<=`, once per item or for two beats per item, and every beat must arrive | ok | B01 caught |
| `st_null_vif_test` | asks `config_db` for a name nobody set | BROKEN (UVM_FATAL [NOVIF]) | |
| `no_such_test` | a test name that does not exist | BROKEN (UVM_FATAL [INVTST], exit 0) | |
| `st_crash_test` | dereferences a null handle while reporting a mismatch | ok | BROKEN |
| `st_fatal_check_test` | reports a mismatch with `uvm_fatal` | ok | BROKEN |
| `st_hang_test` | waits for an event that never comes | BROKEN (RUN_TIMEOUT, or UVM_FATAL [PH_TIMEOUT] with `+UVM_TIMEOUT`) | |
| `st_misconnect_test` | connects the scoreboard's imp to the monitor's port backwards | BROKEN (library UVM_ERROR [Connection Error]) | |
| `st_unsat_test` | a contradictory inline constraint, result ignored | BROKEN (UNSATCONSTR) | |
| `st_cheat_test` | reads `+BUG` and `st_bug_pkg::bug_id` | refused before anything is built | |
| `broken/st_syntax_error.sv` | does not compile | BROKEN (the build) | |

## The three parts

The script prints them in the order 1, 3, 2, fastest first.

1. **The classifier, on real logs.** Each scenario's recorded log goes through `verdict.py` and has
   to land in the class the table in `selftest.py` gives it: pass, caught or BROKEN, and the reason.
   Two cases read a real log the wrong way round (a golden log graded as a bug run, and a bug log
   graded as golden) to prove `BUG_CONFIRM` is enforced when a lab sets it, and a third reads the
   golden log as a bug run without `BUG_CONFIRM`, as the router's labs do. No simulator; under a
   second.
2. **The graders, end to end** (`FULL=1`). Builds `alu/` once, then runs `make check`, `check-all`,
   `new`, `hunt`, `verdict`, `reveal`, `regress`, `waves`, `lint` and the solver guard with the
   fixtures, and checks what each prints and its exit status. It checks that the waves hold the
   design and no package, so `st_bug_pkg::bug_id` stays out of them. The solver runs start the
   simulator by hand, because `make` refuses to run without a solver. Last, it builds
   `nba/nba_repro.sv` and checks that the module-task loop still gives 1 of 3 and the other three
   shapes 3 of 3; if a new Verilator changes any of them, this fails so the course text gets
   updated.
3. **The source audit.** `check.py`, `hunt.py` and `regress.py` must import `verdict.py` and must not
   read UVM or Verilator output themselves.

`make capture` reruns every scenario and rewrites `logs/`. Read the diff before committing it: a
changed log is how a new image or UVM version shows up here first.
