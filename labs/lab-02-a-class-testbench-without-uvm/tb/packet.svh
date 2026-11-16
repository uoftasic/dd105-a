// DD105-A Lab 02: the transaction, and the test's knobs.
//
//   packet      one packet: its beats, header first
//   router_cfg  what the test sends and how the router is configured, read
//               from plusargs, so a different test needs no rebuild

// One packet. The generator fills in data and gap; a monitor fills in data,
// t_first and t_last from what it saw on the pins.
class packet;
  bit [7:0]    data[$];   // the beats; data[0] is the header, and DST is its bits 7:6
  int unsigned gap[$];    // stimulus only: idle cycles the driver leaves before each beat
  longint      t_first;   // monitors: the time (ns) of the first beat's handshake
  longint      t_last;    // monitors: the time (ns) of the last beat's handshake

  function bit [1:0] dst();
    return data[0][7:6];
  endfunction

  // Two packets are the same if they have the same beats. The gaps and the
  // times say how a packet travelled, not what it is, so they don't count.
  function bit same(packet other);
    if (data.size() != other.data.size()) return 0;
    foreach (data[i])
      if (data[i] != other.data[i]) return 0;
    return 1;
  endfunction

  // "dst 2, 3 beats: 85 3c f0"
  function string sprint();
    string s;
    s = $sformatf("dst %0d, %0d beat%s:", dst(), data.size(),
                  data.size() == 1 ? string'("") : string'("s"));
    foreach (data[i]) s = {s, $sformatf(" %02h", data[i])};
    return s;
  endfunction
endclass

// The knobs. Each has a plusarg, so `make run PLUSARGS="+N=16 +DSTS=0"`
// changes the test without rebuilding the simulator.
class router_cfg;
  int unsigned n_pkts = 100;     // +N=<n>       packets to send
  string       dsts   = "0123";  // +DSTS=<digits> the DST values the generator picks from
  string       routes = "0110";  // +ROUTES=<abcd> ROUTE0 to ROUTE3: 0 or 1 is the output, - is disabled
  int unsigned len    = 0;       // +LEN=<n>     every packet n beats long (1 to 8); 0 is random
  int unsigned show   = 0;       // +SHOW=<n>    each monitor prints the first n packets it sees

  function void from_plusargs();
    void'($value$plusargs("N=%d", n_pkts));
    void'($value$plusargs("DSTS=%s", dsts));
    void'($value$plusargs("ROUTES=%s", routes));
    void'($value$plusargs("LEN=%d", len));
    void'($value$plusargs("SHOW=%d", show));
    if (dsts.len() == 0)
      $fatal(1, "+DSTS=%s: give at least one DST, for example +DSTS=0123", dsts);
    foreach (dsts[i])
      if (!(dsts[i] inside {"0", "1", "2", "3"}))
        $fatal(1, "+DSTS=%s: each character must be a DST, 0 to 3", dsts);
    if (routes.len() != 4)
      $fatal(1, "+ROUTES=%s: give four characters, one per route, for example +ROUTES=0110", routes);
    foreach (routes[i])
      if (!(routes[i] inside {"0", "1", "-"}))
        $fatal(1, "+ROUTES=%s: each character must be 0, 1 or - (disabled)", routes);
    if (len > 8)
      $fatal(1, "+LEN=%0d: a packet in this lab is 1 to 8 beats (0 picks at random)", len);
  endfunction

  // ROUTE[d].EN and ROUTE[d].PORT, as the test configures them.
  function bit route_en(bit [1:0] d);
    return routes[int'(d)] != "-";
  endfunction

  function bit route_port(bit [1:0] d);
    return routes[int'(d)] == "1";
  endfunction

  function string describe();
    return $sformatf("%0d packets, DST from %s, routes %s, %s", n_pkts, dsts, routes,
                     len == 0 ? string'("1 to 8 beats") : $sformatf("%0d beats", len));
  endfunction
endclass
