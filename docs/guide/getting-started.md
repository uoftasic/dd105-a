# Getting started

This page covers what DD105-A needs from your machine, which tool versions its outputs depend on,
how long the builds take and where they leave their files, how to read a lab's output, and how to
get help. You'll do the setup itself in
[Lab 01, Part 1](../labs/lab-01-one-alu-two-testbenches-overview.md#part-1-load-the-course).

## Requirements

You did the hard part of the setup in [IC101](https://uoftasic.com/ic101/), and you used the same
container all through [DD104](https://uoftasic.com/dd104/). DD105-A runs in it too, and like DD104
it needs no PDK and no synthesis flow: everything in it is simulation.

The setup has three pieces:

- the noVNC desktop, started from your `workspace` clone with `./scripts/start_vnc.sh`
  (`scripts\start_vnc.bat` on Windows). Ports, passwords and blank-page fixes are in
  [IC101: Launch the noVNC desktop](https://uoftasic.com/ic101/guide/launch-novnc.html);
- `. /foss/designs/common/.designinit`, which you load in every new terminal, and which defines the
  workbench's `mod` command;
- `mod add dd105-a`, which you run once. It clones the course from `github.com/uoftasic/dd105-a`
  into `/foss/designs/modules/dd105-a`, and `mod dd105-a` takes you there from then on. That folder
  is in your `workspace` folder, bind-mounted into the container, so your files are on your own
  disk and deleting the container doesn't delete your work.

`mod add dd105-a` prints:

```text
Cloning https://github.com/uoftasic/dd105-a.git
     into /foss/designs/modules/dd105-a
Cloning into '/foss/designs/modules/dd105-a'...
OK  module ready: /foss/designs/modules/dd105-a
    run: mod dd105-a
cwd: /foss/designs/modules/dd105-a
```

Nothing else needs installing. Verilator, Icarus, cocotb, the Yices constraint solver and Surfer
are all in the image, and the one thing the image lacks, a UVM library, is in the course repo
itself, in `third_party/uvm`, so `mod add` brings it with everything else.

Every lab also runs with `make` alone, in a plain `git clone` of the course inside the image, with
no `.designinit` and no `mod`, because each lab's makefile works out its own paths. So if a setup
step fails late at night, `make` in a lab folder will still tell you whether the tools work.

## Versions

The course is pinned to the workbench image `hpretl/iic-osic-tools:2026.08`. These are the versions
it reports, and every exact number in the labs was recorded with them:

| Tool | What its version check prints |
|---|---|
| Verilator | `Verilator 5.050 2026-07-01 rev v5.050` |
| Icarus Verilog | `Icarus Verilog version 14.0 (devel) (s20260301-391-g64f13540-dirty)` |
| cocotb | `2.0.1` |
| Yices | `Yices 2.7.0` |
| Surfer | `surfer 0.7.0 (git: v0.7.0)` |
| UVM, in `third_party/uvm` | `Accellera:1800.2:UVM:2020.3.2`, at the start of every run |

Verilator's version matters most, because much of the course depends on what 5.050 does and
doesn't do, and the labs and these pages point out the places where it differs from the
SystemVerilog standard as you come to them.

Yices is there because Verilator needs an outside solver for every `randomize()` that has
constraints. Without one, each such `randomize()` fails, nothing is randomized, and the test still
passes, so the labs' makefile tells Verilator to use Yices and stops before it runs anything if it
can't find it. Lab 01, Part 1 has you check the first five rows of the table.

## How long things take

Verilator translates the whole UVM library into C++ along with your testbench every time it builds
a lab's simulator, and g++ then compiles all of it, so the builds are the slow part of this course
and the runs are quick. These are the times we measured for Lab 01 in the course image, on 2 CPUs
of a shared machine:

| Job | Wall time |
|---|---|
| The first build, with an empty compiler cache | 126 s |
| A rebuild after a change inside one function | 27 s |
| A rebuild after adding a member to a class | 108 s |
| One run of the random test, 2000 vectors | 1.2 s |
| `make check-all`: the test against the correct ALU and three bugs | four runs of 1.1 s to 1.2 s |
| The cocotb test on Icarus, for comparison | 23.0 s, and 0.4 s to build |

The build prints its own estimate when it starts:

```text
========================================================================
 BUILD  alu_tb_top   (2 jobs; ccache: /w/.ccache)
 A cold build takes 1.5 to 2.5 minutes on 2 CPUs; a rebuild with a warm
 ccache takes from 10 s to about 2 minutes. Full log: /w/labs/lab-01-one-alu-two-testbenches/build/build.log
========================================================================
```

We ran it with the course folder mounted at `/w`, so on the workbench your paths start with
`/foss/designs/modules/dd105-a` instead. While it builds, the terminal shows a `compiling` line for
each file g++ compiles.

Build times move with the machine and with whatever else it's doing. Lab 01's own writeup records a
first build of 102 s, and rebuilds of 26 s and 93 s for the same two kinds of change, so treat the
table as a guide to how long to wait rather than a number to match.

The two rebuild times differ because of what changed. A change inside a function body leaves most
of the generated C++ as it was, and the compiler cache supplies the rest. A new member changes the
class's layout, and most of the generated C++ changes with it.
[What a framework buys you](../guide/what-a-framework-buys-you.md) says more about this.

The test, the seed, the planted bug and a test's knobs are all chosen when the simulator starts, so
changing them never rebuilds anything. Every lab is written to make use of that.

## Where the builds go

Each lab builds into its own `build/` folder. After a build, it holds mainly the simulator,
`build/sim`, about 47 MB, and the build's log, because the build deletes Verilator's generated
C++, almost 900 MB of it, once the simulator is linked. Each run gets a folder of its own under
`build/runs/`, named for the test, the seed and the bug. It holds `run.log` and, if you asked for
them, the waves.

The compiler cache, ccache, lives at the top of your clone, in `.ccache`, and every lab shares it.
Because it's in your workspace it survives a container restart, so a new container doesn't start
again from a cold build. It's capped at 2 GB, and after the Lab 01 builds in the table it held
211 MB.

`make clean` in a lab folder removes that lab's `build/` and keeps the cache:

```text
 removed /w/labs/lab-01-one-alu-two-testbenches/build. The ccache (/w/.ccache) is kept: make clean-cache removes it.
```

Every lab README shows it, and it's worth running when you finish a lab. `make clean-cache`
removes the cache as well, which makes the next build a cold one again.
[`labs/common/README.md`](https://github.com/uoftasic/dd105-a/tree/main/labs/common) lists every
make target the labs share, and `make help` in a lab prints the targets that lab has.

## Reading a lab's output

Every run starts with UVM's release notes, a block of text headed `IMPORTANT RELEASE NOTES` that
names the library, `Accellera:1800.2:UVM:2020.3.2`, and ends with
`(Specify +UVM_NO_RELNOTES to turn off this notice)`. You can ignore it. After it come your test's
own lines, and then the end of the run, which comes in one of two orders.

A run that passes prints `DD105: TEST PASSED`, a line from the course's base test, then UVM's
report summary, and last, a one-line verdict from the labs' makefile:

```text
------------------------------------------------------------------------
 ok: 0 UVM_ERROR, 0 UVM_FATAL   1.18 s   log: build/runs/alu_rand_test-s1/run.log
------------------------------------------------------------------------
```

A run that reports errors prints UVM's report summary first, then a `DD105: TEST FAILED` line with
the error counts, then a `%Fatal` line from `dd105_base_test` saying
`DD105: UVM counted errors, so the exit status is nonzero`. The `%Fatal` is there on purpose. On
Verilator 5.050 a UVM run that reports errors would otherwise exit with status 0, and we want a
failing run to exit with a nonzero status.

The graders judge your testbench from both sides, as in DD104: it must pass on the correct design
and fail on a broken one. `make check` and `make check-all` run your test against each and put
every run into one class: `ok` (passed), `caught` (a check fired), `MISSED` (a bug run passed) or
`BROKEN` (the run failed for some other reason, such as a crash, a timeout or a failed build). A
BROKEN run never counts as a catch. Lab 01's shipped testbench misses one of its three bugs, so its
first `make check-all` ends like this:

```text
  MISSED  tier 1  A03_zero_flag_low_nibble         0 UVM_ERROR, 0 UVM_FATAL        1.1s
  caught  tier 1  A01_sub_operands_swapped         282 UVM_ERROR                   1.1s
  caught  tier 1  A02_nand_is_nor                  255 UVM_ERROR                   1.1s
------------------------------------------------------------------------
 2 of 3 caught.
 Still hiding from this test:
   A03_zero_flag_low_nibble
      hides behind: every check that compares results and not flags
========================================================================

  The verdict above is FAIL, so this target exits non-zero and make
  prints an error line under this one. That is the verdict talking,
  not a broken Makefile.
make: *** [../common/uvm.mk:300: check-all] Error 1
```

You'll see that last line often. It's `make` reporting the failed verdict, and it goes away once
your testbench catches every bug.

Counts, simulated times and verdicts come out the same on every run of the same code with the same
seed, which is 1 unless you choose another, so yours should match the labs' exactly. If one
doesn't, something is different, and we'd like to know what. Wall-clock times are only a rough
guide, because they depend on your machine and on what else it's doing.

## Getting help

- Ask in the [team Discord](https://discord.gg/hrJnP5UsGz). No question is too basic. A good part
  of this course is about places where the tools go wrong without telling you, so much of what
  looks like your own mistake is the simulator being unhelpful.
- Quote the exact error, the command you ran, and the test, seed and bug. "My scoreboard fails" and
  "my scoreboard reports 46 errors on B09 with seed 1 and none on the golden router" are different
  questions, and the second is much easier to answer.
- Paste the verdict block and the first error from `run.log` as text. When one bug causes many
  errors, the later ones are mostly its consequences, so the first is the one to read. If the build
  failed, its whole log is in `build/build.log`, and the makefile prints the last 30 lines of it
  for you.
- If a command in a lab doesn't do what the lab says, please report it. We ran every command
  before writing it down and copied every output from a real run, so a mismatch means something
  has drifted since.

### Requests to avoid

`labs/common/bugs.py` lists all fifteen of the router's planted bugs, with the exact line each one
changes, and every lab has a `solutions/` folder. All of it is in your clone and you can read it,
but if you do, you skip what the course is teaching you, which is how to find a bug you can't
see. The graders also refuse a testbench that reads the `+BUG` switch or the design's record of
which bug is on, so a testbench that peeks can't pass. If you're stuck, ask in Discord for help
finding a better question to put to the design rather than for the answer.

## Check yourself

1. You finish Lab 01 and run `make clean` to free space. Will Lab 02's first build be a cold one?

   <details>
   <summary>Answer</summary>

   No. `make clean` removes only that lab's `build/` folder, and the compiler cache in `.ccache` at
   the top of your clone stays, so Lab 02's build can reuse whatever it shares with Lab 01. Only
   `make clean-cache` empties it.

   </details>

2. `make check-all` ends with `make: *** [...] Error 1`. Is something wrong with the makefile?

   <details>
   <summary>Answer</summary>

   No. The verdict was FAIL, so the target exits with a nonzero status, and `make` reports that
   with its error line. The three lines just above it say so.

   </details>

3. A run's log ends with `%Fatal: ... DD105: UVM counted errors, so the exit status is nonzero`. Did
   the simulator crash?

   <details>
   <summary>Answer</summary>

   No. Your test reported at least one `UVM_ERROR`, and `dd105_base_test` stopped the run with
   `$fatal` so that its exit status is nonzero. The `DD105: TEST FAILED` line just above it gives
   the count, and the errors themselves are earlier in the log, before UVM's report summary.

   </details>

## Further reading

ChipVerify has a few pages about Verilator and about getting UVM running. Read them with these
corrections, because each was written for a different setup from this course's.

- [Introduction to Verilator](https://chipverify.com/rtl-synthesis/introduction-to-verilator).
  Correction: it says Verilator supports only synthesizable Verilog, can't run `#` delays or
  `fork`, and that you should use Icarus for testbenches that need them. That was true before
  Verilator 5, which added `--timing` and `--binary`. Every lab here builds with both.
- [Verilator Simulation](https://chipverify.com/rtl-synthesis/verilator-simulation): its section on
  two-state simulation is worth reading. Correction: its claims that class-based SystemVerilog has
  minimal support and that UVM testbenches won't compile are out of date; every lab in this course
  builds a UVM testbench on Verilator 5.050.
- [UVM Installation](https://www.chipverify.com/uvm/uvm-installation): what a UVM library is and
  how you'd get one. You don't need to, because the course carries its own. Note: the page puts the
  library on the include path but never says that `uvm_pkg.sv` itself has to be compiled too, which
  the labs' makefile does.

Next: [What a framework buys you](../guide/what-a-framework-buys-you.md).
