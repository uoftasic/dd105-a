// DD105-A Lab 03: functional coverage (reference solution).
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

  // The covergroup takes its values as arguments of sample(). This simulator
  // doesn't support a covergroup in a class whose coverpoints read a member
  // of the class (coverpoint f.len): it warns COVERIGN and leaves the
  // covergroup out, and uvm.mk's build stops on that warning.
  //
  // Every bin of a crossed coverpoint is written out by name: an array of
  // bins (bins low[] = {[1:7]}) on a coverpoint in a cross becomes a single
  // bin here (labs/ref/README.md).
  covergroup cg_pkt with function sample(int len, int dst, int fate, int level);
    cp_len: coverpoint len {
      bins len1 = {1};
      bins len2 = {2};
      bins len3 = {3};
      bins len4 = {4};
      bins len5 = {5};
      bins len6 = {6};
      bins len7 = {7};
      bins len8 = {8};
    }
    cp_dst: coverpoint dst {
      bins dst0 = {0};
      bins dst1 = {1};
      bins dst2 = {2};
      bins dst3 = {3};
    }
    cp_fate: coverpoint fate {
      bins noroute = {0};
      bins full    = {1};
      bins out0    = {2};
      bins out1    = {3};
    }
    cp_level: coverpoint level {
      bins empty = {0};
      bins low   = {[1:7]};
      bins at_8  = {8};
      bins at_9  = {9};
      bins high  = {[10:16]};
    }
    x_fate_level: cross cp_fate, cp_level;
  endgroup

  function new();
    cg_pkt = new();
  endfunction

  function void sample_pkt(pkt_fate f);
    cg_pkt.sample(f.len, f.dst, int'(f.fate), f.level);
  endfunction
endclass
