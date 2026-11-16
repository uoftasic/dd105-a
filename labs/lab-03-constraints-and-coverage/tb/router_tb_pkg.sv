// DD105-A Lab 03: the router's class testbench.
//
// A testbench built from plain SystemVerilog classes, as in Lab 02: drivers
// and monitors that reach the pins through virtual interfaces, mailboxes
// between them, a reference model and a scoreboard. The only parts of UVM it
// uses are the test class that starts it (router_test_pkg) and the reporting
// macros, `uvm_info and `uvm_error, which give every run UVM's report summary
// and let the graders count errors.
//
// The pieces, one file each, in the order they're compiled:
//
//   packet.svh      the input packet, and how it's randomized      (Part 3)
//   items.svh       what the monitors report: beats, APB transfers, one
//                   sample per cycle, and one record per packet
//   drivers.svh     the APB master, the source and the two sinks
//   monitors.svh    a monitor for each stream, the APB bus and reset/irq
//   model.svh       the router as the specification describes it
//   coverage.svh    functional coverage                            (Part 2)
//   scoreboard.svh  runs the model on what the monitors saw, cycle by cycle
//   env.svh         creates the pieces and starts them
//
// The virtual interface types are written out in full (`virtual apb_if`),
// never through a typedef: on this simulator (5.050) a class in a package
// that reaches an interface through a typedef'd virtual interface type reads
// 0 from every clocking-block input, with no warning (labs/ref/README.md).

package router_tb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "packet.svh"
  `include "items.svh"
  `include "drivers.svh"
  `include "monitors.svh"
  `include "model.svh"
  `include "coverage.svh"
  `include "scoreboard.svh"
  `include "env.svh"
endpackage
