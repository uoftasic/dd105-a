# Figure scripts

Each script draws one diagram for the site and writes it as an SVG into `docs/assets/img/`. Two
files set the look. `circuit_style.py` is the schemdraw style, copied from DD104 so that the
courses' diagrams match, and `uvm_figure_style.py` does the same for the plain matplotlib figures
on the UVM pages. Run a script from the top of the clone:

```bash
pip install -r scripts/figures/requirements.txt
python3 scripts/figures/<script>.py
```

With the versions in `requirements.txt` (schemdraw 0.23 and matplotlib 3.10.9, DD104's pins),
rerunning a script reproduces its SVG byte for byte. All the scripts but one were checked that way
on Nov 16, 2026. The exception is `router_block.py`: its SVG was drawn in the course image, which
has matplotlib 3.11.1, and it reproduces there, so rerun it in the image rather than with the pins
here. To look at a figure while you work on it, set `FIG_PREVIEW=<folder>` for a schemdraw script or
`FIG_PREVIEW_DIR=<folder>` for one that uses `uvm_figure_style.py`, and the script also writes a PNG
there; the site doesn't use the PNGs.

A script whose figure plots numbers from a run says in its docstring which run of which guide
example they came from.

| Script | Style | Writes | Used on |
|---|---|---|---|
| `lab01_uvm_structure.py` | schemdraw | `dd105-lab01-two-testbenches.svg` | What a framework buys you |
| `handles.py` | schemdraw | `dd105-handles.svg` | Classes for testbenches |
| `lab02_threads.py` | schemdraw | `dd105-lab02-threads.svg` | Threads, mailboxes and events |
| `functional_coverage_cross.py` | `uvm_figure_style` | `functional-coverage-cross.svg` | Functional coverage you can read |
| `the_uvm_skeleton_tree.py` | `uvm_figure_style` | `the-uvm-skeleton-lab04-tree.svg` | The UVM skeleton |
| `the_uvm_skeleton_objections.py` | `uvm_figure_style` | `the-uvm-skeleton-objections.svg` | The UVM skeleton |
| `sequences_handshake.py` | `uvm_figure_style` | `sequences-handshake.svg` | Sequences, sequencers and drivers |
| `monitors_lab04_connections.py` | `uvm_figure_style` | `monitors-lab04-connections.svg` | Monitors, analysis ports and scoreboards |
| `assertion_drop_timing.py` | matplotlib | `assertion-drop-timing.svg` | Assertions for interface rules |
| `reactive_wait_histograms.py` | matplotlib | `reactive-wait-histograms.svg` | Reactive agents and backpressure |
| `virtual_sequence_handles.py` | schemdraw | `virtual-sequence-handles.svg` | Virtual sequences |
| `register_model_paths.py` | schemdraw | `register-model-paths.svg` | Register models |
| `router_block.py` | schemdraw | `router-block.svg` | The router in one page |

Waveform screenshots are made with `scripts/screenshots/` instead.
