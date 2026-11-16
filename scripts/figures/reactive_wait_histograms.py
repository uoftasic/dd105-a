"""Reactive agents and backpressure: how long each of 2,000 beats waited, for four sinks.

    python3 scripts/figures/reactive_wait_histograms.py

writes docs/assets/img/reactive-wait-histograms.svg. The counts are the [HIST] lines of four
runs of guide-examples/reactive-agents-and-backpressure (seed 1), copied here as printed:

    make run PLUSARGS="+MODE=coin +READY_PCT=5"
    make run PLUSARGS="+MODE=coin +READY_PCT=50"
    make run PLUSARGS="+MODE=beat +MAX_DELAY=12"
    make run PLUSARGS="+MODE=beat +MAX_DELAY=12 +URANDOM"

Each list is hist[0] .. hist[40]: the beats that waited 0, 1, ..., 39 cycles, then 40 or more.
"""
import os

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "uoftasic-figures"
matplotlib.rcParams["font.family"] = "serif"
import matplotlib.pyplot as plt  # noqa: E402

RUNS = [
    ("coin flip, ready in 5% of cycles",
     "99 72 74 91 82 89 80 70 80 67 68 58 55 65 64 37 45 44 41 36 33 44 36 24 33 19 27 22 17 "
     "24 24 29 22 11 24 13 20 11 14 16 220"),
    ("coin flip, ready in 50% of cycles",
     "1017 495 246 113 68 33 15 7 4 1 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 "
     "0 0"),
    ("per beat, delay 0 to 12 from randomize()",
     "116 131 129 130 113 120 108 131 131 245 251 281 114 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 "
     "0 0 0 0 0 0 0 0 0"),
    ("per beat, delay 0 to 12 from $urandom_range",
     "169 151 162 153 139 161 138 138 150 160 162 137 180 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 "
     "0 0 0 0 0 0 0 0 0"),
]

BAR = "#2a78d6"      # one series per panel, so one hue
INK = "#0b0b0b"
MUTED = "#52514e"
GRID = "#d8d7d2"

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                                    "docs", "assets", "img", "reactive-wait-histograms.svg"))

fig, axes = plt.subplots(len(RUNS), 1, figsize=(7.6, 7.2), sharex=True)
x = list(range(41))
for ax, (title, counts) in zip(axes, RUNS):
    h = [int(c) for c in counts.split()]
    assert len(h) == 41 and sum(h) == 2000, title
    ax.bar(x, h, width=0.78, color=BAR, linewidth=0)
    ax.set_title(title, loc="left", fontsize=11, color=INK, pad=4)
    # The two per-beat panels share a scale, so their bars can be compared.
    ax.set_ylim(0, 320 if title.startswith("per beat") else max(h) * 1.15)
    ax.yaxis.grid(True, color=GRID, linewidth=0.6)
    ax.set_axisbelow(True)
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(MUTED)
    ax.tick_params(colors=MUTED, labelsize=9, length=0)
    ax.set_ylabel("beats", fontsize=9, color=MUTED)

axes[-1].set_xticks([0, 5, 10, 15, 20, 25, 30, 35, 40])
axes[-1].set_xticklabels(["0", "5", "10", "15", "20", "25", "30", "35", "40+"])
axes[-1].set_xlabel("cycles the beat waited before it was taken", fontsize=10, color=INK)
fig.tight_layout(h_pad=1.2)
fig.savefig(OUT, format="svg", facecolor="white", metadata={"Date": None})
print(OUT)
