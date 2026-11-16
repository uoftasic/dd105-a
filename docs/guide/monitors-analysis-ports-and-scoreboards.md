# Monitors, analysis ports and scoreboards

This page answers: *how does what happened on the pins reach the checks, and what does a
scoreboard do with it?*

In Lab 02 your monitor turned the handshakes on a stream into whole packets and put them in a
mailbox, and the scoreboard ran a loop of its own that took them out. Lab 03 added a tracker,
with another loop, that watched the pins for itself. In
[Lab 04](../labs/lab-04-the-same-testbench-in-uvm-overview.md) every monitor writes each beat to
an **analysis port** as it moves, and the scoreboard has no thread at all: it's a class whose
`write` functions the monitors call. This page explains how that works, what can go wrong with it,
and what Lab 04's scoreboard does when a beat arrives.

The example,
[`guide-examples/monitors-analysis-ports-and-scoreboards/`](https://github.com/uoftasic/dd105-a/tree/main/guide-examples/monitors-analysis-ports-and-scoreboards),
puts a complete agent on SimProc's ALU: the driver from the sequences example, a monitor, and
three subscribers on the monitor's one analysis port. The ALU is Lab 01's, so its run-time bug
switch works here too, and `make run BUG=A01` runs the same test on the ALU whose `SUB` computes
`B - A`.

## The monitor

A monitor reads the pins and reports what it saw. It doesn't drive anything, and it doesn't know
what the driver sent or what the answer should be, which is what lets the same monitor serve a
scoreboard, a coverage collector and anything else you add later. The example's reads through a
clocking block that only has inputs, so it sees each signal as it was just before the clock edge,
which is the value in that cycle:

```systemverilog
task run_phase(uvm_phase phase);
  alu_item t;
  forever begin
    @(vif.mon_cb);
    if (vif.mon_cb.valid) begin
      t        = alu_item::type_id::create("seen");   // a new item every time
      t.op     = alu_op_e'(vif.mon_cb.ALUop);
      t.A      = vif.mon_cb.A;
      t.B      = vif.mon_cb.B;
      t.ALUout = vif.mon_cb.ALUout;
      t.N      = vif.mon_cb.N;
      t.Z      = vif.mon_cb.Z;
      ap.write(t);
    end
  end
endtask
```

Lab 04's monitors do the same for a stream (one `stream_beat` per handshake, stamped with its
cycle number) and for APB (one `apb_item` per completed transfer).

## Analysis ports

`ap` is a `uvm_analysis_port #(alu_item)`. Its `write(t)` is a function, so it can't wait, and it
calls the `write` function of every subscriber connected to the port, one after another, before it
returns. A port with no subscribers is allowed, and `write` then does nothing. The monitor has no
way of knowing who, if anyone, is listening; the environment makes the connections in
`connect_phase`:

```systemverilog
agent.mon.ap.connect(sb.imp);
agent.mon.ap.connect(cov.analysis_export);
agent.mon.ap.connect(hist.analysis_export);
```

On the receiving side, a scoreboard declares a `uvm_analysis_imp #(alu_item, alu_scoreboard)`,
which calls the scoreboard's own `write(alu_item t)`. A `uvm_subscriber #(alu_item)` comes with
the receiving end already built in, called `analysis_export`, and you only write its `write`
function. The example's coverage collector and history are subscribers.

A scoreboard with several inputs needs one `write` function for each, and an imp can call only a
function named `write`. The macro `` `uvm_analysis_imp_decl(_in) `` declares a new imp class,
`uvm_analysis_imp_in`, that calls `write_in()` instead. Lab 04's scoreboard declares three, at
package scope, for the input stream, the outputs and the APB port:

![Lab 04's analysis connections: four monitors write to three exports on the scoreboard, and the scoreboard's own analysis port feeds the coverage collector.](../assets/img/monitors-lab04-connections.svg)

*Where Lab 04's transactions go, from `router_env::connect_phase`. Both output monitors write to
the same `out_export`; each `stream_beat` carries its port number, so `write_out()` knows which
output it came from. The scoreboard decides each packet's fate and writes it to its own analysis
port, `fate_ap`, for the coverage.*

One `mon_rand_test` run of 200 vectors shows all three subscribers getting every item:

```text
UVM_INFO guide-examples/monitors-analysis-ports-and-scoreboards/mon_pkg.sv(238) @ 3995000: uvm_test_top.env.cov [COV] cg: 100.0% of its bins hit
UVM_INFO guide-examples/monitors-analysis-ports-and-scoreboards/mon_pkg.sv(260) @ 3995000: uvm_test_top.env.hist [HIST] kept 200 handles to 200 different objects
UVM_INFO guide-examples/monitors-analysis-ports-and-scoreboards/mon_pkg.sv(217) @ 3995000: uvm_test_top.env.sb [SB] 200 vectors checked: 0 wrong
UVM_INFO guide-examples/monitors-analysis-ports-and-scoreboards/mon_pkg.sv(313) @ 3995000: uvm_test_top [MON] the monitor wrote 200 items
```

## The scoreboard

A scoreboard predicts what the design should have done and compares that with what the monitors
saw. The example's prediction is a model of the ALU written from SimProc's instruction set, as in
Lab 01, and it does all its work inside `write`:

```systemverilog
virtual function void write(alu_item t);
  bit [7:0] want = predict(t);
  bit       bad  = (t.ALUout != want);
  if (check_flags) bad |= (t.N != want[7]) || (t.Z != (want == 8'h00));
  n_checked++;
  if (bad) begin
    n_bad++;
    `uvm_error("SB", $sformatf("%s, expected ALUout=%02h N=%0b Z=%0b", t.convert2string(),
               want, want[7], want == 8'h00))
  end
endfunction
```

On the ALU with bug A01 the first of its errors is

```text
UVM_ERROR guide-examples/monitors-analysis-ports-and-scoreboards/mon_pkg.sv(207) @ 35000: uvm_test_top.env.sb [SB] SUB A=1f B=34 -> ALUout=15 N=0 Z=0, expected ALUout=eb N=1 Z=0
```

and the run reports 33 of them. The scoreboard also checks in `check_phase` that it checked
something, because a scoreboard that was never called reports no errors either.

Because `write` is a function, a scoreboard can't wait inside it for the design's answer. The ALU
is combinational, so the answer is in the same item as the question. The router isn't: a packet
goes in on one stream and comes out of another, several cycles later. So Lab 04's scoreboard
splits the work between its write functions. `write_in()` decides at each header what the router
must do with the packet (forward it to output 0 or 1, or drop it as NOROUTE or FULL), using the
routing table it has seen written over APB and the level of each output, and queues the beats it
expects on that output. `write_out()` pops the next expected beat for that output and compares.
`write_apb()` follows the routing table and checks every `DROP_CNT` read against the drops it
counted. At the end, `check_phase` reports any beats still queued, which are beats the router
never delivered.

A scoreboard checks only what it compares. With `check_flags` off, the example compares `ALUout`
and nothing else, and `make check-all` against Lab 01's three bugs says so:

```text
  caught  tier 1  A01_sub_operands_swapped         33 UVM_ERROR                    0.2s
  caught  tier 1  A02_nand_is_nor                  26 UVM_ERROR                    0.2s
  MISSED  tier 1  A03_zero_flag_low_nibble         0 UVM_ERROR, 0 UVM_FATAL        0.2s
```

A03 breaks the zero flag, and the monitor reported every wrong `Z`, but nothing compared it.
[The factory and config_db](the-factory-and-config-db.md) turns `check_flags` on from a test,
without editing the scoreboard.

## One object per write

Every subscriber gets the same handle, to the same object. That's cheap, and it's safe as long as
nobody changes the object afterwards. The example's monitor makes a new `alu_item` for every
vector. `mon_alias_test` swaps in a monitor that makes one item and fills it in again for every
vector (the swap is a factory override, which the next page explains), and the history
subscriber, which keeps every handle it's given, finds out at the end:

```text
UVM_INFO guide-examples/monitors-analysis-ports-and-scoreboards/mon_pkg.sv(260) @ 3995000: uvm_test_top.env.hist [HIST] kept 200 handles to 1 different objects
UVM_INFO guide-examples/monitors-analysis-ports-and-scoreboards/mon_pkg.sv(262) @ 3995000: uvm_test_top.env.hist [HIST] vector 0: ADD A=c7 B=91 -> ALUout=58 N=0 Z=0
UVM_INFO guide-examples/monitors-analysis-ports-and-scoreboards/mon_pkg.sv(262) @ 3995000: uvm_test_top.env.hist [HIST] vector 1: ADD A=c7 B=91 -> ALUout=58 N=0 Z=0
UVM_INFO guide-examples/monitors-analysis-ports-and-scoreboards/mon_pkg.sv(262) @ 3995000: uvm_test_top.env.hist [HIST] vector 2: ADD A=c7 B=91 -> ALUout=58 N=0 Z=0
UVM_INFO guide-examples/monitors-analysis-ports-and-scoreboards/mon_pkg.sv(217) @ 3995000: uvm_test_top.env.sb [SB] 200 vectors checked: 0 wrong
```

All 200 handles point at one object, which holds the last vector. In `mon_rand_test` the first
three were an `OR`, a `SUB` and a `SHL`. The scoreboard still passed, because it reads the item
inside `write`, before the next vector overwrites it, but any subscriber that keeps a handle for
later, or queues it to compare when the answer arrives, sees the wrong values. So a monitor makes
a new object for every `write`, and a subscriber that keeps something either copies the values it
needs, as Lab 04's scoreboard does when it queues `{last, data}` for each expected beat, or keeps
the handle and never changes the object.

## Coverage as a subscriber

A coverage collector is the simplest subscriber: its `write` samples a covergroup. On Verilator
5.050 the covergroup has to take its values as arguments, `covergroup cg with function
sample(int op, bit eq)`, because a covergroup whose coverpoints read a member of the class is
dropped; [Functional coverage you can read](functional-coverage-you-can-read.md) shows that.

What a collector subscribes to depends on what it covers. The example covers what went into the
ALU, so it listens to the monitor. Lab 04's `router_coverage` covers each packet's fate and the
level its output was at, which only the scoreboard knows, so it listens to the scoreboard's
`fate_ap`.

## Check yourself

1. `write()` on an analysis port is a function. What does that rule out for a scoreboard's
   `write`, and how does Lab 04's scoreboard live with it?

   <details>
   <summary>Answer</summary>

   It can't wait: no `@`, no `#`, no blocking `get`. The router's answer comes out cycles after
   the packet goes in, so `write_in()` predicts and queues the expected beats, and `write_out()`
   compares when the output monitor reports each beat. Nothing in between needs a thread.

   </details>

2. In `mon_alias_test` the scoreboard passed and the history was wrong. Would a scoreboard that
   pushed each input item onto a queue and compared it when an output arrived have passed?

   <details>
   <summary>Answer</summary>

   No. Every handle on its queue would point at the one object, which by then holds a later
   vector, so it would compare the wrong inputs with each output. The example's scoreboard passed
   only because it finished with each item inside `write`.

   </details>

3. Two monitors write `stream_beat`s to the same `out_export`. How does `write_out()` tell
   output 0's beats from output 1's?

   <details>
   <summary>Answer</summary>

   From the beat itself: each monitor stamps `b.port` from its `out_cfg`, and `write_out()` uses
   it to pick which queue of expected beats to compare with.

   </details>

## Further reading

- ChipVerify's [UVM Monitor](https://www.chipverify.com/uvm/uvm-monitor) builds a monitor for a
  register file. Correction: it says a monitor that didn't get its virtual interface can keep
  running with a `uvm_error`; it can't, because its `run_phase` uses the interface at once, so
  use `uvm_fatal`, as its driver page does. Its test also sets two knobs through `config_db` that
  the monitor never reads.
- [UVM TLM Analysis Port](https://www.chipverify.com/uvm/uvm-tlm-analysis-port), with a broadcast
  to three subscribers. Its log comes from UVM 1.1d, an older version than the course's library.
- [Using _decl macro in TLM](https://www.chipverify.com/uvm/using-decl-macro-in-tlm) builds a
  two-input scoreboard. Correction: it says the macro can't go inside a class because
  SystemVerilog doesn't allow nested classes; nested classes are legal, though package scope,
  where Lab 04 puts it, is still the right place.
- [UVM Scoreboard](https://www.chipverify.com/uvm/uvm-scoreboard) and
  [UVM Scoreboard Architecture](https://www.chipverify.com/uvm/uvm-scoreboard-architecture), for
  in-order and out-of-order comparison. The second page's examples skip the end-of-test checks
  its own text recommends.
- [UVM Subscriber](https://www.chipverify.com/uvm/uvm-subscriber). Its covergroup reads a class
  member, which Verilator 5.050 drops; write it `with function sample`.
