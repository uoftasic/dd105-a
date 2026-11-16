# Shared data

DD105-A — Testbenches with UVM keeps no shared data here; the folder is left from the course
template. Everything a lab reads is in its own package or in `labs/common/`: the router's RTL in
`labs/common/rtl/`, its bug catalogue in `labs/common/bugs.py`, and the graders' recorded logs in
`labs/common/selftest/logs/`. A lab's runs, waves and coverage go to its `build/` folder, which git
ignores.
