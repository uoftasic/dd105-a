// DD105-A Lab 03: the tracker, which follows output 0's level and decides
// what the router must do with each packet.
//
//   fate_e    NOROUTE, FULL, OUT0 or OUT1: what happens to a packet
//   pkt_fate  one record per packet, handed to the coverage class
//   tracker   the level model and the drop counts
//
// The router decides a packet's fate once, in the cycle its header is
// accepted, from ROUTE[DST] and the level of the output that the entry's PORT
// names (spec, Routing). The level of an output in cycle t is the beats
// written into it in input handshakes before t, minus the beats taken from it
// in output handshakes before t. So the tracker watches the input and output
// 0, once per cycle, and handles each cycle's input handshake before its
// output handshake: a header sees only earlier cycles' handshakes.
//
// It looks at the raw signals at the falling edge, in the middle of the
// cycle, where the specification says nothing is changing. One thread reads
// both streams, so the order within a cycle is the order of the code.
//
// Nothing watches output 1 in this testbench, and both sinks are ready
// whenever output 1 has anything, so the tracker takes output 1's level as 0.
//
// The tracker checks nothing itself. It counts the drops it predicts, which
// env.check_drops() compares with DROP_CNT, and it hands each packet's record
// to the coverage class when the packet's last beat goes in.

typedef enum int {FATE_NOROUTE, FATE_FULL, FATE_OUT0, FATE_OUT1} fate_e;

typedef class router_coverage;   // coverage.svh, which comes after this file

class pkt_fate;
  bit [1:0]    dst;
  int unsigned len;       // beats taken from the input, header included
  fate_e       fate;
  int          level;     // the level of output ROUTE[DST].PORT in the header's cycle
endclass

class tracker;
  router_cfg            cfg;
  virtual stream_mon_if in_vif, out0_vif;
  router_coverage       cov;

  int          level0;          // output 0's level, as of the cycles handled so far
  int          max_level0;      // the highest level0 a header saw
  int unsigned noroute_cnt;     // drops since DROP_CNT was last cleared
  int unsigned full_cnt;
  int unsigned n_pkts, n_fate[4];

  pkt_fate     cur;             // the packet coming in, or null between packets
  bit          to_out0;         // 1 if cur's beats are written into output 0

  function new(router_cfg cfg, virtual stream_mon_if in_vif, virtual stream_mon_if out0_vif,
               router_coverage cov);
    this.cfg      = cfg;
    this.in_vif   = in_vif;
    this.out0_vif = out0_vif;
    this.cov      = cov;
  endfunction

  task run();
    forever begin
      @(negedge in_vif.clk);
      if (!in_vif.rst_n) begin
        // A reset empties both outputs and abandons the packet coming in.
        level0 = 0;
        cur    = null;
        continue;
      end
      if (in_vif.valid && in_vif.ready) in_beat(in_vif.data, in_vif.last);
      if (out0_vif.valid && out0_vif.ready) level0--;
    end
  endtask

  // A beat taken from the input.
  function void in_beat(bit [7:0] data, bit last);
    if (cur == null) begin
      // The header: the router decides here what happens to the whole packet.
      bit [1:0] d = data[7:6];
      cur       = new();
      cur.dst   = d;
      cur.level = cfg.route_port(d) ? 0 : level0;   // output 1's level is taken as 0
      if (cur.level > max_level0) max_level0 = cur.level;
      to_out0   = 0;
      if (!cfg.route_en(d)) begin
        cur.fate = FATE_NOROUTE;
        noroute_cnt++;
      end else if (cur.level > 8) begin
        cur.fate = FATE_FULL;
        full_cnt++;
      end else if (cfg.route_port(d)) begin
        cur.fate = FATE_OUT1;
      end else begin
        cur.fate = FATE_OUT0;
        to_out0  = 1;
      end
    end
    cur.len++;
    // A forwarded packet's first 8 beats are written to its output, and the
    // 8th always ends it (spec, Oversize packets).
    if (to_out0 && cur.len <= 8) level0++;
    if (last) begin
      n_pkts++;
      n_fate[cur.fate]++;
      cov.sample_pkt(cur);
      cur = null;
    end
  endfunction

  // The test wrote DROP_CNT, which clears both counters.
  function void clear_drops();
    noroute_cnt = 0;
    full_cnt    = 0;
  endfunction

  // DROP_CNT as the router should have it: {FULL_CNT, NOROUTE_CNT}, each
  // stopping at 255 (spec, DROP_CNT).
  function bit [31:0] drop_cnt();
    return {16'h0, sat(full_cnt), sat(noroute_cnt)};
  endfunction

  function bit [7:0] sat(int unsigned n);
    return n > 255 ? 8'd255 : 8'(n);
  endfunction

  function void report();
    $display("[TRK] %0d packets: %0d to output 0, %0d to output 1, %0d NOROUTE, %0d FULL; the highest level a header saw was %0d",
             n_pkts, n_fate[FATE_OUT0], n_fate[FATE_OUT1], n_fate[FATE_NOROUTE], n_fate[FATE_FULL],
             max_level0);
  endfunction
endclass
