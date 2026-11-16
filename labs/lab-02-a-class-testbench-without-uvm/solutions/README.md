# Lab 02: reference solution

Open this after `make check-all` prints `2 of 2 caught.` with your own monitor and scoreboard.

| File | What it is |
|---|---|
| `monitor.svh` | `tb/monitor.svh` with `run()` written |
| `scoreboard.svh` | `tb/scoreboard.svh` with `run()`, `predict()`, `check()` and the checks in `report()` written |

Apart from the header comments, only the bodies the `TODO`s mark differ from the shipped files.
Compare them with:

```bash
diff tb/monitor.svh solutions/monitor.svh
diff tb/scoreboard.svh solutions/scoreboard.svh
```

To run the solution, keep copies of your own files outside `tb/` and put the solution in their
place:

```bash
cp tb/monitor.svh my_monitor.svh
cp tb/scoreboard.svh my_scoreboard.svh
cp solutions/monitor.svh solutions/scoreboard.svh tb/
make check-all
cp my_monitor.svh tb/monitor.svh
cp my_scoreboard.svh tb/scoreboard.svh
```

On 2 CPUs, with a ccache that held no build of the solution, filling in each file on its own cost
a rebuild of 89 s (the monitor) and 86 s (the scoreboard). Swapping both into a starter build at
once took 15 s, on a ccache that already held a build of the solution.

## What it does

| Piece | How |
|---|---|
| `monitor::run()` | At each `@(vif.cb)`: while `rst_n` is 0, drop the half-built packet; on a handshake (`valid && ready`), add the beat, and on `last` put the packet in `to_sb` |
| `scoreboard::run()` | `fork ... join` of two `forever` loops: `from_in` to `predict()`, `from_out0` to `check()` |
| `scoreboard::predict()` | push the packet onto `expected` when `ROUTE[DST]` is enabled with `PORT` 0 |
| `scoreboard::check()` | an output 0 packet with nothing expected is an error; otherwise pop the oldest expected packet and compare it with `packet::same()` |
| `scoreboard::report()` | each packet still expected is an error, and so is a run that checked no packets |

Each error is a `$error` and adds one to `n_errors`.

## Results

Seed 1, `router_class_test` with its default knobs (100 packets, `+DSTS=0123`, `+ROUTES=0110`):

| Run | Result |
|---|---|
| golden | `[SB] 100 packets in, 51 predicted for output 0, 51 checked, 0 errors` |
| `make seeds NSEEDS=5` | `5 ok  (5 runs)` |
| `make seeds` (seeds 1 to 10) | `10 ok  (10 runs)` |
| B05 | caught, 50 `$error`s; the first at 255 ns, packet `80` (`DST` 2) on output 0 |
| B09 | caught, 46 `$error`s; the first at 895 ns, a 13-beat packet whose last 7 beats are packet 2's |
| all 15 bugs (`BUG_LIST` set to B01 to B15) | `2 of 15 caught.`: B05 and B09, and no other |

The stimulus experiments in Part 4 of the writeup, with this solution:

| `PLUSARGS` | B05 | B09 |
|---|---|---|
| `+ROUTES=0000` | MISSED | |
| `+DSTS=0 +N=32` | MISSED | |
| `+DSTS=0` | caught, 68 | |
| `+DSTS=0 +LEN=1 +N=15` | | MISSED |
| `+DSTS=0 +LEN=1 +N=16` | | caught, 1 |
