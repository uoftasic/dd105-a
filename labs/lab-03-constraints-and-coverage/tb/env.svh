// The environment: creates every piece, connects the mailboxes, and starts
// each piece's run() task in a thread of its own.

class router_env;
  apb_master        apb;
  src_driver        src;
  snk_driver        snk[2];
  src_monitor       in_mon;
  snk_monitor       out_mon[2];
  apb_monitor       apb_mon;
  sys_monitor       sys_mon;
  router_scoreboard sb;
  router_coverage   cov;

  function new(virtual apb_if apb_vif, virtual stream_src_if src_vif,
               virtual stream_snk_if snk0_vif, virtual stream_snk_if snk1_vif,
               virtual router_sys_if sys_vif);
    apb        = new(apb_vif);
    src        = new(src_vif);
    snk[0]     = new(snk0_vif);
    snk[1]     = new(snk1_vif);
    in_mon     = new("in", src_vif);
    out_mon[0] = new("out0", snk0_vif);
    out_mon[1] = new("out1", snk1_vif);
    apb_mon    = new(apb_vif);
    sys_mon    = new(sys_vif);
    sb         = new();
    cov        = new();

    in_mon.beats     = sb.in_mb;
    out_mon[0].beats = sb.out_mb[0];
    out_mon[1].beats = sb.out_mb[1];
    apb_mon.xfers    = sb.apb_mb;
    sys_mon.samples  = sb.sys_mb;
    sb.cov           = cov;
  endfunction

  task start();
    fork
      src.run();
      snk[0].run();
      snk[1].run();
      in_mon.run();
      out_mon[0].run();
      out_mon[1].run();
      apb_mon.run();
      sys_mon.run();
      sb.run();
    join_none
  endtask
endclass
