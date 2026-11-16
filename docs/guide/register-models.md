# Register models

This page answers: *what does a UVM register model know about a design's registers, and what does
it do for you that raw bus transfers don't?*

Up to the end of Lab 05, your testbench reached the router's registers with raw APB transfers:
`wr(A_ROUTE0, ...)` to set up a route, `rd(A_DROP_CNT)` to read the counters. The scoreboard
checked one register, `DROP_CNT`, and nothing ever read `ID`, `CTRL`, `STATUS`, `INT_EN` or a
`ROUTE` register. So nothing could notice a register that reset to the wrong value, or one that
read back with its fields swapped, and your Lab 05 testbench misses all five of Lab 06's planted
bugs. In [Lab 06](../labs/lab-06-the-register-block-overview.md) you'll give the testbench a
**register model**, a set of UVM classes that describes every register and field the way the
specification's [Register map](../reference/router-spec.md#register-map) does, and that knows how
to turn "write 1 to `CTRL.EN`" into a bus transfer.

This page explains how the pieces fit together, on a small register block of our own in
[`guide-examples/register-models/`](https://github.com/uoftasic/dd105-a/tree/main/guide-examples/register-models).
The [UVM register layer](../reference/register-layer.md) reference page has the arguments,
policies and messages you'll look up while you work.

## The example block

`regblk` has four 16-bit registers on a simple bus. A transfer is one cycle with `sel` = 1; the
block answers in the same cycle, and a write takes effect at the rising edge that ends it.

| Address | Register | Access | Fields |
|---|---|---|---|
| `0x0` | `ID` | RO | [15:0], reads `105A` |
| `0x4` | `CTRL` | RW | [0] `EN`, [3:1] `MODE`; resets to 0 |
| `0x8` | `FLAGS` | W1C | [0] `OVF`, [1] `ERR`; set by the design when an event happens |
| `0xC` | `COUNT` | RO | [7:0], the number of events since reset |

`CTRL` is the kind of register that software owns: it changes only when someone writes it. `FLAGS`
and `COUNT` change on their own, when the design sees an event. A register model handles the two
kinds differently, as most of the sections below show.

## Fields, registers and the map

Each register is a class with a `build()` that makes its fields and configures each one:

```systemverilog
virtual function void build();
  en   = uvm_reg_field::type_id::create("en");
  mode = uvm_reg_field::type_id::create("mode");
  en.configure  (this, 1, 0, "RW", 0, 0, 1, 1, 0);
  mode.configure(this, 3, 1, "RW", 0, 0, 1, 1, 0);
endfunction
```

The arguments after `this` are the field's width, its lowest bit, its access policy, whether it's
**volatile** (changed by the design on its own), its reset value, whether it has one, whether
`randomize()` may choose it, and whether it's alone in its register. `FLAGS.OVF` is configured as
`"W1C"` with volatile set to 1, and `COUNT` as `"RO"`, volatile. The register block makes the four
registers and puts each at its address in a map:

```systemverilog
default_map = create_map("map", 0, 2, UVM_LITTLE_ENDIAN, 1);   // 2 bytes per register
default_map.add_reg(id,    'h0, "RO");
default_map.add_reg(ctrl,  'h4, "RW");
default_map.add_reg(flags, 'h8, "RW");
default_map.add_reg(count, 'hC, "RO");
```

For every field, the model keeps two values. The **mirror** is what the model believes the design
holds right now. The **desired** value is what the testbench last asked for. Most of what a register
model does for you comes from comparing those two with what the design returns when you read it.

## From a register operation to a transfer

A test calls `regs.ctrl.write(status, 'h0005)`. The model looks up `CTRL` in the map, finds its
address, and hands an abstract operation (a write of `0005` to address `4`) to an **adapter**. The
adapter's `reg2bus()` turns that operation into your bus agent's item, and the map starts it on the
agent's sequencer, so it goes through the same driver as every other transfer. When the driver has
finished, the adapter's `bus2reg()` turns the item back into an operation, with the read data and a
status: `UVM_IS_OK`, or `UVM_NOT_OK` if the bus reported an error. Those two functions are the only
code in the register layer that knows what your bus looks like. In Lab 06, Part 2 you'll write them
for the router's APB agent.

![The register model and the two ways its mirror can follow the design](../assets/img/register-model-paths.svg){width=720 fig-alt="A block diagram. On the left, the register model, with a mirror and a desired value for each field. An arrow labelled write and read goes from it to the map, from the map to the adapter's reg2bus, and from there to the bus agent's sequencer and driver, which drive the bus into the design. A second path, labelled raw sequence, goes straight to the sequencer without passing through the model. The bus agent's monitor watches the bus and sends every transfer it sees to a predictor, which calls bus2reg and updates the mirror. A dashed arrow labelled auto-predict runs from the adapter back to the mirror, for the model's own operations only."}

## Auto-predict and the predictor

The model's mirror changes only when something tells the model about a transfer, and there are two
ways to do that. With **auto-predict** on (`set_auto_predict(1)` on the map), the model updates the
mirror after each operation it sends itself. A **predictor** (`uvm_reg_predictor`) is connected to
the bus monitor's analysis port instead, and updates the mirror after every transfer the monitor
sees, whoever started it.

Our example's `reg_mirror_test` makes the difference visible. It writes `0005` to `CTRL` through the
model, then writes `000b` with a raw bus sequence that goes around the model, the way Lab 04's
`wr()` does, and then calls `regs.ctrl.mirror(status, UVM_CHECK)`, which reads `CTRL` and compares
the value with the mirror. We ran it three ways, with `+PREDICT=` choosing how the mirror is kept:

| `+PREDICT=` | Mirror after the model's write | After the raw write | `mirror(UVM_CHECK)` |
|---|---|---|---|
| `predictor` | `0005` | `000b` | passes |
| `auto` | `0005` | `0005` | `UVM_ERROR` |
| `none` | `0000` | `0000` | `UVM_ERROR` |

With auto-predict, the error was:

```text
UVM_ERROR third_party/uvm/src/reg/uvm_reg.svh(2812) @ 95000: reporter [RegModel] Register "regs.CTRL" value read from DUT (0x000000000000000b) does not match mirrored value (0x0000000000000005) (valid bit mask = 0x000000000000000f)
UVM_INFO third_party/uvm/src/reg/uvm_reg.svh(2833) @ 95000: reporter [RegModel] Field mode (regs.CTRL[3:1]) mismatch read=3'h5 mirrored=3'h2
```

The design was right and the mirror was out of date, because auto-predict never saw the raw write.
Neither line points to a design bug, and both would show up on a golden design. A check that fails on
the golden design means the testbench is wrong, and here the missing piece is a predictor, which
the labs connect to the monitor that the scoreboard already listens to. The valid bit mask has a 1
for each bit that was compared, which here is all four bits of `CTRL`'s two fields.

## Volatile fields

`FLAGS` is set by the design, so the model can't know its value until it reads it. The test makes
the design set `FLAGS.OVF` and then looks at the mirror:

```text
UVM_INFO guide-examples/register-models/regblk_tb.sv(366) @ 125000: uvm_test_top [RAL] after an overflow event, the mirror of FLAGS is 0000
UVM_INFO guide-examples/register-models/regblk_tb.sv(368) @ 145000: uvm_test_top [RAL] after mirror(UVM_CHECK) reads FLAGS, the mirror is 0001
```

The mirror said `0000` while the design held `0001`, and `mirror(UVM_CHECK)` reported no error,
because the register layer never compares a volatile field when it reads one. It just takes the
value it read. UVM also warns you when you ask for a volatile field's mirror, with
`[UVM/FLD/GET_MIRRORED_VAL/VOL] Mirrored value returned for volatile field "regs.FLAGS.ovf" may not
reflect the actual current value.` So the model is no help in checking a register like this. The
router's `STATUS`, `DROP_CNT` and `LEVEL` are all volatile, and in Lab 06 the scoreboard keeps its
own copy of `STATUS`, following the router cycle by cycle, to check `STATUS` reads and `irq`.

## Desired and mirrored values

`set()` changes only the desired value, and `update()` writes the register if the desired value
differs from the mirror:

```text
UVM_INFO guide-examples/register-models/regblk_tb.sv(373) @ 145000: uvm_test_top [RAL] after set(3) on CTRL.MODE: desired 0007, mirror 000b, needs_update 1
UVM_INFO guide-examples/register-models/regblk_tb.sv(376) @ 165000: uvm_test_top [RAL] after update(): desired 0007, mirror 0007, needs_update 0
```

`MODE` is bits 3 to 1, so setting it to 3 gives `0111`, `0007`, with `EN` unchanged at 1. With
`+PREDICT=none` the last line read `desired 0007, mirror 0000, needs_update 1`: the write happened,
but nothing told the mirror, so the model would write the register again on every `update()`.

## The built-in sequences

A register model gives you stimulus for nothing, because it knows every register's policy and reset
value. Two of UVM's built-in sequences do most of the work. Each runs with no sequencer of its own:
you set its `model` to the register block and start it with `start(null)`, and it sends its
transfers through the model.

`uvm_reg_hw_reset_seq` resets the model to its reset values, then reads every register it can check
and compares it. On `regblk` it printed

```text
... [uvm_reg_hw_reset_seq] Verifying reset value of register regs.ID in map "regs.map"...
... [uvm_reg_hw_reset_seq] Verifying reset value of register regs.CTRL in map "regs.map"...
```

and nothing for `FLAGS` or `COUNT`: every field in them is volatile, so a read would compare
nothing. With the planted bug `en_reset_1`, which makes `CTRL.EN` reset to 1, it reported

```text
UVM_ERROR third_party/uvm/src/reg/uvm_reg.svh(2812) @ 75000: reporter [RegModel] Register "regs.CTRL" value read from DUT (0x0000000000000001) does not match mirrored value (0x0000000000000000) (valid bit mask = 0x000000000000000f)
UVM_INFO third_party/uvm/src/reg/uvm_reg.svh(2833) @ 75000: reporter [RegModel] Field en (regs.CTRL[0:0]) mismatch read=1'h1 mirrored=1'h0
```

The sequence compares with the reset values, so it has to run while the design still holds them:
before anything has written a register, or straight after a reset.

`uvm_reg_bit_bash_seq` tests every bit it can check, one at a time. For each one it writes the
register twice with that bit the opposite of the desired value, reads it back after each write, and
compares. It skips the bits of volatile fields, and it treats a bit with no field as read-only, so
it still checks that bits 2 to 15 of `FLAGS` and 8 to 15 of `COUNT` read 0. On `regblk` it printed
`Verifying bits in register` for all four registers. With the planted bug `mode_stuck`, which makes
bit 3 of `CTRL` impossible to set, it reported the same line once for each of its two writes:

```text
UVM_ERROR third_party/uvm/src/reg/sequences/uvm_reg_bit_bash_seq.svh(211) @ 1595000: reporter@@s.reg_single_bit_bash_seq [uvm_reg_bit_bash_seq] Writing a 1 in bit #3 of register "regs.CTRL" with initial value 'h0000000000000000 yielded 'h0000000000000000 instead of 'h0000000000000008
```

Neither sequence was written for `regblk`: each works from the model's description of the
registers. In Lab 06 the same two sequences catch two of the five planted bugs without a single test
step written for either.

The model can't send a transfer to an address that has no register, because there is nothing to
name, so the router's 246 bad addresses still need raw transfers (Lab 06, Part 4). Nor does it know
anything about what the registers *do* to the rest of the design, such as `irq`, which needs the
scoreboard (Part 5).

## The back door

A **back-door** access reads (`peek()`) or writes (`poke()`) a register through the name of the
signal that holds it, with no bus transfer and no simulation time. UVM finds the signal through
VPI, so on Verilator the signal has to be made visible: Lab 06's `tb/router_regs.vlt` marks the five
signals that hold `CTRL`, `STATUS`, `INT_EN` and `DROP_CNT`, one line each, because the flag that
makes every signal visible, `--public-flat-rw`, breaks the UVM build on Verilator 5.050.

On the router, Lab 06 measured that a poke sticks. `router_backdoor_test` pokes `CTRL`, `INT_EN`
and `DROP_CNT` and peeks each one at once, one rising edge later and two, and every peek returned
the poked value:

```text
165000 ps  poke DROP_CNT with                     505   (UVM_IS_OK)
165000 ps    peek at once:                        505   (UVM_IS_OK)
175000 ps    peek one rising edge later:          505   (UVM_IS_OK)
185000 ps    peek two rising edges later:         505   (UVM_IS_OK)
```

That's a measurement of three registers in one design. Before you rely on a poke anywhere else,
peek the register after a rising edge, as that test does. A poke also goes around every model that
keeps its own copy of the register. The scoreboard learns `DROP_CNT` only from the transfers it sees
on the bus, so after a poke its copy and the router's disagree, and Part 6 has you read the poked
value through the front door to see what the scoreboard makes of it. Reading through the back door
has no such cost, so `peek()` is the safer of the two.

## Check yourself

1. A testbench has auto-predict on and no predictor. A test sets up the routing table with raw
   transfers, then runs `mirror(UVM_CHECK)` on `ROUTE0`. What happens, and is the router at
   fault?

   <details>
   <summary>Answer</summary>

   The read returns what the raw transfer wrote, the mirror still holds the reset value, and the
   register model reports a `[RegModel] ... does not match mirrored value` error. The router is
   right. Auto-predict updates the mirror only after the model's own operations, so the testbench
   needs a predictor on the monitor, which sees every transfer.

   </details>

2. Why did `uvm_reg_hw_reset_seq` read only `ID` and `CTRL` on `regblk`, and what does the bit
   bash still test in `FLAGS`?

   <details>
   <summary>Answer</summary>

   Every field of `FLAGS` and `COUNT` is volatile, and the register layer never compares a volatile
   field, so a read of either would check nothing and the reset sequence skips them. The bit bash
   skips the bits of volatile fields too, but bits 2 to 15 of `FLAGS` hold no field, so it treats
   them as read-only and checks that they still read 0 after it writes 1 to each.

   </details>

3. After `set(3)` on `CTRL.MODE`, `needs_update` was 1. Which two values differed, and what made
   them equal again?

   <details>
   <summary>Answer</summary>

   The desired value, `0007`, and the mirror, `000b`. `update()` wrote the desired value to the
   register, and the predictor saw the write and set the mirror to `0007`.

   </details>

## Further reading

ChipVerify's register-layer pages (section 12) build one model for one small APB block, across
several pages. Read 12.1 to 12.6 in order.

- [UVM Register Abstraction Layer](https://www.chipverify.com/uvm/uvm-register-layer): registers,
  fields, maps, and the path of a model write down to the bus.
- [UVM Register Model Classes](https://www.chipverify.com/uvm/uvm-register-model), the clearest
  account of the desired and mirrored values. Correction: its block maps the status register with
  `"RO"` rights, but its write-1-to-clear bit can only be cleared through a map that allows writes.
- [UVM Register Environment](https://www.chipverify.com/uvm/uvm-register-environment): the adapter,
  and auto-predict against a predictor.
- [Connecting register env](https://www.chipverify.com/uvm/connecting-register-env): the map's
  sequencer and the predictor's connection, and why each goes in the phase it does.
- [UVM Register Access Methods](https://www.chipverify.com/uvm/uvm-register-access-methods).
  Correction: it says a front-door `write()` or `read()` always updates the mirror. That's true
  only with auto-predict on or a predictor connected, which the same page says further down.
- [UVM Register Model Example](https://www.chipverify.com/uvm/uvm-register-model-example), the whole
  model in one place. It has no top module, so it doesn't run as shown, and its bus item's address
  constraint leaves out the status register the test reads.
- [UVM Register Sequences](https://www.chipverify.com/uvm/uvm-register-sequences): the built-in
  sequences, why the reset test goes before the bit bash, and how to leave a register out.
- [UVM Register Backdoor Access](https://www.chipverify.com/uvm/uvm-register-backdoor-access). On
  Verilator a back door needs UVM's DPI code, `--vpi` and the signals listed in a `.vlt` file, as
  Lab 06 does.

Next: [Regressions and seeds](../guide/regressions-and-seeds.md).
