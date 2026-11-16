// DD105-A Lab 04: the scoreboard, the coverage and the environment.
//
//   pkt_fate           what happened to one input packet, for the coverage
//   router_scoreboard  the scoreboard, fed by analysis ports
//   router_coverage    the covergroup, as a subscriber
//   router_env         makes the agents, the scoreboard and the coverage,
//                      and connects them
//
// Lab 03's testbench watched only output 0, and so does this port of it.
// Parts 2 and 3 of the lab fill in the TODOs below.

package router_env_pkg;
  import uvm_pkg::*;
  import router_agents_pkg::*;
  `include "uvm_macros.svh"

  // Register addresses (spec, Register map).
  localparam bit [7:0] A_ID = 8'h00, A_CTRL = 8'h04, A_STATUS = 8'h08, A_INT_EN = 8'h0C,
                       A_DROP_CNT = 8'h10, A_LEVEL = 8'h14, A_ROUTE0 = 8'h20;

  // Lab 03's fates, in Lab 03's order: the coverage's cp_fate bins are 0 to 3.
  typedef enum int {FATE_NOROUTE, FATE_FULL, FATE_OUT0, FATE_OUT1} fate_e;

  // Lab 03's pkt_fate: one record per packet, for the coverage.
  class pkt_fate extends uvm_object;
    `uvm_object_utils(pkt_fate)
    bit [1:0]    dst;
    int unsigned len;
    fate_e       fate;
    int          level;     // the level of output ROUTE[DST].PORT in the header's cycle
    function new(string name = "pkt_fate");
      super.new(name);
    endfunction
  endclass

  // One write() function per kind of analysis port the scoreboard listens to.
  `uvm_analysis_imp_decl(_in)
  `uvm_analysis_imp_decl(_out)
  `uvm_analysis_imp_decl(_apb)

  // ── the scoreboard ────────────────────────────────────────────────────────
  // Lab 03's scoreboard and its tracker, in one class. Both took their
  // inputs in run() loops of their own, from mailboxes and from the pins;
  // here each monitor calls one of the write_*() functions below as each
  // beat moves, and the scoreboard has no thread at all.
  //
  // For every packet that comes in, it decides at the header what the router
  // must do with it (spec, Routing), as Lab 03's tracker did, using the
  // routing table it has seen written over APB and the level of each output,
  // and queues the beats it expects on that output. Lab 03's scoreboard
  // expected every packet for an enabled route to come out; this one also
  // predicts FULL drops, from the levels. Every beat that comes out must be
  // the next one queued for its output, and every read of DROP_CNT must
  // match the drops counted since DROP_CNT was last written.
  class router_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(router_scoreboard)

    uvm_analysis_imp_in  #(stream_beat, router_scoreboard) in_export;
    uvm_analysis_imp_out #(stream_beat, router_scoreboard) out_export;
    uvm_analysis_imp_apb #(apb_item,    router_scoreboard) apb_export;
    uvm_analysis_port    #(pkt_fate)                       fate_ap;

    // The routing table, as written over APB: bit r is ROUTEr.EN or ROUTEr.PORT.
    bit [3:0]    route_en, route_port;

    // The packet coming in.
    int          in_beats;        // beats of it taken so far; 0: the next beat is a header
    int          in_port;         // the output it's written to, or -1 if it's dropped
    pkt_fate     cur;

    // Each output.
    bit [8:0]    expected[2][$];  // {last, data} of every beat still to come out, in order
    int          written[2];      // beats written into it so far
    int          taken[2];        // beats taken from it so far
    int unsigned last_take[2];    // the cycle of the most recent of those

    // DROP_CNT, as the router should have it.
    int unsigned noroute_cnt, full_cnt;

    // For the report.
    int unsigned n_pkts, n_fate[4], n_ok[2], n_dropcnt;
    int          max_level;       // the highest level a header saw
    int unsigned n_unwatched;     // beats written to an output that nothing watches

    function new(string name, uvm_component parent);
      super.new(name, parent);
      in_export  = new("in_export", this);
      out_export = new("out_export", this);
      apb_export = new("apb_export", this);
      fate_ap    = new("fate_ap", this);
    endfunction

    // The level of output p in cycle t: the beats written into it in cycles
    // before t, minus the beats taken from it in cycles before t (spec,
    // Routing). A beat taken in cycle t itself doesn't count, and its monitor
    // may already have reported it, in the same time step as the header.
    // That is Lab 03's tracker's rule: a cycle's input handshake before its
    // output handshake.
    //
    // TODO (Part 3): Lab 03's tracker took output 1's level as 0, because no
    // test stalled output 1, so it never held more than two beats, and this
    // does the same. Make it give output 1's real level, as it does output
    // 0's.
    function int level(int p, int unsigned t);
      int l;
      if (p == 1) return 0;
      l = written[p] - taken[p];
      if (taken[p] > 0 && last_take[p] == t) l++;
      return l;
    endfunction

    // A beat accepted on the input.
    function void write_in(stream_beat b);
      if (in_beats == 0) begin
        // The header: the router decides here what happens to the whole packet.
        bit [1:0] dst = b.data[7:6];
        int       p   = int'(route_port[dst]);
        cur = pkt_fate::type_id::create("fate");
        cur.dst   = dst;
        cur.level = level(p, b.cycle);
        if (cur.level > max_level) max_level = cur.level;
        n_pkts++;
        if (!route_en[dst]) begin
          cur.fate = FATE_NOROUTE;
          noroute_cnt++;
          in_port = -1;
        end else if (cur.level > 8) begin
          cur.fate = FATE_FULL;
          full_cnt++;
          in_port = -1;
        end else begin
          cur.fate = (p == 1) ? FATE_OUT1 : FATE_OUT0;
          in_port = p;
        end
      end
      in_beats++;
      // A forwarded packet's first 8 beats are written to its output, and the
      // 8th always ends it (spec, Oversize packets).
      if (in_port >= 0 && in_beats <= 8) begin
        written[in_port]++;
        // TODO (Part 2): Lab 03 watched only output 0, so this queues only
        // output 0's beats. Queue output 1's as well, once router_env
        // connects output 1's monitor.
        if (in_port == 0) expected[0].push_back({b.last || in_beats == 8, b.data});
        else              n_unwatched++;
      end
      if (b.last) begin
        cur.len = in_beats;
        n_fate[cur.fate]++;
        fate_ap.write(cur);
        in_beats = 0;
      end
    endfunction

    // A beat taken from output b.port.
    function void write_out(stream_beat b);
      int p = b.port;
      bit [8:0] want;
      taken[p]++;
      last_take[p] = b.cycle;
      if (expected[p].size() == 0) begin
        `uvm_error("OUT", $sformatf("output %0d: got %s, and no beat was expected", p,
                   b.convert2string()))
        return;
      end
      want = expected[p].pop_front();
      if (b.data != want[7:0] || b.last != want[8])
        `uvm_error("OUT", $sformatf("output %0d: got %s, expected %02h%s", p, b.convert2string(),
                   want[7:0], want[8] ? string'(" last") : string'("")))
      else
        n_ok[p]++;
    endfunction

    // A completed APB transfer. Writes update the model; reads of DROP_CNT
    // are checked. The tests write registers only while no packet is coming
    // in, so a write never lands in the cycle of a header.
    function void write_apb(apb_item t);
      if (t.slverr) return;
      if (t.write) begin
        if (t.addr == A_DROP_CNT) begin
          noroute_cnt = 0;
          full_cnt    = 0;
        end else if (t.addr inside {8'h20, 8'h24, 8'h28, 8'h2C}) begin
          int r = int'(t.addr[3:2]);      // 20, 24, 28, 2C: ROUTE0 to ROUTE3
          route_en[r]   = t.wdata[0];
          route_port[r] = t.wdata[1];
        end
      end else if (t.addr == A_DROP_CNT) begin
        // Lab 03's check_drops(): {FULL_CNT, NOROUTE_CNT}, each stopping at 255.
        bit [31:0] want = {16'h0, sat(full_cnt), sat(noroute_cnt)};
        n_dropcnt++;
        if (t.rdata != want)
          `uvm_error("DROP_CNT", $sformatf("read %08h, expected %08h (FULL_CNT %0d, NOROUTE_CNT %0d)",
                     t.rdata, want, sat(full_cnt), sat(noroute_cnt)))
        else
          `uvm_info("DROP", $sformatf("DROP_CNT %08h as expected", t.rdata), UVM_LOW)
      end
    endfunction

    // The counters stop at 255 (spec, DROP_CNT).
    function bit [7:0] sat(int unsigned n);
      return n > 255 ? 8'd255 : 8'(n);
    endfunction

    // Beats still expected on either output. The tests wait for 0 before they end.
    function int outstanding();
      return expected[0].size() + expected[1].size();
    endfunction

    function void check_phase(uvm_phase phase);
      foreach (expected[p])
        if (expected[p].size() > 0)
          `uvm_error("LEFT", $sformatf("output %0d: %0d beats were expected and never came out; the first is %02h",
                     p, expected[p].size(), expected[p][0][7:0]))
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SB", $sformatf("%0d packets in: %0d to output 0, %0d to output 1, %0d NOROUTE, %0d FULL; the highest level a header saw was %0d",
                n_pkts, n_fate[FATE_OUT0], n_fate[FATE_OUT1], n_fate[FATE_NOROUTE], n_fate[FATE_FULL],
                max_level), UVM_LOW)
      `uvm_info("SB", $sformatf("beats checked: %0d on output 0, %0d on output 1; %0d DROP_CNT reads checked",
                n_ok[0], n_ok[1], n_dropcnt), UVM_LOW)
      if (n_unwatched > 0)
        `uvm_info("SB", $sformatf("%0d beats went to output 1, which nothing watches", n_unwatched), UVM_LOW)
    endfunction
  endclass

  // ── the coverage ──────────────────────────────────────────────────────────
  // Lab 03's coverage, as a subscriber to the scoreboard's fate_ap: cg_pkt,
  // with Lab 03's coverpoints, bins and cross. It's written `with function
  // sample`, because this simulator leaves out a class's covergroup whose
  // coverpoints read a member of the class (Lab 03, Part 2), and every bin
  // of a crossed coverpoint is written out by name, because an array of bins
  // on a coverpoint in a cross becomes a single bin here. `make cov` lists
  // the bins.
  class router_coverage extends uvm_subscriber #(pkt_fate);
    `uvm_component_utils(router_coverage)

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

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg_pkt = new();
    endfunction

    function void write(pkt_fate t);
      cg_pkt.sample(t.len, int'(t.dst), int'(t.fate), t.level);
    endfunction
  endclass

  // ── the environment ───────────────────────────────────────────────────────
  // Lab 03's env class built its pieces in its constructor and handed them
  // mailboxes. Here build_phase makes them through the factory, and
  // connect_phase joins each monitor's analysis port to the scoreboard.
  class router_env extends uvm_env;
    `uvm_component_utils(router_env)
    src_agent         src;
    apb_agent         apb;
    out_agent         out[2];
    router_scoreboard sb;
    router_coverage   cov;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      src    = src_agent::type_id::create("src", this);
      apb    = apb_agent::type_id::create("apb", this);
      out[0] = out_agent::type_id::create("out0", this);
      // TODO (Part 2): make the agent for output 1, named "out1". The top
      // module and the test have already set its interface and its out_cfg.
      sb     = router_scoreboard::type_id::create("sb", this);
      cov    = router_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      src.mon.ap.connect(sb.in_export);
      apb.mon.ap.connect(sb.apb_export);
      out[0].mon.ap.connect(sb.out_export);
      // TODO (Part 2): connect output 1's monitor to the scoreboard.
      sb.fate_ap.connect(cov.analysis_export);
    endfunction
  endclass
endpackage
