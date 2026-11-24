# Scripts

Utilities for DD105-A — Testbenches with UVM under the UofT ASIC org (`uoftasic`).

## Entry points

| Script | Purpose |
|--------|---------|
| `check_site.py` | Check that every local link and `#anchor` in the rendered site resolves, and that every page has the navbar's link to https://edu.uoftasic.com/; `.github/workflows/site.yml` runs it on `docs/_site` |
| `init-template.py` | The template's bootstrap script, which filled in `dd105-a`, the title and the description; see `TEMPLATE.md` |
| `ci/check-labs.sh` | The reference-solution checks that `.github/workflows/labs.yml` runs: the starter's `make check` must fail and the solution's pass, `labs/ref` must catch all 15 bugs, and `labs/common/selftest` must pass |
| `ci/in-image.sh` | Runs a command in the course image with the course's limits (2 CPUs, 3 GB): `IMAGE=<image@digest> scripts/ci/in-image.sh <command>` |
| `figures/` | The scripts that draw the diagrams in `docs/assets/img/` with schemdraw and matplotlib. `python3 scripts/figures/<name>.py` rewrites that figure's SVG; [`figures/README.md`](figures/README.md) says which matplotlib reproduces each one |
| `screenshots/shoot.sh` | Render a PNG of Surfer or GTKWave showing a waveform, headless in the screenshot rig image; see [`screenshots/README.md`](screenshots/README.md) |

## Usage

```bash
# From the top of the clone, with Docker and the course image
export IMAGE=hpretl/iic-osic-tools@sha256:3c371645b19c6f6564dc8c7b21e39ad1c1833d274fe5b85639afe1ba9d7987e7
scripts/ci/in-image.sh scripts/ci/check-labs.sh lab lab-02-a-class-testbench-without-uvm
scripts/ci/in-image.sh python3 scripts/figures/router_block.py

# After rendering the site
python3 scripts/check_site.py docs/_site
```

## Conventions

- Write scripts in Python where you can. HDL tooling belongs in `labs/` or the shared workbench.
- Keep secrets out of the repo. If a script needs configuration, add a `.env.example`.
- When you add a script, add it to the table above.
