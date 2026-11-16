// DD105-A Lab 02: the generator.
//
// Makes cfg.n_pkts packets and puts them in a mailbox for the driver. Each
// header is {DST, tag}: DST is picked from cfg.dsts, and the tag is the
// packet's sequence number (0, 1, 2, ... wrapping at 64), so you can find a
// packet in a log by its header. The other beats are random bytes, and
// about one beat in four waits 1 to 3 idle cycles before it is offered.
//
// The values come from $urandom, so the seed (make run SEED=7) changes them.
// Lab 03 replaces this with constrained-random packets.

class generator;
  router_cfg        cfg;
  mailbox #(packet) to_drv;

  function new(router_cfg cfg, mailbox #(packet) to_drv);
    this.cfg    = cfg;
    this.to_drv = to_drv;
  endfunction

  task run();
    packet       p;
    int unsigned n;
    bit [1:0]    dst;
    for (int k = 0; k < cfg.n_pkts; k++) begin
      p   = new();
      n   = cfg.len != 0 ? cfg.len : $urandom_range(8, 1);
      dst = 2'(cfg.dsts[$urandom_range(cfg.dsts.len() - 1)] - "0");
      for (int i = 0; i < n; i++) begin
        p.data.push_back(i == 0 ? {dst, 6'(k)} : 8'($urandom));
        p.gap.push_back($urandom_range(3) == 0 ? $urandom_range(3, 1) : 0);
      end
      to_drv.put(p);
    end
  endtask
endclass
