// Functional coverage.
//
// The scoreboard calls sample_pkt() once for every packet the router took,
// when its last beat is accepted, with what the model decided for it: its
// DST, how many beats it had, its fate (FATE_NOROUTE, FATE_FULL, FATE_OUT0
// or FATE_OUT1) and the level of the output its route names, in the cycle its
// header was accepted. router_pkt_info is in items.svh.
//
// Every run writes the hit count of each covergroup bin to coverage.dat in
// its run folder, and `make cov` merges them and lists the bins.

class router_coverage;

  // TODO (Part 2): a covergroup for the packets, and its sample() call below.

  function new();
  endfunction

  function void sample_pkt(router_pkt_info i);
  endfunction
endclass
