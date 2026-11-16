"""
DD105-A: reading a UVM run, and the one distinction every verdict depends on.

    from verdict import read_run
    run = read_run("build/grade/golden", expect_bug=None)
    run.kind        'pass', 'caught' or 'broken'
    run.mark("pass")   'ok' / 'FAIL' / 'BROKEN'     (the golden design)
    run.mark("fail")   'caught' / 'MISSED' / 'BROKEN' (a design with a bug on)

    python3 verdict.py <run folder> [--bug ID]    one run, one line; exit 0 = pass

────────────────────────────────────────────────────────────────────────────
WHY THIS FILE EXISTS
────────────────────────────────────────────────────────────────────────────
DD104 learned this the hard way: a test that does not pass has not
necessarily checked anything. DD104's grader once told a student `3 of 3 ALU
bugs caught` about a testbench that raised NameError on every core. The
three catches were three crashes.

A UVM run on Verilator has more ways to go wrong than a cocotb test, and
fewer of them show in the exit status:

  - UVM_ERROR and even UVM_FATAL end with exit status 0 (matrix, limit 6),
    unless the test extends dd105_base_test, which adds a $fatal at the end.
  - With no constraint solver, every randomize() returns 0 and the run
    passes, having sent the same item over and over (limit 1).
  - A null handle in a scoreboard's mismatch path kills the run only when
    the design is wrong: the exact shape of DD104's NameError.

So the verdict reads the log, not just the exit status. A run is one of:

    pass     it ran to UVM's report summary, exit status 0, and nothing
             fired: no UVM_ERROR, no UVM_FATAL, no failed assertion
    caught   a CHECK fired, and nothing else went wrong
    BROKEN   anything else. A BROKEN run is a statement about the testbench
             or the setup, not about the design, so it is never a pass and
             never a catch.

────────────────────────────────────────────────────────────────────────────
WHAT COUNTS AS A CHECK: a whitelist, on purpose
────────────────────────────────────────────────────────────────────────────
Only three things count as "a check fired":

  1. a UVM_ERROR raised by code in the lab (your scoreboard, monitor, test):
     a `uvm_error with a file name that is not in the UVM library;
  2. a UVM_ERROR from the UVM register layer that compares the design with
     the register model (LIBRARY_CHECKS below: mirror, bit-bash, mem walk);
  3. a failed SystemVerilog assertion, or a $error, which Verilator reports
     the same way ("%Error: ... Assertion failed in ..."). A $fatal is not.

Everything else is BROKEN: a build that failed, any UVM_FATAL (unknown test,
missing virtual interface, randomize() failed, phase timeout), a UVM_ERROR
from the UVM library itself (a port left unconnected), a run that hit the
time limit, a crash or a null handle, a constraint the solver could not
satisfy, a missing solver, a run that stopped before UVM's summary, and, in a
lab that sets BUG_CONFIRM, a bug switch the design did not confirm.

As in DD104, a whitelist and not a blacklist: a blacklist is wrong the first
time a run fails in a way nobody listed, and wrong in that direction means a
crash scored as a catch. A whitelist that is wrong prints FAIL with the
reason, which a student can read and act on. When the course adds a new way
for a check to say "the design is wrong", add it here and to the selftest.
"""

import argparse
import os
import re
import sys

# ── the bug switch contract (the design under test provides this) ───────────
# No +BUG (or +BUG=none) is the golden design, +BUG=<id> turns one bug on, and
# an id the design doesn't know is a $fatal. The design need not say which bug
# is on. If it does, the lab sets BUG_CONFIRM to that line with {id} in it,
# and then a bug run without the line, or a golden run with one, is BROKEN.
BUG_UNKNOWN = re.compile(r"DD105-BUG: unknown bug id|is not a bug in this build")


def confirm_regex(confirm):
    """'DD105-BUG: {id} enabled' -> a regex that captures the id."""
    if not confirm:
        return None
    return re.compile(r"(\S+)".join(re.escape(p) for p in confirm.split("{id}")))

# ── UVM's own output ─────────────────────────────────────────────────────────
REPORT = re.compile(
    r"^(UVM_INFO|UVM_WARNING|UVM_ERROR|UVM_FATAL)\s+"
    r"(?:(\S+)\((\d+)\)\s+)?"          # file(line), absent for function-call reports
    r"@\s*([^:]*):\s+"                 # @ time:
    r"(\S+)\s+"                        # context (component path or reporter)
    r"\[([^\]]*)\]\s?(.*)$")           # [ID] message
SUMMARY_HEAD = "--- UVM Report Summary ---"
SUMMARY_COUNT = re.compile(r"^(UVM_INFO|UVM_WARNING|UVM_ERROR|UVM_FATAL)\s*:\s*(\d+)\s*$")
MARKER = re.compile(r"^DD105: TEST (PASSED|FAILED)")

# ── Verilator's own output ───────────────────────────────────────────────────
VL_ERROR = re.compile(r"^(?:\[[^\]]*\]\s*)?%(Error|Fatal)(?:-[A-Z0-9_]+)?:\s*(.*)$")
ASSERTION = re.compile(r"Assertion failed in")
OUR_FATAL = re.compile(r"DD105: UVM counted errors")   # dd105_base_test's own $fatal
SOLVER_TROUBLE = re.compile(r"Subprocess command .* failed|SAT solver|solver.*not found",
                            re.IGNORECASE)
UNSAT = re.compile(r"%Warning-UNSATCONSTR")

# UVM_ERRORs raised inside the UVM library that are checks of the DESIGN: the
# register layer comparing what it read with what the model predicted.
LIBRARY_CHECKS = [
    ("RegModel", re.compile(r"value read from DUT .* does not match mirrored value")),
    ("uvm_reg_bit_bash_seq", re.compile(r"^Writing a [01] in bit #\d+ of register")),
    ("uvm_mem_walk_seq", re.compile(r"read back as .* instead of")),
    ("uvm_mem_access_seq", re.compile(r"read back as .* instead of")),
]

UVM_LIB_PATH = re.compile(r"(^|/)third_party/uvm/src/")
INFRA_FILE = re.compile(r"(^|/)common/uvm/dd105_[a-z_]+\.sv$")

# What each kind of BROKEN means, in words a student can act on.
WHY = {
    "build": "The simulator did not build, so nothing ran. The build log says why.",
    "nolaunch": "The simulator never started, so nothing ran.",
    "timeout": ("The run was still going when the time limit hit, and it was stopped. A hang "
                "is not a catch: if the design really stops answering, catch that with a "
                "check of your own (a watchdog that reports `uvm_error` after N cycles)."),
    "signal": ("The simulator crashed. Nothing after the crash was checked, so this says "
               "nothing about the design."),
    "solver": ("Verilator could not start its constraint solver, so every constrained "
               "randomize() failed and nothing was randomized. Run through make, which sets "
               "VERILATOR_SOLVER=\"yices-smt2 --incremental\"."),
    "randomize": ("randomize() failed during the run (UNSATCONSTR or RNDFLD), so the stimulus "
                  "was not what the test asked for. Check its return value, and see the "
                  "course's list of constraints Verilator 5.050 gets wrong."),
    "fatal-user": ("UVM_FATAL is how a testbench says it cannot go on: no virtual interface in "
                   "config_db, randomize() failed, a missing configuration. It is not a check. "
                   "If you meant it as one, report a wrong answer with `uvm_error, so the run "
                   "goes on and counts."),
    "fatal-lib": "The UVM library stopped the run. Its message says what the testbench did wrong.",
    "INVTST": ("UVM has no test by that name. Compare UVM_TESTNAME with `make tests`, and check "
               "the test class has `uvm_component_utils."),
    "NOCOMP": "No test ran: UVM_TESTNAME was empty and the top module created no components.",
    "PH_TIMEOUT": ("The run hit UVM's phase timeout: an objection was raised and never dropped. "
                   "A hang is not a catch; catch a design that stops answering with a check of "
                   "your own."),
    "SOLVER": ("dd105_base_test found that constrained randomize() does not work, so nothing "
               "would have been randomized. Run through make, which sets VERILATOR_SOLVER."),
    "lib-error": ("This UVM_ERROR comes from the UVM library, not from a check: the testbench "
                  "used UVM wrongly (for example a port left unconnected). It fires on the "
                  "golden design too, so it says nothing about the design."),
    "hidden": ("UVM counted more errors or fatals than it printed, so their origin can't be "
               "read. Leave the display action on for UVM_ERROR and UVM_FATAL."),
    "runtime": ("The simulator stopped with an error that is not a check: a null handle or "
                "an array index out of range in the testbench, for example."),
    "fatal-sv": ("A $fatal stopped the run. Like UVM_FATAL, it is how a testbench gives up, "
                 "not how it checks: report a wrong answer with $error, an assertion or "
                 "`uvm_error."),
    "no-summary": ("The run ended before UVM printed its report summary: something called "
                   "$finish early, or UVM never started."),
    "exit": "The simulator exited non-zero, and nothing in the log says why.",
    "bug-id": "The design does not know that bug id. `make check-all` lists the ids.",
    "bug-unconfirmed": ("This run asked for a planted bug, and the design never printed the "
                        "line that says it is on (BUG_CONFIRM), so the bug may be off. A run "
                        "against a bug that is off says nothing."),
    "bug-on-golden": ("This was meant to be the golden design, but the design printed the "
                      "line that says a bug is on (BUG_CONFIRM)."),
}


class Report:
    """One UVM report line."""

    def __init__(self, severity, file, line, time, context, rid, msg):
        self.severity, self.file, self.line = severity, file, line
        self.time, self.context, self.id, self.msg = time, context, rid, msg

    def from_library(self, uvm_home=None):
        if not self.file:
            return True                      # uvm_report_*() calls carry no file
        if UVM_LIB_PATH.search(self.file):
            return True
        if uvm_home and os.path.abspath(self.file).startswith(os.path.abspath(uvm_home)):
            return True
        return bool(INFRA_FILE.search(self.file))

    def library_check(self):
        return any(self.id == rid and rx.search(self.msg) for rid, rx in LIBRARY_CHECKS)

    @property
    def one_line(self):
        return f"{self.severity} [{self.id}] {self.msg.strip()}"


class Run:
    """What one simulation did, read from its folder (see uvm.mk's run_sim)."""

    def __init__(self, label="", run_dir="", log="", exit_status=None, seconds=0.0,
                 cmd="", launched=True, build_failed=False):
        self.label = label
        self.run_dir = run_dir
        self.log = log
        self.exit_status = exit_status
        self.seconds = seconds
        self.cmd = cmd
        self.launched = launched
        self.build_failed = build_failed
        self.reports = []
        self.counts = None                   # the UVM summary, if the run reached it
        self.marker = None                   # 'PASSED' / 'FAILED' from dd105_base_test
        self.vl_errors = []
        self.bug_ids = []
        self.fired = []                      # (kind, one line): the checks that fired
        self.problems = []                   # (key, one line): why the run is BROKEN
        self.notes = []                      # remarks that change nothing

    # ── the three classes ───────────────────────────────────────────────────
    @property
    def kind(self):
        if self.problems:
            return "broken"
        return "caught" if self.fired else "pass"

    @property
    def broken(self):
        return self.kind == "broken"

    @property
    def passed(self):
        return self.kind == "pass"

    @property
    def caught(self):
        return self.kind == "caught"

    def mark(self, expectation):
        """The word in a report row. expectation is 'pass' (the golden design:
        nothing may fire) or 'fail' (a bug is on: a check must fire)."""
        if self.broken:
            return "BROKEN"
        if expectation == "pass":
            return "ok" if self.passed else "FAIL"
        return "caught" if self.caught else "MISSED"

    def count(self, sev):
        n = sum(1 for r in self.reports if r.severity == sev)
        if self.counts and sev in self.counts:
            n = max(n, self.counts[sev])
        return n

    def summary(self):
        """A few words for a report row."""
        if self.build_failed:
            return "the build failed"
        if not self.launched:
            return "did not run"
        if self.problems:
            key, line = self.problems[0]
            if key == "timeout":
                return "timed out"
            if key == "signal":
                return "crashed"
            if key in ("solver", "SOLVER"):
                return "no constraint solver"
            if key == "randomize":
                return "randomize() failed"
            if key.startswith("bug"):
                return "bug switch problem"
            m = re.match(r"(UVM_\w+) \[([^\]]*)\]", line)
            if m:
                return f"{m.group(1)} [{m.group(2)}]"[:30]
            return key
        if self.fired:
            n_err = sum(1 for k, _ in self.fired if k == "UVM_ERROR")
            n_asr = sum(1 for k, _ in self.fired if k == "assertion")
            bits = []
            if n_err:
                bits.append(f"{self.count('UVM_ERROR')} UVM_ERROR")
            if n_asr:
                bits.append(f"{n_asr} assertion" + ("" if n_asr == 1 else "s"))
            return ", ".join(bits)
        return "0 UVM_ERROR, 0 UVM_FATAL"

    def first_fired(self):
        return self.fired[0][1] if self.fired else ""


# ── reading a run ────────────────────────────────────────────────────────────

def _read(path, default=""):
    try:
        with open(path, errors="replace") as f:
            return f.read()
    except OSError:
        return default


def read_run(run_dir, expect_bug=None, label="", uvm_home=None, confirm=None):
    """Read a run folder written by uvm.mk (run.log, exit_status, seconds, cmd).
    expect_bug is the +BUG id the run was given (None: the golden design), and
    confirm is the lab's BUG_CONFIRM line, if it has one."""
    log = _read(os.path.join(run_dir, "run.log"), None)
    rc_text = _read(os.path.join(run_dir, "exit_status")).strip()
    if log is None or not rc_text:
        run = Run(label, run_dir, log or "", None, 0.0, launched=False)
        run.problems.append(("nolaunch", "the simulator never ran"))
        return run
    try:
        seconds = float(_read(os.path.join(run_dir, "seconds"), "0") or 0)
    except ValueError:
        seconds = 0.0
    run = Run(label, run_dir, log, int(rc_text), seconds,
              _read(os.path.join(run_dir, "cmd")).strip())
    classify(run, expect_bug, uvm_home, confirm)
    return run


def build_failed(label="the build", log=""):
    run = Run(label, "", log, None, 0.0, launched=False, build_failed=True)
    run.problems.append(("build", "the simulator did not build"))
    return run


def classify(run, expect_bug=None, uvm_home=None, confirm=None):
    """Fill run.fired, run.problems and run.notes from run.log and the exit status."""
    lines = run.log.splitlines()
    confirm_rx = confirm_regex(confirm)
    in_summary = False
    counts = None
    for line in lines:
        s = line.rstrip()
        m = REPORT.match(s)
        if m:
            run.reports.append(Report(*m.groups()))
            continue
        if s.strip() == SUMMARY_HEAD:
            in_summary, counts = True, {}
            continue
        if in_summary:
            c = SUMMARY_COUNT.match(s.strip())
            if c:
                counts[c.group(1)] = int(c.group(2))
                continue
        m = MARKER.match(s)
        if m:
            run.marker = m.group(1)
            continue
        m = VL_ERROR.match(s)
        if m:
            run.vl_errors.append((m.group(1), m.group(2)))
        m = confirm_rx.search(s) if confirm_rx else None
        if m:
            run.bug_ids.append(m.group(1))
    run.counts = counts

    P = run.problems

    # how the process ended
    rc = run.exit_status
    if rc == 124:
        P.append(("timeout", f"stopped after {run.seconds:.0f} s (the RUN_TIMEOUT limit)"))
    elif rc is not None and (rc < 0 or rc >= 128):
        sig = -rc if rc < 0 else rc - 128
        P.append(("signal", f"killed by signal {sig} (exit status {rc})"))

    # the solver, and randomize() failures
    solver = [l for l in lines if SOLVER_TROUBLE.search(l) and l.lstrip().startswith("%")]
    if solver:
        P.append(("solver", solver[0].strip()))
    unsat = [l for l in lines if UNSAT.search(l)]
    rndfld = [r for r in run.reports if r.id == "RNDFLD"]
    if unsat or rndfld:
        n = len(unsat) + len(rndfld)
        first = (unsat[0] if unsat else rndfld[0].one_line).strip()
        P.append(("randomize", f"randomize() failed {n} time{'s' if n != 1 else ''}: {first}"))

    # the bug switch
    if BUG_UNKNOWN.search(run.log):
        P.append(("bug-id", next(l.strip() for l in lines if BUG_UNKNOWN.search(l))))
    elif confirm_rx and expect_bug and expect_bug not in run.bug_ids:
        P.append(("bug-unconfirmed", f"asked for +BUG={expect_bug}; no "
                  f"'{confirm.replace('{id}', expect_bug)}' line in the log"))
    elif confirm_rx and not expect_bug and run.bug_ids:
        P.append(("bug-on-golden", f"'{confirm.replace('{id}', run.bug_ids[0])}' on the golden design"))

    # UVM's reports
    for r in run.reports:
        if r.severity == "UVM_FATAL":
            if r.id in WHY:
                key = r.id
            else:
                key = "fatal-lib" if r.from_library(uvm_home) else "fatal-user"
            P.append((key, r.one_line))
        elif r.severity == "UVM_ERROR":
            if not r.from_library(uvm_home) or r.library_check():
                run.fired.append(("UVM_ERROR", r.one_line))
            else:
                P.append(("lib-error", r.one_line))
    if counts:
        for sev in ("UVM_ERROR", "UVM_FATAL"):
            shown = sum(1 for r in run.reports if r.severity == sev)
            if counts.get(sev, 0) > shown:
                P.append(("hidden", f"the summary counts {counts[sev]} {sev}, the log shows {shown}"))

    # Verilator's own messages. It reports $error and a failed assertion as
    # "%Error: ... Assertion failed in ...", and $fatal as "%Fatal: ... Assertion
    # failed in ...", then "%Error: ... Verilog $stop" as the consequence.
    for sev, e in run.vl_errors:
        if OUR_FATAL.search(e) or BUG_UNKNOWN.search(e) or "Verilog $stop" in e:
            continue
        if ASSERTION.search(e) and sev == "Error":
            run.fired.append(("assertion", e.strip()))
        elif ASSERTION.search(e):
            P.append(("fatal-sv", e.strip()))
        else:
            P.append(("runtime", e.strip()))

    # did the run reach the end?
    asserted = any(k == "assertion" for k, _ in run.fired)
    if counts is None and not asserted and not P:
        P.append(("no-summary", "no '--- UVM Report Summary ---' in the log"))

    # the exit status has to agree with what the log says
    if rc == 0 and run.fired:
        run.notes.append("The exit status was 0 although a check fired: this test does not "
                         "end through dd105_base_test, so a script that reads only the exit "
                         "status would have called it a pass.")
    if rc not in (0, None, 124) and 0 < rc < 128 and not run.fired and not P:
        P.append(("exit", f"exit status {rc}"))
    return run


# ── the words the verdict says ───────────────────────────────────────────────

def explain(run, indent="   ", width=70):
    """The reason a run is BROKEN, in sentences."""
    out = []
    if not run.problems:
        return out
    key, line = run.problems[0]
    out.append(f"{indent}{line[:200]}")
    words, cur = WHY.get(key, WHY["exit"]).split(), ""
    for w in words:
        if len(cur) + len(w) + 1 > width:
            out.append(indent + cur)
            cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur:
        out.append(indent + cur)
    if len(run.problems) > 1:
        out.append(f"{indent}(and {len(run.problems) - 1} more problem"
                   f"{'s' if len(run.problems) > 2 else ''} in the same run)")
    return out


def report_problems(run, indent="        ", limit=3):
    """Under a report row: what broke, or the first checks that fired."""
    for key, line in run.problems[:limit]:
        print(f"{indent}BROKEN: {line[:100]}")
    if not run.problems:
        for kind, line in run.fired[:limit]:
            print(f"{indent}{line[:100]}")
    for n in run.notes:
        print(f"{indent}note: {n[:200]}")


def main():
    ap = argparse.ArgumentParser(description="DD105-A: classify one UVM run")
    ap.add_argument("run_dir")
    ap.add_argument("--bug", default="", help="the +BUG id the run was given, if any")
    ap.add_argument("--uvm-home", default=None)
    ap.add_argument("--bug-confirm", default="", help="the lab's BUG_CONFIRM, if any")
    a = ap.parse_args()
    run = read_run(a.run_dir, expect_bug=a.bug or None, uvm_home=a.uvm_home,
                   confirm=a.bug_confirm or None)
    rel = os.path.relpath(os.path.join(a.run_dir, "run.log"))
    mark = run.mark("fail" if a.bug else "pass")
    print("-" * 72)
    print(f" {mark}: {run.summary()}   {run.seconds:.2f} s   log: {rel}")
    if run.broken:
        for l in explain(run):
            print(l)
    else:
        for kind, line in run.fired[:3]:
            print(f"   {line[:110]}")
    for n in run.notes:
        print(f"   note: {n}")
    print("-" * 72)
    return 0 if run.passed else 1


if __name__ == "__main__":
    sys.exit(main())
