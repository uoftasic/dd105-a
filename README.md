# DD105-A — Testbenches with UVM

Build a UVM testbench in SystemVerilog on Verilator, and find out what the framework costs and buys.

Part of the UofT ASIC Team education materials (`uoftasic`).
Course site: <https://uoftasic.com/dd105-a/> · Education hub: <https://edu.uoftasic.com/>

DD105-A comes after [DD104](https://uoftasic.com/dd104/). Students verify a small packet router
written for the course, with fifteen planted bugs behind a run-time switch: first with a class
testbench and no UVM, and finally with a full UVM environment, a verification plan and a
verification report. Lab 01 compares DD104's cocotb test with a UVM testbench on SimProc's ALU.

## Quick start

Everything runs in the team workbench image `hpretl/iic-osic-tools:2026.08` (Verilator 5.050,
Yices 2.7.0, cocotb 2.0.1, Icarus Verilog 14.0). The UVM library is in this repository, in
`third_party/uvm`, so a clone needs nothing else. Every lab runs with `make`, and prints a verdict.

Students set up through the shared `workspace` and the desktop from
[IC101](https://uoftasic.com/ic101/); [Lab 01, Part 1](https://uoftasic.com/dd105-a/labs/lab-01-one-alu-two-testbenches-overview.html)
has the steps. In a terminal on that desktop:

```bash
. /foss/designs/common/.designinit
mod add dd105-a                                       # first time only
mod dd105-a
cd labs/lab-01-one-alu-two-testbenches && make build  # about 100 s the first time
```

Without the desktop, from a clone of this repo, with Docker and the image:

```bash
git clone https://github.com/uoftasic/dd105-a.git
cd dd105-a
export IMAGE=hpretl/iic-osic-tools@sha256:3c371645b19c6f6564dc8c7b21e39ad1c1833d274fe5b85639afe1ba9d7987e7
scripts/ci/in-image.sh make -C labs/lab-01-one-alu-two-testbenches
```

[Getting the tools outside the course image](https://uoftasic.com/dd105-a/reference/getting-the-tools-outside-the-course-image.html)
says what the labs need on any other machine.

## Lab packages

| Path | What it is | Writeup |
|---|---|---|
| `labs/lab-01-one-alu-two-testbenches/` | SimProc's ALU with DD104's three bugs, DD104's cocotb test and a UVM testbench | Lab 01 |
| `labs/lab-02-a-class-testbench-without-uvm/` | a class testbench for the router, without UVM | Lab 02 |
| `labs/lab-03-constraints-and-coverage/` | Lab 02's testbench with constrained-random packets and a covergroup | Lab 03 |
| `labs/lab-04-the-same-testbench-in-uvm/` | Lab 03's testbench ported to UVM | Lab 04 |
| `labs/lab-05-protocol-rules-and-backpressure/` | assertions bound into the router, a reactive sink and virtual sequences | Lab 05 |
| `labs/lab-06-the-register-block/` | a register model, its adapter and predictor, and checks on the registers and `irq` | Lab 06 |
| `labs/lab-07-capstone/` | resets with traffic in flight, a plan, a regression, mystery builds and a report | Lab 07 |
| `labs/common/` | the router's RTL and bug catalogue, the shared build (`uvm.mk`) and the graders | all labs |
| `labs/ref/` | the router's reference UVM environment, written from the specification alone | instructor side |
| `third_party/uvm/` | the UVM 2020-3.2 library, copied unchanged from `chipsalliance/uvm-verilator` | all labs |

From Lab 03 on, each lab's starter is the previous lab's solution. Reference solutions live in each package's
`solutions/`, and `labs/common/bugs.py` is the answer key to the planted bugs, so a student should
open neither until the lab is done.

`.github/workflows/labs.yml` checks the reference solutions in the course image: for every lab, the
starter's `make check` must fail and the solution's must pass, `labs/ref` must catch all fifteen
bugs, and `labs/common/selftest` must pass. It runs on changes to `labs/`, `third_party/`, its
scripts in `scripts/ci/` and itself, every Monday, and by hand. Each step is one command you can run
locally, for example `scripts/ci/in-image.sh scripts/ci/check-labs.sh lab lab-02-a-class-testbench-without-uvm`.

## Docs

The course site is built with Quarto from `./docs`. `docs/_quarto.yml` holds the site, sidebar
and navbar, and `docs/_quarto-pdf.yml` builds the whole course as one PDF. To preview it you need
[Quarto](https://quarto.org/docs/get-started/) 1.11:

```bash
quarto preview docs                            # -> http://localhost:4200
quarto render docs --profile pdf --to typst    # whole course as one PDF in docs/_book/
```

| Path | On Pages? | Purpose |
|------|-----------|---------|
| `docs/` | Yes | The course site; `docs/index.md` is the home page and has the Course path |
| `docs/guide/` | Yes | Guide pages: reading only, no commands |
| `docs/labs/` | Yes | Lab writeups: every command a student runs, in numbered parts and steps |
| `docs/reference/` | Yes | Lookup pages: the router's specification and a one-page summary, the UVM register layer, and the tools outside the course image |
| `labs/` | No | Runnable packages |
| `guide-examples/` | No | The SystemVerilog examples on the guide pages, each with a Makefile; `guide-examples/README.md` says how to run them |
| `third_party/` | No | The UVM library |
| `scripts/` | No | `check_site.py`, the link check for the rendered site; `ci/`, the reference-solution checks; `figures/`, the scripts that draw the diagrams in `docs/assets/img/`; `screenshots/`, the waveform screenshots |
| `notebooks/`, `data/`, `figures/` | No | Repo scaffolding, unused by DD105-A |

GitHub Pages is set to Source: GitHub Actions. On every push to `main` that touches `docs/`,
`scripts/check_site.py` or the workflow itself, `.github/workflows/site.yml` renders the site (with
a PDF of every page) and the course PDF, checks the rendered site's local links and anchors with
`scripts/check_site.py`, and deploys `docs/_site`.

This repo was created from [uoftasic/course-template](https://github.com/uoftasic/course-template).
`TEMPLATE.md` and `scripts/init-template.py` are that template's bootstrap files and are not part
of the course.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) — Copyright UofT ASIC Team / `uoftasic`.
`third_party/uvm` is the UVM library under the Apache License 2.0; see
`third_party/uvm/LICENSE.txt`, `third_party/uvm/NOTICE.txt` and `third_party/uvm/VENDORED.md`.
