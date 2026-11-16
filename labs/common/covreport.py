"""
DD105-A: functional coverage you can read.

    make cov          every coverage.dat under build/runs, merged and reported
    (make regress     ends with the same report for the runs it just did)

On Verilator 5.050 the percentages a covergroup reports for itself do not
follow the standard's formula (crosses, ignore_bins and option.weight all
change it), and type-level get_coverage() returns 0. The per-bin hit counts in
coverage.dat are right. So this report merges the coverage.dat files with
verilator_coverage and lists every covergroup bin with its count, empty bins
first: an empty bin is a question about your stimulus.
"""

import argparse
import os
import re
import subprocess
import sys

RULE = "=" * 72
THIN = "-" * 72


def find_dats(paths):
    out = []
    for p in paths:
        if os.path.isfile(p):
            out.append(p)
        elif os.path.isdir(p):
            for root, _, files in os.walk(p):
                if "coverage.dat" in files:
                    out.append(os.path.join(root, "coverage.dat"))
    return sorted(out)


def read_dat(path):
    """[(fields, count)] from a Verilator coverage.dat."""
    recs = []
    with open(path, "rb") as f:
        for raw in f:
            line = raw.decode("utf-8", "replace").rstrip("\n")
            m = re.match(r"^C '(.*)' (\d+)$", line)
            if not m:
                continue
            fields = {}
            for item in m.group(1).split("\x01"):
                if "\x02" in item:
                    k, v = item.split("\x02", 1)
                    fields[k] = v
            recs.append((fields, int(m.group(2))))
    return recs


def report(run_dirs_or_dats, out_dir, empty_limit=40):
    dats = find_dats(run_dirs_or_dats)
    print(RULE)
    print(f" COVERAGE   {len(dats)} coverage.dat file{'s' if len(dats) != 1 else ''}")
    print(RULE)
    if not dats:
        print(" No coverage.dat found. Build with COVERAGE=1 (the default) and run a")
        print(" test first; each run writes coverage.dat into its folder in build/runs.")
        print(RULE)
        return False
    os.makedirs(out_dir, exist_ok=True)
    merged = os.path.join(out_dir, "merged.dat")
    p = subprocess.run(["verilator_coverage", "--write", merged] + dats,
                       capture_output=True, text=True)
    if p.returncode != 0 or not os.path.exists(merged):
        print(" verilator_coverage could not merge them:")
        print(p.stdout + p.stderr)
        return False
    p = subprocess.run(["verilator_coverage", merged], capture_output=True, text=True)
    summary = [l for l in (p.stdout + p.stderr).splitlines() if l.strip()]

    bins = [(f, n) for f, n in read_dat(merged) if f.get("t") == "covergroup"]
    groups = {}
    for f, n in bins:
        name = f.get("h") or f.get("o") or "?"
        point, _, b = name.rpartition(".")
        groups.setdefault(point or name, []).append((b or name, n, f))

    lines = []
    for point in sorted(groups):
        items = groups[point]
        hit = sum(1 for _, n, _ in items if n > 0)
        lines.append(f"  {point:<44} {hit:>4} of {len(items):<4} bins hit")
    empty = [(point, b) for point in sorted(groups) for b, n, _ in groups[point] if n == 0]

    for l in summary:
        print(f" verilator_coverage: {l.strip()}")
    print(THIN)
    if not bins:
        print(" No covergroup bins in the data (no covergroup was sampled).")
    else:
        print(f" {len(bins)} covergroup bins, {len(bins) - len(empty)} hit at least once:")
        for l in lines:
            print(l)
        if empty:
            print(THIN)
            print(f" {len(empty)} bins never hit" + (f" (first {empty_limit}):" if len(empty) > empty_limit else ":"))
            for point, b in empty[:empty_limit]:
                print(f"    {point}.{b}")
    print(THIN)
    with open(os.path.join(out_dir, "bins.txt"), "w") as f:
        for point in sorted(groups):
            for b, n, _ in groups[point]:
                f.write(f"{n:>10}  {point}.{b}\n")
    print(f" every bin with its count: {os.path.relpath(os.path.join(out_dir, 'bins.txt'))}")
    print(f" merged database:          {os.path.relpath(merged)}")
    print(RULE)
    return True


def main():
    ap = argparse.ArgumentParser(description="DD105-A: merge and read coverage.dat")
    ap.add_argument("paths", nargs="+", help="run folders or coverage.dat files")
    ap.add_argument("--out", required=True, help="where merged.dat and bins.txt go")
    a = ap.parse_args()
    return 0 if report(a.paths, a.out) else 1


if __name__ == "__main__":
    sys.exit(main())
