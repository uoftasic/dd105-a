# Vendored UVM library

This folder is a copy of the UVM library that every DD105-A lab builds against, so the labs work
without fetching anything.

- Source: <https://github.com/chipsalliance/uvm-verilator>, branch `master`
- Commit: `5d72b6618acfddece7f09382a032ccbc05862fdc` (2026-08-14)
- Version: UVM 2020-3.2 (IEEE 1800.2), with `src/dpi/uvm_hdl_verilator.c`, the VPI back end that
  lets `uvm_hdl_*` work on Verilator
- Licence: Apache-2.0 (`LICENSE.txt`, `NOTICE.txt`), unchanged

Only `src/` and the licence and readme files were copied. Nothing in them has been edited. To check,
compare this folder with a clone of that repository at that commit.
