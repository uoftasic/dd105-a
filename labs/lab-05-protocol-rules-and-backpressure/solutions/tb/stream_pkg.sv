// DD105-A Lab 05: the valid/ready stream agents.
//
//   stream_pkt          one input packet: its beats and the idle cycles between them
//   stream_ready_item   what the sink does for one output beat
//   stream_beat         one beat a monitor saw move, with the cycles it waited
//   stream_obs_pkt      the beats of one packet a monitor saw, assembled
//   stream_monitor      watches any of the three streams (input, out0, out1)
//   stream_src_agent    drives packets into the router (the source)
//   stream_snk_agent    a reactive sink: takes beats with random backpressure
//
// Neither driver ever blocks forever on the router. The source gives up on a
// beat that waits longer than its cfg.max_wait and reports it, so a router
// that stops answering ends the test with an error instead of a hang.
//
// The virtual interface type is written out in full (`virtual stream_src_if`) and
// never through a typedef. On this simulator (5.050), a class in a package
// that reaches an interface through a typedef'd virtual interface type reads
// 0 from every clocking-block input, forever, with no warning.

package stream_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ── items ─────────────────────────────────────────────────────────────────
  // A packet for the input stream. Its length comes in four kinds, and the
  // kind is drawn with randcase in pre_randomize(), from weights the
  // sequence can set; the solver then picks len from the kind's range. The
  // weighted choice isn't left to a dist constraint because this simulator's
  // solver gets it wrong when the selector's values are named: for weights
  // 20/50/20/10, 1,000 draws gave 73/557/356/14 with the values as package
  // localparams and 0/0/0/1000 with them as an enum. Literal values gave
  // 206/492/201/101 and randcase 182/526/184/108 (labs/ref/probes/dist_weights.sv).
  localparam bit [1:0] LEN_ONE = 2'd0, LEN_MID = 2'd1, LEN_EIGHT = 2'd2, LEN_OVER = 2'd3;

  class stream_pkt extends uvm_sequence_item;
    `uvm_object_utils(stream_pkt)

    bit [1:0]         kind;       // LEN_ONE, LEN_MID, LEN_EIGHT or LEN_OVER (pre_randomize)
    rand int unsigned len;        // beats sent; more than 8 is an oversize packet
    rand bit [1:0]    dst;        // the header's DST field
    rand bit [5:0]    tag;        // the header's other six bits
    bit               wait_ready; // hold in_valid at 0 until in_ready is 1 (rule I4 allows it)

    // Knobs, set before randomize(): the weights of the length kinds, and
    // how often (in percent) a beat is preceded by idle cycles, and how many.
    // w_over is 0, so a packet is 1 to 8 beats long unless a sequence asks
    // for oversize ones (9 to max_len beats) by raising it.
    int unsigned w_one = 20, w_mid = 50, w_eight = 20, w_over = 0;
    int unsigned gap_pct = 25, max_gap = 3;
    int unsigned max_len = 14;

    // Built from the fields above by post_randomize() or make().
    bit [7:0]    data[];
    bit          last[];
    int unsigned gap[];          // idle cycles before each beat

    constraint c_len  { (kind == LEN_ONE)   -> len == 1;
                        (kind == LEN_MID)   -> len inside {[2:7]};
                        (kind == LEN_EIGHT) -> len == 8;
                        (kind == LEN_OVER)  -> len inside {[9:max_len]}; }

    function new(string name = "stream_pkt");
      super.new(name);
    endfunction

    function void pre_randomize();
      if (w_one + w_mid + w_eight + w_over == 0) w_mid = 1;
      randcase
        w_one:   kind = LEN_ONE;
        w_mid:   kind = LEN_MID;
        w_eight: kind = LEN_EIGHT;
        w_over:  kind = LEN_OVER;
      endcase
      wait_ready = ($urandom_range(3) == 0);
    endfunction

    function void post_randomize();
      build(1);
    endfunction

    // Fill data, last and gap from len, dst and tag. With random_gaps 0 the
    // beats go back to back.
    function void build(bit random_gaps);
      data = new[len];
      last = new[len];
      gap  = new[len];
      foreach (data[i]) begin
        data[i] = (i == 0) ? {dst, tag} : 8'($urandom);
        last[i] = (i == len - 1);
        gap[i]  = (random_gaps && $urandom_range(99) < gap_pct) ? $urandom_range(max_gap, 1) : 0;
      end
    endfunction

    // A packet built by hand, for directed tests: no idle cycles.
    static function stream_pkt make(bit [1:0] dst, int unsigned len, bit [5:0] tag = 0);
      stream_pkt p = new("pkt");
      p.dst  = dst;
      p.len  = len;
      p.tag  = tag;
      p.kind = len == 1 ? LEN_ONE : len < 8 ? LEN_MID : len == 8 ? LEN_EIGHT : LEN_OVER;
      p.wait_ready = 0;
      p.build(0);
      return p;
    endfunction

    virtual function string convert2string();
      string s = $sformatf("dst %0d, %0d beats:", dst, len);
      foreach (data[i]) s = {s, $sformatf(" %02h", data[i])};
      return s;
    endfunction
  endclass

  // What a sink does for one beat: raise ready before valid appears
  // (pre_ready), or wait `delay` cycles after valid appears and then raise it.
  // stream_snk_seq makes one item per beat, in one of three modes:
  //   SNK_FAST    pre_ready, so ready is 1 whenever the sink isn't stalled
  //   SNK_RANDOM  randomized: half the items pre_ready, delays of 0, 1 to 3, or 4 to 12
  //   SNK_SLOW    a delay of 4 to 20 cycles after valid appears, for every beat
  typedef enum bit [1:0] {SNK_FAST, SNK_RANDOM, SNK_SLOW} snk_mode_e;

  // The delay's range is picked in pre_randomize() with randcase, and the
  // solver picks the delay inside it. That's a distribution put on a selector
  // variable, not a dist on delay itself, which this simulator gets wrong when
  // another constraint names the same variable.
  class stream_ready_item extends uvm_sequence_item;
    `uvm_object_utils(stream_ready_item)
    bit               pre_ready;   // ready is already 1 when valid appears
    bit [1:0]         dsel;        // which range delay comes from (pre_randomize)
    rand int unsigned delay;       // cycles to wait after valid appears
    constraint c_delay { (dsel == 2'd0) -> delay == 0;
                         (dsel == 2'd1) -> delay inside {[1:3]};
                         (dsel >= 2'd2) -> delay inside {[4:12]}; }
    function new(string name = "stream_ready_item");
      super.new(name);
    endfunction
    function void pre_randomize();
      pre_ready = $urandom_range(1);
      randcase
        5: dsel = 2'd0;
        3: dsel = 2'd1;
        2: dsel = 2'd2;
      endcase
    endfunction
  endclass

  // A beat that moved: its data, and the cycles of its handshake and of the
  // first cycle it was offered (valid = 1). For an output beat, first_cycle
  // is the cycle it appeared on the pins, which rule O8 predicts.
  class stream_beat extends uvm_sequence_item;
    `uvm_object_utils(stream_beat)
    bit [7:0]    data;
    bit          last;
    int unsigned cycle;
    int unsigned first_cycle;
    function new(string name = "stream_beat");
      super.new(name);
    endfunction
    virtual function string convert2string();
      return $sformatf("%02h%s (offered from cycle %0d, taken in cycle %0d)", data,
                       last ? string'(" last") : string'(""), first_cycle, cycle);
    endfunction
  endclass

  // The beats of one packet, as a monitor assembled them.
  class stream_obs_pkt extends uvm_sequence_item;
    `uvm_object_utils(stream_obs_pkt)
    bit [7:0]    data[$];
    int unsigned first_cycle, last_cycle;
    int unsigned max_wait;       // the longest any of its beats waited for its handshake
    function new(string name = "stream_obs_pkt");
      super.new(name);
    endfunction
  endclass

  // ── configuration ─────────────────────────────────────────────────────────
  class stream_src_cfg extends uvm_object;
    `uvm_object_utils(stream_src_cfg)
    virtual stream_src_if      vif;
    int unsigned max_wait = 4000;   // cycles a beat may wait for in_ready before we give up
    function new(string name = "stream_src_cfg");
      super.new(name);
    endfunction
  endclass

  class stream_snk_cfg extends uvm_object;
    `uvm_object_utils(stream_snk_cfg)
    virtual stream_snk_if    vif;
    // The virtual sequences steer the sinks through these two:
    //   mode   how stream_snk_seq makes its items (SNK_RANDOM until a
    //          sequence changes it)
    //   stall  1 holds ready at 0, whatever the item says
    snk_mode_e mode  = SNK_RANDOM;
    bit        stall = 0;
    function new(string name = "stream_snk_cfg");
      super.new(name);
    endfunction
  endclass

  typedef uvm_sequencer #(stream_pkt)        stream_src_sequencer;
  typedef uvm_sequencer #(stream_ready_item) stream_snk_sequencer;

  // ── source driver ─────────────────────────────────────────────────────────
  // Like the APB driver, it decides at the falling edge in the middle of each
  // cycle (did the beat move? what goes out next?) and drives right after the
  // rising edge, through the clocking block, so that try_next_item()'s wait
  // never delays a drive by a cycle. While in_valid is 0 it puts random values
  // on in_data and in_last: the router must ignore them.
  class stream_src_driver extends uvm_driver #(stream_pkt);
    `uvm_component_utils(stream_src_driver)
    stream_src_cfg        cfg;
    virtual stream_src_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(stream_src_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "stream_src_driver has no stream_src_cfg")
      vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
      stream_pkt   p;
      int          i;             // the beat of p on offer, or next to offer
      int unsigned gap_left, waited;
      bit          offering = 0;  // in_valid is 1 in this cycle
      bit          drive_beat;
      vif.cb.valid <= 1'b0;
      forever begin
        @(negedge vif.clk);
        drive_beat = 0;
        if (!vif.rst_n) begin
          // Rule I3: a reset abandons the packet; the next beat offered after
          // it is a header.
          if (p != null) begin
            `uvm_info("SRC", $sformatf("reset: abandoned %s at beat %0d", p.convert2string(), i),
                      UVM_MEDIUM)
            seq_item_port.item_done();
            p = null;
          end
          offering = 0;
        end else if (offering) begin
          if (vif.ready) begin            // the handshake: the beat moves at this edge
            offering = 0;
            i++;
            if (i == p.data.size()) begin
              seq_item_port.item_done();
              p = null;
            end else begin
              gap_left = p.gap[i];
            end
          end else if (++waited >= cfg.max_wait) begin
            `uvm_error("SRC", $sformatf("beat %0d of a packet (%02h) waited %0d cycles for in_ready; giving the packet up",
                       i, p.data[i], waited))
            offering = 0;
            seq_item_port.item_done();
            p = null;
          end
        end
        if (vif.rst_n && !offering) begin
          if (p == null) begin
            seq_item_port.try_next_item(p);
            if (p != null) begin
              i = 0;
              gap_left = p.gap[0];
              waited = 0;
            end
          end
          if (p != null) begin
            if (gap_left > 0) gap_left--;
            else if (i == 0 && p.wait_ready && !vif.ready) begin
              // Rule I4 lets a source wait for in_ready before raising in_valid.
              if (++waited >= cfg.max_wait) begin
                `uvm_error("SRC", $sformatf("in_ready stayed 0 for %0d cycles before header %02h; giving the packet up",
                           waited, p.data[0]))
                seq_item_port.item_done();
                p = null;
              end
            end else begin
              drive_beat = 1;
              offering = 1;
              waited = 0;
            end
          end
        end
        @(vif.cb);
        if (drive_beat) begin
          vif.cb.valid <= 1'b1;
          vif.cb.data  <= p.data[i];
          vif.cb.last  <= p.last[i];
        end else if (!offering) begin
          vif.cb.valid <= 1'b0;
          vif.cb.data  <= 8'($urandom);
          vif.cb.last  <= 1'($urandom);
        end
      end
    endtask
  endclass

  // ── sink driver ───────────────────────────────────────────────────────────
  // A reactive slave: it doesn't decide when beats arrive, the router does,
  // so each item is the answer to one beat. The item says whether ready is
  // already 1 before valid appears (pre_ready), or how many cycles to wait
  // after valid appears before raising it (delay). cfg.stall holds ready at
  // 0 whatever the item says, and the wait doesn't count down while it does.
  //
  // Like the source, it decides at the falling edge in the middle of each
  // cycle, when this cycle's valid has settled, and drives the next cycle's
  // ready right after the rising edge, through the clocking block.
  class stream_snk_driver extends uvm_driver #(stream_ready_item);
    `uvm_component_utils(stream_snk_driver)
    stream_snk_cfg        cfg;
    virtual stream_snk_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(stream_snk_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "stream_snk_driver has no stream_snk_cfg")
      vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
      stream_ready_item r;         // the item answering the beat on offer, or the next one
      bit          seen = 0;       // valid has been 1 for the beat r answers
      int unsigned wait_left;      // cycles of r.delay still to wait
      bit          rdy = 0;        // ready in this cycle
      vif.cb.ready <= 1'b0;
      forever begin
        @(negedge vif.clk);
        // What happened in this cycle.
        if (vif.rst_n && vif.valid && rdy) begin     // the handshake: r is answered
          if (r != null) seq_item_port.item_done();
          r = null;
        end else if (vif.rst_n && vif.valid && r != null) begin
          // A beat is waiting. The cycle valid first appears starts the wait;
          // each cycle after it counts one off, down to 0, unless the sink is
          // stalled. Below 0 the unsigned wait_left would wrap round.
          if (!seen) seen = 1;
          else if (wait_left > 0 && !cfg.stall) wait_left--;
        end
        if (r == null) begin
          seq_item_port.try_next_item(r);
          if (r != null) begin
            seen = 0;
            wait_left = r.delay;
          end
        end
        // Ready in the next cycle: never while stalled; already, for a
        // pre_ready item; otherwise once valid has been seen and the wait is over.
        rdy = r != null && !cfg.stall && (r.pre_ready || (seen && wait_left == 0));
        // Drive it, just after the edge.
        @(vif.cb);
        vif.cb.ready <= rdy;
      end
    endtask
  endclass

  // ── monitor ───────────────────────────────────────────────────────────────
  // The same code watches the input stream and both outputs. The two stream
  // interfaces are different types (each drives different signals), so the
  // only interface-specific part, sampling the pins at an edge, is a virtual
  // task that the two subclasses below implement.
  class stream_monitor extends uvm_monitor;
    `uvm_component_utils(stream_monitor)
    uvm_analysis_port #(stream_beat)    beat_ap;
    uvm_analysis_port #(stream_obs_pkt) pkt_ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      beat_ap = new("beat_ap", this);
      pkt_ap  = new("pkt_ap", this);
    endfunction

    virtual task sample(output bit rst_n, valid, ready, last, output bit [7:0] data,
                        output int unsigned cycle);
      `uvm_fatal("MON", "stream_monitor::sample is not implemented")
    endtask

    task run_phase(uvm_phase phase);
      bit rst_n, valid, ready, last;
      bit [7:0] data;
      int unsigned t, first = 0;
      bit offering = 0;
      stream_obs_pkt pkt;
      forever begin
        sample(rst_n, valid, ready, last, data, t);
        if (!rst_n) begin            // a reset drops a half-assembled packet
          offering = 0;
          pkt = null;
          continue;
        end
        if (valid && !offering) begin
          offering = 1;
          first = t;
        end
        if (valid && ready) begin
          stream_beat b = stream_beat::type_id::create("beat");
          b.data = data;
          b.last = last;
          b.cycle = t;
          b.first_cycle = first;
          beat_ap.write(b);
          if (pkt == null) begin
            pkt = stream_obs_pkt::type_id::create("obs");
            pkt.first_cycle = t;
          end
          pkt.data.push_back(data);
          if (t - first > pkt.max_wait) pkt.max_wait = t - first;
          if (last) begin
            pkt.last_cycle = t;
            pkt_ap.write(pkt);
            pkt = null;
          end
          offering = 0;
        end
        if (!valid) offering = 0;
      end
    endtask
  endclass

  class stream_src_monitor extends stream_monitor;
    `uvm_component_utils(stream_src_monitor)
    virtual stream_src_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      stream_src_cfg cfg;
      super.build_phase(phase);
      if (!uvm_config_db#(stream_src_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "stream_src_monitor has no stream_src_cfg")
      vif = cfg.vif;
    endfunction
    virtual task sample(output bit rst_n, valid, ready, last, output bit [7:0] data,
                        output int unsigned cycle);
      @(vif.mon_cb);
      rst_n = vif.mon_cb.rst_n;
      valid = vif.mon_cb.valid;
      ready = vif.mon_cb.ready;
      last  = vif.mon_cb.last;
      data  = vif.mon_cb.data;
      cycle = vif.mon_cb.cycle;
    endtask
  endclass

  class stream_snk_monitor extends stream_monitor;
    `uvm_component_utils(stream_snk_monitor)
    virtual stream_snk_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      stream_snk_cfg cfg;
      super.build_phase(phase);
      if (!uvm_config_db#(stream_snk_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "stream_snk_monitor has no stream_snk_cfg")
      vif = cfg.vif;
    endfunction
    virtual task sample(output bit rst_n, valid, ready, last, output bit [7:0] data,
                        output int unsigned cycle);
      @(vif.mon_cb);
      rst_n = vif.mon_cb.rst_n;
      valid = vif.mon_cb.valid;
      ready = vif.mon_cb.ready;
      last  = vif.mon_cb.last;
      data  = vif.mon_cb.data;
      cycle = vif.mon_cb.cycle;
    endtask
  endclass

  // ── agents ────────────────────────────────────────────────────────────────
  class stream_src_agent extends uvm_agent;
    `uvm_component_utils(stream_src_agent)
    stream_src_sequencer sqr;
    stream_src_driver    drv;
    stream_src_monitor   mon;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = stream_src_sequencer::type_id::create("sqr", this);
      drv = stream_src_driver::type_id::create("drv", this);
      mon = stream_src_monitor::type_id::create("mon", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  class stream_snk_agent extends uvm_agent;
    `uvm_component_utils(stream_snk_agent)
    stream_snk_sequencer sqr;
    stream_snk_driver    drv;
    stream_snk_monitor   mon;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = stream_snk_sequencer::type_id::create("sqr", this);
      drv = stream_snk_driver::type_id::create("drv", this);
      mon = stream_snk_monitor::type_id::create("mon", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ── sequences ─────────────────────────────────────────────────────────────
  // Send a list of packets, in order.
  class stream_list_seq extends uvm_sequence #(stream_pkt);
    `uvm_object_utils(stream_list_seq)
    stream_pkt pkts[$];
    function new(string name = "stream_list_seq");
      super.new(name);
    endfunction
    task body();
      foreach (pkts[i]) begin
        start_item(pkts[i]);
        finish_item(pkts[i]);
      end
    endtask
  endclass

  // Send n random packets. dst_mask limits which DST values are used (bit d
  // set: DST d allowed); the other knobs are copied into each packet. With
  // w_over at 0 every packet is 1 to 8 beats long.
  class stream_rand_seq extends uvm_sequence #(stream_pkt);
    `uvm_object_utils(stream_rand_seq)
    int unsigned n = 20;
    bit [3:0]    dst_mask = 4'hF;
    int unsigned w_one = 20, w_mid = 50, w_eight = 20, w_over = 0;
    int unsigned gap_pct = 25, max_gap = 3, max_len = 14;
    function new(string name = "stream_rand_seq");
      super.new(name);
    endfunction
    task body();
      for (int k = 0; k < n; k++) begin
        stream_pkt p = stream_pkt::type_id::create("pkt");
        p.w_one = w_one; p.w_mid = w_mid; p.w_eight = w_eight; p.w_over = w_over;
        p.gap_pct = gap_pct; p.max_gap = max_gap; p.max_len = max_len;
        start_item(p);
        if (!p.randomize() with { ((dst_mask >> dst) & 4'h1) == 4'h1; })
          `uvm_fatal("RAND", "stream_pkt randomize() failed")
        p.tag = 6'(k);
        p.data[0] = {p.dst, p.tag};
        finish_item(p);
      end
    endtask
  endclass

  // The sinks' sequence: one item per beat, forever, made the way the sink's
  // cfg.mode says. The test starts one on each sink and leaves it running.
  class stream_snk_seq extends uvm_sequence #(stream_ready_item);
    `uvm_object_utils(stream_snk_seq)
    stream_snk_cfg cfg;
    function new(string name = "stream_snk_seq");
      super.new(name);
    endfunction
    task body();
      forever begin
        stream_ready_item r = stream_ready_item::type_id::create("r");
        start_item(r);
        case (cfg.mode)
          SNK_FAST: begin
            r.pre_ready = 1;
            r.delay = 0;
          end
          SNK_SLOW: begin
            r.pre_ready = 0;
            r.delay = $urandom_range(20, 4);
          end
          default:
            if (!r.randomize()) `uvm_fatal("RAND", "stream_ready_item randomize() failed")
        endcase
        finish_item(r);
      end
    endtask
  endclass
endpackage
