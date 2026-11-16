# From cocotb to SystemVerilog classes

This page answers: *I can write a cocotb test. What changes when the testbench is written in
SystemVerilog instead?*

A cocotb test and a SystemVerilog class testbench do the same three jobs, drive, observe and
decide, and most of the Python you wrote in DD104 has a direct SystemVerilog counterpart. The differences that matter are where the testbench runs, the fact that every value
has a fixed width, and the way a failed check is reported. This page goes through them with one
example, DD104's `t01` translated line by line. You'll read a full UVM testbench written in
SystemVerilog classes in [Lab 01](../labs/lab-01-one-alu-two-testbenches-overview.md), Part 3, and
write your own classes from Lab 02 on.

We ran every example on this page in the course image. The source is in
[`guide-examples/from-cocotb-to-systemverilog-classes/`](https://github.com/uoftasic/dd105-a/tree/main/guide-examples/from-cocotb-to-systemverilog-classes),
and its README gives the command for each output.

## Where the testbench runs

In DD104 your test was a Python program running beside the simulator. Icarus or Verilator ran the
design, cocotb reached into it through VPI, and the two took turns: every `await` handed control
back to the simulator until the thing you were waiting for happened.

A SystemVerilog testbench is part of the simulation. On Verilator that means it's translated into
C++ along with the design and compiled into one program, the simulator, which runs both. This has
three consequences you'll feel from the first lab:

- **Every change to the testbench is a rebuild.** Changing a Python test costs nothing before the
  next run. Changing a SystemVerilog class means running Verilator and g++ again, and with the UVM
  library in the build that takes from about 25 s to well over a minute.
  [What a framework buys you](../guide/what-a-framework-buys-you.md) has Lab 01's numbers.
- **Mistakes show up at two different times.** A type error, a misspelt name or a missing
  semicolon stops Verilator before anything runs, usually within a few seconds. Everything else
  shows up when the simulator runs. The labs give you `make lint`, which runs only the first stage,
  so you can find the first kind of mistake without waiting for a build.
- **What changes without a rebuild is decided when the simulator starts.** The test, the seed, the
  planted bug and the test's knobs are all arguments on the simulator's command line (`+UVM_TESTNAME`,
  `+verilator+seed+`, `+BUG` and plusargs), so trying another one takes a second or so and no rebuild.

## DD104's t01 in SystemVerilog

`cocotb/test_alu.py` in Lab 01 is DD104 Lab 03's reference test for SimProc's ALU. Its first test,
`t01`, checks one vector for each of the six operations. These are the parts that do the work:

```python
def spec(op, a, b):
    if op == ADD:
        out = (a + b) & 0xFF
    elif op == SUB:
        out = (a - b) & 0xFF
    ...
    return out, (out >> 7) & 1, int(out == 0)

async def alu(dut, op, a, b):
    dut.ALUop.value = op
    dut.A.value = a
    dut.B.value = b
    await Timer(1, unit="ns")
    return int(dut.ALUout.value), int(dut.N.value), int(dut.Z.value)
```

and, in the test itself, for each of the six cases:

```python
got = await alu(dut, op, a, b)
want = spec(op, a, b)
assert got == want, (
    f"{OPS[op]}(0x{a:02X}, 0x{b:02X}) gave out=0x{got[0]:02X} "
    f"N={got[1]} Z={got[2]}, expected out=0x{want[0]:02X} "
    f"N={want[1]} Z={want[2]}")
```

Here is the same test as one SystemVerilog class, `alu_t01`. `spec()` becomes a function called
`predict()`, and the tuple it returns becomes a packed struct:

```systemverilog
typedef enum bit [2:0] {ADD, SUB, OR, NAND, SHL, SHR} alu_op_e;

typedef struct packed {
  bit [7:0] out;
  bit       n;
  bit       z;
} alu_result_t;

function alu_result_t predict(alu_op_e op, bit [7:0] a, bit [7:0] b);
  alu_result_t r;
  case (op)
    ADD:     r.out = a + b;
    SUB:     r.out = a - b;
    ...
  endcase
  r.n = r.out[7];
  r.z = (r.out == 8'h00);
  return r;
endfunction
```

The coroutine `alu()` becomes a task, which is the kind of routine that's allowed to wait:

```systemverilog
task drive_and_read(alu_op_e op, bit [7:0] a, bit [7:0] b, output alu_result_t got);
  vif.ALUop = op;
  vif.A     = a;
  vif.B     = b;
  #1;
  got = '{vif.ALUout, vif.N, vif.Z};
endtask
```

and the `assert` becomes an `if` with an `$error`, which takes a format string the way `$display`
does:

```systemverilog
drive_and_read(ops[i], as[i], bs[i], got);
want = predict(ops[i], as[i], bs[i]);
if (got != want)
  $error("%s(0x%02X, 0x%02X) gave out=0x%02X N=%0d Z=%0d, expected out=0x%02X N=%0d Z=%0d",
         ops[i].name(), as[i], bs[i], got.out, got.n, got.z, want.out, want.n, want.z);
```

Most lines translate one for one. The differences are these:

- **Every argument and every variable has a type.** `op` is an `alu_op_e`, an enum, and
  `ops[i].name()` gives back the name of its value as a string, `"SUB"`, which does the job of the
  `OPS` dictionary in the Python.
- **`& 0xFF` is gone.** `r.out` is 8 bits wide, so a sum that comes to 260 wraps to 4 as it's
  stored, the way the ALU's own adder wraps. The next section says when that helps you and when it
  doesn't.
- **The class can't name the design's pins.** cocotb hands your test the design as `dut`. A
  SystemVerilog class lives in a package, outside the module hierarchy, so it reaches the pins
  through `vif`, a *virtual interface*: a handle to an interface instance that the top module
  connects to the ALU. The task writes the pins directly, as `alu()` does, because the ALU has no
  clock to time the writes against. From Lab 01 on, every driver writes through a clocking block
  instead, which [Interfaces, clocking blocks and virtual interfaces](../guide/interfaces-clocking-blocks-and-virtual-interfaces.md)
  explains.
- **`await Timer(1, unit="ns")` becomes `#1`.** The unit comes from the time unit the code is
  compiled with. The example's Makefile sets 1 ns, as every lab's does.
- **A task can wait and a function can't.** `predict()` takes no simulated time, so it's a
  function. `drive_and_read()` waits 1 ns, so it has to be a task;
  [Classes for testbenches](../guide/classes-for-testbenches.md) shows the error you get if you try
  it in a function.

On the correct ALU the class checks its six vectors and prints its summary line:

```text
t01: 6 directed vectors checked
```

With bug A01 switched on, where `SUB` computes `B - A`, it stops at the second vector:

```text
[2000] %Error: alu_t01_pkg.sv:62: Assertion failed in alu_t01_pkg.alu_t01.t01_one_vector_per_operation.unnamedblk1: SUB(0xc8, 0x3c) gave out=0x74 N=0 Z=0, expected out=0x8c N=1 Z=0
%Error: guide-examples/from-cocotb-to-systemverilog-classes/alu_t01_pkg.sv:62: Verilog $stop
Aborting...
```

The message is the cocotb test's message, with three differences worth knowing about before you
read your first SystemVerilog log:

- `[2000]` is the simulated time, in the simulation's precision of 1 ps, so this is 2 ns: the
  second vector, one nanosecond each. The file, line and enclosing routine come before your text.
- The hex digits are lower case. In Python `X` asks for upper-case digits, but SystemVerilog's
  `%X` means the same as `%x`, and Verilator printed lower case.
- The run stopped. A failed `assert` in cocotb ends that test, and cocotb moves on to the next one.
  Verilator's default is to stop the whole simulation at the first `$error`, which is why there's no
  summary line after it. [Lab 02](../labs/lab-02-a-class-testbench-without-uvm-overview.md), Part 3
  adds `+verilator+error+limit+100` to every run so that a scoreboard can report more than one
  mismatch.

In a UVM testbench you report with `` `uvm_error `` instead, as Lab 01's scoreboard does. That goes
through UVM's report server, which counts the errors by ID and keeps the run going.

## Widths

Python integers have no width, which is why `spec()` has to mask every result with `& 0xFF`. In
SystemVerilog every value has a width, and the width of an expression is decided by where its
result goes. The example adds `a = 200` and `b = 60`, both `bit [7:0]`, in three places:

```systemverilog
sum8 = a + b;               // sum8 is bit [7:0]
sum9 = a + b;               // sum9 is bit [8:0]
$display("%0d", a + b);
```

and prints:

```text
sum8 = a + b      -> 4
sum9 = a + b      -> 260
$display(a + b)   -> 4
```

The two assignments run the same expression and get different answers. In an assignment the
operands are widened to the width of the left-hand side before the addition, so `sum9` keeps the
carry. Inside `$display` the expression has nothing to take its width from, so it's computed at
the width of its widest operand, 8 bits, and the carry is gone. That's the standard's rule, not
anything peculiar to Verilator, and it's why `predict()` gets the ALU's wrap-around for free. It's
also how a model loses a carry it was meant to keep, so when a scoreboard reports mismatches only on
results that overflow, check the widths in the model before you blame the design.

DD104 also taught you that Verilator has two states, 0 and 1, and no X. That still holds in a
SystemVerilog testbench, whether you declare a variable `bit` or `logic`.

## Strings

A string literal in SystemVerilog is a number, a packed array of 8-bit characters, until something
makes it a `string`. Most of the time you won't notice, but a conditional between two literals of
different lengths is one place you will. The example prints the same thing two ways:

```systemverilog
$display("[%0d beat%s]", n, n == 1 ? "" : "s");
$display("[%0d beat%s]", n, n == 1 ? string'("") : string'("s"));
```

```text
[1 beat ]
[1 beat]
```

In the first line the `?:` has two numbers of different widths, so the empty literal is padded to
the width of `"s"`, and the padding prints as a space. Casting both sides to `string` keeps them
strings. That's why Lab 02's `packet::sprint()` writes `string'("")` and `string'("s")`.

## Python and SystemVerilog side by side

| In cocotb and Python | In a SystemVerilog testbench |
|---|---|
| `class Packet:` with `__init__(self, ...)` | `class packet;` with `function new(...)` |
| `self.x` | `this.x`, or just `x` |
| `None` | `null` |
| a variable holding an object (a reference) | a handle; [Classes for testbenches](../guide/classes-for-testbenches.md) |
| `def f(...)` | `function`, which can't wait |
| `async def f(...)` | `task`, which can |
| `await Timer(1, unit="ns")` | `#1` |
| `await RisingEdge(dut.clk)` | `@(posedge clk)`, or `@(vif.cb)` through a clocking block |
| `dut.A.value = 5` | `vif.cb.A <= 5` through a clocking block, from Lab 01 on |
| `cocotb.start_soon(coro())` | `fork coro(); join_none` |
| `await First(a, b)` | `fork ... join_any` |
| `cocotb.triggers.Event` | `event`, with `->e` and `@e` |
| a `cocotb.queue.Queue` between coroutines | a `mailbox` |
| a list, with `append` and `pop(0)` | a queue, `int q[$]`, with `push_back` and `pop_front` |
| a dict | an associative array, `int counts[string]` |
| a tuple | a packed struct |
| `f"0x{a:02X}"` | `$sformatf("0x%02X", a)` |
| `assert got == want, "message"` | `if (got != want) $error("message")`, or `` `uvm_error `` in UVM |
| `random.randint(0, 255)` | `$urandom_range(255, 0)`, or `randomize()` with constraints from Lab 03 |
| the `@cocotb.test()` functions in a module | UVM test classes, one chosen per run by `+UVM_TESTNAME=` |

The rows about threads, events and mailboxes are the subject of
[Threads, mailboxes and events](../guide/threads-mailboxes-and-events.md).

## Check yourself

1. `spec()` masks every result with `& 0xFF` and `predict()` doesn't. Why not, and in what kind of
   expression could a SystemVerilog model still lose a carry it needed?

   <details>
   <summary>Answer</summary>

   `r.out` is 8 bits wide, so a result is cut to 8 bits as it's stored, the way the ALU's adder
   cuts it. A carry goes missing when an expression is computed at the width of its operands with
   nothing wider to take its width from, as `a + b` was inside `$display`, or when you store it in a
   variable that's too narrow, as `sum8` was. Stored in a 9-bit variable, the same sum kept its
   carry.

   </details>

2. Your SystemVerilog check prints one `%Error` line, then `Verilog $stop` and `Aborting...`, and
   nothing after them. Is the rest of the test passing?

   <details>
   <summary>Answer</summary>

   You can't tell, because nothing after the first error ran. Verilator stops a simulation at its
   first `$error` unless the run raises the limit with `+verilator+error+limit+N`, so the vectors
   after that one were never checked. In cocotb only the failing test would have stopped.

   </details>

3. Why is `drive_and_read()` a task, while `predict()` can be a function?

   <details>
   <summary>Answer</summary>

   `drive_and_read()` waits 1 ns for the ALU to answer, and only a task may contain a delay or wait
   for an event. `predict()` computes its answer in zero time, so a function is enough.

   </details>

## Further reading

ChipVerify's SystemVerilog pages cover each of these language features at more length. Most of
their logs come from Cadence simulators rather than Verilator, and the course doesn't reuse their
code, but the explanations apply.

- [Testbench Evolution](https://chipverify.com/verification/testbench-evolution): six styles of
  testbench, from a linear one to UVM. Your DD104 suites sit near the end of that list.
- [bit, byte and int](https://chipverify.com/systemverilog/systemverilog-data-types-integer-byte):
  the 2-state integer types.
- [Strings](https://chipverify.com/systemverilog/systemverilog-strings).
- [Enumeration](https://chipverify.com/systemverilog/systemverilog-enumeration).
- [Structure](https://chipverify.com/systemverilog/systemverilog-struct).
- [Queue](https://chipverify.com/systemverilog/systemverilog-queue) and
  [Associative Array](https://chipverify.com/systemverilog/systemverilog-associative-array).
- [Class vs Struct](https://chipverify.com/systemverilog/systemverilog-class-vs-struct): why
  assigning a class copies a handle and assigning a struct copies the value.
- [Testbench Example Adder](https://chipverify.com/systemverilog/systemverilog-testbench-example-adder):
  a class testbench without UVM, for a design much like the ALU. Correction: its "buggy design"
  listing is the same as the correct one, so the bug it describes isn't in the code shown.

Next: [Lab 01: One ALU, two testbenches](../labs/lab-01-one-alu-two-testbenches-overview.md).
