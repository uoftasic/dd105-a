// DD105-A Lab 06: everything above the agents.
//
//   router_sys_agent    drives rst_n, and samples rst_n, irq and the assertion
//                       count every cycle
//   router_model        the router as the specification describes it, one
//                       cycle at a time
//   router_scoreboard   runs the model on what the monitors saw and reports
//                       every place the router disagrees with it
//   router_coverage     functional coverage, every covergroup written
//                       "with function sample", which is the form this
//                       simulator supports in a class
//   router_vsequencer   the handles a virtual sequence needs
//   router_env          builds and connects the lot, and the register model
//                       (router_ral_pkg) with its adapter and predictor
//
// Lab 06 has two TODOs here: the predictor's connections in
// router_env::connect_phase (Part 3), and the scoreboard's irq check in
// router_scoreboard::process (Part 5).
//
// The scoreboard is cycle-exact because the specification is. It needs to
// know, for every cycle, what happened on every port, so every monitor
// stamps its transactions with the cycle number, and the reset/irq monitor
// sends one sample per cycle. That sample is also the scoreboard's clock:
// when the sample for cycle t arrives, every transaction of cycle t-1 has
// already arrived (they were all written at the edge that ended cycle t-1),
// so the scoreboard runs the model through cycle t-1.

package router_env_pkg;
  import uvm_pkg::*;
  import apb_pkg::*;
  import stream_pkg::*;
  import router_ral_pkg::*;
  `include "uvm_macros.svh"


  // ══════════════════════════════════════════════════════════════════════════
  // Reset and interrupt agent
  // ══════════════════════════════════════════════════════════════════════════

  // A request for a reset: rst_n low for `cycles` cycles.
  class router_reset_item extends uvm_sequence_item;
    `uvm_object_utils(router_reset_item)
    int unsigned cycles = 3;
    function new(string name = "router_reset_item");
      super.new(name);
    endfunction
  endclass

  // What the monitor saw in one cycle.
  class router_sys_sample extends uvm_sequence_item;
    `uvm_object_utils(router_sys_sample)
    int unsigned cycle;
    bit          rst_n;
    bit          irq;
    int unsigned sva_fails;
    function new(string name = "router_sys_sample");
      super.new(name);
    endfunction
  endclass

  typedef uvm_sequencer #(router_reset_item) router_sys_sequencer;

  class router_sys_driver extends uvm_driver #(router_reset_item);
    `uvm_component_utils(router_sys_driver)
    virtual router_sys_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual router_sys_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "router_sys_driver has no router_sys_if")
    endfunction
    // At edge x the driver announces that cycle x+2 starts the reset (the
    // APB driver reads it at edge x+1 and keeps psel at 0 from cycle x+2),
    // and at edge x+1 it drives rst_n low for cycles x+2 onwards.
    task run_phase(uvm_phase phase);
      forever begin
        seq_item_port.get_next_item(req);
        @(vif.cb);
        vif.rst_at = vif.cb.cycle + 2;
        @(vif.cb);
        vif.cb.rst_n <= 1'b0;
        repeat (req.cycles) @(vif.cb);
        vif.cb.rst_n <= 1'b1;
        vif.rst_at = 0;
        seq_item_port.item_done();
      end
    endtask
  endclass

  class router_sys_monitor extends uvm_monitor;
    `uvm_component_utils(router_sys_monitor)
    uvm_analysis_port #(router_sys_sample) ap;
    virtual router_sys_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual router_sys_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "router_sys_monitor has no router_sys_if")
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        router_sys_sample s;
        @(vif.mon_cb);
        s = router_sys_sample::type_id::create("s");
        s.cycle     = vif.mon_cb.cycle;
        s.rst_n     = vif.mon_cb.rst_n;
        s.irq       = vif.mon_cb.irq;
        s.sva_fails = vif.mon_cb.sva_fails;
        ap.write(s);
      end
    endtask
  endclass

  class router_sys_agent extends uvm_agent;
    `uvm_component_utils(router_sys_agent)
    router_sys_sequencer sqr;
    router_sys_driver    drv;
    router_sys_monitor   mon;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = router_sys_sequencer::type_id::create("sqr", this);
      drv = router_sys_driver::type_id::create("drv", this);
      mon = router_sys_monitor::type_id::create("mon", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  class router_reset_seq extends uvm_sequence #(router_reset_item);
    `uvm_object_utils(router_reset_seq)
    int unsigned cycles = 3;
    function new(string name = "router_reset_seq");
      super.new(name);
    endfunction
    task body();
      router_reset_item r = router_reset_item::type_id::create("r");
      start_item(r);
      r.cycles = cycles;
      finish_item(r);
    endtask
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Reference model
  // ══════════════════════════════════════════════════════════════════════════

  typedef enum int {ACT_NOROUTE = 0, ACT_FULL = 1, ACT_OUT0 = 2, ACT_OUT1 = 3} act_e;

  // The corners the coverage counts. The scoreboard sees each one happen.
  typedef enum int {
    C_CNT_CLEAR_WITH_DROP,      // a DROP_CNT write completes in the cycle of a drop (E9)
    C_STATUS_CLEAR_WITH_EVENT,  // a STATUS write clears a bit an event sets in the same cycle
    C_ROUTE_WRITE_WITH_HEADER,  // ROUTE[DST] written in the cycle its header is accepted
    C_CTRL_WRITE_WITH_HEADER,   // CTRL written in the cycle a header is accepted
    C_CTRL_OFF_MID_PACKET,      // CTRL.EN cleared while a packet is coming in (E7)
    C_NOROUTE_SATURATED,        // a NOROUTE drop with NOROUTE_CNT already 255
    C_FULL_SATURATED,           // a FULL drop with FULL_CNT already 255
    C_ADMIT_AT_8,               // a packet admitted with its output at exactly 8
    C_DROP_AT_9,                // a FULL drop with its output at exactly 9
    C_HEADER_WITH_TAKE,         // a header decided in a cycle its output hands a beat over
    C_LEVEL_READ_WITH_BEAT,     // LEVEL read in a first access cycle with an input beat
    C_RESET_WITH_BEATS,         // a reset with beats still in a buffer (E8)
    C_RESET_MID_PACKET,         // a reset with a packet half accepted
    C_IRQ_RISE,
    C_IRQ_FALL,
    C_OVERSIZE_DROPPED,         // an oversize packet that was also dropped
    C_APB_BACK_TO_BACK,         // a setup cycle right after a transfer completed (A3)
    C_NCORNERS
  } corner_e;

  class router_corner extends uvm_object;
    `uvm_object_utils(router_corner)
    corner_e kind;
    function new(string name = "router_corner");
      super.new(name);
    endfunction
  endclass

  // One input packet, as the model handled it. The scoreboard sends one to
  // the coverage when the packet's last beat is accepted.
  class router_pkt_info extends uvm_object;
    `uvm_object_utils(router_pkt_info)
    bit [1:0]    dst;
    act_e        act;
    int          level;        // the level of output PORT in the header's cycle
    int unsigned len;          // beats accepted, header included
    bit          oversize;
    int unsigned hdr_cycle;
    function new(string name = "router_pkt_info");
      super.new(name);
    endfunction
  endclass

  class exp_beat;
    bit [7:0]    data;
    bit          last;
    int unsigned t_in;         // the cycle of its input handshake
  endclass

  // One output buffer, as the model sees it.
  class out_state;
    exp_beat q[$];             // beats written and not yet taken, oldest first
    int      level;            // the level in the cycle being processed
    longint  h_prev;           // the cycle the previous beat was taken; -1 since reset
    function new();
      h_prev = -1;
    endfunction
  endclass

  class router_model;
    // Registers, as they are in the cycle being processed.
    bit       ctrl_en;
    bit [2:0] status;
    bit [2:0] int_en;
    bit [7:0] nr_cnt, full_cnt;
    bit       route_en[4];
    bit       route_port[4];
    out_state outs[2];

    // The input side.
    bit             in_pkt;      // a packet's header is in and its in_last beat isn't
    int unsigned    beats;       // beats of the current packet accepted so far
    act_e           act;         // what happens to the current packet
    bit             cutting;     // past the 8th beat of an oversize packet
    router_pkt_info info;        // the current packet, for the coverage

    // What the cycle being processed does, applied by end_cycle().
    bit [2:0] ev_status;
    bit       ev_nr, ev_full;
    int       wr[2], tk[2];

    function new();
      outs[0] = new();
      outs[1] = new();
      reset();
    endfunction

    // The reset values of the register map, empty buffers, and no packet.
    function void reset();
      ctrl_en  = 0;
      status   = 0;
      int_en   = 0;
      nr_cnt   = 0;
      full_cnt = 0;
      foreach (route_en[n]) begin
        route_en[n]   = 0;
        route_port[n] = 0;
      end
      foreach (outs[p]) begin
        outs[p].q.delete();
        outs[p].level  = 0;
        outs[p].h_prev = -1;
      end
      in_pkt  = 0;
      beats   = 0;
      cutting = 0;
      info    = null;
      begin_cycle();
    endfunction

    static function bit good_addr(bit [7:0] a);
      return a inside {8'h00, 8'h04, 8'h08, 8'h0C, 8'h10, 8'h14, 8'h20, 8'h24, 8'h28, 8'h2C};
    endfunction

    static function string reg_name(bit [7:0] a);
      case (a)
        8'h00: return "ID";
        8'h04: return "CTRL";
        8'h08: return "STATUS";
        8'h0C: return "INT_EN";
        8'h10: return "DROP_CNT";
        8'h14: return "LEVEL";
        8'h20: return "ROUTE0";
        8'h24: return "ROUTE1";
        8'h28: return "ROUTE2";
        8'h2C: return "ROUTE3";
        default: return "a bad address";
      endcase
    endfunction

    // What a read of address a returns in this cycle (0 for a bad address).
    function bit [31:0] reg_value(bit [7:0] a);
      case (a)
        8'h00: return 32'hD105_0001;
        8'h04: return {31'b0, ctrl_en};
        8'h08: return {29'b0, status};
        8'h0C: return {29'b0, int_en};
        8'h10: return {16'b0, full_cnt, nr_cnt};
        8'h14: return {19'b0, 5'(outs[1].level), 3'b0, 5'(outs[0].level)};
        8'h20: return {30'b0, route_port[0], route_en[0]};
        8'h24: return {30'b0, route_port[1], route_en[1]};
        8'h28: return {30'b0, route_port[2], route_en[2]};
        8'h2C: return {30'b0, route_port[3], route_en[3]};
        default: return 32'h0;
      endcase
    endfunction

    // in_ready in this cycle: 1 inside a packet, CTRL.EN between packets.
    function bit in_ready();
      return in_pkt || ctrl_en;
    endfunction

    // irq in this cycle: a plain combination of STATUS and INT_EN.
    function bit irq();
      return |(status & int_en);
    endfunction

    function void begin_cycle();
      ev_status = 0;
      ev_nr     = 0;
      ev_full   = 0;
      wr[0] = 0; wr[1] = 0;
      tk[0] = 0; tk[1] = 0;
    endfunction

    function void push(int p, bit [7:0] data, bit last, int unsigned t);
      exp_beat b = new();
      b.data = data;
      b.last = last;
      b.t_in = t;
      outs[p].q.push_back(b);
      wr[p]++;
    endfunction

    // A beat accepted in cycle t. Returns the packet's info when this beat
    // ends the packet (its in_last beat), otherwise null.
    function router_pkt_info accept(bit [7:0] data, bit last, int unsigned t);
      router_pkt_info done = null;
      if (!in_pkt) begin
        // The header. The decision uses ROUTE[DST] and the output's level as
        // they are in this cycle; a write completing now changes neither yet.
        bit [1:0] d = data[7:6];
        int p = route_port[d];
        info = new();
        info.dst = d;
        info.hdr_cycle = t;
        info.level = outs[p].level;
        beats = 1;
        cutting = 0;
        if (!route_en[d]) begin
          act = ACT_NOROUTE;
          ev_nr = 1;
          ev_status[0] = 1;
        end else if (outs[p].level > 8) begin
          act = ACT_FULL;
          ev_full = 1;
          ev_status[1] = 1;
        end else begin
          act = p ? ACT_OUT1 : ACT_OUT0;
          push(p, data, last, t);
        end
        info.act = act;
        in_pkt = !last;
      end else begin
        beats++;
        if (cutting) begin
          // An oversize packet's tail: taken and thrown away.
        end else if (beats == 8 && !last) begin
          // The 8th beat isn't the last: the packet is oversize. A forwarded
          // one ends here, with out_last on this beat.
          ev_status[2] = 1;
          cutting = 1;
          info.oversize = 1;
          if (act == ACT_OUT0 || act == ACT_OUT1) push(act == ACT_OUT1, data, 1'b1, t);
        end else if (act == ACT_OUT0 || act == ACT_OUT1) begin
          push(act == ACT_OUT1, data, last, t);
        end
        if (last) in_pkt = 0;
      end
      if (!in_pkt) begin
        info.len = beats;
        done = info;
        info = null;
      end
      return done;
    endfunction

    // A write to a good address, completing in this cycle. It takes effect at
    // the edge that ends the cycle. STATUS's write-1-to-clear is applied here
    // and this cycle's events are OR'ed in afterwards, so an event wins; the
    // DROP_CNT clear is applied here and this cycle's drop is counted after it.
    function void reg_write(bit [7:0] a, bit [31:0] d);
      case (a)
        8'h04: ctrl_en = d[0];
        8'h08: status  = status & ~d[2:0];
        8'h0C: int_en  = d[2:0];
        8'h10: begin nr_cnt = 0; full_cnt = 0; end
        8'h20: begin route_en[0] = d[0]; route_port[0] = d[1]; end
        8'h24: begin route_en[1] = d[0]; route_port[1] = d[1]; end
        8'h28: begin route_en[2] = d[0]; route_port[2] = d[1]; end
        8'h2C: begin route_en[3] = d[0]; route_port[3] = d[1]; end
        default: ;   // ID and LEVEL ignore writes
      endcase
    endfunction

    // The beat at the front of output p, taken in this cycle (null if none).
    function exp_beat take(int p);
      tk[p]++;
      if (outs[p].q.size() == 0) return null;
      return outs[p].q.pop_front();
    endfunction

    // The edge that ends the cycle.
    function void end_cycle();
      status |= ev_status;
      if (ev_nr   && nr_cnt   != 8'd255) nr_cnt++;
      if (ev_full && full_cnt != 8'd255) full_cnt++;
      foreach (outs[p]) begin
        outs[p].level += wr[p] - tk[p];
        if (outs[p].level < 0) outs[p].level = 0;
      end
      begin_cycle();
    endfunction

    function bit idle();
      return outs[0].q.size() == 0 && outs[1].q.size() == 0 && !in_pkt;
    endfunction
  endclass

  // Register values in one cycle, for reads whose first access cycle it was.
  class reg_snap;
    bit [31:0] v[12];          // indexed by address / 4, 0x00 to 0x2C
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Scoreboard
  // ══════════════════════════════════════════════════════════════════════════

  `uvm_analysis_imp_decl(_in)
  `uvm_analysis_imp_decl(_out0)
  `uvm_analysis_imp_decl(_out1)
  `uvm_analysis_imp_decl(_apb)
  `uvm_analysis_imp_decl(_sys)

  class router_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(router_scoreboard)

    uvm_analysis_imp_in   #(stream_beat,       router_scoreboard) in_imp;
    uvm_analysis_imp_out0 #(stream_beat,       router_scoreboard) out0_imp;
    uvm_analysis_imp_out1 #(stream_beat,       router_scoreboard) out1_imp;
    uvm_analysis_imp_apb  #(apb_item,          router_scoreboard) apb_imp;
    uvm_analysis_imp_sys  #(router_sys_sample, router_scoreboard) sys_imp;
    uvm_analysis_port #(router_pkt_info) pkt_ap;
    uvm_analysis_port #(router_corner)   corner_ap;

    router_model m;

    // Transactions waiting for their cycle to be processed, by cycle.
    stream_beat       in_at[int unsigned];
    stream_beat       out0_at[int unsigned];
    stream_beat       out1_at[int unsigned];
    apb_item          apb_at[int unsigned];
    router_sys_sample sys_at[int unsigned];
    reg_snap          snaps[int unsigned];

    int unsigned next_cycle = 1;     // the next cycle to process
    int unsigned last_seen  = 0;     // the latest cycle a sample arrived for
    longint      last_rdy1  = -1;    // the latest processed cycle with in_ready predicted 1
    bit          in_reset   = 1;
    bit          last_irq   = 0;
    bit          irq_bad    = 0;     // irq was wrong in the previous cycle
    int unsigned sva_fails  = 0;
    int unsigned last_apb_end = 0;   // the cycle the previous APB transfer completed

    // Totals for the report.
    int unsigned n_in_beats, n_pkts, n_fwd, n_noroute, n_full, n_oversize;
    int unsigned n_out_beats, n_reads, n_writes, n_bad, n_resets, n_cycles;
    int unsigned n_irq_checked, n_irq_bad;
    int unsigned n_corner[C_NCORNERS];

    function new(string name, uvm_component parent);
      super.new(name, parent);
      in_imp    = new("in_imp", this);
      out0_imp  = new("out0_imp", this);
      out1_imp  = new("out1_imp", this);
      apb_imp   = new("apb_imp", this);
      sys_imp   = new("sys_imp", this);
      pkt_ap    = new("pkt_ap", this);
      corner_ap = new("corner_ap", this);
      m = new();
    endfunction

    // ── collecting ─────────────────────────────────────────────────────────
    function void write_in(stream_beat b);
      in_at[b.cycle] = b;
    endfunction
    function void write_out0(stream_beat b);
      out0_at[b.cycle] = b;
    endfunction
    function void write_out1(stream_beat b);
      out1_at[b.cycle] = b;
    endfunction
    function void write_apb(apb_item a);
      if (a.setup_cycle == last_apb_end + 1) corner(C_APB_BACK_TO_BACK);
      last_apb_end = a.end_cycle;
      apb_at[a.end_cycle] = a;
    endfunction
    function void write_sys(router_sys_sample s);
      sys_at[s.cycle] = s;
      if (s.cycle > last_seen) last_seen = s.cycle;
      while (next_cycle < s.cycle) begin
        process(next_cycle);
        next_cycle++;
      end
    endfunction

    function void corner(corner_e k);
      router_corner c = new();
      c.kind = k;
      n_corner[k]++;
      corner_ap.write(c);
    endfunction

    function bit idle();
      return m.idle() && in_at.num() == 0 && out0_at.num() == 0 && out1_at.num() == 0;
    endfunction

    // ── one cycle ──────────────────────────────────────────────────────────
    function void process(int unsigned t);
      router_sys_sample s;
      stream_beat ib, ob[2];
      apb_item a;
      router_pkt_info done;
      bit rdy, hdr = 0;
      bit [1:0] hdr_dst;
      int hdr_port;

      if (!sys_at.exists(t)) return;
      s = sys_at[t];
      sys_at.delete(t);
      if (in_at.exists(t))   begin ib    = in_at[t];   in_at.delete(t);   end
      if (out0_at.exists(t)) begin ob[0] = out0_at[t]; out0_at.delete(t); end
      if (out1_at.exists(t)) begin ob[1] = out1_at[t]; out1_at.delete(t); end
      if (apb_at.exists(t))  begin a     = apb_at[t];  apb_at.delete(t);  end
      if (t > 64 && snaps.exists(t - 64)) snaps.delete(t - 64);
      sva_fails = s.sva_fails;
      n_cycles++;

      // ── a reset cycle: everything is gone, and nothing moves ─────────────
      if (!s.rst_n) begin
        if (!in_reset) begin
          int lost = m.outs[0].q.size() + m.outs[1].q.size();
          n_resets++;
          if (lost > 0) corner(C_RESET_WITH_BEATS);
          if (m.in_pkt) corner(C_RESET_MID_PACKET);
          `uvm_info("SB", $sformatf("reset from cycle %0d: %0d expected beats are lost", t, lost),
                    UVM_MEDIUM)
        end
        in_reset = 1;
        m.reset();
        // TODO (Part 5): irq is 0 while rst_n is 0 (the specification's
        // Reset section). Report it with `uvm_error if s.irq is 1 here.
        if (ib != null || ob[0] != null || ob[1] != null || a != null)
          `uvm_error("SB", $sformatf("a monitor saw a transfer in cycle %0d, a reset cycle", t))
        last_irq = 0;
        irq_bad = 0;
        return;
      end
      in_reset = 0;

      // The register values in this cycle, for a read whose first access it is.
      begin
        reg_snap r = new();
        for (int i = 0; i < 12; i++) r.v[i] = m.reg_value(8'(4 * i));
        snaps[t] = r;
      end

      // ── irq ───────────────────────────────────────────────────────────────
      // TODO (Part 5): check irq in every cycle. s.irq is what the router
      // drove in cycle t, and m.irq() is what the specification says it
      // should be, from the model's STATUS and INT_EN as they are in cycle t.
      // Count each cycle you check in n_irq_checked. When they differ, count
      // the cycle in n_irq_bad, and report it with `uvm_error only if irq
      // was right in the cycle before (irq_bad is 0), so that a wrong irq
      // gives one error, not one per cycle; then set irq_bad to say whether
      // this cycle was wrong. Put STATUS (m.status) and INT_EN (m.int_en) in
      // the message.
      if (s.irq && !last_irq) corner(C_IRQ_RISE);
      if (!s.irq && last_irq) corner(C_IRQ_FALL);
      last_irq = s.irq;

      // ── the input: in_ready, then the beat ────────────────────────────────
      rdy = m.in_ready();
      if (ib != null) begin
        n_in_beats++;
        if (!rdy) begin
          `uvm_error("SB", $sformatf("the router accepted %02h in cycle %0d, but in_ready should be 0 then: it is between packets and CTRL.EN is 0 (rule I5)",
                     ib.data, t))
        end else if (ib.first_cycle < t && last_rdy1 >= longint'(ib.first_cycle)) begin
          `uvm_error("SB", $sformatf("beat %02h was offered from cycle %0d and taken in cycle %0d, but in_ready should have been 1 in cycle %0d (%s)",
                     ib.data, ib.first_cycle, t, last_rdy1,
                     m.in_pkt ? string'("inside a packet, rule I6") : string'("between packets with CTRL.EN = 1, rule I5")))
        end
        hdr = !m.in_pkt;
        if (hdr) begin
          hdr_dst  = ib.data[7:6];
          hdr_port = m.route_port[hdr_dst];
          if (m.route_en[hdr_dst] && m.outs[hdr_port].level == 8) corner(C_ADMIT_AT_8);
          if (m.route_en[hdr_dst] && m.outs[hdr_port].level == 9) corner(C_DROP_AT_9);
          if (m.route_en[hdr_dst] && ob[hdr_port] != null) corner(C_HEADER_WITH_TAKE);
        end
        done = m.accept(ib.data, ib.last, t);
        if (m.ev_nr && m.nr_cnt == 8'd255) corner(C_NOROUTE_SATURATED);
        if (m.ev_full && m.full_cnt == 8'd255) corner(C_FULL_SATURATED);
      end
      if (rdy) last_rdy1 = t;

      // ── APB ───────────────────────────────────────────────────────────────
      if (a != null) check_apb(a, t, ib, hdr, hdr_dst);

      // ── the outputs ───────────────────────────────────────────────────────
      for (int p = 0; p < 2; p++)
        if (ob[p] != null) check_out(p, ob[p], t);

      m.end_cycle();

      if (done != null) begin
        n_pkts++;
        case (done.act)
          ACT_NOROUTE: n_noroute++;
          ACT_FULL:    n_full++;
          default:     n_fwd++;
        endcase
        if (done.oversize) n_oversize++;
        if (done.oversize && (done.act == ACT_NOROUTE || done.act == ACT_FULL))
          corner(C_OVERSIZE_DROPPED);
        pkt_ap.write(done);
      end
    endfunction

    function void check_apb(apb_item a, int unsigned t, stream_beat ib, bit hdr, bit [1:0] hdr_dst);
      bit bad = !router_model::good_addr(a.addr);
      string what = $sformatf("%s of %s (%02h), completing in cycle %0d",
                              a.write ? string'("a write") : string'("a read"), router_model::reg_name(a.addr), a.addr, t);
      if (bad) n_bad++;
      if (a.slverr != bad)
        `uvm_error("SB", $sformatf("%s: pslverr is %0d, but %02h is %s address", what, a.slverr, a.addr,
                   bad ? string'("a bad") : string'("a good")))
      if (!a.write) begin
        bit [31:0] exp = 32'h0;
        n_reads++;
        if (!bad) begin
          if (!snaps.exists(a.access_cycle)) begin
            `uvm_info("SB", $sformatf("%s: no record of cycle %0d, so it isn't checked", what,
                      a.access_cycle), UVM_LOW)
            return;
          end
          exp = snaps[a.access_cycle].v[a.addr >> 2];
        end
        if (a.addr == 8'h14 && ib != null && a.access_cycle == t - 1) corner(C_LEVEL_READ_WITH_BEAT);
        if (a.rdata != exp)
          `uvm_error("SB", $sformatf("%s returned %08h; it should return %08h, %s", what, a.rdata, exp,
                     bad ? string'("as every bad read does") :
                     $sformatf("the value in cycle %0d (its first access cycle)", a.access_cycle)))
        return;
      end
      n_writes++;
      if (bad) return;             // a bad write changes nothing
      // The corners that need a write and an event in the same cycle.
      if (a.addr == 8'h10 && (m.ev_nr || m.ev_full)) corner(C_CNT_CLEAR_WITH_DROP);
      if (a.addr == 8'h08 && (a.wdata[2:0] & m.ev_status) != 0) corner(C_STATUS_CLEAR_WITH_EVENT);
      if (hdr && a.addr == 8'h20 + 4 * hdr_dst) corner(C_ROUTE_WRITE_WITH_HEADER);
      if (hdr && a.addr == 8'h04) corner(C_CTRL_WRITE_WITH_HEADER);
      if (a.addr == 8'h04 && !a.wdata[0] && m.ctrl_en && m.in_pkt) corner(C_CTRL_OFF_MID_PACKET);
      m.reg_write(a.addr, a.wdata);
    endfunction

    function void check_out(int p, stream_beat ob, int unsigned t);
      longint h_prev = m.outs[p].h_prev;
      exp_beat e = m.take(p);
      m.outs[p].h_prev = t;
      n_out_beats++;
      if (e == null) begin
        `uvm_error("SB", $sformatf("output %0d delivered %s, but no beat was waiting for it there",
                   p, ob.convert2string()))
        return;
      end
      if (ob.data != e.data || ob.last != e.last) begin
        `uvm_error("SB", $sformatf("output %0d delivered %02h with out_last = %0d in cycle %0d; it should be %02h with out_last = %0d (accepted in cycle %0d)",
                   p, ob.data, ob.last, t, e.data, e.last, e.t_in))
        return;
      end
      begin
        longint a_k = longint'(e.t_in) + 2;
        if (h_prev + 1 > a_k) a_k = h_prev + 1;
        if (longint'(ob.first_cycle) != a_k)
          `uvm_error("SB", $sformatf("output %0d: beat %02h appeared in cycle %0d, but rule O8 puts it in cycle %0d (accepted in cycle %0d; the beat before it was taken in cycle %0d)",
                     p, ob.data, ob.first_cycle, a_k, e.t_in, h_prev))
      end
    endfunction

    // ── the end of the test ────────────────────────────────────────────────
    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      // The transactions of the last cycles: their samples are all in.
      while (next_cycle <= last_seen) begin
        process(next_cycle);
        next_cycle++;
      end
      foreach (m.outs[p])
        if (m.outs[p].q.size() > 0)
          `uvm_error("SB", $sformatf("%0d beats routed to output %0d never came out; the first is %02h, accepted in cycle %0d",
                     m.outs[p].q.size(), p, m.outs[p].q[0].data, m.outs[p].q[0].t_in))
      if (n_in_beats == 0 && n_reads == 0)
        `uvm_error("SB", "the router accepted no beats and no register was read, so nothing was checked")
      if (sva_fails > 0)
        `uvm_error("SVA", $sformatf("the bound assertions (router_sva.sv) counted %0d failures; the %%Error lines above name each one",
                   sva_fails))
    endfunction

    function void report_phase(uvm_phase phase);
      string s;
      super.report_phase(phase);
      `uvm_info("SB", $sformatf("%0d cycles, %0d resets; %0d input beats in %0d packets: %0d forwarded, %0d NOROUTE, %0d FULL, %0d oversize; %0d output beats",
                n_cycles, n_resets, n_in_beats, n_pkts, n_fwd, n_noroute, n_full, n_oversize, n_out_beats),
                UVM_LOW)
      `uvm_info("SB", $sformatf("%0d register reads checked, %0d writes, %0d to bad addresses; %0d assertion failures",
                n_reads, n_writes, n_bad, sva_fails), UVM_LOW)
      `uvm_info("SB", $sformatf("irq checked in %0d cycles, wrong in %0d", n_irq_checked, n_irq_bad),
                UVM_LOW)
      s = "corners hit:";
      for (int k = 0; k < C_NCORNERS; k++) begin
        corner_e c = corner_e'(k);
        s = {s, $sformatf(" %s=%0d", c.name(), n_corner[k])};
      end
      `uvm_info("SB", s, UVM_LOW)
    endfunction
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Coverage
  // ══════════════════════════════════════════════════════════════════════════

  `uvm_analysis_imp_decl(_cpkt)
  `uvm_analysis_imp_decl(_capb)
  `uvm_analysis_imp_decl(_ccorner)
  `uvm_analysis_imp_decl(_cwait0)
  `uvm_analysis_imp_decl(_cwait1)

  class router_coverage extends uvm_component;
    `uvm_component_utils(router_coverage)
    uvm_analysis_imp_cpkt    #(router_pkt_info, router_coverage) pkt_imp;
    uvm_analysis_imp_capb    #(apb_item,        router_coverage) apb_imp;
    uvm_analysis_imp_ccorner #(router_corner,   router_coverage) corner_imp;
    uvm_analysis_imp_cwait0  #(stream_obs_pkt,  router_coverage) wait0_imp;
    uvm_analysis_imp_cwait1  #(stream_obs_pkt,  router_coverage) wait1_imp;

    // Every packet: how long, where it was going, what happened to it, and
    // how full its output was when its header was decided.
    //
    // A coverpoint that is part of a cross has every bin written out: this
    // simulator turns an array of bins such as `bins len[] = {[2:7]}` into a
    // single bin when its coverpoint is crossed, without a warning.
    covergroup cg_pkt with function sample(int len, int dst, int act, int level);
      cp_len: coverpoint len {
        bins len1 = {1};
        bins len2 = {2};
        bins len3 = {3};
        bins len4 = {4};
        bins len5 = {5};
        bins len6 = {6};
        bins len7 = {7};
        bins len8 = {8};
        bins oversize = {[9:64]};
      }
      cp_dst: coverpoint dst {
        bins dst0 = {0};
        bins dst1 = {1};
        bins dst2 = {2};
        bins dst3 = {3};
      }
      cp_act: coverpoint act {
        bins noroute = {0};
        bins full = {1};
        bins out0 = {2};
        bins out1 = {3};
      }
      cp_level: coverpoint level {
        bins empty = {0};
        bins low = {[1:7]};
        bins at_8 = {8};
        bins at_9 = {9};
        bins high = {[10:16]};
      }
      x_dst_act: cross cp_dst, cp_act;
      x_len_act: cross cp_len, cp_act;
    endgroup

    // Every APB transfer: which register (or kind of bad address), which way.
    covergroup cg_apb with function sample(int areg, int write, int slverr);
      cp_reg: coverpoint areg {
        bins id = {0};
        bins ctrl = {1};
        bins status = {2};
        bins int_en = {3};
        bins drop_cnt = {4};
        bins level = {5};
        bins route0 = {8};
        bins route1 = {9};
        bins route2 = {10};
        bins route3 = {11};
        bins bad_aligned = {12};
        bins bad_unaligned = {13};
      }
      cp_write: coverpoint write { bins read = {0}; bins write = {1}; }
      cp_slverr: coverpoint slverr { bins ok = {0}; bins err = {1}; }
      x_reg_write: cross cp_reg, cp_write;
    endgroup

    // The same-cycle and boundary corners the scoreboard saw.
    covergroup cg_corner with function sample(int kind);
      cp_kind: coverpoint kind { bins corner[] = {[0:C_NCORNERS-1]}; }
    endgroup

    // Backpressure: the longest any beat of an output packet waited.
    covergroup cg_wait with function sample(int port, int max_wait);
      cp_port: coverpoint port {
        bins out0 = {0};
        bins out1 = {1};
      }
      cp_wait: coverpoint max_wait {
        bins none = {0};
        bins short_wait = {[1:3]};
        bins long_wait = {[4:20]};
        bins stalled = {[21:1000000]};
      }
      x_port_wait: cross cp_port, cp_wait;
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      pkt_imp    = new("pkt_imp", this);
      apb_imp    = new("apb_imp", this);
      corner_imp = new("corner_imp", this);
      wait0_imp  = new("wait0_imp", this);
      wait1_imp  = new("wait1_imp", this);
      cg_pkt    = new();
      cg_apb    = new();
      cg_corner = new();
      cg_wait   = new();
    endfunction

    function void write_cpkt(router_pkt_info i);
      cg_pkt.sample(i.len, i.dst, int'(i.act), i.level);
    endfunction

    function void write_capb(apb_item a);
      int r;
      if (router_model::good_addr(a.addr)) r = (a.addr >= 8'h20) ? 8 + ((a.addr - 8'h20) >> 2) : a.addr >> 2;
      else r = (a.addr[1:0] == 2'b00) ? 12 : 13;
      cg_apb.sample(r, a.write, a.slverr);
    endfunction

    function void write_ccorner(router_corner c);
      cg_corner.sample(int'(c.kind));
    endfunction

    function void write_cwait0(stream_obs_pkt p);
      cg_wait.sample(0, p.max_wait);
    endfunction

    function void write_cwait1(stream_obs_pkt p);
      cg_wait.sample(1, p.max_wait);
    endfunction
  endclass

  // ══════════════════════════════════════════════════════════════════════════
  // Virtual sequencer and environment
  // ══════════════════════════════════════════════════════════════════════════

  // A virtual sequencer runs no items of its own. It holds handles to the
  // agents' sequencers, so that one virtual sequence can start sequences on
  // all of them, and to whatever else the sequences steer or wait on: the
  // register model and its predictor, the sinks' configuration
  // (backpressure), the scoreboard (to know when the outputs are empty) and
  // the clock.
  class router_vsequencer extends uvm_sequencer;
    `uvm_component_utils(router_vsequencer)
    apb_sequencer        apb_sqr;
    stream_src_sequencer src_sqr;
    stream_snk_sequencer snk_sqr[2];
    router_sys_sequencer sys_sqr;
    router_reg_block     regs;
    uvm_reg_predictor #(apb_item) predictor;
    stream_snk_cfg       snk_cfg[2];
    router_scoreboard    sb;
    virtual router_sys_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class router_env extends uvm_env;
    `uvm_component_utils(router_env)

    apb_agent          apb;
    stream_src_agent   src;
    stream_snk_agent   snk[2];
    router_sys_agent   sys;
    router_scoreboard  sb;
    router_coverage    cov;
    router_vsequencer  vsqr;
    router_reg_block   regs;
    router_reg_adapter adapter;
    uvm_reg_predictor #(apb_item) predictor;

    apb_cfg        apb_c;
    stream_src_cfg src_c;
    stream_snk_cfg snk_c[2];
    virtual router_sys_if        vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      virtual apb_if a_vif;
      virtual stream_src_if s_vif;
      virtual stream_snk_if k_vif[2];
      super.build_phase(phase);
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", a_vif))
        `uvm_fatal("NOVIF", "no apb_if in config_db")
      if (!uvm_config_db#(virtual stream_src_if)::get(this, "", "src_vif", s_vif))
        `uvm_fatal("NOVIF", "no stream_src_if in config_db")
      if (!uvm_config_db#(virtual stream_snk_if)::get(this, "", "snk0_vif", k_vif[0]))
        `uvm_fatal("NOVIF", "no stream_snk_if for output 0 in config_db")
      if (!uvm_config_db#(virtual stream_snk_if)::get(this, "", "snk1_vif", k_vif[1]))
        `uvm_fatal("NOVIF", "no stream_snk_if for output 1 in config_db")
      if (!uvm_config_db#(virtual router_sys_if)::get(this, "", "sys_vif", vif))
        `uvm_fatal("NOVIF", "no router_sys_if in config_db")

      apb_c = apb_cfg::type_id::create("apb_c");
      apb_c.vif = a_vif;
      src_c = stream_src_cfg::type_id::create("src_c");
      src_c.vif = s_vif;
      foreach (snk_c[p]) begin
        snk_c[p] = stream_snk_cfg::type_id::create($sformatf("snk%0d_c", p));
        snk_c[p].vif = k_vif[p];
      end
      uvm_config_db#(apb_cfg)::set(this, "apb*", "cfg", apb_c);
      uvm_config_db#(stream_src_cfg)::set(this, "src*", "cfg", src_c);
      uvm_config_db#(stream_snk_cfg)::set(this, "snk0*", "cfg", snk_c[0]);
      uvm_config_db#(stream_snk_cfg)::set(this, "snk1*", "cfg", snk_c[1]);
      uvm_config_db#(virtual router_sys_if)::set(this, "sys*", "vif", vif);
      // Let a sequence take a few delta cycles to hand over its next item,
      // so drivers that ask with try_next_item can run transfers back to back.
      uvm_config_db#(int)::set(this, "*", "wait_for_sequences_count", 4);
      // With check-on-read, every read through the register model is compared
      // with the mirror, and UVM warns on each read of a volatile field that
      // its mirror may be stale. The scoreboard checks those fields, so the
      // warning is turned off.
      uvm_root::get().set_report_id_action("UVM/FLD/GET_MIRRORED_VAL/VOL", UVM_NO_ACTION);

      apb    = apb_agent::type_id::create("apb", this);
      src    = stream_src_agent::type_id::create("src", this);
      snk[0] = stream_snk_agent::type_id::create("snk0", this);
      snk[1] = stream_snk_agent::type_id::create("snk1", this);
      sys    = router_sys_agent::type_id::create("sys", this);
      sb     = router_scoreboard::type_id::create("sb", this);
      cov    = router_coverage::type_id::create("cov", this);
      vsqr   = router_vsequencer::type_id::create("vsqr", this);

      // The register model is an object, not a component: build() makes its
      // registers and its map. The predictor is a component.
      regs = router_reg_block::type_id::create("regs");
      regs.build();
      adapter   = router_reg_adapter::type_id::create("adapter");
      predictor = uvm_reg_predictor#(apb_item)::type_id::create("predictor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      // The register model sends its reads and writes through the APB
      // sequencer, and the adapter turns each one into an apb_item. With
      // auto-predict off, the model never updates its own mirror.
      regs.default_map.set_sequencer(apb.sqr, adapter);
      regs.default_map.set_auto_predict(0);

      // TODO (Part 3): the predictor. Give it the map and the adapter
      // (predictor.map, predictor.adapter), connect the APB driver's done_ap
      // (apb.drv.done_ap, which reports every transfer the driver finishes)
      // to its bus_in, and turn on the map's check-on-read
      // (regs.default_map.set_check_on_read(1)), so that every read the
      // predictor sees is compared with the mirror.

      // The scoreboard hears every port.
      src.mon.beat_ap.connect(sb.in_imp);
      snk[0].mon.beat_ap.connect(sb.out0_imp);
      snk[1].mon.beat_ap.connect(sb.out1_imp);
      apb.mon.ap.connect(sb.apb_imp);
      sys.mon.ap.connect(sb.sys_imp);

      // Coverage.
      sb.pkt_ap.connect(cov.pkt_imp);
      sb.corner_ap.connect(cov.corner_imp);
      apb.mon.ap.connect(cov.apb_imp);
      snk[0].mon.pkt_ap.connect(cov.wait0_imp);
      snk[1].mon.pkt_ap.connect(cov.wait1_imp);

      vsqr.apb_sqr    = apb.sqr;
      vsqr.src_sqr    = src.sqr;
      vsqr.snk_sqr[0] = snk[0].sqr;
      vsqr.snk_sqr[1] = snk[1].sqr;
      vsqr.sys_sqr    = sys.sqr;
      vsqr.regs       = regs;
      vsqr.predictor  = predictor;
      vsqr.snk_cfg[0] = snk_c[0];
      vsqr.snk_cfg[1] = snk_c[1];
      vsqr.sb         = sb;
      vsqr.vif        = vif;
    endfunction
  endclass
endpackage
