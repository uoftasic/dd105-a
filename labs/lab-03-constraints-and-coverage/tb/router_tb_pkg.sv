// DD105-A Lab 03: the class testbench, as one package of plain SystemVerilog
// classes. Nothing in it uses UVM.
//
//   packet.svh      packet; router_cfg, the test's knobs; rand_packet     (Part 3)
//   generator.svh   generator: randomizes the packets
//   driver.svh      driver (input stream), sink (outputs), apb_master
//   monitor.svh     monitor: turns a stream's handshakes into packets
//   scoreboard.svh  scoreboard: predicts output 0 and checks it
//   tracker.svh     tracker: output 0's level, each packet's fate, the drops
//   coverage.svh    router_coverage: the covergroup                     (Part 2)
//   env.svh         env: builds the pieces, connects them, runs the steps
//
// Lab 02's package with two new files, tracker.svh and coverage.svh, and a
// new class, rand_packet, in packet.svh. The monitor and the scoreboard are
// Lab 02's solution, unchanged; if yours passed Lab 02's `make check-all`, you
// can use yours instead.
//
// The classes talk through mailboxes, and each one that runs for the whole
// test has a run() task that env.start() starts in a fork.

package router_tb_pkg;
  `include "packet.svh"
  `include "generator.svh"
  `include "driver.svh"
  `include "monitor.svh"
  `include "scoreboard.svh"
  `include "tracker.svh"
  `include "coverage.svh"
  `include "env.svh"
endpackage
