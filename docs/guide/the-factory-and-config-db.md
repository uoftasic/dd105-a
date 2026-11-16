# The factory and config_db

This page answers: *how does a test change what the environment builds, and how it's set up,
without editing the environment?*

That's most of what
[Lab 04](../labs/lab-04-the-same-testbench-in-uvm-overview.md) asks you to do. You make a second
copy of the output agent in Part 2, and `config_db` tells each copy which output it's on. The
stall test you write in Part 3 changes a knob the drivers read, one output at a time. And Part 4's
test sends packets to disabled routes by telling the factory to build a different packet class,
without touching the sequence that makes the packets. Lab 04's Part 5 asks what the extra lines
of the UVM testbench bought, and these two mechanisms are most of the answer.

The example,
[`guide-examples/the-factory-and-config-db/`](https://github.com/uoftasic/dd105-a/tree/main/guide-examples/the-factory-and-config-db),
builds the environment from the [monitors page](monitors-analysis-ports-and-scoreboards.md)
example, an agent and a scoreboard on SimProc's ALU, from that example's own files. Its four tests
change what the environment does from the test alone, and none of them edits a line of the
environment.

## The factory

Every UVM class registers itself with the factory through its utils macro,
`` `uvm_object_utils(alu_item) `` or `` `uvm_component_utils(alu_env) ``, and the labs make almost
everything by asking the factory for it:

```systemverilog
req = alu_item::type_id::create("req");
```

Without overrides, that returns an `alu_item`, exactly as `new()` would. The difference is that a
test can tell the factory to return something else, a subclass of `alu_item`, to everyone who asks
for an `alu_item`. The code that asks never finds out.

`fac_equal_test` uses that to make every vector have equal operands. The subclass replaces one
constraint of `alu_item`:

```systemverilog
class alu_equal_item extends alu_item;
  `uvm_object_utils(alu_equal_item)
  constraint c_same { same == 1; same -> B == A; }
  ...
endclass
```

A constraint with the same name as one in the parent class replaces it, so `alu_equal_item` has
the parent's `c_op` and this `c_same`. (Lab 04 checked that Verilator 5.050 does this as the
standard says; its `router_noroute_pkt` replaces `c_dst` the same way.) The test sets the override
in its `build_phase`, before `super.build_phase()` builds the environment:

```systemverilog
function void build_phase(uvm_phase phase);
  alu_item::type_id::set_type_override(alu_equal_item::get_type());
  super.build_phase(phase);
endfunction
```

and prints the factory's overrides with `uvm_factory::get().print(0)`:

```text
#### Factory Configuration (*)
No instance overrides are registered with this factory
Type Overrides:
  Requested Type  Override Type 
  --------------  --------------
  alu_item        alu_equal_item
```

The sequence still calls `alu_item::type_id::create("req")` and still randomizes what it gets, so
every one of its 200 vectors now has `A == B`. Run against Lab 01's three ALU bugs, the test
catches none of them:

```text
 0 of 3 caught.
 Still hiding from this test:
   A01_sub_operands_swapped
      hides behind: SUB rX, rX, the idiom for clearing a register
   A02_nand_is_nor
      hides behind: NAND rX, rX, the only way to write NOT
   A03_zero_flag_low_nibble
      hides behind: every check that compares results and not flags
```

That's the DD104 lesson about symmetric operands again: with equal operands, `A - B` and `B - A`
are both 0, and `~(A & B)` and `~(A | B)` are both `~A`. Here it shows how far an override reaches.
One line in the test changed every item the sequence made, and the coverage collector, which
counted the vectors, reported only 65% of its bins hit, because no vector had unequal operands.

An override changes every object the factory makes of that type, and that can include objects
you meant to leave alone. Lab 04's `close_holes()` needs two packets exactly as `router_pkt`
defines them, so it makes them with `new()`, which doesn't go through the factory. When we made them through the factory, `router_inject_test`'s override turned them into
`router_noroute_pkt`s too, and `randomize()` failed on 4 of 5 seeds (Lab 04, Part 4, step 3).

An override doesn't even need a test class. UVM reads overrides from the command line, so the
same swap can be made on `mon_rand_test`, which knows nothing about `alu_equal_item`, with
`+uvm_set_type_override=alu_item,alu_equal_item`. On the ALU with bug A01:

```text
UVM_INFO @ 0: reporter [UVM_CMDLINE_PROC] Applying type override from the command line: +uvm_set_type_override=alu_item,alu_equal_item
```

and `MISSED: 0 UVM_ERROR`, where the same test without the plusarg catches A01 with 33 errors.
Lab 04 does the same to the router in Part 4, step 6, and the run needs no rebuild.

The factory can also override a single instance, by its path in the tree, rather than a whole
type. The course's labs use only type overrides, and so does `mon_alias_test` on the monitors
page, which replaced the monitor class in an environment that has one monitor.

## config_db

`config_db` is a table of values that one component puts in and another takes out. The one that
sets a value names who may read it, by a path in the component tree, relative to itself:

```systemverilog
uvm_config_db#(bit)::set(this, "env.sb", "check_flags", 1);     // in the test
void'(uvm_config_db#(bit)::get(this, "", "check_flags", check_flags));  // in the scoreboard
```

The test's full name is `uvm_test_top`, so its `set` is for `uvm_test_top.env.sb`. The
scoreboard's `get` with an empty path looks for a value set for its own full name, which is that
one. A path can contain wildcards, and the top module, which isn't a component, sets each
virtual interface with a `null` context and a full path such as `"uvm_test_top.env.agent.*"`, so
that every component inside the agent finds it.

The example's scoreboard compares `ALUout` only, unless `check_flags` is set. `fac_flags_test`
sets it, and catches all three bugs:

```text
      ok  the golden design                        0 UVM_ERROR, 0 UVM_FATAL        0.2s
------------------------------------------------------------------------
  caught  tier 1  A01_sub_operands_swapped         33 UVM_ERROR                    0.2s
  caught  tier 1  A02_nand_is_nor                  26 UVM_ERROR                    0.2s
  caught  tier 1  A03_zero_flag_low_nibble         8 UVM_ERROR                     0.2s
------------------------------------------------------------------------
 3 of 3 caught.
```

`fac_typo_test` sets the same value for `"env.scoreboard"`, a component that doesn't exist. No
error appears anywhere: the `get` finds nothing, the scoreboard keeps its default, and A03 goes
uncaught again. The way to see it is `+UVM_CONFIG_DB_TRACE`, which logs every `set` and `get`:

```text
UVM_INFO third_party/uvm/src/base/uvm_config_db_implementation.svh(485) @ 0: reporter [CFGDB/SET] Configuration scope='uvm_test_top.env.scoreboard' name='check_flags' (type PARAMTYPEDTYPE 'T') set accessor=uvm_test_top = (PARAMTYPEDTYPE 'T') 1
UVM_INFO third_party/uvm/src/base/uvm_config_db_implementation.svh(485) @ 0: reporter [CFGDB/GET] Configuration scope='uvm_test_top.env.sb' name='check_flags' (type PARAMTYPEDTYPE 'T') read accessor=uvm_test_top.env.sb = null (failed lookup)
```

Comparing the two scopes shows the mistake. A knob with a sensible default can be read the way
`check_flags` is, with `void'(...)`, but a component that can't work without a value should stop
the run when the `get` fails. Every driver and monitor in Lab 04 does that for its virtual
interface and its `out_cfg`, with `` `uvm_fatal("NOVIF", ...) `` and `` `uvm_fatal("NOCFG", ...) ``.

Two components can set the same value for the same component. In `fac_prec_test` the
environment is overridden by a subclass that sets a default of 0 for its scoreboard, after the
test has already set 1:

```text
[TEST] uvm_test_top set check_flags = 1 for "env.sb"
[ENV] uvm_test_top.env set check_flags = 0 for "sb"
```

and the scoreboard ended up checking the flags, `200 vectors checked with N and Z: 0 wrong`. In
the build phase the set from higher in the tree, the test's, beat the later one from lower down,
which is what lets an environment give its components defaults that any test can override.

### Objects by handle

`config_db` can hold an object as well as a number, and then what it stores is the handle, so the
component that gets it shares the object with the one that set it. Lab 04 uses that for the
output agents. `router_base_test` makes an `out_cfg` for each output, sets output 0's for
`"env.out0*"` and output 1's for `"env.out1*"`, and keeps the two handles. Both output agents are
the same class, and the only things that differ between them are the virtual interface and the
`out_cfg` each one gets. Because the test kept the handles, your Part 3 stall test can change
`ocfg[p].ready_pct` in the middle of a run, and each `out_ready_driver`, which reads `ready_pct`
again every cycle, follows it at the next clock edge.

One measured caution for virtual interfaces: write their types out in full, as
`virtual stream_src_if`. On Verilator 5.050 a class in a package that reached an interface
through a `typedef` of the virtual interface read 0 from every clocking-block input, with no
warning (`labs/ref/README.md` has the probe), so the labs' packages don't use one.

## Check yourself

1. `fac_equal_test` changed one line of a test and catches none of the three bugs that
   `mon_rand_test` catches two of. Did the override change the sequence?

   <details>
   <summary>Answer</summary>

   No. The sequence's code is the same; it still asks the factory for an `alu_item` and
   randomizes it. What changed is the class the factory hands back, and with it the constraint
   that decides the operands. Every item the sequence made had `A == B`, which hides both operand
   bugs, and nothing checked the flags.

   </details>

2. A test sets a knob for its scoreboard, and the run is no different from a run without the
   `set`. Nothing printed an error. What do you look at?

   <details>
   <summary>Answer</summary>

   Run it with `+UVM_CONFIG_DB_TRACE` and compare the scope in the `CFGDB/SET` line with the scope
   in the scoreboard's `CFGDB/GET` line. If the `get` says `failed lookup`, the `set` didn't name
   the component that reads it, as in `fac_typo_test`, and nothing else reports that.

   </details>

3. Lab 04's `close_holes()` makes its two random packets with `new()`. What happened in
   `router_inject_test` when they were made through the factory instead?

   <details>
   <summary>Answer</summary>

   The test's override reached them too, so they were `router_noroute_pkt`s. `close_holes()`
   switches `c_dst` off for the packet to DST 1 through a `router_pkt` handle, and that left the
   subclass's own `c_dst` on, so when the packet's `pre_randomize()` chose an enabled route,
   DST 1 (disabled) was impossible and `randomize()` failed, on 4 of 5 seeds
   (Lab 04, Part 4, step 3).

   </details>

## Further reading

- ChipVerify's [UVM Factory Override](https://www.chipverify.com/uvm/uvm-factory-override) covers
  type and instance overrides and the argument-order trap between the factory's methods and the
  component's. Correction: its last example calls methods on a global `factory` variable, which
  the course's UVM library (1800.2-2020.3.2) doesn't have; use `uvm_factory::get()`.
- [UVM config database](https://www.chipverify.com/uvm/uvm-config-db), for the API, the
  wildcards and the precedence rules.
- [uvm_config_db Examples](https://www.chipverify.com/uvm/uvm-config-db-examples) works through
  eight scopes with `+UVM_CONFIG_DB_TRACE` logs. Its third case depends on a `set()` the page
  never shows.
- [Configure Components](https://www.chipverify.com/uvm/configure-components), on configuration
  objects like Lab 04's `out_cfg`.
- [Passing the Virtual Interface](https://www.chipverify.com/uvm/passing-virtual-interface), on
  how the top module's `set` reaches the driver and the monitor.

Next: [Lab 04: The same testbench in UVM](../labs/lab-04-the-same-testbench-in-uvm-overview.md).
