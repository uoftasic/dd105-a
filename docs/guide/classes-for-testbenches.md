# Classes for testbenches

This page answers: *what does a class give a testbench that a module doesn't, and what do I need to
know about handles before I write a monitor and a scoreboard?*

Lab 01's UVM testbench was made of classes, and you read them without writing any. In
[Lab 02](../labs/lab-02-a-class-testbench-without-uvm-overview.md) you'll write two, a monitor and a
scoreboard for the router, as plain SystemVerilog classes with no UVM in them. This page covers the
parts of classes those two need: objects made while the simulation runs, the handles that point at
them, functions and tasks, static members, and inheritance with virtual methods, which is how Lab 01's
tests shared one `run_phase`.

We ran every example on this page in the course image. The source is in
[`guide-examples/classes-for-testbenches/`](https://github.com/uoftasic/dd105-a/tree/main/guide-examples/classes-for-testbenches),
and its README gives the command for each output.

## Modules and classes

A module is hardware. Its instances are fixed when the design is elaborated, before simulated time
starts, and each one exists for the whole run. That suits a design, and it suits the top module of a
testbench, which holds the clock, the interfaces and the design under test.

A class is a type, and the things made from it, **objects**, are created while the simulation runs,
as many as you need. That suits most of a testbench. Lab 02's generator makes one `packet` object
for each packet it sends, 100 of them by default, and your monitor will make one for each packet it
sees on a stream. A transaction like that has no fixed place in the hardware; it exists from the
moment something makes it until nothing refers to it any more.

The classes of a testbench live in a package. Lab 02's `router_tb_pkg.sv` is a list of `` `include ``
lines for `packet.svh`, `generator.svh` and the rest, so any file that imports the package can use
every class in them.

## A class

This is the class the examples use, a smaller version of Lab 02's `packet`:

```systemverilog
class pkt;
  static int unsigned n_made;   // one variable, shared by every pkt
  int unsigned        id;       // one per object
  bit [7:0]           data[$];

  function new();
    id = n_made;
    n_made++;
  endfunction

  function string sprint();
    string s;
    s = $sformatf("pkt %0d:", id);
    foreach (data[i]) s = {s, $sformatf(" %02h", data[i])};
    return s;
  endfunction
endclass
```

It has three **members** (`n_made`, `id` and `data`, a queue of bytes) and two **methods**. `new()`
is the constructor, which runs once for each object when it's made. Constructors can take
arguments, and in Lab 02 they're how the pieces are wired together: `env::new()` makes three
mailboxes and passes each one to the constructors of the two classes that use it, and every class
that touches the pins gets its virtual interface the same way. When an argument has the same name as
a member, `this.vif = vif` says which is which, as Python's `self.vif = vif` does.

## Handles

`pkt a;` doesn't make a packet. It declares a **handle**, a variable that can point at a `pkt`
object, and until something is assigned to it, it points at nothing: its value is `null`. `new()`
makes the object and returns a handle to it. From there, assigning a handle copies the handle, not
the object. The example's `handles_test` does this:

```systemverilog
pkt a, b, c;
$display("a is %s", a == null ? string'("null") : string'("an object"));
a = new();
a.data = '{8'h80, 8'h11};
b = a;
b.data.push_back(8'h22);
c = new a;
c.data.push_back(8'h33);
```

and prints:

```text
a is null
a: pkt 0: 80 11 22
b: pkt 0: 80 11 22
c: pkt 0: 80 11 22 33
a == b is 1, a == c is 0, pkt::n_made is 1
```

![Left: handles a and b point at one pkt object and c at a copy of it. Right: a queue of three handles that all point at one reused pkt, and a queue of three handles that point at three different pkts.](../assets/img/dd105-handles.svg){fig-alt="Two drawings. On the left, small squares labelled a and b both have arrows to one box reading pkt 0: 80 11 22, and a square labelled c has an arrow to a separate box reading pkt 0: 80 11 22 33. On the right, under kept_once, three squares labelled [0], [1] and [2] all have arrows to one box reading pkt 0: 02 a2. Under kept_new, three squares labelled [0], [1] and [2] each have an arrow to its own box: pkt 1: 00 a0, pkt 2: 01 a1 and pkt 3: 02 a2."}

*The objects that `handles_test` and `reuse_test` leave behind, with the values they printed.*

`b = a` gave the one object a second name, so the byte pushed through `b` shows up through `a`.
`a == b` compares handles, and it's 1 because they point at the same object. Two objects with the
same contents would compare unequal, which is why Lab 02's `packet` has a `same()` method that
compares the beats one by one.

`c = new a` is different: it makes a new object and copies every member of `a` into it, so `c` has
its own queue, and the byte pushed onto it doesn't appear in `a`. It's a *shallow* copy, though. The
copy doesn't run the constructor, so `c` kept `a`'s `id` of 0 and `n_made` stayed at 1, and if `pkt`
had a member that was itself a handle, the copy would get the handle and the two objects would share
whatever it pointed at.

You won't often copy objects in the labs, but you'll pass handles around all the time, and each
place that keeps one keeps the same object. That makes the next example the class bug you're most
likely to write in Lab 02.

## The same object kept three times

`reuse_test` is two monitors in miniature. Each sees the same three two-byte packets go by and keeps
them in a queue, the way Lab 02's scoreboard keeps the packets it expects. The first makes one `pkt`
and reuses it for every packet; the second makes a new one each time:

```systemverilog
p = new();
for (int k = 0; k < 3; k++) begin
  p.data.delete();
  p.data.push_back(8'(k));
  p.data.push_back(8'hA0 + 8'(k));
  kept_once.push_back(p);
end

for (int k = 0; k < 3; k++) begin
  p = new();
  p.data.push_back(8'(k));
  p.data.push_back(8'hA0 + 8'(k));
  kept_new.push_back(p);
end
```

```text
one pkt, reused:   [0] pkt 0: 02 a2
one pkt, reused:   [1] pkt 0: 02 a2
one pkt, reused:   [2] pkt 0: 02 a2
a new pkt each:    [0] pkt 1: 00 a0
a new pkt each:    [1] pkt 2: 01 a1
a new pkt each:    [2] pkt 3: 02 a2
```

The first queue holds three handles to one object, so it holds the last packet three times, and the
first two packets are gone. A mailbox behaves the same way, because what goes into it is a handle.
That's why the `TODO` in Lab 02's `monitor.svh` has you start a new packet when `p` is null and set
`p = null` once you've put a finished one into the mailbox: the next packet then gets an object of
its own, and the scoreboard keeps the one it was given.

## Null handles

Use a handle before it points at anything and the run stops. `null_test` declares `pkt p;`, prints
a line, and then asks for `p.data.size()`. This is everything after the test's start in its log:

```text
%Error: guide-examples/classes-for-testbenches/classes_demo_pkg.sv:112: Null pointer dereferenced
Aborting...
```

The file and line are where the null handle was used. Nothing after that line ran, not even UVM's
report summary, so the labs' graders call the run BROKEN rather than caught. The line the test
printed just before it isn't in the log either, so when a run aborts, look at the line the error
names rather than at the last thing that was printed. In Lab 02 you'll see this error if your
monitor pushes a beat onto `p.data` before it has made `p`.

## Functions and tasks

A class has two kinds of method. A **function** runs in zero simulated time and can return a value;
`sprint()` and Lab 02's `packet::same()` are functions. A **task** may wait, for a clock edge with
`@`, for a delay with `#`, or for a mailbox to have something in it, so anything that follows the
simulation through time is a task: the monitor's `run()`, the driver's `run()`, and the scoreboard's
`run()`, which waits on two mailboxes.

Verilator checks this before it builds anything. A function with `#10;` in it stops `make lint`:

```text
%Error-FUNCTIMECTL: guide-examples/classes-for-testbenches/classes_demo_pkg.sv:120:5: Functions cannot contain time-controlling statements (IEEE 1800-2023 13.4)
```

Methods of a class are *automatic*: each call gets its own copy of the method's local variables.
That's what lets two threads run the same task at the same time without disturbing each other, and
[Threads, mailboxes and events](../guide/threads-mailboxes-and-events.md) shows where it matters.

## Static members

A `static` member belongs to the class rather than to any one object, so there's one `n_made`
however many packets exist, and code outside the class reads it as `pkt::n_made`. Counters like this
one, which number objects as they're made, are the usual use. Everything that isn't static, `id` and
`data` here, exists once per object.

## Inheritance and virtual methods

A class can **extend** another, inheriting all its members and methods and replacing the ones it
wants to. `dispatch_test` has a base class whose `run()` calls two methods, one declared `virtual`
and one not, and a class that overrides both:

```systemverilog
class base_test;
  function string name();
    return "base_test";
  endfunction
  virtual task stimulus();
    $display("  stimulus() of base_test: no stimulus");
  endtask
  task run();
    $display("run() of %s", name());
    stimulus();
  endtask
endclass

class rand_test extends base_test;
  function string name();
    return "rand_test";
  endfunction
  virtual task stimulus();
    $display("  stimulus() of rand_test: 2000 random vectors");
  endtask
endclass
```

It makes one `rand_test` object and calls `run()` on it twice, once through a `base_test` handle and
once through a `rand_test` handle:

```text
through a base_test handle:
run() of base_test
  stimulus() of rand_test: 2000 random vectors
through a rand_test handle:
run() of base_test
  stimulus() of rand_test: 2000 random vectors
```

`run()` is defined only in `base_test`, so both calls run that code. Inside it, the call to
`stimulus()` went to `rand_test`'s version, because `stimulus()` is virtual, and a virtual call goes
to the method of the object's own class, whatever kind of handle you reached it through. The call
to `name()` went to `base_test`'s version both times, even though the object is a `rand_test`,
because a call to a method that isn't virtual is fixed at compile time by the class the code is
written in.

This is how Lab 01's two tests share their run phase. `alu_base_test::run_phase()` raises an
objection, calls `stimulus()`, waits three cycles and drops the objection; `stimulus()` is a
virtual task that `alu_rand_test` and `alu_directed_test` each override with the sequence they
start. UVM depends on the same mechanism: `build_phase`, `run_phase` and the other phase methods are
declared virtual in the library, so when UVM calls them on your components it gets your versions.

A method that overrides another can still call the one it replaced, as `super.build_phase(phase)`.
Lab 01's `alu_base_test::build_phase()` starts that way, and it matters, because the parent's
version is `dd105_base_test`'s, which checks that the constraint solver works. If you leave the
`super` call out, the check doesn't run, and nothing reports that it didn't.

## Check yourself

1. A scoreboard reports that every packet it expected has the same beats, which are the last
   packet's. Its monitor makes `p = new()` once, in its constructor. What's wrong, and what's the
   fix?

   <details>
   <summary>Answer</summary>

   The monitor puts the same object into the mailbox for every packet and refills it each time,
   so every handle the scoreboard kept points at one object, which holds whatever was written into
   it last. Make a new `packet` for each packet the monitor sees, and stop using the old one once
   it's in the mailbox, which is what setting `p = null` after the `put()` does.

   </details>

2. In `dispatch_test`, the call through the `rand_test` handle still printed `run() of base_test`.
   Why, and what would it print if `name()` were declared `virtual`?

   <details>
   <summary>Answer</summary>

   `run()` is `base_test`'s code, and inside it the call to `name()`, which isn't virtual, was bound
   to `base_test::name()` when the class was compiled. The handle's type doesn't come into it. If
   `name()` were virtual, the call would go to the object's own class, and both lines would read
   `run() of rand_test`.

   </details>

3. After `c = new a`, `c.id` is 0, the same as `a.id`, and `pkt::n_made` is still 1. Why didn't the
   copy get a new number?

   <details>
   <summary>Answer</summary>

   `new a` copies the members of `a` into a new object without calling the constructor, and the
   constructor is the only code that numbers objects. If a copy needs its own number, give `pkt` a
   copy method of its own that makes the object with `new()` and then copies the data.

   </details>

4. Which of these has to be a task: the monitor's `run()`, `packet::sprint()`, the scoreboard's
   `predict()`?

   <details>
   <summary>Answer</summary>

   Only the monitor's `run()`, which waits for clock edges. `sprint()` builds a string and
   `predict()` decides where a packet goes, both in zero time, so they're functions, as Lab 02 ships
   them.

   </details>

## Further reading

ChipVerify has a page for each class feature, most with a complete example. Most of the logs on its
SystemVerilog pages come from Cadence simulators rather than Verilator, and the course doesn't
reuse its code.

- [Class](https://chipverify.com/systemverilog/systemverilog-class) and
  [Class Handle](https://chipverify.com/systemverilog/systemverilog-class-handle-object): objects,
  handles, `null`, and two handles to one object.
- [Class Constructor](https://chipverify.com/systemverilog/systemverilog-class-constructor):
  `new()`, default arguments, and `super.new()`.
- [Copying Objects](https://chipverify.com/systemverilog/systemverilog-copying-objects): shallow
  copies with `new`, and deep copies written by hand.
- [Static Variables & Functions](https://chipverify.com/systemverilog/systemverilog-static-variables-functions).
- [Inheritance](https://chipverify.com/systemverilog/systemverilog-inheritance),
  [Virtual Methods](https://chipverify.com/systemverilog/systemverilog-virtual-methods) and
  [super Keyword](https://chipverify.com/systemverilog/systemverilog-super). The Virtual Methods page
  runs the same code with and without `virtual`, as `dispatch_test` does.
- [Polymorphism](https://chipverify.com/systemverilog/systemverilog-polymorphism): base handles
  to derived objects, and `$cast`. Correction: it says a failed `$cast` returns 0 and simulation
  goes on. That's true only when `$cast` is called as a function; called as a task, a failed cast
  is a run-time error, as the page's own log shows.
  [Cast Dynamic](https://chipverify.com/systemverilog/systemverilog-dynamic-cast) gets this right.

Next: [Interfaces, clocking blocks and virtual interfaces](../guide/interfaces-clocking-blocks-and-virtual-interfaces.md).
