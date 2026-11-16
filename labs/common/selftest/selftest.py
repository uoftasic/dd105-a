"""
DD105-A: does the grader actually grade?

    cd labs/common/selftest && make            the fast parts, no simulator
    cd labs/common/selftest && make FULL=1     ... and every grader, for real
    cd labs/common/selftest && make capture    re-record logs/ from real runs

DD104's rule, and the reason this file exists:

    A grader that says PASS when it did nothing is worse than no grader at all.

So the graders are themselves tested, by pointing them at tests that are
known to be bad in one specific way and reading what they say. The fixture
tests are in alu/tb/st_pkg.sv; each names the verdict it must provoke.

────────────────────────────────────────────────────────────────────────────
PART 1 -- the classifier, against real logs, with no simulator
────────────────────────────────────────────────────────────────────────────
logs/<scenario>/ holds run.log and exit_status from a real run of each
scenario below in the course image (`make capture` re-records them). Each is
read through verdict.py and must land in the class the table says. Under a
second, and it is the part that catches a change to the rule itself.

────────────────────────────────────────────────────────────────────────────
PART 2 -- the graders, end to end (FULL=1)
────────────────────────────────────────────────────────────────────────────
Builds alu/ once (about 90 s cold; ccache shares only Verilator's runtime
library with the labs), then runs make check, check-all, the hunt, regress,
waves and the solver guard with the fixture tests, and reads what they print.

────────────────────────────────────────────────────────────────────────────
PART 3 -- every grader reads the rule from verdict.py
────────────────────────────────────────────────────────────────────────────
No grader may carry its own copy of the classification.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
COMMON = os.path.abspath(os.path.join(HERE, ".."))
ALU = os.path.join(HERE, "alu")
LOGS = os.path.join(HERE, "logs")
sys.path.insert(0, COMMON)

import verdict as V                              # noqa: E402

RULE = "=" * 72
THIN = "-" * 72


# ─────────────────────────────────────────────────────────────────────────────
# The scenarios: one real run each. Part 1 reads their logs; `make capture`
# records them.
# ─────────────────────────────────────────────────────────────────────────────

# alu/'s design prints this line for a bug, and alu/Makefile sets BUG_CONFIRM
# to it. A lab's design need not print anything.
CONFIRM = "DD105-BUG: {id} enabled"


class Scn:
    """One run. solver=None runs it through make; "unset" or a solver command
    runs the simulator by hand with that environment, which make won't do."""

    def __init__(self, name, test, bug="", plusargs="+N=300", solver=None, timeout=60,
                 read_bug=None, confirm=CONFIRM, kind="pass", key=None, why=""):
        self.name, self.test, self.bug, self.plusargs = name, test, bug, plusargs
        self.solver, self.timeout = solver, timeout
        self.read_bug = bug if read_bug is None else read_bug   # what verdict.py is told
        self.confirm = confirm
        self.kind, self.key, self.why = kind, key, why


SCENARIOS = [
    Scn("good_golden", "st_good_test", kind="pass",
        why="the reference test on the golden design"),
    Scn("good_B01", "st_good_test", "B01", kind="caught", key="UVM_ERROR",
        why="the scoreboard's UVM_ERROR is a check"),
    Scn("good_B02", "st_good_test", "B02", kind="caught", key="assertion",
        why="a failed assertion bound to the design is a check"),
    Scn("good_B03", "st_good_test", "B03", kind="pass",
        why="a bug the stimulus never reaches: a clean pass, so MISSED"),
    Scn("empty_B01", "st_empty_test", "B01", kind="pass",
        why="sends nothing: passes on a broken design, so MISSED"),
    Scn("fixed_B01", "st_fixed_test", "B01", kind="pass",
        why="never randomizes: passes on a broken design, so MISSED"),
    Scn("plain_B01", "st_plain_test", "B01", kind="caught", key="UVM_ERROR",
        why="plain uvm_test: exit status 0 after UVM_ERROR, still caught from the log"),
    Scn("plain_nosolver_golden", "st_plain_test", "", solver="z3 --in", kind="broken", key="solver",
        why="no solver, randomize() result ignored: would pass everything"),
    Scn("plain_nosolver_B01", "st_plain_test", "B01", solver="z3 --in", kind="broken", key="solver",
        why="no solver, on a broken design: no check fires, still not a pass"),
    Scn("good_nosolver_golden", "st_good_test", "", solver="z3 --in", kind="broken", key="SOLVER",
        why="dd105_base_test's solver check stops the run"),
    Scn("good_unset_golden", "st_good_test", "", solver="unset", kind="pass",
        why="no VERILATOR_SOLVER at run time: the default uvm.mk built in works"),
    Scn("nba_item_golden", "st_nba_item_test", kind="pass",
        why="a class driver driving pins with <= once per item sends them all"),
    Scn("nba_beat_golden", "st_nba_beat_test", kind="pass",
        why="a class driver driving pins with <= in a loop of beats sends them all"),
    Scn("null_vif", "st_null_vif_test", kind="broken", key="fatal-user",
        why="UVM_FATAL [NOVIF] is config, not a check"),
    Scn("no_such_test", "no_such_test", kind="broken", key="INVTST",
        why="unknown UVM_TESTNAME: UVM_FATAL, and exit status 0"),
    Scn("crash_golden", "st_crash_test", kind="pass",
        why="the crash path is never reached on the golden design"),
    Scn("crash_B01", "st_crash_test", "B01", kind="broken", key="runtime",
        why="a null handle in the mismatch path: a crash, not a catch"),
    Scn("fatal_check_B01", "st_fatal_check_test", "B01", kind="broken", key="fatal-user",
        why="uvm_fatal used as a check"),
    Scn("hang_timeout", "st_hang_test", timeout=10, kind="broken", key="timeout",
        why="stopped by RUN_TIMEOUT"),
    Scn("hang_ph_timeout", "st_hang_test", plusargs="+UVM_TIMEOUT=100000,YES",
        kind="broken", key="PH_TIMEOUT", why="stopped by UVM's phase timeout"),
    Scn("misconnect", "st_misconnect_test", kind="broken", key="lib-error",
        why="a UVM_ERROR from the UVM library is not a check"),
    Scn("unsat", "st_unsat_test", kind="broken", key="randomize",
        why="randomize() failed and the test carried on"),
    Scn("unknown_bug", "st_good_test", "B99", kind="broken", key="bug-id",
        why="the design refuses a bug id it does not know"),
    # The bug-switch contract, using real logs read the wrong way round.
    Scn("good_golden", "st_good_test", read_bug="B01", kind="broken", key="bug-unconfirmed",
        why="BUG_CONFIRM set: asked for B01, and the design never said it was on"),
    Scn("good_B01", "st_good_test", "B01", read_bug="", kind="broken", key="bug-on-golden",
        why="BUG_CONFIRM set: a 'golden' run in which the design says a bug is on"),
    Scn("good_golden", "st_good_test", read_bug="B01", confirm=None, kind="pass",
        why="no BUG_CONFIRM (the router's case): the graders don't need the line"),
]


def first_key(run):
    if run.problems:
        return run.problems[0][0]
    if run.fired:
        return run.fired[0][0]
    return None


def keys(run):
    """Every reason a run is BROKEN, or every kind of check that fired."""
    return [k for k, _ in (run.problems or run.fired)]


def matches(run, s):
    """The run is in the expected class, and the expected reason is among its
    reasons (or, for a catch, in the text of a check that fired)."""
    if run.kind != s.kind:
        return False
    return s.key is None or s.key in keys(run) or any(s.key in l for _, l in run.fired)


def part1():
    print(RULE)
    print(" PART 1   verdict.py against real logs (logs/, recorded in the course image)")
    print(RULE)
    bad = 0
    for s in SCENARIOS:
        d = os.path.join(LOGS, s.name)
        if not os.path.exists(os.path.join(d, "run.log")):
            print(f"  {'WRONG':>6}  {s.name}: logs/{s.name}/run.log is missing (make capture)")
            bad += 1
            continue
        r = V.read_run(d, expect_bug=s.read_bug or None, confirm=s.confirm)
        ok = matches(r, s)
        bad += not ok
        tag = f"{s.name}" + (f" read as +BUG={s.read_bug}" if s.read_bug != s.bug else "") \
            + (" no BUG_CONFIRM" if s.confirm is None else "")
        shown = s.key if ok and s.key else (first_key(r) or "")
        print(f"  {'ok' if ok else 'WRONG':>6}  {tag:<38} {r.kind:<7} {shown:<16}")
        print(f"          {s.why}")
        if not ok:
            print(f"          EXPECTED {s.kind}/{s.key}, got {r.kind}/{keys(r)}")
            for k, l in r.problems[:3]:
                print(f"            problem {k}: {l[:90]}")
    print(THIN)
    print(f" {len(SCENARIOS) - bad} of {len(SCENARIOS)} classifier cases correct.")
    print(RULE)
    return bad == 0


# ─────────────────────────────────────────────────────────────────────────────
# Running the selftest design
# ─────────────────────────────────────────────────────────────────────────────

def make(*args, env=None, timeout=900):
    cmd = ["make", "--no-print-directory", "-C", ALU] + list(args)
    e = dict(os.environ)
    if env:
        e.update(env)
    p = subprocess.run(cmd, capture_output=True, text=True, env=e, timeout=timeout)
    return p.returncode, p.stdout + p.stderr


def sim_path():
    return os.path.join(ALU, "build", "sim")


def run_direct(s, run_dir):
    """Run the simulator by hand, the way a student might outside make, with a
    broken solver in the environment. make refuses to do this (its solver
    guard), which is why the selftest has to."""
    os.makedirs(run_dir, exist_ok=True)
    args = [sim_path(), f"+UVM_TESTNAME={s.test}", "+verilator+seed+1"] + s.plusargs.split()
    if s.bug:
        args.append(f"+BUG={s.bug}")
    env = dict(os.environ)
    env.pop("VERILATOR_SOLVER", None)
    if s.solver != "unset":
        env["VERILATOR_SOLVER"] = s.solver
    with open(os.path.join(run_dir, "run.log"), "w") as log:
        try:
            p = subprocess.run(args, cwd=run_dir, stdout=log, stderr=subprocess.STDOUT,
                               env=env, timeout=s.timeout)
            rc = p.returncode
        except subprocess.TimeoutExpired:
            rc = 124
    open(os.path.join(run_dir, "exit_status"), "w").write(f"{rc}\n")


def run_scenario(s, run_dir):
    if s.solver:
        run_direct(s, run_dir)
    else:
        make("_run", "NOBUILD=1", f"RUN_DIR={run_dir}", f"UVM_TESTNAME={s.test}", "SEED=1",
             f"BUG={s.bug}", f"PLUSARGS={s.plusargs}", f"RUN_TIMEOUT={s.timeout}",
             timeout=s.timeout + 60)


def capture():
    """Re-record logs/ from real runs. Run this in the course image after an
    image or library change, then read the diff before committing it."""
    print(RULE)
    print(" CAPTURE   re-recording logs/ from real runs of alu/")
    print(RULE)
    rc, out = make("build")
    if rc != 0:
        print(out[-3000:])
        return False
    done = set()
    for s in SCENARIOS:
        if s.name in done:
            continue
        done.add(s.name)
        d = os.path.join(LOGS, s.name)
        shutil.rmtree(d, ignore_errors=True)
        tmp = os.path.join(ALU, "build", "capture", s.name)
        shutil.rmtree(tmp, ignore_errors=True)
        run_scenario(s, tmp)
        os.makedirs(d, exist_ok=True)
        for f in ("run.log", "exit_status"):
            src = os.path.join(tmp, f)
            if os.path.exists(src):
                text = open(src, errors="replace").read()
                # Make the logs independent of where the clone was mounted.
                text = text.replace(os.path.abspath(os.path.join(COMMON, "..", "..")) + "/", "")
                open(os.path.join(d, f), "w").write(text)
        rc_text = open(os.path.join(d, "exit_status")).read().strip()
        print(f"  {s.name:<26} exit {rc_text:>3}   {len(open(os.path.join(d, 'run.log')).read()):>6} bytes")
    print(RULE)
    return True


# ─────────────────────────────────────────────────────────────────────────────
# PART 2 -- the graders, end to end
# ─────────────────────────────────────────────────────────────────────────────

class Expect:
    """Run a make target in alu/, then read what it printed."""

    def __init__(self, label, args, must_say, must_not_say=("VERDICT: PASS",),
                 exit_zero=False, then=None):
        self.label, self.args = label, args
        self.must_say, self.must_not_say = must_say, must_not_say
        self.exit_zero, self.then = exit_zero, then

    def check(self):
        code, out = make(*self.args)
        problems = [f'did not say "{s}"' for s in self.must_say if s not in out]
        problems += [f'said "{s}" and must not' for s in self.must_not_say if s in out]
        if self.exit_zero and code != 0:
            problems.append(f"exited {code}, expected 0")
        if not self.exit_zero and code == 0:
            problems.append("exited 0")
        if self.then:
            problems += self.then()
        return problems, out


TB = "tb/st_if.sv tb/st_sva.sv tb/st_pkg.sv tb/st_top.sv"


def no_file(path):
    return lambda: [] if not os.path.exists(path) else [f"{path} exists and must not"]


def has_file(path):
    return lambda: [] if os.path.exists(path) else [f"{path} is missing"]


def cases():
    T = "UVM_TESTNAME="
    return [
        Expect("solver guard: VERILATOR_SOLVER empty",
               ["build", "VERILATOR_SOLVER="], ["VERILATOR_SOLVER is empty"]),
        Expect("solver guard: a solver that is not installed",
               ["build", "VERILATOR_SOLVER=z3 --in"], ["is not on PATH"]),
        Expect("reads +BUG and st_bug_pkg::bug_id: refused before anything is built",
               ["check", T + "st_cheat_test", f"TB_SRCS={TB} cheat/st_cheat_test.sv"],
               ["reads which bug is on", "cheat/st_cheat_test.sv:11", "cheat/st_cheat_test.sv:12"],
               must_not_say=("VERDICT: PASS", " BUILD ")),
        Expect("a build that fails",
               ["check", T + "st_good_test", f"TB_SRCS={TB} broken/st_syntax_error.sv",
                f"BUILD_DIR={ALU}/build-broken"],
               ["BUILD FAILED", "BROKEN", "did not build"]),
        Expect("the reference test, B01: a UVM_ERROR fires",
               ["check", T + "st_good_test", "BUG=B01"],
               ["VERDICT: PASS", "caught", "MISMATCH SUB"],
               must_not_say=("VERDICT: FAIL", "BROKEN"), exit_zero=True),
        Expect("the reference test, B02: only an assertion can see it",
               ["check", T + "st_good_test", "BUG=B02"],
               ["VERDICT: PASS", "Assertion failed"],
               must_not_say=("VERDICT: FAIL", "BROKEN"), exit_zero=True),
        Expect("the reference test against every bug",
               ["check-all", T + "st_good_test"],
               ["2 of 3 caught", "MISSED", "B03_add_magic_pair", "one operand pair"],
               must_not_say=("NO COUNT", "BROKEN")),
        Expect("sends nothing",
               ["check", T + "st_empty_test", "BUG=B01"],
               ["MISSED", "passes B01_sub_borrow_on_equal too"]),
        Expect("never randomizes",
               ["check", T + "st_fixed_test", "BUG=B01"],
               ["MISSED", "passes B01_sub_borrow_on_equal too"]),
        Expect("plain uvm_test: exit status 0 after UVM_ERROR",
               ["check", T + "st_plain_test", "BUG=B01"],
               ["VERDICT: PASS", "exit status was 0"],
               must_not_say=("VERDICT: FAIL", "BROKEN"), exit_zero=True),
        Expect("UVM_FATAL from config (no virtual interface)",
               ["check", T + "st_null_vif_test", "BUG=B01"],
               ["BROKEN", "NOVIF", "VERDICT: FAIL"]),
        Expect("unknown UVM_TESTNAME",
               ["check", T + "no_such_test", "BUG=B01"],
               ["BROKEN", "INVTST", "VERDICT: FAIL"]),
        Expect("crash in the mismatch path",
               ["check", T + "st_crash_test", "BUG=B01"],
               ["ok", "BROKEN", "VERDICT: FAIL", "only a wrong answer reaches"],
               must_not_say=("VERDICT: PASS", " caught ")),
        Expect("uvm_fatal used as a check",
               ["check", T + "st_fatal_check_test", "BUG=B01"],
               ["BROKEN", "UVM_FATAL [SB]", "VERDICT: FAIL"]),
        Expect("a hang, stopped by RUN_TIMEOUT",
               ["check", T + "st_hang_test", "BUG=B01", "RUN_TIMEOUT=10"],
               ["BROKEN", "timed out", "VERDICT: FAIL"]),
        Expect("a hang, stopped by UVM's phase timeout",
               ["check", T + "st_hang_test", "BUG=B01", "PLUSARGS=+UVM_TIMEOUT=100000,YES"],
               ["BROKEN", "PH_TIMEOUT", "VERDICT: FAIL"]),
        Expect("a UVM_ERROR from the UVM library",
               ["check", T + "st_misconnect_test", "BUG=B01"],
               ["BROKEN", "Connection Error", "VERDICT: FAIL"]),
        Expect("class driver, <= once per item: every item arrives (no NBA trap)",
               ["check", T + "st_nba_item_test", "BUG=B01"],
               ["VERDICT: PASS"], must_not_say=("VERDICT: FAIL", "BROKEN", "COUNT"),
               exit_zero=True),
        Expect("class driver, <= in a loop of beats: every beat arrives (no NBA trap)",
               ["check", T + "st_nba_beat_test", "BUG=B01"],
               ["VERDICT: PASS"], must_not_say=("VERDICT: FAIL", "BROKEN", "COUNT"),
               exit_zero=True),
        Expect("an unsatisfiable constraint, result ignored",
               ["check", T + "st_unsat_test", "BUG=B01"],
               ["BROKEN", "randomize() failed", "VERDICT: FAIL"]),
        Expect("a bug id the lab does not have",
               ["check", T + "st_good_test", "BUG=B99"],
               ["is not one of this lab's bugs"]),
        Expect("a bug id the design does not know (make run)",
               ["run", T + "st_good_test", "BUG=B99"],
               ["BROKEN", "unknown bug id"]),
        Expect("make run, golden: one line, ok",
               ["run", T + "st_good_test"],
               ["ok: 0 UVM_ERROR, 0 UVM_FATAL", "DD105: TEST PASSED"],
               must_not_say=("BROKEN",), exit_zero=True),
        Expect("make regress: 2 tests x 2 seeds, then coverage",
               ["regress", "TESTS=st_good_test st_empty_test", "SEEDS=1 2"],
               ["4 ok", "covergroup"], must_not_say=("BROKEN", "FAIL"), exit_zero=True),
        Expect("make waves: an FST file with the design in it and no package variable",
               ["waves", T + "st_good_test", "PLUSARGS=+N=20", "BUG=B01"],
               ["waves.fst"], must_not_say=("BROKEN",), exit_zero=True,
               then=wave_scopes(os.path.join(ALU, "build", "runs", "st_good_test-s1-B01", "waves.fst"))),
    ]


def wave_scopes(fst):
    """The waves hold the top, the interface, the ALU and its bound assertion,
    and no variable from any package: not uvm_pkg's statics, not
    st_bug_pkg::bug_id. (Verilator 5.050 still lists a few package scopes,
    empty, with dd105_trace.vlt on.)"""
    def check():
        if not os.path.exists(fst):
            return [f"{fst} is missing"]
        p = subprocess.run(["fst2vcd", fst], capture_output=True, text=True)
        head = p.stdout.split("$enddefinitions")[0]
        scopes, path, in_pkg = set(), [], []
        out = []
        for line in head.splitlines():
            m = re.match(r"\$scope module (\S+) \$end", line)
            if m:
                path.append(m.group(1))
                scopes.add(m.group(1))
            elif line.startswith("$upscope"):
                path.pop()
            elif line.startswith("$var") and any("pkg" in s for s in path):
                in_pkg.append(".".join(path) + ": " + line.split()[4])
        out += [f"no scope {s} in the waves" for s in ("st_top", "sif", "u_alu", "u_sva")
                if s not in scopes]
        out += [f"package variable in the waves: {v}" for v in in_pkg[:5]]
        if "bug_id" in head:
            out.append("bug_id is in the waves")
        return out
    return check


def nba_repro():
    """Build nba/nba_repro.sv on its own (seconds) and read what it prints."""
    d = os.path.join(ALU, "build", "nba")
    shutil.rmtree(d, ignore_errors=True)
    src = os.path.join(HERE, "nba", "nba_repro.sv")
    b = subprocess.run(["verilator", "--binary", "--timing", "-Wno-fatal", "--Mdir", d, "-o", "sim", src],
                       capture_output=True, text=True)
    if b.returncode != 0:
        return [f"the reproducer did not build: {b.stdout[-300:]}{b.stderr[-300:]}"], b.stdout
    r = subprocess.run([os.path.join(d, "sim")], capture_output=True, text=True)
    want = "a 1 of 3, b 3 of 3, c 3 of 3, g 3 of 3"
    problems = [] if want in r.stdout else [
        f"expected '{want}', got '{r.stdout.strip()}'. The trap has changed on this "
        "Verilator: update labs/common/README.md, uvm/dd105_pkg.sv and nba/nba_repro.sv."]
    shutil.rmtree(d, ignore_errors=True)
    return problems, r.stdout


def hunt_cases():
    T = "UVM_TESTNAME="
    seal = os.path.join(ALU, ".hunt")
    return [
        Expect("hunt: deal B01", ["new", "BUGPICK=B01"], ["A MYSTERY BUG"], must_not_say=("B01",),
               exit_zero=True, then=has_file(seal)),
        Expect("hunt: the loop names no bug", ["hunt", T + "st_good_test", "VERBOSE=1"],
               ["<sealed>", "disagrees with your test"], must_not_say=("B01", "borrow"),
               exit_zero=True),
        Expect("hunt verdict: a test that catches it",
               ["verdict", T + "st_good_test"],
               ["VERDICT: PASS", "B01_sub_borrow_on_equal"], must_not_say=("BROKEN",),
               exit_zero=True),
        Expect("hunt verdict: a test that sends nothing",
               ["verdict", T + "st_empty_test"],
               ["MISSED", "row 2", "VERDICT: FAIL"]),
        Expect("hunt verdict: a crash in the mismatch path",
               ["verdict", T + "st_crash_test"],
               ["BROKEN", "VERDICT: FAIL"], must_not_say=("VERDICT: PASS", "B01")),
        Expect("hunt: reveal", ["reveal"], ["B01_sub_borrow_on_equal"], must_not_say=(),
               exit_zero=True),
    ]


def solver_cases():
    """Run the simulator with a broken solver, outside make, and grade the logs."""
    out = []
    for name in ("plain_nosolver_golden", "plain_nosolver_B01", "good_nosolver_golden",
                 "good_unset_golden"):
        s = next(x for x in SCENARIOS if x.name == name)
        d = os.path.join(ALU, "build", "nosolver", name)
        shutil.rmtree(d, ignore_errors=True)
        run_scenario(s, d)
        r = V.read_run(d, expect_bug=s.bug or None, confirm=s.confirm)
        problems = []
        if not matches(r, s):
            problems.append(f"classified {r.kind}/{keys(r)}, expected {s.kind}/{s.key}")
        if s.kind == "broken" and any(k == "UVM_ERROR" for k, _ in r.fired):
            problems.append("a check fired, so the stimulus did vary")
        out.append((f"run by hand: {s.why}", problems, r.log))
    return out


def part2(full):
    print(RULE)
    print(" PART 2   the graders, end to end, on alu/")
    print(RULE)
    if not full:
        print(" Skipped. This part builds a UVM simulator and takes minutes.")
        print("     make FULL=1")
        print(RULE)
        return True
    if not shutil.which("verilator"):
        print(" verilator is not on PATH: run this in the course image.")
        print(RULE)
        return False
    if os.path.exists(os.path.join(ALU, ".hunt")):
        os.remove(os.path.join(ALU, ".hunt"))

    print(" building alu/ ...")
    rc, out = make("build")
    print("   " + "\n   ".join(l for l in out.splitlines() if re.search(r"built |up to date|FAILED", l)))
    if rc != 0:
        print(out[-3000:])
        return False

    bad = 0

    def show(label, problems, out):
        nonlocal bad
        bad += bool(problems)
        print(f"  {'ok' if not problems else 'WRONG':>6}  {label}")
        for p in problems:
            print(f"          {p}")
        if problems:
            print(THIN)
            for l in out.strip().splitlines()[-25:]:
                print("          " + l)
            print(THIN)

    try:
        for e in cases():
            show(e.label, *e.check())
        for label, problems, log in solver_cases():
            show(label, problems, log)
        show("the NBA trap: a module-task loop loses it, class code doesn't (nba/nba_repro.sv)",
             *nba_repro())
        for e in hunt_cases():
            show(e.label, *e.check())
    finally:
        for p in (os.path.join(ALU, ".hunt"),):
            if os.path.exists(p):
                os.remove(p)
        shutil.rmtree(os.path.join(ALU, "build-broken"), ignore_errors=True)

    print(THIN)
    print(" every grader gave every fixture the verdict it must." if not bad
          else f" {bad} case(s) got the wrong verdict. That is the serious kind.")
    print(RULE)
    return bad == 0


# ─────────────────────────────────────────────────────────────────────────────
# PART 3 -- nobody has re-grown their own copy of the rule
# ─────────────────────────────────────────────────────────────────────────────

GRADERS = ["check.py", "hunt.py", "regress.py"]
FORBIDDEN = [
    (re.compile(r"^\s*class Run\b", re.M), "its own Run class -- use verdict.read_run()"),
    (re.compile(r"^\s*def classify\(", re.M), "its own classify() -- use verdict.py"),
    (re.compile(r"Report Summary"), "reads the UVM summary itself -- verdict.py does that"),
    (re.compile(r"Assertion failed"), "reads assertion failures itself -- verdict.py does that"),
    (re.compile(r"%Error|UNSATCONSTR"), "reads Verilator's messages itself -- verdict.py does that"),
    (re.compile(r"open\([^)]*exit_status"), "reads exit_status itself -- verdict.py does that"),
]


def part3():
    print(RULE)
    print(" PART 3   every grader reads the rule from verdict.py")
    print(RULE)
    bad = 0
    for g in GRADERS:
        src = open(os.path.join(COMMON, g)).read()
        hits = [why for rx, why in FORBIDDEN if rx.search(src)]
        if not re.search(r"^import verdict as V", src, re.M):
            hits.append("does not import verdict.py")
        bad += bool(hits)
        print(f"  {'ok' if not hits else 'WRONG':>6}  {g}")
        for h in hits:
            print(f"          {h}")
    print(THIN)
    print(f" {len(GRADERS) - bad} of {len(GRADERS)} graders.")
    print(RULE)
    return bad == 0


def main():
    if "--capture" in sys.argv:
        return 0 if capture() else 1
    full = os.environ.get("FULL", "").strip().lower() not in ("", "0", "no", "false")
    ok = part1()
    ok = part3() and ok
    ok = part2(full) and ok
    print("")
    print(" SELFTEST: PASS" if ok else " SELFTEST: FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
