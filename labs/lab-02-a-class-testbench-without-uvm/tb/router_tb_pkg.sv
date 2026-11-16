// DD105-A Lab 02: the class testbench, as one package of plain SystemVerilog
// classes. Nothing in it uses UVM.
//
//   packet.svh      packet, the transaction; router_cfg, the test's knobs
//   generator.svh   generator: makes the packets
//   driver.svh      driver (input stream), sink (outputs), apb_master
//   monitor.svh     monitor: turns a stream's handshakes into packets   (yours)
//   scoreboard.svh  scoreboard: predicts output 0 and checks it          (yours)
//   env.svh         env: builds the pieces, connects them, runs the test
//
// The classes talk through mailboxes, and each one that runs for the whole
// test has a run() task that env.run() starts in a fork.

package router_tb_pkg;
  `include "packet.svh"
  `include "generator.svh"
  `include "driver.svh"
  `include "monitor.svh"
  `include "scoreboard.svh"
  `include "env.svh"
endpackage
