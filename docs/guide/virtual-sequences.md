# Virtual sequences

This page answers: *the routing table, the packets and the backpressure are each driven by a
different agent. How do you make them change together, from one place?*

Lab 04's tests did one thing at a time, from the test's `run_phase`: write the routing table, set
the sinks, send packets, drain, read `DROP_CNT`, and start again. Each step waited for the one
before it to finish. In [Lab 05, Part 4](../labs/lab-05-protocol-rules-and-backpressure-overview.md#part-4-a-virtual-sequence)
you'll want routes that move to the other output while packets are still going in, with both sinks
changing their behaviour at the same time. That's three agents doing things at once, in an order you
choose, and the UVM piece that does it is a **virtual sequence**: a sequence that starts other
sequences on several agents' sequencers, and changes their knobs, but makes no items of its own.

This page builds one on a small design of our own, a four-beat FIFO with a valid/ready stream on
each side, in
[`guide-examples/virtual-sequences/`](https://github.com/uoftasic/dd105-a/tree/main/guide-examples/virtual-sequences).
Two things drive the FIFO, and neither knows about the other: a source agent, whose sequences send
one beat per item, and a sink driver with a knob, `ready_pct`, in a configuration object. The sink
has no sequencer at all, which makes it a good stand-in for Lab 05's sinks: you steer it by
changing its configuration, not by sending it items.

## A sequencer that holds handles

A sequence runs on a sequencer, so a virtual sequence needs one too. A **virtual sequencer** is a
sequencer with no driver connected to it. It exists to hold handles to everything the virtual
sequence needs to reach:

```systemverilog
class vs_vsequencer extends uvm_sequencer;
  `uvm_component_utils(vs_vsequencer)
  uvm_sequencer #(src_item) src_sqr;   // the source agent's sequencer
  snk_cfg                   snk;       // the sink's knob
  vs_monitor                mon;       // what has come out, for the sequence to report
  virtual vs_if             vif;       // a clock to count cycles with
  ...
```

The environment makes it in `build_phase` like any other component, and fills in the handles in
`connect_phase`, after every agent exists. Lab 05's `router_vsequencer` holds the same kinds of
thing for the router: the source's and the APB agent's sequencers, both sinks' sequencers and
`out_cfg` objects, the scoreboard, and the APB interface.

![The example's testbench: one virtual sequence steering two drivers](../assets/img/virtual-sequence-handles.svg){width=720 fig-alt="A block diagram. On the left, a box labelled virtual sequence on the virtual sequencer. One line from it, labelled starts sequences, goes to the source sequencer, which passes items to the source driver, which drives in_valid and in_data into the FIFO. A second line, labelled writes the knob, goes to the sink's knob, ready_pct, which the sink driver reads each cycle; the sink driver drives out_ready into the FIFO. Below the FIFO, a monitor watches every beat in and out."}

*Our example's testbench. The virtual sequence reaches the source through its sequencer and the
sink through its configuration object, both by handles that the virtual sequencer holds. The
monitor checks every beat, whoever caused it.*

The virtual sequence gets at the virtual sequencer through `p_sequencer`, a handle of the right type
that this macro declares and fills in when the sequence starts:

```systemverilog
class vs_base_vseq extends uvm_sequence;
  `uvm_object_utils(vs_base_vseq)
  `uvm_declare_p_sequencer(vs_vsequencer)
  ...
  task send(int unsigned n, bit [7:0] base);   // n beats, through the source agent
    src_seq s = src_seq::type_id::create($sformatf("src_%h", base));
    s.n    = n;
    s.base = base;
    s.start(p_sequencer.src_sqr, this);
  endtask
  function void sink(int unsigned pct);        // the sink's readiness from now on
    p_sequencer.snk.ready_pct = pct;
    ...
```

`s.start(p_sequencer.src_sqr, this)` runs the source agent's own sequence on the source agent's
sequencer, as the test would, with the virtual sequence as its parent. `sink()` doesn't start
anything; it writes the knob, and the sink's driver reads the new value at its next clock edge.
Lab 05's `router_base_vseq` gives you a dozen tasks like these (`route()`, `ctrl()`, `burst()`,
`send_rand()`, `stall()`, `drain()` and more), which are the base test's steps from Lab 04,
rewritten as a sequence's tasks.

There is a second style, in which the test hands the virtual sequence its handles directly and
starts it with `start(null)`, with no virtual sequencer. It works as well. With a virtual
sequencer the handles are filled in once, by the environment, for every virtual sequence and every
test, and that's the style the labs use.

## Doing two things at once

The test starts our virtual sequence, `vs_demo_vseq`, on the virtual sequencer, and its first step
stalls the sink and sends six beats, while a second branch waits and then lets the sink go:

```systemverilog
sink(0);
fork
  begin
    send(6, 8'h10);
    `uvm_info("VSEQ", "step 1: all 6 beats have gone in", UVM_LOW)
  end
  begin
    cycles(15);
    `uvm_info("VSEQ", $sformatf("step 1: the FIFO holds %0d beats", p_sequencer.vif.level), UVM_LOW)
    sink(100);
  end
join
```

It printed:

```text
UVM_INFO guide-examples/virtual-sequences/vseq_tb.sv(218) @ 26000: uvm_test_top.env.vsqr@@v [VSEQ] sink ready 0% of cycles
UVM_INFO guide-examples/virtual-sequences/vseq_tb.sv(241) @ 175000: uvm_test_top.env.vsqr@@v [VSEQ] step 1: the FIFO holds 4 beats
UVM_INFO guide-examples/virtual-sequences/vseq_tb.sv(218) @ 175000: uvm_test_top.env.vsqr@@v [VSEQ] sink ready 100% of cycles
UVM_INFO guide-examples/virtual-sequences/vseq_tb.sv(237) @ 235000: uvm_test_top.env.vsqr@@v [VSEQ] step 1: all 6 beats have gone in
```

By 175 ns the FIFO was full, and `send()` was stuck with its fifth beat on the input, waiting for
`in_ready`. It could only return once the sink had taken some beats, and the sink would only take
beats once something set `ready_pct` again. Written as two statements one after the other, `send()`
then `sink(100)`, that's a deadlock: `send()` waits for the sink, and the line that releases the
sink waits for `send()` to return. With `fork ... join`, the two branches run at the same time, and
`join` waits for both, so the step ends at 235 ns, when the last beat has gone in.

The path in each message, `uvm_test_top.env.vsqr@@v`, says the report came from the sequence `v`
running on `env.vsqr`, which is how you tell a virtual sequence's messages from an agent's.

## A loop that ends with the traffic

The second step sends 30 beats while a second branch keeps changing the sink. The changing branch
doesn't know how long the traffic will take, so it loops until the traffic branch sets a flag:

```systemverilog
traffic_done = 0;
fork
  begin
    send(30, 8'h40);
    traffic_done = 1;
  end
  while (!traffic_done) begin
    sink(pick[$urandom_range(2)]);     // 0, 30 or 100 percent
    cycles($urandom_range(12, 4));
  end
join
```

The sink changed twelve times between 335 ns and 1415 ns, and the last beat went in at 1445 ns.
Lab 05's step 4 has this shape, with `backpressure()` as the looping branch and a third branch that
moves routes. If the traffic branch didn't set `traffic_done`, the loop would go on changing the
sink for ever, and `join`, which waits for both branches, would never return.

None of these sequences checks anything. The monitor checks every beat in every cycle, whatever is
driving the FIFO, and at the end of this run it said
`44 beats in, 44 out, 0 out of order`. The sequences make situations happen, and the checking is
left to the monitor here, and to the scoreboard and the assertions in the labs.

## Two sequences on one sequencer

The third step starts two source sequences at once, on the same sequencer, with four beats each,
numbered from `80` and from `a0`:

```systemverilog
fork
  send(4, 8'h80);
  send(4, 8'hA0);
join
```

and the beats came out of the FIFO as

```text
step 3: the sink took 80 a0 81 a1 82 a2 83 a3
```

A sequencer takes one item at a time from the sequences that are running on it. Each
`start_item()` is a request for the driver, and the sequencer grants them in turn, so the two
sequences alternated item by item. Sometimes that's exactly what you want, such as two traffic
streams mixed together. But it means that starting a sequence on a sequencer that already has one
running doesn't replace the first one; the two share the driver. Lab 05's sinks each run a sequence
that never ends, and Part 4 asks you why the virtual sequencer holds each sink's `out_cfg` and not
only its sequencer.

## Configuration changes and the scoreboard

A virtual sequence makes it easy to change the configuration while traffic is moving, and that
puts a new demand on the scoreboard: it has to apply each change from the right cycle. In Lab 04
the tests wrote the routing table only between phases, so the scoreboard could apply a write as soon
as it saw it. In Lab 05 a route can change between one header and the next, and the specification
says that a header accepted in the same cycle as the write completes still uses the old route.
Lab 05's scoreboard stamps each write with the cycle it completed in, and Part 4 asks you why it
uses the cycle rather than the order in which the two monitors report.

Where you create a sequence matters too, for a different reason. Making a sequence and starting it
both change the random values drawn after them (on Verilator 5.050, even in other threads), so a
sequence added at the start of a test changes every random choice made after it, even if the new
sequence does nothing. Lab 06,
Part 1 shows this on `router_test`, and Lab 07 puts its new sequence at the end of the test for
this reason. [Regressions and seeds](regressions-and-seeds.md) measures it.

## Check yourself

1. In step 1, the release could have gone in a branch that waits for the FIFO's level to reach 4,
   instead of waiting 15 cycles. Why can't it simply follow `send(6, 8'h10)` in the same branch?

   <details>
   <summary>Answer</summary>

   `send()` returns only when all six beats have gone into the FIFO, and the FIFO holds four. The
   fifth beat waits for `in_ready`, which comes back only when the sink takes a beat, and the sink
   takes beats only after `sink(100)`. In one branch, `sink(100)` would never be reached.

   </details>

2. What does `join` wait for in step 2, and what would happen if the traffic branch forgot to set
   `traffic_done`?

   <details>
   <summary>Answer</summary>

   For both branches to finish. Without the flag the backpressure loop never ends, so the
   virtual sequence never returns, the test never drops its objection, and the run goes on until
   something stops it from outside. In the course that is `make`'s run timeout, which grades the
   run BROKEN.

   </details>

3. You want the four beats from `80` to go in before the four from `a0`, with both sends still
   started by the virtual sequence. What do you change?

   <details>
   <summary>Answer</summary>

   Start them one after the other instead of in a `fork`: `send(4, 8'h80); send(4, 8'hA0);`. The
   second sequence then starts only when the first has returned.

   </details>

## Further reading

- [UVM Virtual Sequencer](https://www.chipverify.com/uvm/uvm-virtual-sequencer): declaring one,
  making it in the environment and filling in its handles in `connect_phase`. Its log was made from
  a different version of the code than the page shows, so the names in it don't match.
- [UVM Virtual Sequence](https://www.chipverify.com/uvm/uvm-virtual-sequence): both styles,
  `p_sequencer` and `start(null)`. Correction: two of its three code blocks create their child
  sequences in `pre_body()` and start them without a parent, which the page itself advises
  against.
- [UVM Sequence Arbitration](https://www.chipverify.com/uvm/uvm-sequence-arbitration): how a
  sequencer chooses between sequences that run on it at the same time, mode by mode, with logs.
- [UVM Lock & Grab](https://www.chipverify.com/uvm/uvm-lock-grab): how one sequence keeps a
  sequencer to itself.
- [How to execute sequences via start()](https://www.chipverify.com/uvm/how-to-execute-sequences-via-start-method).
  Its example test starts a sequence without raising an objection, which works only because that
  sequence takes no simulation time.

Next: [Lab 05: Protocol rules and backpressure](../labs/lab-05-protocol-rules-and-backpressure-overview.md).
