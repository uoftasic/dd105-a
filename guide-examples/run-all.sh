#!/usr/bin/env bash
# Rebuild every guide example from a clean build folder and run every command whose output a guide
# page quotes, in the order guide-examples/README.md lists them. Run it from guide-examples/, in
# the course image:
#
#     ./run-all.sh
#
# It took 1 min 49 s on 2 CPUs with a warm ccache; with an empty one, add about 100 s for each
# of the five builds. Each `make run` prints its usual one-line verdict; the lines around it are
# the ones the pages quote.
set -u
cd "$(dirname "$0")"
quoted='\[STAGE\]|\[SVA\]|%Error|Aborting|TEST PASSED|ok:|FAIL:|caught:|MISSED:|BROKEN|\[WAIT\]|\[HIST\]|\[VSEQ\]|\[MON\]|\[RAL\]|RegModel|uvm_reg_hw_reset_seq\] Verifying|uvm_reg_bit_bash_seq\]|GET_MIRRORED_VAL|\[RANDOM\]|\[COUNT\]|ok  \(|covergroup :'

say() { printf '\n=== %s\n' "$*"; }
run() { say "$*"; "$@" 2>&1 | grep -E "$quoted"; }

for d in assertions-for-interface-rules reactive-agents-and-backpressure virtual-sequences \
         register-models regressions-and-seeds; do
  make -C "$d" clean > /dev/null
  say "make -C $d build"
  make -C "$d" build 2>&1 | grep -E "built |Error"
done

cd assertions-for-interface-rules
run make run
run make run BUG=drop PLUSARGS=
echo "exit_status: $(cat build/runs/stage_test-s1-drop/exit_status)"
run make run BUG=drop
run make run BUG=drop PLUSARGS="+verilator+error+limit+1000 +IGNORE_SVA"
echo "exit_status: $(cat build/runs/stage_test-s1-drop/exit_status)"
run make run BUG=drop PLUSARGS="+verilator+error+limit+1000 +READY_PCT=100"
run make run BUG=bubble
say "the cover property in the golden run's coverage.dat"
tr '\001\002' '|=' < build/runs/stage_test-s1/coverage.dat | grep c_S1
verilator_coverage build/runs/stage_test-s1/coverage.dat | grep user

cd ../reactive-agents-and-backpressure
run make run PLUSARGS="+MODE=coin +READY_PCT=5"
run make run PLUSARGS="+MODE=coin +READY_PCT=50"
run make run PLUSARGS="+MODE=coin +READY_PCT=95"
run make run PLUSARGS="+MODE=beat +MAX_DELAY=12"
run make run SEED=2 PLUSARGS="+MODE=beat +MAX_DELAY=12"
run make run PLUSARGS="+MODE=beat +MAX_DELAY=12 +URANDOM"

cd ../virtual-sequences
run make run

cd ../register-models
run make run UVM_TESTNAME=reg_reset_test
run make run UVM_TESTNAME=reg_reset_test BUG=en_reset_1
run make run UVM_TESTNAME=reg_bitbash_test
run make run UVM_TESTNAME=reg_bitbash_test BUG=mode_stuck
run make run UVM_TESTNAME=reg_mirror_test
run make run UVM_TESTNAME=reg_mirror_test PLUSARGS=+PREDICT=auto
run make run UVM_TESTNAME=reg_mirror_test PLUSARGS=+PREDICT=none

cd ../regressions-and-seeds
run make run UVM_TESTNAME=random_test SEED=1
run make run UVM_TESTNAME=random_test SEED=2
for p in +EXTRA_DRAW +EXTRA_NEW +EXTRA_SEQ +EXTRA_START; do
  run make run UVM_TESTNAME=random_test SEED=1 PLUSARGS=$p
done
run make seeds UVM_TESTNAME=count_test SEEDS="1 2 3 4 5 6 7 8 9 10"
for s in 1 2 3 4 5 6 7 8 9 10; do
  printf 'seed %-2s ' "$s"; grep -h -o '\[COUNT\] [0-9].*' build/runs/regress/count_test-s$s/run.log
done
for s in 1 2 3 4 5 6 7 8 9 10; do
  run make run UVM_TESTNAME=count_test SEED=$s BUG=wrap
done
run make run UVM_TESTNAME=count_test SEED=random
ls build/runs
