// DD105-A Lab 03: functional coverage. You write the covergroup (Part 2).
//
// The tracker calls sample_pkt() once for every packet the router took from
// the input, when its last beat goes in, with a pkt_fate (tracker.svh): its
// DST, its length in beats, its fate (FATE_NOROUTE, FATE_FULL, FATE_OUT0 or
// FATE_OUT1, which are 0 to 3) and the level of the output its route names,
// in the cycle its header was accepted.
//
// Every run writes the hit count of each covergroup bin to coverage.dat in
// its run folder, and `make cov` merges them and lists the bins.

class router_coverage;

  // TODO (Part 2): a covergroup cg_pkt over the packets, constructed in new()
  // and sampled in sample_pkt().

  function new();
  endfunction

  function void sample_pkt(pkt_fate f);
  endfunction
endclass
