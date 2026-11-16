// DD105-A Lab 03: the environment, which builds every other piece, connects
// them with mailboxes and runs them.
//
//   generator --(gen2drv)--> driver --> router input
//   router input  --> in_mon   --(in2sb)----> scoreboard
//   router out0   --> out0_mon --(out02sb)--> scoreboard
//   router input and out0 --> tracker --> coverage
//   router out0, out1 <-- sink (ready unless stalled)
//
// Lab 02's run() was the whole test in one task. Here it's split into the
// steps a test calls one after another (start, write_routes, enable,
// send_random or send, drain, check_drops, report), and run() is those steps
// in Lab 02's order, so router_class_test still runs Lab 02's test.
//
// check_drops() is new in this lab. A router that counts a drop wrongly can
// deliver every packet correctly, so the scoreboard can't see it; reading
// DROP_CNT and comparing it with the tracker's counts is the only check in
// this testbench that can.

class env;
  localparam int unsigned DRAIN = 50;   // cycles after the last input beat

  router_cfg        cfg;
  mailbox #(packet) gen2drv, in2sb, out02sb;
  generator         gen;
  driver            drv;
  sink              snk0, snk1;
  apb_master        apb;
  monitor           in_mon, out0_mon;
  scoreboard        sb;
  router_coverage   cov;
  tracker           trk;
  int unsigned      n_drop_reads, n_drop_errors;

  function new(router_cfg cfg,
               virtual stream_src_if in_vif,
               virtual stream_snk_if out0_vif,
               virtual stream_snk_if out1_vif,
               virtual stream_mon_if in_mon_vif,
               virtual stream_mon_if out0_mon_vif,
               virtual apb_if        apb_vif);
    this.cfg = cfg;
    gen2drv  = new();
    in2sb    = new();
    out02sb  = new();
    gen      = new(cfg, gen2drv);
    drv      = new(in_vif, gen2drv);
    snk0     = new(out0_vif);
    snk1     = new(out1_vif);
    apb      = new(apb_vif);
    in_mon   = new("in", in_mon_vif, in2sb, cfg.show);
    out0_mon = new("out0", out0_mon_vif, out02sb, cfg.show);
    sb       = new(cfg, in2sb, out02sb);
    cov      = new();
    trk      = new(cfg, in_mon_vif, out0_mon_vif, cov);
  endfunction

  // Wait for reset, then start everything that runs for the whole test.
  task start();
    apb.wait_for_reset();
    fork
      snk0.run();
      snk1.run();
      in_mon.run();
      out0_mon.run();
      sb.run();
      trk.run();
    join_none
  endtask

  // ROUTE0 to ROUTE3, written as +ROUTES is: one character per route, 0 or 1
  // for the output, - for disabled (written with PORT 0). cfg.routes changes
  // with them, and the scoreboard and the tracker predict from it, so call
  // this only while no packet is coming in.
  task write_routes(string routes);
    cfg.check_routes(routes);
    cfg.routes = routes;
    for (int d = 0; d < 4; d++)
      apb.write(8'h20 + 8'(4 * d), {30'b0, cfg.route_port(2'(d)), cfg.route_en(2'(d))});
  endtask

  // CTRL.EN, which opens the input.
  task enable();
    apb.write(8'h04, 32'h1);
  endtask

  // Lab 02's configure(): the routing table from +ROUTES, then CTRL.EN.
  task configure();
    write_routes(cfg.routes);
    enable();
  endtask

  // n random packets for the routes in cfg.routes. Returns when the last
  // one has gone into the router.
  task send_random(int unsigned n);
    fork
      gen.run(n);
      drv.run(n);
    join
  endtask

  // Packets the test built itself, in order, each with the next tag.
  // Returns when the last one has gone into the router.
  task send(rand_packet pkts[$]);
    foreach (pkts[i]) gen.put(pkts[i]);
    drv.run(pkts.size());
  endtask

  task cycles(int unsigned n);
    repeat (n) @(drv.vif.cb);
  endtask

  // Give the outputs DRAIN cycles to empty.
  task drain();
    cycles(DRAIN);
  endtask

  // Read DROP_CNT and compare it with the drops the tracker predicted.
  task check_drops();
    bit [31:0] got, want;
    apb.read(8'h10, got);
    want = trk.drop_cnt();
    n_drop_reads++;
    if (got != want) begin
      n_drop_errors++;
      $error("DROP_CNT read %08h, expected %08h (FULL_CNT %0d, NOROUTE_CNT %0d)",
             got, want, want[15:8], want[7:0]);
    end else begin
      $display("[DROP] DROP_CNT %08h as expected", got);
    end
  endtask

  // Write DROP_CNT, which clears both counters, and clear the tracker's.
  task clear_drops();
    apb.write(8'h10, 32'h0);
    trk.clear_drops();
  endtask

  task report();
    $display("[ENV] sent %0d packets (%0d beats); output 0 took %0d beats and output 1 took %0d",
             drv.n_pkts, drv.n_beats, snk0.n_beats, snk1.n_beats);
    trk.report();
    sb.report();
  endtask

  // Lab 02's test: the routing table from +ROUTES, cfg.n_pkts random packets,
  // a drain, and the report. The DROP_CNT check is this lab's.
  task run();
    $display("[ENV] %s", cfg.describe());
    start();
    configure();
    send_random(cfg.n_pkts);
    drain();
    check_drops();
    report();
  endtask

  // Every error the testbench reported: the scoreboard's, the driver's and
  // the DROP_CNT check's.
  function int unsigned n_errors();
    return drv.n_errors + sb.n_errors + n_drop_errors;
  endfunction
endclass
