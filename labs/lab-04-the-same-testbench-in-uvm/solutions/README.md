# Lab 04: reference solution

Open this after `make check-all` prints `2 of 2 caught.` with your own tests.

| File | What it is |
|---|---|
| `router_env_pkg.sv` | `tb/router_env_pkg.sv` with the Part 2 and Part 3 TODOs filled in |
| `router_tests_pkg.sv` | `tb/router_tests_pkg.sv` with the Part 3 and Part 4 TODOs filled in |

Compare them with the shipped files:

```bash
diff tb/router_env_pkg.sv solutions/router_env_pkg.sv
diff tb/router_tests_pkg.sv solutions/router_tests_pkg.sv
```

To run the solution, keep copies of your own files outside `tb/` and put the solution in their
place:

```bash
cp tb/router_env_pkg.sv my_router_env_pkg.sv
cp tb/router_tests_pkg.sv my_router_tests_pkg.sv
cp solutions/router_env_pkg.sv solutions/router_tests_pkg.sv tb/
make check-all
cp my_router_env_pkg.sv tb/router_env_pkg.sv
cp my_router_tests_pkg.sv tb/router_tests_pkg.sv
```

A swap rebuilds whatever your files and the solution don't share. Done one part at a time on 2
CPUs, the edits rebuilt in 24 to 32 s and 26 to 36 s (Part 2), 102 s and 33 s (Part 3) and 111 s
(Part 4).

## What changed

| Part | Where | Change |
|---|---|---|
| 2 | `router_env::build_phase`, `connect_phase` | `out[1]` made as `"out1"` and its monitor connected to `sb.out_export` |
| 2 | `router_scoreboard::write_in` | every forwarded beat queued on `expected[in_port]`, not only output 0's |
| 3 | `router_scoreboard::level` | the `if (p == 1) return 0;` that treated output 1 as always empty, removed |
| 3 | `router_stall_test` | `set_sinks(k)`: the output `k % 2` ready in 5% of cycles, the other in 100% |
| 4 | `router_noroute_pkt` | a `router_pkt` whose `c_dst` (same name, so it replaces the parent's) sends one packet in four to a disabled route |
| 4 | `router_inject_test` | `router_pkt::type_id::set_type_override(router_noroute_pkt::get_type())` before `super.build_phase` |

## Results

Measured on 2 CPUs in the course image, `router_inject_test`:

| | Seeds 1 to 5 |
|---|---|
| golden router | `ok` on every seed, 0.6 s a run |
| B06 | caught on every seed, 50 `UVM_ERROR`s, 0.2 to 0.6 s |
| B13 | caught on every seed, 50 `UVM_ERROR`s, 0.2 s |

`make regress SEEDS="1 2 3 4 5"` (four tests, five seeds) gives `20 ok  (20 runs)` and all 15
covergroup bins hit.
