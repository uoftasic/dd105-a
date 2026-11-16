// DD105-A Lab 02: the environment, which builds every other piece, connects
// them with mailboxes and runs them.
//
//   generator --(gen2drv)--> driver --> router input
//   router input  --> in_mon   --(in2sb)----> scoreboard
//   router out0   --> out0_mon --(out02sb)--> scoreboard
//   router out0, out1 <-- sink (always ready)
//
// run() is the whole test: wait for reset, write the configuration over APB,
// start the monitors, the scoreboard and the sinks, send the packets, wait
// for the outputs to drain, and report. The end of the test doesn't depend
// on the monitors or the scoreboard: it comes when the driver has sent every
// packet and the outputs have had DRAIN cycles to empty.

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
  endfunction

  // ROUTE0 to ROUTE3 from cfg.routes, then CTRL.EN, which opens the input.
  task configure();
    for (int d = 0; d < 4; d++)
      apb.write(8'h20 + 8'(4 * d), {30'b0, cfg.route_port(2'(d)), cfg.route_en(2'(d))});
    apb.write(8'h04, 32'h1);
  endtask

  task run();
    $display("[ENV] %s", cfg.describe());
    apb.wait_for_reset();
    configure();
    fork
      snk0.run();
      snk1.run();
      in_mon.run();
      out0_mon.run();
      sb.run();
    join_none
    fork
      gen.run();
      drv.run(cfg.n_pkts);
    join
    repeat (DRAIN) @(drv.vif.cb);
    $display("[ENV] sent %0d packets (%0d beats); output 0 took %0d beats and output 1 took %0d",
             drv.n_pkts, drv.n_beats, snk0.n_beats, snk1.n_beats);
    sb.report();
  endtask

  // Every error the testbench reported: the scoreboard's and the driver's.
  function int unsigned n_errors();
    return drv.n_errors + sb.n_errors;
  endfunction
endclass
