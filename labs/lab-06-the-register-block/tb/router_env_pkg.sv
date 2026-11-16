// DD105-A Lab 06: the scoreboard, the coverage and the environment.
//
//   good_addr             the ten addresses in the register map (Lab 06)
//   pkt_fate              what happened to one input packet, for the coverage
//   router_scoreboard     the scoreboard, fed by analysis ports
//   router_coverage       the covergroup, as a subscriber
//   router_wait_coverage  how long output beats waited (Lab 05)
//   router_vsequencer     the handles a virtual sequence needs (Lab 05)
//   router_env            makes the agents, the scoreboard, the coverage, the
//                         virtual sequencer and the register model, and
//                         connects them
//
// This is Lab 04's solution with Lab 05's additions: the scoreboard follows
// route writes made while packets are coming in, reports the assertions'
// failures, and fails a test that checked nothing; cp_len has an oversize
// bin; and there is a second coverage class and a virtual sequencer.
//
// Lab 06 adds a model of STATUS and INT_EN to the scoreboard, with checks on
// STATUS reads, on PSLVERR and on reads of bad addresses, and the irq check
// (Part 5); and the register model, its adapter and its predictor to the
// environment (Part 3 connects the predictor).
//
// Two TODOs are yours: the predictor's connections in
// router_env::connect_phase (Part 3), and the irq check in
// router_scoreboard::write_sys (Part 5).

package router_env_pkg;
  import uvm_pkg::*;
  import router_agents_pkg::*;
  import router_ral_pkg::*;
  `include "uvm_macros.svh"

  // Register addresses (spec, Register map).
  localparam bit [7:0] A_ID = 8'h00, A_CTRL = 8'h04, A_STATUS = 8'h08, A_INT_EN = 8'h0C,
                       A_DROP_CNT = 8'h10, A_LEVEL = 8'h14, A_ROUTE0 = 8'h20;

  // Lab 06: the ten addresses in the register map. The other 246 are bad,
  // and a transfer to one must end with PSLVERR (spec, APB).
  function automatic bit good_addr(bit [7:0] a);
    return a inside {A_ID, A_CTRL, A_STATUS, A_INT_EN, A_DROP_CNT, A_LEVEL,
                     8'h20, 8'h24, 8'h28, 8'h2C};
  endfunction

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
  `uvm_analysis_imp_decl(_sys)

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
    uvm_analysis_imp_sys #(sys_sample,  router_scoreboard) sys_export;   // Lab 06
    uvm_analysis_port    #(pkt_fate)                       fate_ap;

    // The routing table, as written over APB: bit r is ROUTEr.EN or ROUTEr.PORT.
    bit [3:0]    route_en, route_port;

    // Lab 05: route writes not yet applied, each with the cycle its transfer
    // completed (write_apb). A header accepted in that same cycle still uses
    // the old entry (spec, Routing), so write_in applies a write only when a
    // header comes in a later cycle. The two monitors report a header and a
    // write in the same cycle in either order, so the cycle decides, not the
    // order of the calls.
    typedef struct {
      int unsigned cycle;
      int          r;
      bit          en, port;
    } route_write_t;
    route_write_t pending[$];
    route_write_t w;

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

    // Lab 06: STATUS and INT_EN, cycle by cycle. A drop or an oversize
    // packet in cycle c sets a STATUS bit from cycle c+1, and so does a
    // write that completes in cycle c (spec, STATUS and INT_EN). Each change
    // waits in `changes`, under the cycle it takes effect in, until advance()
    // brings the model to that cycle. A change and a clearing write in the
    // same cycle meet in one entry, and the change wins, as the
    // specification says.
    typedef struct {
      bit [2:0] set;              // STATUS bits that events set
      bit [2:0] clr;              // STATUS bits that a write of 1 clears
      bit       int_en_we;        // INT_EN was written ...
      bit [2:0] int_en;           // ... with this
    } reg_change_t;
    reg_change_t changes[int unsigned];
    int unsigned model_cycle;     // the cycle that status and int_en hold
    bit [2:0]    status, int_en;
    bit [2:0]    status_in[int unsigned];   // STATUS in the last few cycles, for reads
    bit          irq_bad;         // irq was wrong in the cycle before

    // For the report.
    int unsigned n_pkts, n_fate[4], n_ok[2], n_dropcnt;
    int          max_level;       // the highest level a header saw
    int unsigned n_unwatched;     // beats written to an output that nothing watches
    int unsigned n_reads, n_status, n_bad;     // Lab 06: reads, STATUS reads, bad-address transfers
    int unsigned n_irq_checked, n_irq_bad;     // Lab 06: cycles irq was checked, and wrong

    // Lab 05: the bound assertions' failure count (router_ifs.sv, router_tb_top.sv).
    virtual router_sva_if sva;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      in_export  = new("in_export", this);
      out_export = new("out_export", this);
      apb_export = new("apb_export", this);
      sys_export = new("sys_export", this);
      fate_ap    = new("fate_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual router_sva_if)::get(this, "", "sva", sva))
        `uvm_fatal("NOVIF", "the scoreboard has no virtual router_sva_if")
    endfunction

    // The level of output p in cycle t: the beats written into it in cycles
    // before t, minus the beats taken from it in cycles before t (spec,
    // Routing). A beat taken in cycle t itself doesn't count, and its monitor
    // may already have reported it, in the same time step as the header.
    // That is Lab 03's tracker's rule: a cycle's input handshake before its
    // output handshake.
    function int level(int p, int unsigned t);
      int l = written[p] - taken[p];
      if (taken[p] > 0 && last_take[p] == t) l++;
      return l;
    endfunction

    // A beat accepted on the input.
    function void write_in(stream_beat b);
      if (in_beats == 0) begin
        // The header: the router decides here what happens to the whole packet.
        bit [1:0] dst;
        int       p;
        // Lab 05: the route writes that completed before this header's cycle.
        while (pending.size() > 0 && pending[0].cycle < b.cycle) begin
          w = pending.pop_front();
          route_en[w.r]   = w.en;
          route_port[w.r] = w.port;
        end
        dst = b.data[7:6];
        p   = int'(route_port[dst]);
        cur = pkt_fate::type_id::create("fate");
        cur.dst   = dst;
        cur.level = level(p, b.cycle);
        if (cur.level > max_level) max_level = cur.level;
        n_pkts++;
        if (!route_en[dst]) begin
          cur.fate = FATE_NOROUTE;
          noroute_cnt++;
          status_event(b.cycle, 3'b001);    // Lab 06: STATUS.NOROUTE
          in_port = -1;
        end else if (cur.level > 8) begin
          cur.fate = FATE_FULL;
          full_cnt++;
          status_event(b.cycle, 3'b010);    // Lab 06: STATUS.FULL
          in_port = -1;
        end else begin
          cur.fate = (p == 1) ? FATE_OUT1 : FATE_OUT0;
          in_port = p;
        end
      end
      in_beats++;
      // Lab 06: an 8th beat that isn't the last sets STATUS.OVERSIZE,
      // whether or not the packet is forwarded (spec, Oversize packets).
      if (in_beats == 8 && !b.last) status_event(b.cycle, 3'b100);
      // A forwarded packet's first 8 beats are written to its output, and the
      // 8th always ends it (spec, Oversize packets).
      if (in_port >= 0 && in_beats <= 8) begin
        written[in_port]++;
        expected[in_port].push_back({b.last || in_beats == 8, b.data});
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
    // are checked. Lab 04's tests wrote registers only while no packet was
    // coming in; Lab 05's virtual sequence moves routes during traffic, so a
    // route write waits in `pending` for the next header (see write_in). The
    // tests still write DROP_CNT only while no packet is coming in.
    //
    // Lab 06: every transfer's PSLVERR is checked against the address, a
    // read of a bad address must return 0, writes to STATUS and INT_EN go
    // into `changes`, and reads of STATUS are checked. The register model
    // checks reads of ID, CTRL, INT_EN and ROUTEn.
    function void write_apb(apb_item t);
      bit bad = !good_addr(t.addr);
      string what = $sformatf("%s %02h, completing in cycle %0d", t.write ? string'("a write of") : string'("a read of"),
                              t.addr, t.cycle);
      if (!t.write) n_reads++;
      if (t.slverr != bad)
        `uvm_error("APB", $sformatf("%s: pslverr is %0d, but %02h is %s address", what, t.slverr,
                   t.addr, bad ? string'("a bad") : string'("a good")))
      if (bad) begin
        // A bad transfer changes nothing, and a bad read returns 0.
        n_bad++;
        if (!t.write && t.rdata != 0)
          `uvm_error("APB", $sformatf("%s returned %08h; a read of a bad address returns 0", what, t.rdata))
        return;
      end
      if (t.write) begin
        if (t.addr == A_STATUS) begin
          changes[t.cycle + 1].clr |= t.wdata[2:0];
        end else if (t.addr == A_INT_EN) begin
          changes[t.cycle + 1].int_en_we = 1;
          changes[t.cycle + 1].int_en    = t.wdata[2:0];
        end else if (t.addr == A_DROP_CNT) begin
          noroute_cnt = 0;
          full_cnt    = 0;
        end else if (t.addr inside {8'h20, 8'h24, 8'h28, 8'h2C}) begin
          w.cycle = t.cycle;
          w.r     = int'(t.addr[3:2]);    // 20, 24, 28, 2C: ROUTE0 to ROUTE3
          w.en    = t.wdata[0];
          w.port  = t.wdata[1];
          pending.push_back(w);
        end
      end else if (t.addr == A_STATUS) begin
        // Lab 06: a read returns the value in its first access cycle, the
        // cycle before it completes (spec, APB).
        bit [31:0] want;
        advance(t.cycle - 1);
        want = {29'h0, status_in[t.cycle - 1]};
        n_status++;
        if (t.rdata != want)
          `uvm_error("STATUS", $sformatf("%s returned %08h; it should return %08h, STATUS in cycle %0d",
                     what, t.rdata, want, t.cycle - 1))
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

    // Lab 06: an event in cycle c sets STATUS bits from cycle c+1.
    function void status_event(int unsigned c, bit [2:0] bits);
      changes[c + 1].set |= bits;
    endfunction

    // Lab 06: bring STATUS and INT_EN to cycle c, applying every change
    // that takes effect in a cycle up to c, in order. The sys monitor calls
    // this every cycle; a read of STATUS may call it first.
    function void advance(int unsigned c);
      while (model_cycle < c) begin
        model_cycle++;
        if (changes.exists(model_cycle)) begin
          status = (status & ~changes[model_cycle].clr) | changes[model_cycle].set;
          if (changes[model_cycle].int_en_we) int_en = changes[model_cycle].int_en;
          changes.delete(model_cycle);
        end
        status_in[model_cycle] = status;
        if (status_in.exists(model_cycle - 8)) status_in.delete(model_cycle - 8);
      end
    endfunction

    // Lab 06: irq as the specification defines it (INT_EN): any STATUS bit
    // whose enable is set, with no delay.
    function bit irq();
      return |(status & int_en);
    endfunction

    // Lab 06: rst_n and irq in cycle s.cycle, from the sys monitor. In a
    // reset cycle every register is at its reset value. The tests reset the
    // router only at time 0, before anything has happened, so this resets
    // STATUS and INT_EN and nothing else in the scoreboard.
    function void write_sys(sys_sample s);
      if (!s.rst_n) begin
        changes.delete();
        status      = 0;
        int_en      = 0;
        model_cycle = s.cycle;
        status_in[s.cycle] = 0;
        irq_bad     = 0;
        // TODO (Part 5): irq is 0 while rst_n is 0 (the specification's
        // Reset section). Report it with `uvm_error if s.irq is 1 here.
        return;
      end
      advance(s.cycle);
      // TODO (Part 5): check irq in this cycle. s.irq is what the router
      // drove in cycle s.cycle, and irq() is what the specification says it
      // should be, from the model's STATUS and INT_EN (status, int_en) in
      // that cycle. Count each cycle you check in n_irq_checked. When they
      // differ, count the cycle in n_irq_bad, and report it with `uvm_error
      // only if irq was right in the cycle before (irq_bad is 0), so that a
      // wrong irq gives one error, not one per cycle; then set irq_bad to say
      // whether this cycle was wrong. Put status and int_en in the message.
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
      // Lab 05: a test that sent nothing and read nothing checked nothing,
      // so it fails. Lab 06 counts every register read, because the
      // register model checks the reads that the scoreboard doesn't.
      if (n_pkts == 0 && n_reads == 0)
        `uvm_error("SB", "no packet came in and no register was read, so nothing was checked")
      // Lab 05: each failing assertion printed its own %Error line; this
      // makes the test fail through UVM as well.
      if (sva.n_fail > 0)
        `uvm_error("SVA", $sformatf("the bound assertions (router_sva.sv) counted %0d failures; the %%Error lines above name each one",
                   sva.n_fail))
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SB", $sformatf("%0d packets in: %0d to output 0, %0d to output 1, %0d NOROUTE, %0d FULL; the highest level a header saw was %0d",
                n_pkts, n_fate[FATE_OUT0], n_fate[FATE_OUT1], n_fate[FATE_NOROUTE], n_fate[FATE_FULL],
                max_level), UVM_LOW)
      `uvm_info("SB", $sformatf("beats checked: %0d on output 0, %0d on output 1; %0d DROP_CNT reads checked",
                n_ok[0], n_ok[1], n_dropcnt), UVM_LOW)
      `uvm_info("SB", $sformatf("registers: %0d reads, %0d of STATUS checked; %0d transfers to bad addresses; irq checked in %0d cycles, wrong in %0d",
                n_reads, n_status, n_bad, n_irq_checked, n_irq_bad), UVM_LOW)
      if (n_unwatched > 0)
        `uvm_info("SB", $sformatf("%0d beats went to output 1, which nothing watches", n_unwatched), UVM_LOW)
      // Lab 05: the assertions' failure count, printed even when it is 0.
      `uvm_info("SVA", $sformatf("the bound assertions (router_sva.sv) counted %0d failures", sva.n_fail), UVM_LOW)
    endfunction
  endclass

  // ── the coverage ──────────────────────────────────────────────────────────
  // Lab 03's coverage, as a subscriber to the scoreboard's fate_ap: cg_pkt,
  // with Lab 03's coverpoints, bins and cross. Lab 05 adds cp_len's oversize
  // bin: packets of 9 beats or more on the input, before the cut. It's
  // written `with function sample`, because this simulator leaves out a
  // class's covergroup whose coverpoints read a member of the class (Lab 03,
  // Part 2), and every bin of a crossed coverpoint is written out by name,
  // because an array of bins on a coverpoint in a cross becomes a single bin
  // here. `make cov` lists the bins.
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
        bins oversize = {[9:64]};   // Lab 05
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

  // Lab 05: backpressure. For each packet an output delivers, the longest
  // any of its beats waited for out_ready: none is 0 cycles, short_wait 1 to
  // 3, long_wait 4 to 20 and stalled more than 20. It subscribes to both
  // output monitors, which stamp each beat with its wait.
  class router_wait_coverage extends uvm_subscriber #(stream_beat);
    `uvm_component_utils(router_wait_coverage)
    int unsigned max_wait[2];   // the longest wait so far in the packet coming out of each output

    covergroup cg_wait with function sample(int port, int unsigned wait_cycles);
      cp_port: coverpoint port {
        bins out0 = {0};
        bins out1 = {1};
      }
      cp_wait: coverpoint wait_cycles {
        bins none       = {0};
        bins short_wait = {[1:3]};
        bins long_wait  = {[4:20]};
        bins stalled    = {[21:1000000]};
      }
      x_port_wait: cross cp_port, cp_wait;
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg_wait = new();
    endfunction

    function void write(stream_beat t);
      if (t.waited > max_wait[t.port]) max_wait[t.port] = t.waited;
      if (t.last) begin
        cg_wait.sample(t.port, max_wait[t.port]);
        max_wait[t.port] = 0;
      end
    endfunction
  endclass

  // ── the virtual sequencer (Lab 05) ────────────────────────────────────────
  // A virtual sequencer runs no items of its own. It holds handles to the
  // agents' sequencers, so that one virtual sequence can start sequences on
  // all of them, and to what else the sequences steer or wait on: each
  // output's out_cfg (the backpressure), the scoreboard (to know when the
  // outputs are empty) and an interface for the clock. router_env fills
  // them in.
  class router_vsequencer extends uvm_sequencer;
    `uvm_component_utils(router_vsequencer)
    src_sequencer     src_sqr;
    apb_sequencer     apb_sqr;
    out_sequencer     out_sqr[2];
    out_cfg           ocfg[2];
    router_scoreboard sb;
    virtual apb_if    vif;
    router_reg_block  regs;       // Lab 06: the register model
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  // ── the environment ───────────────────────────────────────────────────────
  // Lab 03's env class built its pieces in its constructor and handed them
  // mailboxes. Here build_phase makes them through the factory, and
  // connect_phase joins each monitor's analysis port to the scoreboard.
  class router_env extends uvm_env;
    `uvm_component_utils(router_env)
    src_agent            src;
    apb_agent            apb;
    out_agent            out[2];
    router_scoreboard    sb;
    router_coverage      cov;
    router_wait_coverage wcov;   // Lab 05
    router_vsequencer    vsqr;   // Lab 05
    sys_monitor          sys;    // Lab 06
    router_reg_block     regs;   // Lab 06: the register model ...
    router_reg_adapter   adapter;                  // ... its adapter ...
    uvm_reg_predictor #(apb_item) predictor;       // ... and its predictor

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      src    = src_agent::type_id::create("src", this);
      apb    = apb_agent::type_id::create("apb", this);
      out[0] = out_agent::type_id::create("out0", this);
      out[1] = out_agent::type_id::create("out1", this);
      sb     = router_scoreboard::type_id::create("sb", this);
      cov    = router_coverage::type_id::create("cov", this);
      wcov   = router_wait_coverage::type_id::create("wcov", this);
      vsqr   = router_vsequencer::type_id::create("vsqr", this);
      // Lab 06: the register model is an object, not a component, so it is
      // built here by hand. Its build() makes the registers and the map, and
      // reset() sets every field's mirror to its reset value, as the router's
      // registers are after the reset at time 0.
      sys       = sys_monitor::type_id::create("sys", this);
      regs      = router_reg_block::type_id::create("regs");
      regs.build();
      regs.reset();
      adapter   = router_reg_adapter::type_id::create("adapter");
      predictor = uvm_reg_predictor#(apb_item)::type_id::create("predictor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      src.mon.ap.connect(sb.in_export);
      apb.mon.ap.connect(sb.apb_export);
      out[0].mon.ap.connect(sb.out_export);
      out[1].mon.ap.connect(sb.out_export);
      sb.fate_ap.connect(cov.analysis_export);
      // Lab 05: the wait coverage, and the virtual sequencer's handles. Each
      // agent's driver has fetched its interface and out_cfg in build_phase.
      foreach (out[p]) begin
        out[p].mon.ap.connect(wcov.analysis_export);
        vsqr.out_sqr[p] = out[p].sqr;
        vsqr.ocfg[p]    = out[p].drv.cfg;
      end
      vsqr.src_sqr = src.sqr;
      vsqr.apb_sqr = apb.sqr;
      vsqr.sb      = sb;
      vsqr.vif     = apb.drv.vif;

      // Lab 06: irq and rst_n to the scoreboard, and the register model's
      // operations to the APB sequencer through the adapter. Auto-predict is
      // off: the model learns what the registers hold only from the
      // predictor below.
      sys.ap.connect(sb.sys_export);
      vsqr.regs = regs;
      regs.default_map.set_sequencer(apb.sqr, adapter);
      regs.default_map.set_auto_predict(0);

      // TODO (Part 3): the predictor. Give it the map and the adapter
      // (predictor.map, predictor.adapter), connect the APB monitor's
      // analysis port (apb.mon.ap) to its bus_in, and turn on the map's
      // check-on-read (regs.default_map.set_check_on_read(1)), so that every
      // read the predictor sees is compared with the mirror.
    endfunction
  endclass
endpackage
