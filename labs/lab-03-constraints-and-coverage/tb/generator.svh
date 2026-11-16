// DD105-A Lab 03: the generator.
//
// Makes packets and puts them in a mailbox for the driver. Lab 02's generator
// picked every value with $urandom; this one randomizes a rand_packet, so the
// constraints in packet.svh decide its DST and its length. Each header is
// still {DST, tag}, and the tag is the packet's sequence number (0, 1, 2, ...
// wrapping at 64), so you can find a packet in a log by its header.
//
// The values come from the solver and from $urandom, so the seed
// (make run SEED=7) changes them.

class generator;
  router_cfg        cfg;
  mailbox #(packet) to_drv;
  int unsigned      n_made;    // packets passed to the driver so far

  function new(router_cfg cfg, mailbox #(packet) to_drv);
    this.cfg    = cfg;
    this.to_drv = to_drv;
  endfunction

  // A new packet that knows which routes cfg enables, not yet randomized.
  function rand_packet new_packet();
    rand_packet p = new();
    for (int d = 0; d < 4; d++) p.route_en[d] = cfg.route_en(2'(d));
    return p;
  endfunction

  // Randomize n packets and pass them to the driver.
  task run(int unsigned n);
    rand_packet p;
    repeat (n) begin
      p = new_packet();
      if (p.randomize() == 0)
        $fatal(1, "generator: rand_packet randomize() failed with routes %s", cfg.routes);
      put(p);
    end
  endtask

  // Give p the next tag and pass it to the driver.
  task put(rand_packet p);
    p.tag        = 6'(n_made);
    p.data[0]    = {p.hdr_dst, p.tag};
    n_made++;
    to_drv.put(p);
  endtask
endclass
