# Figure scripts

Each script draws one diagram for the site and writes it as an SVG into `docs/assets/img/`. They
use schemdraw, with the look in `circuit_style.py` (copied from DD104, so the courses' diagrams
match).

```bash
pip install -r scripts/figures/requirements.txt
cd scripts/figures && python3 <script>.py
```

With the versions in `requirements.txt`, rerunning a script reproduces its SVG byte for byte.
`FIG_PREVIEW=<folder>` also writes a PNG of each figure there, to look at while you work.

| Script | Writes | Used on |
|---|---|---|
| `lab01_uvm_structure.py` | `dd105-lab01-two-testbenches.svg` | What a framework buys you |
| `handles.py` | `dd105-handles.svg` | Classes for testbenches |
| `lab02_threads.py` | `dd105-lab02-threads.svg` | Threads, mailboxes and events |

Waveform screenshots are made with `scripts/screenshots/` instead.
