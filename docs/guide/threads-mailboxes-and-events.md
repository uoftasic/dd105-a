# Threads, mailboxes and events

This page answers: *a testbench has to drive, watch and check all at once. How do SystemVerilog
classes run side by side, and how do they hand packets to each other?*

Lab 02's environment runs seven objects at the same time: a generator, a driver, two monitors, two
sinks and a scoreboard. Each one's `run()` task is a separate **thread**, a piece of code that runs
alongside the others and waits for its own things, and they pass packets to each other through three
**mailboxes**. The scoreboard you'll write in
[Lab 02](../labs/lab-02-a-class-testbench-without-uvm-overview.md), Part 3 is two threads of its own,
one for each mailbox it reads. This page covers what that needs: `fork` and its three ways of
joining, mailboxes, events, and how to stop a thread you no longer want.

![Lab 02's environment: the generator and driver in thick boxes, the monitors, sinks and scoreboard in thin ones, and the mailboxes as labels on the arrows between them.](../assets/img/dd105-lab02-threads.svg){fig-alt="A block diagram. A generator box has an arrow labelled gen2drv to a driver box, which has an arrow labelled in to a dashed box labelled router (the design). The router's outputs out1 and out0 go to boxes labelled snk1 and snk0. A dot on the in arrow leads down to an in_mon box, and a dot on the out0 line leads down to an out0_mon box. Arrows labelled in2sb and out02sb lead from the two monitors to a scoreboard box at the bottom. The generator and driver have thick outlines; the note says thick boxes are started with fork...join and env.run() waits for both, and thin boxes with fork...join_none, running until the test ends."}

*Lab 02's environment, from `env.svh`. Each box is an object whose `run()` is one thread, and the
labels on the arrows between them are mailboxes.*

We ran every example on this page in the course image. The source is in
[`guide-examples/threads-mailboxes-and-events/`](https://github.com/uoftasic/dd105-a/tree/main/guide-examples/threads-mailboxes-and-events),
and its README gives the command for each output.

## fork and its three joins

`fork` starts each statement between it and its `join` as a thread of its own. The three kinds of
`join` differ only in how long the thread that ran the `fork`, the parent, waits before it goes on.
The example's `fork_test` forks the same three threads three times, each finishing 10, 20 and 30 ns
after it starts:

```systemverilog
fork
  #10 $display("%0d ns:   A finished", $time);
  #20 $display("%0d ns:   B finished", $time);
  #30 $display("%0d ns:   C finished", $time);
join            // then join_any, then join_none
```

```text
0 ns: fork...join
10 ns:   A finished
20 ns:   B finished
30 ns:   C finished
30 ns: the parent goes on after join
30 ns: fork...join_any
40 ns:   A finished
40 ns: the parent goes on after join_any
50 ns:   B finished
60 ns:   C finished
60 ns: wait fork returns
60 ns: fork...join_none
60 ns: the parent goes on after join_none
70 ns:   A finished
80 ns:   B finished
90 ns:   C finished
90 ns: wait fork returns
```

- `join` waits for every thread, so the parent went on at 30 ns, when the slowest finished.
- `join_any` waits for the first, so the parent went on at 40 ns, and B and C kept running and
  finished later. `join_any` doesn't stop the others.
- `join_none` doesn't wait at all, so the parent went on at 60 ns, the moment it forked them.
- `wait fork` waits until every thread the parent has forked so far has finished.

Lab 02's `env::run()` uses two of these. It starts the sinks, the monitors and the scoreboard with
`fork ... join_none`, because each of them is a `forever` loop that never finishes, and then starts
the generator and the driver with `fork ... join`, because the test is over when the driver has
sent every packet. After that it waits 50 cycles for the outputs to drain and calls the
scoreboard's `report()`. The `forever` threads are still running at that point, and they stop when
the simulation ends.

## Threads forked in a loop

A thread doesn't get its own copy of the variables it uses; it uses the same variables as the code
around it. That's what you want for a counter two threads share, and it's a trap when you fork a
thread in each pass of a loop. `capture_test` forks three threads that each print the loop variable
1 ns later, and then three that each print a copy of it made inside the loop:

```systemverilog
for (int i = 0; i < 3; i++)
  fork
    #1 $display("%0d ns:   i = %0d", $time, i);
  join_none
#5;
for (int i = 0; i < 3; i++) begin
  int j = i;
  fork
    #1 $display("%0d ns:   j = %0d", $time, j);
  join_none
end
```

```text
0 ns: three threads print the loop variable i
1 ns:   i = 3
1 ns:   i = 3
1 ns:   i = 3
5 ns: three threads print j, a copy made in each pass
6 ns:   j = 0
6 ns:   j = 1
6 ns:   j = 2
```

The three threads in the first loop share one `i`, and by the time they print it the loop has
finished and left it at 3. In the second loop, `j` is declared inside the loop body. This code is a
method of a class, and as [Classes for testbenches](../guide/classes-for-testbenches.md) said, a
method's local variables are automatic, so each pass through the body makes a new `j`, and each
thread keeps the one made in its own pass.

Outside a class, the same loop doesn't work. In a module's `initial` block, variables are static
unless you declare them `automatic`, so `int j = i;` there is one variable, set once before the
simulation starts:

```text
0 ns: in a module's initial block, int j = i
1 ns:   j = 0
1 ns:   j = 0
1 ns:   j = 0
5 ns: in a module's initial block, automatic int j = i
6 ns:   j = 0
6 ns:   j = 1
6 ns:   j = 2
```

Verilator does warn about this (`%Warning-IMPLICITSTATIC`, "The initializer value will only be set
once"), but `IMPLICITSTATIC` is one of the five warnings the labs' build turns off, so you'll only
see it from `make lint`. Write `automatic` whenever you declare a variable with an
initializer outside a class.

## Mailboxes

A mailbox carries values from threads that `put()` them to threads that `get()` them, in the order
they were put. `get()` waits while the mailbox is empty, and `put()` waits while it's full, if you
gave it a size. `mailbox_test` has a generator that makes four items as fast as it can and a driver
that takes 10 ns over each, joined by a `mailbox #(int)`, first with no limit and then with room for
one item:

```text
mailbox bound 0 (unbounded)
0 ns: gen put 0
0 ns: gen put 1
0 ns: gen put 2
0 ns: gen put 3
0 ns: gen has made all four
0 ns:   drv got 0
10 ns:   drv got 1
20 ns:   drv got 2
30 ns:   drv got 3
```

```text
mailbox bound 1
0 ns: gen put 0
0 ns:   drv got 0
0 ns: gen put 1
10 ns:   drv got 1
10 ns: gen put 2
20 ns:   drv got 2
20 ns: gen put 3
20 ns: gen has made all four
30 ns:   drv got 3
```

Unbounded, the generator made all four items at 0 ns and the driver worked through them. With room for one, each
`put()` waited until the driver had taken the item before it, so the generator kept pace with the
driver and finished at 20 ns. The driver got the same items at the same times both ways.

Lab 02's mailboxes are all unbounded (`gen2drv = new();`), so its generator makes every packet at
the start and the driver works through them. The monitors' mailboxes work the other way round: a
monitor puts a packet whenever one finishes on its stream, and the scoreboard's `get()` waits for
the next one. That's why the scoreboard has two threads. A thread waiting in `from_out0.get()`
can't take a packet from `from_in` at the same time, and the two mailboxes fill at their own pace,
so one thread predicts each input packet as it arrives and the other checks each packet from output
0 against the predictions made so far.

The `#(int)` gives the mailbox a type. Lab 02's are `mailbox #(packet)`, so what they carry is
handles to packets, and the receiving thread gets the same object the sender made, as [Classes for testbenches](../guide/classes-for-testbenches.md#the-same-object-kept-three-times)
showed with a queue.

## Events

An `event` is a signal from one thread to the others with no value attached: `->done` triggers it,
and any thread waiting for it goes on. There are two ways to wait, and they differ in what happens
when the trigger comes first. `event_test` triggers `done` at 10 ns and then, in the same time
step, starts one thread that waits with `@done` and another that waits with `wait (done.triggered)`:

```text
10 ns: ->done
10 ns:   wait (done.triggered) returns
30 ns: end of the demo
```

`@done` waits for the next time `done` is triggered, so a thread that gets there after the trigger,
even within the same time step, waits for one that never comes. `done.triggered` stays true for the
rest of the time step in which `done` was triggered, so `wait (done.triggered)` doesn't miss it. Use
`wait (e.triggered)` when the thread that waits might get there in the same time step as the one
that triggers.

## Stopping threads

`disable fork` ends every thread that the current thread has forked, and every thread those have
forked, that is still running. Its
common use is a wait with a time limit: fork the thing you're waiting for and a timer, `join_any`,
and kill whichever is left. The trap is the word *every*. `disable_test` starts a monitor, a
`forever` loop that counts 10 ns ticks, with `join_none`, and then waits with a time limit:

```systemverilog
task wait_with_timeout();
  fork
    #25  $display("%0d ns:   the thing we waited for happened", $time);
    #100 $display("%0d ns:   timeout", $time);
  join_any
  disable fork;
endtask
```

It runs this twice: once calling the task directly from the thread that started the monitor, and
once from a thread forked just for it (`fork wait_with_timeout(); join`). 50 ns after the wait each
time, it prints how many ticks the monitor has counted:

```text
25 ns:   the thing we waited for happened
75 ns: with a bare disable fork: the monitor has counted 2 ticks
100 ns:   the thing we waited for happened
150 ns: with the wait in its own fork: the monitor has counted 7 ticks
```

The first time, `disable fork` killed the timer and the monitor as well, because both were threads
that the same parent had forked; the monitor counted 2 ticks and then stopped. The second time, the
task ran in a thread of its own, the only threads that thread had forked were the two in the wait,
and the monitor counted on. In Lab 02's `env::run()`, the monitors and the scoreboard are forked from
the same thread that forks the driver, so a bare `disable fork` added there would stop them too.

## Check yourself

1. `env::run()` starts the monitors and the scoreboard with `fork ... join_none`. What would happen
   if it used `fork ... join` instead?

   <details>
   <summary>Answer</summary>

   Each of those threads is a `forever` loop, so a `join` would wait for ever. `env::run()` would
   never get to the generator and the driver, no packet would be sent, and the test would run
   until something stopped it from outside.

   </details>

2. You copy the second loop of `capture_test`, the one with `int j = i;` in its body, into a
   module's `initial` block. What does it print, and what one-word change fixes it?

   <details>
   <summary>Answer</summary>

   It prints `j = 0` three times. In an `initial` block, `j` is static: one variable, set to its
   initial value once, before the simulation starts, and never set by the loop. Declaring it
   `automatic int j = i;` makes a new `j` in each pass, and the threads print 0, 1 and 2.

   </details>

3. The generator puts four items into `mailbox #(int) mb = new(1)` and the driver takes 10 ns over
   each. When does the generator finish, and when would it finish with `new()`?

   <details>
   <summary>Answer</summary>

   At 20 ns with room for one item, because each `put()` waits for the driver to take the item
   before; at 0 ns with an unbounded mailbox. `mailbox_test` printed both.

   </details>

4. You put a time limit around the driver in `env::run()` with `fork ... join_any` and a bare
   `disable fork`. The test now reports `[SB] 0 packets in`. What happened?

   <details>
   <summary>Answer</summary>

   The `disable fork` ended every thread `env::run()` had forked, the monitors and the scoreboard
   included, which `disable_test` showed with its monitor. Put the timed wait in a `fork ... join`
   of its own, so that `disable fork` only reaches the threads inside it.

   </details>

## Further reading

ChipVerify covers threads and the classes that connect them in detail. Most of the logs on its
SystemVerilog pages come from Cadence simulators rather than Verilator, and the course doesn't
reuse its code.

- [Processes](https://chipverify.com/systemverilog/systemverilog-processes): a short overview of
  the chapter.
- [fork join](https://chipverify.com/systemverilog/systemverilog-fork-join),
  [fork join_any](https://chipverify.com/systemverilog/systemverilog-fork-join-any) and
  [fork join_none](https://chipverify.com/systemverilog/systemverilog-fork-join-none). The
  join_none page covers the loop-variable problem and its `automatic` fix.
- [wait fork](https://chipverify.com/systemverilog/systemverilog-wait-fork).
- [disable fork join](https://chipverify.com/systemverilog/systemverilog-disable-fork). It warns
  that `disable fork` reaches further than you might expect but doesn't show the fix above, the
  wait in a `fork ... join` of its own.
- [Mailbox](https://chipverify.com/systemverilog/systemverilog-mailbox): bounded and unbounded
  mailboxes, `try_put`, `try_get` and `peek`.
- [Event](https://chipverify.com/systemverilog/systemverilog-event): `@e` against `e.triggered`.
- [Semaphore](https://chipverify.com/systemverilog/systemverilog-semaphore): the third way threads
  coordinate, for sharing something only one of them may use at a time.

Next: [Lab 02: A class testbench without UVM](../labs/lab-02-a-class-testbench-without-uvm-overview.md).
