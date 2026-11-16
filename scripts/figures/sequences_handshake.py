"""Sequences, sequencers and drivers: the handshake for the first two items.

The times are from a run of guide-examples/sequences-sequencers-and-drivers:

    make run UVM_TESTNAME=sq_timeline_test

The clock's rising edges are at 5, 15, 25 and 35 ns. Item 1: start_item and
get_next_item returned at 0 ns, item_done and finish_item at 15 ns. Item 2:
start_item and get_next_item returned at 15 ns, item_done and finish_item at
35 ns. The clocking block drives 1 ns after an edge, so valid is high from 6
to 16 ns and from 26 to 36 ns.

    python3 scripts/figures/sequences_handshake.py
"""
from uvm_figure_style import BLUE, GRID, INK, INK_2, MONO, canvas, save

fig, ax = canvas(8.8, 3.3, xlim=(-17, 42), ylim=(-0.7, 4.15))

ROWS = {"sequence": 3.45, "driver": 2.05, "valid": 0.95}
for name, y in ROWS.items():
    ax.text(-1.5, y, name, ha="right", va="center", family=MONO, size=9, color=INK)

# clock edges and the time axis
for t in (5, 15, 25, 35):
    ax.plot([t, t], [0.55, 3.9], color=GRID, lw=0.9, zorder=0)
ax.plot([0, 40], [0.3, 0.3], color=INK, lw=0.9)
for t in range(0, 41, 5):
    ax.plot([t, t], [0.3, 0.22], color=INK, lw=0.9)
    ax.text(t, 0.1, f"{t}", ha="center", va="top", size=8.5, color=INK)
ax.text(41, 0.1, "ns", ha="left", va="top", size=8.5, color=INK)
ax.text(20, -0.45, "grey lines: rising clock edges", ha="center", va="center", size=8.5,
        color=INK_2)

H = 0.36


def bar(y, t0, t1, label, solid):
    if solid:
        ax.barh(y, t1 - t0, left=t0, height=H, color=BLUE, edgecolor="none")
        ax.text((t0 + t1) / 2, y, label, ha="center", va="center", size=8, color="white")
    else:
        ax.barh(y, t1 - t0, left=t0, height=H, color="white", edgecolor=BLUE, hatch="////",
                linewidth=1.0)
        ax.text((t0 + t1) / 2, y + 0.3, label, ha="center", va="bottom", size=8, color=INK_2)


# the sequence: blocked in finish_item() until item_done()
bar(ROWS["sequence"], 0, 15, "finish_item() waits", False)
bar(ROWS["sequence"], 15, 35, "finish_item() waits", False)
# the driver: waits for an edge, then holds the vector for a cycle
bar(ROWS["driver"], 0, 5, "", False)
bar(ROWS["driver"], 5, 15, "item 1", True)
bar(ROWS["driver"], 15, 25, "", False)
bar(ROWS["driver"], 25, 35, "item 2", True)
ax.text(2.5, ROWS["driver"] + 0.3, "@(cb)", ha="center", va="bottom", size=8, color=INK_2)
ax.text(20, ROWS["driver"] + 0.3, "@(cb)", ha="center", va="bottom", size=8, color=INK_2)

# valid on the pins
vy = ROWS["valid"]
xs = [0, 6, 6, 16, 16, 26, 26, 36, 36, 40]
ys = [0, 0, 1, 1, 0, 0, 1, 1, 0, 0]
ax.plot(xs, [vy - 0.18 + 0.36 * v for v in ys], color=INK, lw=1.3)

# the calls
for t, row, text in ((0, "sequence", "start_item, randomize"),
                     (15, "sequence", "start_item, randomize"),
                     (0, "driver", "get_next_item"),
                     (15, "driver", "item_done, get_next_item"),
                     (35, "driver", "item_done")):
    y = ROWS[row] - 0.3
    ax.plot([t], [ROWS[row]], marker="o", ms=4.5, color=INK, zorder=4)
    ax.text(t + 0.4, y, text, ha="left", va="top", size=7.5, color=INK)

save(fig, "sequences-handshake")
