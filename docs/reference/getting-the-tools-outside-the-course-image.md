# Getting the tools outside the course image

This page answers: *what do the labs need, where does each piece come from, and what changes if I
run them somewhere other than the course image?*

Every number and output on this course's pages comes from runs in the course image, IIC-OSIC-TOOLS
2026.08, which you run through the workbench you set up in [IC101](https://uoftasic.com/ic101/). Everything else
the labs need is in this repository, the UVM library included, so a clone builds without fetching
anything. If you want to run the labs on another machine, this page lists the pieces. We checked
every fact on it in the image (on November 16, 2026) or against the source it names. The commands
for other systems are copied from each project's own documentation, and each block of them is
marked *untested by us*: we have not run them, and the labs' expected outputs were all measured in
the image.

## Tool versions

| Tool | In the course image | What the labs use it for |
|---|---|---|
| Verilator | 5.050 (`Verilator 5.050 2026-07-01 rev v5.050`) | builds every testbench, through `labs/common/uvm.mk` |
| Yices | 2.7.0, as `yices-smt2` | Verilator's constraint solver, called while a simulator runs |
| g++ | 13.3.0 | compiles the C++ that Verilator writes; Verilator was configured with it |
| mold | 2.30.0 | the linker the image's Verilator was configured to use (`-fuse-ld=mold`) |
| ccache | 4.9.1 | keeps compiled C++ between builds, so a rebuild after a small edit takes about 25 s instead of about 100 s |
| GNU make, bash, GNU coreutils | make 4.3, bash 5.2.21, coreutils 9.4 | `uvm.mk` itself |
| Python | 3.12.3 | the graders in `labs/common`, which use only the standard library |
| `verilator_coverage` | comes with Verilator | `make cov` merges and reads `coverage.dat` with it |
| `vcd2fst` | from GTKWave, in `/foss/tools/bin` | `make waves` converts the simulator's VCD to FST with it |
| Icarus Verilog, cocotb | 14.0 (devel), 2.0.1 | only Lab 01's cocotb testbench |
| UVM | 2020-3.2 | not in the image: it's in this repository, in `third_party/uvm` |

The image is Ubuntu 24.04.4. It is published on Docker Hub as `hpretl/iic-osic-tools:2026.08`,
and the course pins it by digest:

```text
hpretl/iic-osic-tools@sha256:3c371645b19c6f6564dc8c7b21e39ad1c1833d274fe5b85639afe1ba9d7987e7
```

That digest names a multi-platform index. Its `linux/amd64` image, the only one we've run, is 3.76
GB to download (61 compressed layers) and 11.7 GB once unpacked. The index lists a `linux/arm64`
image as well, which we haven't tried. The course's CI (`.github/workflows/labs.yml`) runs every
lab in that amd64 image with `scripts/ci/in-image.sh`, which is a plain `docker run` with the
course's limits of 2 CPUs and 3 GB. From the top of a clone, with Docker and the image on your
machine, this builds and runs Lab 01's UVM testbench the same way:

```bash
export IMAGE=hpretl/iic-osic-tools@sha256:3c371645b19c6f6564dc8c7b21e39ad1c1833d274fe5b85639afe1ba9d7987e7
scripts/ci/in-image.sh make -C labs/lab-01-one-alu-two-testbenches
```

`in-image.sh` passes `--skip` first, which tells the image's entrypoint to run the command instead
of starting its desktop (it prints `[INFO] SKIPPING UI STARTUP`).

## The UVM library

`third_party/uvm` is a copy of the UVM library from
[chipsalliance/uvm-verilator](https://github.com/chipsalliance/uvm-verilator), branch `master`, at
commit `5d72b6618acfddece7f09382a032ccbc05862fdc` (2026-08-14, "Update master to uvm-2020-3.2").
That is Accellera's UVM 2020-3.2, the reference implementation of IEEE 1800.2-2020, plus
`src/dpi/uvm_hdl_verilator.c`, a back end that lets UVM's HDL access (the register layer's back door,
`uvm_hdl_read` and the rest) reach signals through Verilator's VPI.

| Path | What it is |
|---|---|
| `src/` | the library: `uvm_pkg.sv`, the macros, and the DPI C code in `src/dpi/` |
| `LICENSE.txt` | the Apache License 2.0, which covers the whole library |
| `NOTICE.txt` | the copyright owners, from AMD to Verilab, twenty in all |
| `README.md`, `DEVIATIONS.md` | the library's own release notes and its list of deviations from the standard |
| `VENDORED.md` | where the copy came from, written by us |

Only `src/` and those four files were copied, and none of them was edited. We checked that on
November 16, 2026, by cloning the repository at that commit and comparing: the 186 files in `src/`
and the four files are identical. To check it again:

```bash
git clone https://github.com/chipsalliance/uvm-verilator.git
git -C uvm-verilator checkout 5d72b6618acfddece7f09382a032ccbc05862fdc
diff -r uvm-verilator/src third_party/uvm/src
```

The library's only dependency outside SystemVerilog is its DPI C code. `uvm.mk` compiles
`src/dpi/uvm_dpi.cc` into every simulator, and that file includes the rest of `src/dpi/`; the
Verilator back end is included only when `VERILATOR` is defined, which Verilator's own makefile
does. If you copy the library on, keep `LICENSE.txt` and `NOTICE.txt` with it, as the Apache
License asks.

## Verilator options in `uvm.mk`

Every lab's `Makefile` names its sources and includes `labs/common/uvm.mk`, which runs Verilator from
the top of the clone. These are the options it adds, and why. [`labs/common/README.md`](https://github.com/uoftasic/dd105-a/blob/main/labs/common/README.md)
has the variables that change them, and every build writes its Verilator version, its solver and its
whole Verilator command line, apart from `-j`, to `build/build.flags` in the lab folder.

| Option | Why |
|---|---|
| `--binary --timing` | builds a complete simulator with Verilator's own `main()`, with support for `#`, `@` and `wait` in classes |
| `+incdir+third_party/uvm/src third_party/uvm/src/uvm_pkg.sv` | the UVM library |
| `third_party/uvm/src/dpi/uvm_dpi.cc` and `--vpi` | UVM's DPI C code, which needs VPI for its HDL access |
| `-Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-SYMRSVDWORD -Wno-CASTCONST -Wno-IMPLICITSTATIC` | the UVM field macros expand into code that raises about 200 width warnings, and Verilator stops at the first warning; `make lint` shows them |
| `-CFLAGS "-DVM_SOLVER_DEFAULT='\"yices-smt2 --incremental\"'"` | sets the solver a simulator uses when it's run by hand (below) |
| `--output-groups 8` and `-MAKEFLAGS OPT_FAST=-O0` | eight C++ files compiled without optimization: a cold build in about 100 s on 2 CPUs instead of 526 s, for a simulator about 1.4 times slower |
| `--coverage-user` | covergroups and assertions write `coverage.dat`, which `make cov` reads |
| `--trace-vcd` with `labs/common/uvm/dd105_trace.vlt` | waves for `make waves`, leaving the packages out |
| `-j 2` | two g++ jobs, each of which can need up to 1.3 GB |

Verilator runs in the top of the clone and names every file from there, so the generated C++ is the
same wherever the clone is mounted, and ccache can reuse it from one lab, container or machine to the
next. `uvm.mk` finds the clone from its own location and has no `/foss` paths in it: the CI mounts
the clone at `/w`, and the labs build and pass there as they do in the workspace.

The register model's back door in Labs 06 and 07 needs the signals it reaches marked public for VPI.
The labs name them one at a time in a `.vlt` file, and
[The UVM register layer](register-layer.md#the-back-door) explains why.

## The constraint solver

Verilator hands every constrained `randomize()` to an external SMT solver, named by the environment
variable `VERILATOR_SOLVER`. Verilator 5.050's documentation says that if the variable isn't set,
it uses the solver supplied or found when Verilator was configured, or `z3 --in` if that is empty.
In the course image the configured solver is empty (`verilator -V` prints `VERILATOR_SOLVER   = `)
and `z3` isn't installed, so `uvm.mk` sets `VERILATOR_SOLVER="yices-smt2 --incremental"` for every
build and run, and refuses to start if the solver it names isn't on your `PATH`. It checks because
without a solver every constrained `randomize()` returns 0 and the run still passes. The build also bakes the solver into the simulator, as its default for a run you start by
hand rather than through `make`. Verilator 5.050 bakes a value with a space in it wrongly, so
`uvm.mk` builds with the variable unset and passes the default as a define of its own
(`-DVM_SOLVER_DEFAULT`, in the table above).

You can name another solver on `make`'s command line. In the image, where there is no `z3`, that
gives, from a lab folder:

```text
$ make build VERILATOR_SOLVER="z3 --in"
========================================================================
 VERILATOR_SOLVER is "z3 --in", and z3 is not on PATH.
========================================================================
 Without a solver every constrained randomize() returns 0, nothing is
 randomized, and the run still passes. Are you in the course image?
make: *** [../common/uvm.mk:237: solver-check] Error 1
```

Every constraint result in the course, Lab 03's list of what Verilator 5.050 gets wrong included,
was measured with Yices. We haven't run the labs with another solver.

Yices's README gives these commands for installing it elsewhere. *Untested by us.*

```bash
# Ubuntu or Debian
sudo add-apt-repository ppa:sri-csl/formal-methods
sudo apt-get update
sudo apt-get install yices2

# macOS, with Homebrew
brew install SRI-CSL/sri-csl/yices2
```

## ccache

Verilator's generated makefile runs every compile as `$(OBJCACHE) $(CXX)`. Verilator's
documentation says that if `OBJCACHE` isn't set and ccache was present when Verilator was
configured, ccache is used by default, and the image's Verilator was configured that way
(`OBJCACHE ?= ccache` in its `verilated.mk`). A Verilator configured on a machine without ccache
doesn't use it unless you set `OBJCACHE=ccache` in the environment, and because `uvm.mk` deletes
the generated C++ after each build (`SLIM=1`), every build is then a cold one.
Verilator's install guide also marks ccache and mold "If present at build, needed for run": if they
were installed when Verilator was configured, they have to be there when you use it.

`uvm.mk` keeps the cache in `.ccache` at the top of the clone, capped at 2 GB, so in the workspace
it survives a container restart. In the course's measurements on a small UVM
testbench, a cold build took 102 to 103 s and a rebuild after a one-line edit 24 to 26 s
([Build times](https://github.com/uoftasic/dd105-a/blob/main/labs/common/README.md#build-times)).
`make cache` shows how full it is, and `make clean-cache` empties it.

## Waves

Verilator can write FST directly with `--trace-fst`, but not in the course image: its FST writer
needs the header `lz4.h`, and the image has no `/usr/include/lz4.h`. So `uvm.mk` builds with
`--trace-vcd`, and `make waves` converts the VCD file to FST with `vcd2fst`, which comes with
GTKWave. Elsewhere, `make waves` needs `vcd2fst` on your `PATH`, and `make cov` needs
`verilator_coverage`, which is installed with Verilator.

## Verilator 5.050

Every expected output in the labs is Verilator 5.050's, and so is every limit the course teaches
around: what `solve...before` and `dist` do, how coverage is counted, which shapes of driver code
lose a nonblocking assignment. Another version may print different numbers, or fix or add a limit.
Verilator's install guide warns that distribution packages "almost never have the most recent
Verilator version" and recommends building from Git. If you use another version, run
`make FULL=1` in `labs/common/selftest` first: it builds a small UVM testbench, checks every grader
end to end, and fails if the nonblocking-assignment shapes the course describes change.

Verilator 5.050's install guide (`docs/guide/install.rst` at tag `v5.050`) gives these steps to
build it from Git on Ubuntu. *Untested by us.*

```bash
# Prerequisites:
#sudo apt-get install git help2man perl python3 make autoconf g++ flex bison ccache
#sudo apt-get install libgoogle-perftools-dev libjemalloc-dev numactl perl-doc
#sudo apt-get install libfl2  # Ubuntu only (ignore if gives error)
#sudo apt-get install libfl-dev  # Ubuntu only (ignore if gives error)
#sudo apt-get install zlibc zlib1g zlib1g-dev liblz4 liblz4-dev  # Ubuntu only (ignore if gives error)

git clone https://github.com/verilator/verilator   # Only first time

# Every time you need to build:
unsetenv VERILATOR_ROOT  # For csh; ignore error if on bash
unset VERILATOR_ROOT  # For bash
cd verilator
git pull         # Make sure git repository is up-to-date
git tag          # See what versions exist
#git checkout master      # Use development branch (e.g. recent bug fixes)
#git checkout stable      # Use most recent stable release
#git checkout v{version}  # Switch to specified release version

autoconf         # Create ./configure script
./configure      # Configure and create Makefile
make -j `nproc`  # Build Verilator itself (if error, try just 'make')
sudo make install
```

For this course, the version line is `git checkout v5.050`. The guide also lists mold as optional
(`sudo apt-get install mold`), and z3 as the solver for constraints (`sudo apt-get install z3`); the
course uses Yices instead, as described above. It notes that configure compiles the values of
`VERILATOR_ROOT`, `VERILATOR_SOLVER`, `SYSTEMC_INCLUDE` and `SYSTEMC_LIBDIR` in as defaults, so
they must be what you want before you run it.

## Other differences outside the image

| What | In the image | Elsewhere |
|---|---|---|
| Memory | the course's runs use a 3 GB limit | each g++ job can need 1.3 GB, so keep `JOBS=2` (the default) unless you have more |
| Shell tools | GNU make 4.3, bash, GNU coreutils | `uvm.mk` uses `realpath -m`, `stdbuf`, `timeout`, `seq`, `awk` and `date +%s.%N`; we haven't run it where those differ, as on macOS |
| Python | 3.12.3 | the graders use only the standard library; we haven't run them on other versions |
| The solver | `yices-smt2` on `PATH` | install Yices, or name another solver with `VERILATOR_SOLVER` |
| ccache | used, through Verilator's configure | install it before you build Verilator, or set `OBJCACHE=ccache` |
| Waves | VCD converted with `vcd2fst` | `vcd2fst` on `PATH` for `make waves` |
| Lab 01's cocotb half | cocotb 2.0.1 and Icarus Verilog 14.0 (devel) | other versions untested |
