// DD105-A Lab 02: the scoreboard. You write run(), predict(), check() and
// the checks in report() (Part 3 of the lab).
//
// Predicts which input packets come out of output 0, and checks that output
// 0 delivers exactly those, in the order they went in, with every beat
// unchanged. That is rule O5 of the specification, for output 0, with the
// routing table deciding which packets are "routed to it".
//
// Each input packet is decided by the routing table entry its DST names. In
// this lab the sinks are always ready, so an output never holds more than a
// few beats, no packet is ever dropped as FULL, and the prediction is one
// line: a packet comes out of output 0 if ROUTE[DST] is enabled and its PORT
// is 0. Packets for output 1 or a disabled route aren't checked here.
//
// Report every mismatch with $error, which prints like $display and counts
// as an error, and count it in n_errors. The test turns a nonzero count into
// a failing exit status.

class scoreboard;
  router_cfg        cfg;
  mailbox #(packet) from_in, from_out0;
  packet            expected[$];   // packets predicted for output 0, oldest first
  int unsigned      n_in;          // packets the input monitor saw
  int unsigned      n_predicted;   // ... of which predicted for output 0
  int unsigned      n_checked;     // packets from output 0 compared with a prediction
  int unsigned      n_errors;

  function new(router_cfg cfg, mailbox #(packet) from_in, mailbox #(packet) from_out0);
    this.cfg       = cfg;
    this.from_in   = from_in;
    this.from_out0 = from_out0;
  endfunction

  task run();
    // TODO (Part 3): two threads that both run forever, in a fork...join:
    //  - get a packet from from_in and call predict() with it;
    //  - get a packet from from_out0 and call check() with it.
  endtask

  function void predict(packet p);
    // TODO (Part 3): count p in n_in. cfg.route_en(p.dst()) and
    // cfg.route_port(p.dst()) say what ROUTE[DST] is set to. If the packet
    // will come out of output 0, push it onto the back of `expected` and
    // count it in n_predicted.
  endfunction

  function void check(packet got);
    // TODO (Part 3): `got` is the next packet output 0 delivered. If nothing
    // is expected, that's an error. Otherwise pop the oldest expected packet,
    // count the check in n_checked, and report an error if got.same() says
    // the two differ. Print both packets (sprint()) and their times in the
    // message: it's what you'll read when this fires.
  endfunction

  // Called once, at the end of the test, after the outputs have drained.
  function void report();
    // TODO (Part 3): every packet still in `expected` never came out, which
    // is an error each. And if n_checked is 0, the test checked nothing,
    // which is an error too.
    $display("[SB] %0d packets in, %0d predicted for output 0, %0d checked, %0d errors",
             n_in, n_predicted, n_checked, n_errors);
  endfunction
endclass
