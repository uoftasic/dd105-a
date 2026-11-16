# Lab 01: reference solution

Open this after `make check BUG=A03` passes on your own scoreboard.

| File | What it is |
|---|---|
| `alu_pkg.sv` | `tb/alu_pkg.sv` with the scoreboard extended to check `N` and `Z` |

Only `alu_scoreboard` differs from the shipped file. Compare the two with:

```bash
diff tb/alu_pkg.sv solutions/alu_pkg.sv
```

To run the solution, keep your own file and put the solution in its place for one build:

```bash
cp tb/alu_pkg.sv tb/alu_pkg.mine.sv
cp solutions/alu_pkg.sv tb/alu_pkg.sv
make check-all
cp tb/alu_pkg.mine.sv tb/alu_pkg.sv
```

## What changed

`write()` compares the flags after the value, with its own counters and its own report ID:

```systemverilog
if (t.N != n || t.Z != z) begin
  n_bad_flags++;
  bad_flags[t.op]++;
  `uvm_error("FLAGS", $sformatf("%s, expected N=%0b Z=%0b", t.convert2string(), n, z))
end
```

`report_phase` adds the flag count to its line. Because value and flag mismatches are reported
under different IDs, UVM's report summary counts them apart (`[VALUE]` and `[FLAGS]` under
"Report counts by id"), which is the two-bucket report DD104 Lab 03's `t02` builds by hand.

A wrong value usually brings wrong flags with it, so on A01 and A02 most mismatched vectors are
reported twice, once under each ID. On A03 every value is right and only `[FLAGS]` fires.
