"""Threads, mailboxes and events: Lab 02's environment as threads and mailboxes.

From labs/lab-02-a-class-testbench-without-uvm/tb/env.svh. Each box is an
object whose run() is one thread; the generator and the driver are started
with fork...join, everything else with fork...join_none. The labels on the
arrows between classes are the mailboxes.
"""
import schemdraw.elements as elm
import schemdraw.flow as flow

from circuit_style import drawing, save

TEXT_DROP = 0.11    # schemdraw puts the baseline on y; this centres the letters on it instead
NOTE = 11


def text(d, xy, s, halign="center", size=None):
    """Text at xy. right() stops it inheriting the last element's direction."""
    d.add(elm.Label().right().at((xy[0], xy[1] - TEXT_DROP)).label(s, halign=halign, fontsize=size))


def box(d, x, y, w, h, label, lw=1.3):
    """A box centred on (x, y)."""
    return d.add(flow.Box(w=w, h=h).anchor("center").at((x, y)).label(label).linewidth(lw))


d = drawing()
d.config(margin=0.3)

Y = 6.0          # the row the stimulus and the router sit on
JOIN = 2.6       # line width for the two threads env.run() waits for

gen = box(d, 1.4, Y, 2.4, 0.9, "generator", lw=JOIN)
drv = box(d, 5.9, Y, 2.0, 0.9, "driver", lw=JOIN)
rtr = d.add(flow.Box(w=2.4, h=1.8).anchor("center").at((11.0, Y)).label("router\n(the design)", fontsize=NOTE).linestyle("--"))
snk1 = box(d, 16.0, Y + 0.45, 1.6, 0.7, "snk1")
snk0 = box(d, 16.0, Y - 0.45, 1.6, 0.7, "snk0")

d.add(elm.Arrow().at(gen.E).to(drv.W).label("gen2drv", loc="top", fontsize=NOTE))
d.add(elm.Arrow().at(drv.E).to((rtr.W[0], Y)).label("in", loc="top", fontsize=NOTE))
d.add(elm.Line().at((rtr.E[0], Y + 0.45)).to(snk1.W).label("out1", loc="top", fontsize=NOTE))
d.add(elm.Line().at((rtr.E[0], Y - 0.45)).to(snk0.W).label("out0", loc="top", fontsize=NOTE))

# The monitors watch the input and output 0 without driving them.
in_mon = box(d, 8.5, 3.4, 2.0, 0.9, "in_mon")
out_mon = box(d, 13.6, 3.4, 2.2, 0.9, "out0_mon")
d.add(elm.Dot().at((8.5, Y)))
d.add(elm.Arrow().at((8.5, Y)).to(in_mon.N))
d.add(elm.Dot().at((13.6, Y - 0.45)))
d.add(elm.Arrow().at((13.6, Y - 0.45)).to(out_mon.N))

sb = box(d, 11.05, 0.8, 6.0, 0.9, "scoreboard")
d.add(elm.Arrow().at(in_mon.S).to((8.5, sb.N[1])).label("in2sb", loc="bottom", fontsize=NOTE))
d.add(elm.Arrow().at(out_mon.S).to((13.6, sb.N[1])).label("out02sb", loc="top", fontsize=NOTE))

text(d, (0.2, 3.2), "thick: fork...join,", halign="left", size=NOTE)
text(d, (0.2, 2.65), "env.run() waits for both", halign="left", size=NOTE)
text(d, (0.2, 1.75), "thin: fork...join_none,", halign="left", size=NOTE)
text(d, (0.2, 1.2), "running until the test ends", halign="left", size=NOTE)

print(save(d, "dd105-lab02-threads"))
