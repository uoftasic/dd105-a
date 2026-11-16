"""The UVM skeleton: the component tree of Lab 04's testbench.

The names and classes are those that router_base_test and router_env build in
labs/lab-04-the-same-testbench-in-uvm/solutions/ (router_tests_pkg.sv and
router_env_pkg.sv) and that the agents build in tb/router_agents_pkg.sv. Each
box is one component: its instance name, which is the last part of its full
name, and under it its class.

    python3 scripts/figures/the_uvm_skeleton_tree.py
"""
from uvm_figure_style import INK, box, canvas, save

W, H = 1.62, 0.62          # a box
CW, CH = 1.42, 0.5         # a child box
COL = 2.08                 # distance between columns

fig, ax = canvas(12.4, 5.0, xlim=(-0.2, 12.25), ylim=(-0.25, 4.85))


def tree_line(x0, y0, xs, y1):
    """From the bottom centre of a parent at (x0, y0) down to the tops of
    children whose centres are xs, all with their tops at y1."""
    ym = (y0 + y1) / 2
    ax.plot([x0, x0], [y0, ym], color=INK, lw=1.0)
    ax.plot([min(xs + [x0]), max(xs + [x0])], [ym, ym], color=INK, lw=1.0)
    for x in xs:
        ax.plot([x, x], [ym, y1], color=INK, lw=1.0)


# the test and the environment
cx = 0.8 + COL * 2.5
box(ax, cx - W / 2 - 0.25, 4.15, W + 0.5, H, "uvm_test_top", "router_inject_test")
box(ax, cx - W / 2, 3.15, W, H, "env", "router_env")
tree_line(cx, 4.15, [cx], 3.15 + H)

# the environment's children
kids = [("src", "src_agent"), ("apb", "apb_agent"), ("out0", "out_agent"),
        ("out1", "out_agent"), ("sb", "router_scoreboard"), ("cov", "router_coverage")]
xs = [0.8 + COL * i for i in range(len(kids))]
for (name, cls), x in zip(kids, xs):
    w = W + (0.22 if cls.startswith("router_") else 0)
    box(ax, x - w / 2, 1.95, w, H, name, cls)
tree_line(cx, 3.15, xs, 1.95 + H)

# the agents' children, stacked under each agent
agent_kids = {
    0: [("sqr", "uvm_sequencer"), ("drv", "src_driver"), ("mon", "src_monitor")],
    1: [("sqr", "uvm_sequencer"), ("drv", "apb_driver"), ("mon", "apb_monitor")],
    2: [("drv", "out_ready_driver"), ("mon", "out_monitor")],
    3: [("drv", "out_ready_driver"), ("mon", "out_monitor")],
}
for i, children in agent_kids.items():
    x = xs[i]
    top = 1.95
    last = 1.13 - 0.62 * (len(children) - 1) + CH / 2
    ax.plot([x - CW / 2 - 0.08, x - CW / 2 - 0.08], [top, last], color=INK, lw=1.0)
    for k, (name, cls) in enumerate(children):
        y = 1.13 - 0.62 * k
        ax.plot([x - CW / 2 - 0.08, x - CW / 2 + 0.06], [y + CH / 2, y + CH / 2], color=INK, lw=1.0)
        box(ax, x - CW / 2 + 0.06, y, CW, CH, name, cls, size=8.5)

save(fig, "the-uvm-skeleton-lab04-tree")
