"""Monitors, analysis ports and scoreboards: where Lab 04's transactions go.

The connections are the ones router_env::connect_phase makes in
labs/lab-04-the-same-testbench-in-uvm/solutions/router_env_pkg.sv:

    src.mon.ap.connect(sb.in_export);
    apb.mon.ap.connect(sb.apb_export);
    out[0].mon.ap.connect(sb.out_export);
    out[1].mon.ap.connect(sb.out_export);
    sb.fate_ap.connect(cov.analysis_export);

and the write functions are the ones the scoreboard's three imps call.

    python3 scripts/figures/monitors_lab04_connections.py
"""
from matplotlib.patches import Circle, Rectangle

from uvm_figure_style import BLUE, INK, INK_2, MONO, arrow, box, canvas, save

fig, ax = canvas(9.2, 4.0, xlim=(0, 10.4), ylim=(0.1, 4.6))

# the monitors, on the left, each in its agent
mons = [("src.mon", "src_monitor", "stream_beat", 3.75),
        ("apb.mon", "apb_monitor", "apb_item", 2.75),
        ("out0.mon", "out_monitor", "stream_beat", 1.75),
        ("out1.mon", "out_monitor", "stream_beat", 0.75)]
MW, MH = 1.75, 0.62
for name, cls, _, y in mons:
    box(ax, 0.2, y - MH / 2, MW, MH, name, cls, size=9)

# the scoreboard, with its three exports and the write function each calls
SBX, SBW = 5.0, 2.3
box(ax, SBX, 0.35, SBW, 3.85, "", None)
ax.text(SBX + SBW / 2, 3.95, "sb", ha="center", va="center", family=MONO, size=10, color=INK)
ax.text(SBX + SBW / 2, 3.68, "router_scoreboard", ha="center", va="center", family=MONO,
        size=8, color=INK_2)
exports = [("in_export", "write_in()", 3.05), ("apb_export", "write_apb()", 2.2),
           ("out_export", "write_out()", 1.25)]
for name, fn, y in exports:
    ax.add_patch(Circle((SBX, y), 0.07, facecolor="white",
                                                         edgecolor=INK, lw=1.1, zorder=3))
    ax.text(SBX + 0.15, y + 0.12, name, ha="left", va="center", family=MONO, size=8.5, color=INK)
    ax.text(SBX + 0.15, y - 0.16, fn, ha="left", va="center", family=MONO, size=8.5, color=BLUE)

# the analysis ports on the monitors, and the connections
targets = {"src.mon": 3.05, "apb.mon": 2.2, "out0.mon": 1.25, "out1.mon": 1.25}
for name, _, item, y in mons:
    x0 = 0.2 + MW
    ax.add_patch(Rectangle((x0 - 0.06, y - 0.06), 0.12, 0.12,
                                                            facecolor=INK, edgecolor=INK, zorder=3))
    ty = targets[name]
    arrow(ax, (x0 + 0.06, y), (SBX - 0.08, ty), lw=1.1)
ax.text(2.1, 4.35, "ap.write(t): one call per beat or transfer", ha="left", va="center",
        size=8.5, color=INK_2)

# the coverage subscriber, fed by the scoreboard's own analysis port
ax.add_patch(Rectangle((SBX + SBW - 0.06, 2.2 - 0.06), 0.12, 0.12,
                                                        facecolor=INK, edgecolor=INK, zorder=3))
ax.text(SBX + SBW - 0.15, 1.95, "fate_ap", ha="right", va="center", family=MONO, size=8.5, color=INK)
box(ax, 8.3, 1.89, 1.85, 0.62, "cov", "router_coverage", size=9)
arrow(ax, (SBX + SBW + 0.06, 2.2), (8.3 - 0.02, 2.2), lw=1.1)
ax.text(8.3 + 0.92, 1.62, "write(): cg_pkt.sample()", ha="center", va="center", family=MONO,
        size=8, color=BLUE)

save(fig, "monitors-lab04-connections")
