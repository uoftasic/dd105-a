"""Classes for testbenches: handles and objects.

Left, guide-examples/classes-for-testbenches handles_test: a and b are two
handles to one pkt object, and c is a handle to a copy made with `new a`.
Right, reuse_test: a queue of three handles to one reused pkt, and a queue of
three handles to three pkts. The values are the ones the example printed.
"""
import schemdraw.elements as elm
import schemdraw.flow as flow

from circuit_style import drawing, save

TEXT_DROP = 0.11    # schemdraw puts the baseline on y; this centres the letters on it instead
NOTE = 11


def text(d, xy, s, halign="center", size=None):
    """Text at xy. right() stops it inheriting the last element's direction."""
    d.add(elm.Label().right().at((xy[0], xy[1] - TEXT_DROP)).label(s, halign=halign, fontsize=size))


def handle(d, x, y, name):
    """A small square for a handle, its name to the left. Returns the square."""
    text(d, (x - 0.45, y), name, halign="right")
    return d.add(flow.Box(w=0.6, h=0.6).anchor("center").at((x, y)))


def obj(d, x, y, label, w=3.6):
    """An object: a box with its contents, centred on (x, y)."""
    return d.add(flow.Box(w=w, h=0.8).anchor("center").at((x, y)).label(label, fontsize=NOTE))


def points(d, h, o):
    """An arrow from the middle of handle h to the left side of object o."""
    d.add(elm.Arrow().at(h.center).to(o.W))


d = drawing()
d.config(margin=0.3)

# ── handles_test ─────────────────────────────────────────────────────────────
text(d, (2.8, 6.2), "handles_test", size=NOTE)
ha = handle(d, 0.9, 4.8, "a")
hb = handle(d, 0.9, 3.6, "b")
hc = handle(d, 0.9, 1.6, "c")
o1 = obj(d, 4.6, 4.2, "pkt 0: 80 11 22")
o2 = obj(d, 4.6, 1.6, "pkt 0: 80 11 22 33")
points(d, ha, o1)
points(d, hb, o1)
points(d, hc, o2)

# ── reuse_test ───────────────────────────────────────────────────────────────
X0 = 8.6
text(d, (X0 + 1.2, 6.2), "kept_once", size=NOTE)
text(d, (X0 + 7.0, 6.2), "kept_new", size=NOTE)
once = [handle(d, X0 + 1.2, 5.0 - 1.4 * k, "[%d]" % k) for k in range(3)]
o3 = obj(d, X0 + 3.9, 3.6, "pkt 0: 02 a2", w=2.6)
for h in once:
    points(d, h, o3)
new = [handle(d, X0 + 7.0, 5.0 - 1.4 * k, "[%d]" % k) for k in range(3)]
for k, h in enumerate(new):
    o = obj(d, X0 + 9.7, 5.0 - 1.4 * k, "pkt %d: %02x a%d" % (k + 1, k, k), w=2.6)
    d.add(elm.Arrow().at(h.center).to(o.W))

print(save(d, "dd105-handles"))
