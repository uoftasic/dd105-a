# The UVM register layer

A lookup page for [Lab 06](../labs/lab-06-the-register-block-overview.md): the arguments, policies
and messages of UVM's register layer that the lab uses, as the course's UVM library (UVM 2020-3.2,
in `third_party/uvm`) implements them. The router's own register map, with the UVM access policy
of every field, is in the [specification](router-spec.md#register-map).

## Configuring a field

A field is created with the factory and then configured:

```systemverilog
f = uvm_reg_field::type_id::create("noroute");
f.configure(parent, size, lsb, access, volatile, reset, has_reset, is_rand, individually_accessible);
```

| Argument | Meaning |
|---|---|
| `parent` | the register the field belongs to: `this`, in the register's `build()` |
| `size` | the field's width in bits |
| `lsb` | its lowest bit in the register |
| `access` | the UVM access policy, such as `"RW"`, `"RO"`, `"W1C"` or `"WC"` |
| `volatile` | 1 if the design can change the field on its own |
| `reset` | its value after reset |
| `has_reset` | 1 if the field has a reset value (all of the router's do) |
| `is_rand` | 1 if `randomize()` may pick a value for it; 1 only for a field that software sets to a value it chooses, which on the router means an `RW` field |
| `individually_accessible` | 1 only for a field that is alone in its register |

A field that is volatile is never compared when the register layer reads it, because the design
may have changed it since the model last looked.

## Mirror, desired value and prediction

The model keeps two values for every field. The **mirror** is what the model believes the design
holds. The **desired** value is what the testbench last asked for: a `write()` sets it before the
transfer starts.

| Way the mirror changes | When |
|---|---|
| auto-predict (`set_auto_predict(1)` on the map) | after each operation that the model itself sends, and only those |
| a `uvm_reg_predictor` connected to a monitor's analysis port | after every transfer the monitor reports, whoever started it |
| `peek()` and `poke()` | at once: `peek()` predicts as a read of the value it found, and `poke()` as a write of the value it wrote |

A prediction from a read sets both the mirror and the desired value to the value read.

| Check | What it compares |
|---|---|
| `r.mirror(status, UVM_CHECK)` | the value read with the mirror, for every field that isn't volatile |
| check-on-read (`set_check_on_read(1)` on the map) | the predictor compares every read it sees with the mirror |

A mismatch is reported as

```text
[RegModel] Register "regs.CTRL" value read from DUT (0x0000000000000001) does not match mirrored value (0x0000000000000000) (valid bit mask = 0x0000000000000001)
```

where the valid bit mask has a 1 for every bit that was compared.

## The built-in sequences

Both run on no sequencer of their own: set `model` to the register block and start them with
`start(null, this)`. They send their transfers through the model, and so through your adapter.

| Sequence | What it does | What it skips |
|---|---|---|
| `uvm_reg_hw_reset_seq` | resets the model to its reset values, then reads every register with `mirror(UVM_CHECK)` and prints `Verifying reset value of register ...` for each | a register in which no field would be compared, which on the router means one whose fields are all volatile |
| `uvm_reg_bit_bash_seq` | for each bit it can check, writes the register twice, each time with that bit the opposite of the desired value, reads it back after each write, and compares the read with the desired value; prints `Verifying bits in register ...` for each register | the bits of volatile fields. A bit with no field counts as read-only: the model expects it to read 0, so both writes set it to 1 |

A bit-bash failure is reported as

```text
[uvm_reg_bit_bash_seq] Writing a 1 in bit #0 of register "regs.ROUTE3" with initial value 'h0000000000000000 yielded 'h0000000000000002 instead of 'h0000000000000001
```

## The back door

A back-door access reads (`peek`) or writes (`poke`) a register through the name of the signal that
holds it, with no bus transfer and no simulation time. The model finds the signal from HDL paths:
`add_hdl_path()` on the block names the instance, and `add_hdl_path_slice(signal, lsb, width)` on a
register names the signal for each of its bit ranges. In Lab 06 the block's path is
`router_tb_top.dut.u_regs` and `CTRL` is `en_q` inside it.

UVM reaches the signal through VPI, and Verilator lets VPI see a signal only if it is marked public.
The lab's `tb/router_regs.vlt` marks the five signals that hold `CTRL`, `STATUS`, `INT_EN` and
`DROP_CNT`, one line each:

```text
public_flat_rw -module "router_regs" -var "en_q"
```

The command-line flag that marks every signal public, `--public-flat-rw`, breaks the UVM build on
Verilator 5.050, which is why the lab names the signals one by one. Lab 06, Part 6, measures what
`peek` and `poke` do on the router.
