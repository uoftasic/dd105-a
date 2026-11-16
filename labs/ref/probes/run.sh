#!/bin/bash
# Build and run each probe in the course image, from labs/ref/probes:
#   bash run.sh
# The output is what labs/ref/README.md quotes.
set -u
export VERILATOR_SOLVER="yices-smt2 --incremental"
for p in vif_typedef late_drive cross_bins dist_weights; do
  echo "== $p"
  rm -rf obj_$p
  if ! verilator --binary --timing --timescale 1ns/1ps --coverage-user -Wno-fatal \
         --Mdir obj_$p -o sim $p.sv --top-module top > obj_$p.log 2>&1; then
    echo "build failed: obj_$p.log"; continue
  fi
  (cd obj_$p && ./sim +verilator+coverage+file+coverage.dat | grep -v '^- ')
  if [ $p = cross_bins ]; then
    tr '\001\002' '|=' < obj_$p/coverage.dat | grep -ao "h=[^']*' [0-9]*" | sed "s/^h=//; s/'//"
  fi
  rm -rf obj_$p obj_$p.log
done
