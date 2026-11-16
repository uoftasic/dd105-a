"""Assertions for interface rules: the stage's drop bug, cycle by cycle, and where a_S1 fires.

    python3 scripts/figures/assertion_drop_timing.py

writes docs/assets/img/assertion-drop-timing.svg. The values are those of the stage's signals in
the middle of cycles 19 to 27 of this run of guide-examples/assertions-for-interface-rules, read
from its waveform:

    make waves BUG=drop

Cycle n is the clock period that ends at the rising edge at 10n - 5 ns.
"""
import os

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "uoftasic-figures"
matplotlib.rcParams["font.family"] = "serif"
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Polygon, Rectangle  # noqa: E402

FIRST = 19
# cycle: (out_valid, out_ready, out_data, n_S1)
CYCLES = {
    19: (1, 0, "06", 0),
    20: (1, 1, "06", 0),
    21: (1, 0, "07", 0),
    22: (1, 0, "07", 0),
    23: (1, 0, "07", 0),
    24: (1, 0, "07", 0),
    25: (0, 0, "07", 0),
    26: (1, 1, "08", 1),
    27: (1, 1, "09", 1),
}
LAST = max(CYCLES)

INK = "#0b0b0b"
MUTED = "#52514e"
WAIT = "#dbe8f8"       # the cycles in which the antecedent of S1 holds
FAIL = "#c0392b"

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                                    "docs", "assets", "img", "assertion-drop-timing.svg"))

ROWS = ["clk", "out_valid", "out_ready", "out_data", "n_S1"]
H = 0.6          # height of a trace
GAP = 1.15       # distance between rows


def t0(n):
    """Start of cycle n, in ns: the rising edge that ends cycle n - 1."""
    return 10 * n - 15


fig, ax = plt.subplots(figsize=(8.6, 3.9))
y = {name: -k * GAP for k, name in enumerate(ROWS)}
x0, x1 = t0(FIRST), t0(LAST + 1)

# The cycles in which a beat waits, and the edge at which a_S1 fails.
for n, (v, r, _, _) in CYCLES.items():
    if v and not r:
        ax.add_patch(Rectangle((t0(n), y["n_S1"] - 0.25), 10, y["clk"] + H + 0.25 - y["n_S1"] + 0.25,
                               facecolor=WAIT, edgecolor="none", zorder=0))
fail_t = 10 * 25 - 5
ax.plot([fail_t, fail_t], [y["n_S1"] - 0.3, y["clk"] + H + 1.1], color=FAIL, lw=1.4, zorder=3)
ax.text(fail_t + 0.6, y["clk"] + H + 1.0, "a_S1 fails at 245 ns", color=FAIL, fontsize=10,
        va="center", ha="left")

# Cycle numbers along the top.
for n in CYCLES:
    ax.text(t0(n) + 5, y["clk"] + H + 0.25, str(n), ha="center", va="bottom", fontsize=9, color=MUTED)
ax.text(x0 - 1, y["clk"] + H + 0.25, "cycle", ha="right", va="bottom", fontsize=9, color=MUTED)

# clk: rises at the start of every cycle, falls in the middle.
xs, ys = [x0], [y["clk"]]
for n in range(FIRST, LAST + 1):
    a = t0(n)
    xs += [a, a, a + 5, a + 5, a + 10]
    ys += [y["clk"], y["clk"] + H, y["clk"] + H, y["clk"], y["clk"]]
ax.plot(xs, ys, color=INK, lw=1.2)


def bit(name, idx):
    xs, ys = [], []
    for n in range(FIRST, LAST + 1):
        level = y[name] + H * CYCLES[n][idx]
        xs += [t0(n), t0(n) + 10]
        ys += [level, level]
    ax.plot(xs, ys, color=INK, lw=1.2)


def bus(name, idx):
    n = FIRST
    while n <= LAST:
        m = n
        while m + 1 <= LAST and CYCLES[m + 1][idx] == CYCLES[n][idx]:
            m += 1
        a, b, s = t0(n), t0(m + 1), 0.8
        lo, hi = y[name], y[name] + H
        ax.add_patch(Polygon([(a, (lo + hi) / 2), (a + s, hi), (b - s, hi), (b, (lo + hi) / 2),
                              (b - s, lo), (a + s, lo)], closed=True, fill=False, edgecolor=INK, lw=1.2))
        ax.text((a + b) / 2, (lo + hi) / 2, str(CYCLES[n][idx]), ha="center", va="center", fontsize=10,
                color=INK)
        n = m + 1


bit("out_valid", 0)
bit("out_ready", 1)
bus("out_data", 2)
bus("n_S1", 3)

for name in ROWS:
    ax.text(x0 - 1.5, y[name] + H / 2, name, ha="right", va="center", fontsize=11, color=INK)

ax.text((t0(21) + t0(25)) / 2, y["n_S1"] - 0.55, "beat 07 waits in cycles 21 to 24, then disappears",
        ha="center", va="center", fontsize=10, color=MUTED)

ax.set_xlim(x0 - 16, x1 + 1)
ax.set_ylim(y["n_S1"] - 0.85, y["clk"] + H + 1.3)
ax.axis("off")
fig.tight_layout()
fig.savefig(OUT, format="svg", facecolor="white", metadata={"Date": None})
print(OUT)
