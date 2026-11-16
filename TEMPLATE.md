# Template bootstrap (UofT ASIC)

DD105-A was created from [uoftasic/course-template](https://github.com/uoftasic/course-template).
This is the template's bootstrap checklist, filled in for DD105-A: what was done when the course
was made from the template, and what's still to do before it goes live.

## Fixed and fillable values

| Item | Value |
|------|--------|
| GitHub org | `uoftasic` (hardcoded, don't change it) |
| Team | UofT ASIC Team |

| Token | Meaning | Value in DD105-A |
|-------|---------|------------------|
| `{{COURSE_ID}}` | Repo slug and course id | `dd105-a` |
| `{{COURSE_TITLE}}` | Display name | `DD105-A — Testbenches with UVM` |
| `{{DESCRIPTION}}` | One-line blurb | `Build a UVM testbench in SystemVerilog on Verilator, and find out what the framework costs and buys.` |

## Init script

The template's `scripts/init-template.py` filled those in:

```bash
python3 scripts/init-template.py \
  --id dd105-a \
  --title "DD105-A — Testbenches with UVM" \
  --description "Build a UVM testbench in SystemVerilog on Verilator, and find out what the framework costs and buys."
```

Add `--dry-run` to see what it would change without writing anything.

## After-clone checklist

- [x] `scripts/init-template.py` run with the three values above
- [x] The template's sample lab removed (`docs/labs/lab-01-overview.md`, `labs/lab-01/`, `scripts/hello.py`)
- [x] Home page filled in: who the course is for, the prerequisites, the total time, and the 14 course path rows
- [x] The Read rows' times and the total time on the home page (marked `READTIME` in `docs/index.md`), so the rows add up to the total
- [x] Sidebar in `docs/_quarto.yml` and chapters in `docs/_quarto-pdf.yml` in course path order: Home, then seven sections, each a Read row's guide pages and its lab (Getting started to Lab 07: Capstone), then the reference pages
- [x] Math and figures render: the formulas and the block diagram on The router in one page, and the waveforms on the lab pages
- [ ] Repo created under `uoftasic`, named `dd105-a`, and pushed to `main`
- [ ] Pages: **Settings → Pages → Source: GitHub Actions** (`.github/workflows/site.yml` builds `docs/` with Quarto)
- [ ] Live at `https://uoftasic.com/dd105-a/` (org Pages; the hub is https://edu.uoftasic.com/)
- [ ] The first run of `.github/workflows/labs.yml` on GitHub passes, which shows its free-disk step leaves room for the course image

The pages follow the course structure in [AGENTS.md](AGENTS.md). The home page has the course path,
guide pages are for reading only, and lab writeups are the one place where students run things. The
seven labs are the worked examples of a lab writeup.

## Naming

Use a course id the team already follows (`ic###`, `ad###`, `dd###`) or a clear kebab-case lab name. Keep the GitHub repo name equal to `dd105-a` so the Pages and clone URLs are predictable.

## Related

Each course made from the template is published at `https://uoftasic.com/<course-id>/`, with its Quarto site under `docs/` and its runnable code in `labs/` and `scripts/`. The education hub is https://edu.uoftasic.com/.
