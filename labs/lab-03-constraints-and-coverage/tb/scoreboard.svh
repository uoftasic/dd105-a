// DD105-A Lab 03: the scoreboard, as Lab 02's solution wrote it.
//
// Predicts which input packets come out of output 0, and checks that output
// 0 delivers exactly those, in the order they went in, with every beat
// unchanged. That is rule O5 of the specification, for output 0, with the
// routing table deciding which packets are "routed to it".
//
// Each input packet is decided by the routing table entry its DST names.
// Until Part 4 of Lab 03 the sinks are always ready, so an output never holds
// more than a few beats. Part 4 stalls output 0, but never sends it a packet
// it is too full to take, so no packet is ever dropped as FULL, and the
// prediction is one line: a packet comes out of output 0 if ROUTE[DST] is
// enabled and its PORT is 0. Packets for output 1 or a disabled route aren't
// checked here.
//
// Every mismatch is reported with $error and counted in n_errors. The test
// turns a nonzero count into a failing exit status.

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

  // Two threads, both forever: one takes packets from the input monitor and
  // predicts, the other takes packets from the output 0 monitor and checks.
  // A packet's last input beat moves at least two cycles before its last
  // output beat, so its prediction is always in `expected` before it can
  // come out.
  task run();
    fork
      forever begin
        packet p;
        from_in.get(p);
        predict(p);
      end
      forever begin
        packet p;
        from_out0.get(p);
        check(p);
      end
    join
  endtask

  function void predict(packet p);
    bit [1:0] d = p.dst();
    n_in++;
    if (cfg.route_en(d) && cfg.route_port(d) == 0) begin
      expected.push_back(p);
      n_predicted++;
    end
  endfunction

  function void check(packet got);
    packet want;
    if (expected.size() == 0) begin
      n_errors++;
      $error("out0 delivered %s at %0d ns, and no packet was expected", got.sprint(), got.t_last);
      return;
    end
    want = expected.pop_front();
    n_checked++;
    if (!got.same(want)) begin
      n_errors++;
      $error("out0 delivered %s at %0d ns; expected %s, which went in at %0d ns",
             got.sprint(), got.t_last, want.sprint(), want.t_first);
    end
  endfunction

  // Called once, at the end of the test, after the outputs have drained.
  function void report();
    foreach (expected[i]) begin
      n_errors++;
      $error("out0 never delivered %s, which went in at %0d ns",
             expected[i].sprint(), expected[i].t_first);
    end
    if (n_checked == 0) begin
      n_errors++;
      $error("no packet was checked on output 0, so this test checked nothing");
    end
    $display("[SB] %0d packets in, %0d predicted for output 0, %0d checked, %0d errors",
             n_in, n_predicted, n_checked, n_errors);
  endfunction
endclass
