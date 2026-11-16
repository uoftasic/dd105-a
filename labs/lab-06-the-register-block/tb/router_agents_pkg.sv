// DD105-A Lab 06: the agents. One agent per kind of port, each with the same
// shape: a driver that wiggles the pins, a monitor that reports what moved on
// them, and a sequencer.
//
//   router_pkt       one input packet: the item the source driver sends
//   stream_beat      one beat a monitor saw move, stamped with its cycle
//   src_agent        the input stream: sequencer, driver, monitor
//   out_cfg          one output's knobs: which output, how its sink answers
//                    (mode), and how often it's ready in Lab 04's mode
//   out_ready_item   what the sink does for one output beat (Lab 05)
//   out_ready_seq    the sink's sequence: one item per beat, forever (Lab 05)
//   out_agent        an output stream: a ready driver, its sequencer and a
//                    monitor; the environment makes two of them, one per output
//   apb_item         one APB transfer
//   apb_agent        the APB port: sequencer, driver, monitor
//   sys_sample       rst_n and irq in one cycle (Lab 06)
//   sys_monitor      reports a sys_sample every cycle (Lab 06)
//   router_rand_seq  n random packets
//   router_one_seq   one packet that the test made itself
//   apb_rw_seq       one APB transfer
//
// This is Lab 04's file with Lab 05's additions: an oversize length kind in
// router_pkt (off unless a sequence gives it a weight), the cycle of each
// APB transfer, how long each output beat waited, and an output agent whose
// driver answers each beat from its sequence (Lab 05, Part 3, filled in).
// Lab 06 adds the sys monitor and changes nothing else.
//
// Every virtual interface is written out in full (`virtual stream_src_if`),
// never through a typedef: on this simulator (5.050) a class in a package that
// reaches an interface through a typedef reads 0 from every clocking-block
// input, with no warning (labs/ref/README.md has the probe).
//
// Every driver waits for a clock edge, @(vif.cb), before its first drive of an
// item. A drive issued in the same time step as an edge but after the
// sequencer handed over the item lands a cycle late on this simulator, and
// starting from the edge avoids that.

package router_agents_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ── the packet ────────────────────────────────────────────────────────────
  // Lab 03's rand_packet, as a sequence item. Its fields and its three
  // constraints are Lab 03's: c_dst keeps it on an enabled route, c_kind
  // weights the length kinds 25/50/25, and c_len solves len from kind.
  // The DST field is still called hdr_dst. post_randomize() fills in the
  // beats and the idle gaps before them, as Lab 03's build() did.
  //
  // Lab 05 adds a fourth kind, LEN_OVER: an oversize packet of 9 to 12
  // beats, which the router cuts to 8 (spec, Oversize packets). Its weight,
  // w_over, is 0 unless a sequence sets it, so until then every packet is 1
  // to 8 beats, as in Lab 04.
  typedef enum bit [1:0] {LEN_ONE, LEN_MID, LEN_MAX, LEN_OVER} len_kind_e;

  class router_pkt extends uvm_sequence_item;
    `uvm_object_utils(router_pkt)

    rand bit [1:0]    hdr_dst;    // the header's DST: which routing table entry it uses
    rand len_kind_e   kind;       // one beat, 2 to 7 beats, exactly 8, or 9 to 12
    rand int unsigned len;        // beats, header included
    bit [5:0]         tag;        // the header's other six bits: the packet's number
    bit [3:0]         route_en;   // set by whoever makes it: bit d is ROUTE[d].EN
    int unsigned      gap_pct = 25;  // percent of beats that wait 1 to 3 idle cycles first
    bit [7:0]         data[];     // the beats; data[0] is the header
    int unsigned      gap[];      // idle cycles the driver leaves before each beat

    // Only to enabled routes, so a random packet is never dropped as NOROUTE.
    // The bit is picked with a shift because the index, hdr_dst, is random.
    constraint c_dst { ((route_en >> hdr_dst) & 4'h1) == 4'h1; }

    // How often each kind comes out, in parts of the total. A dist written
    // with the enum's names put its weights on the wrong values on this
    // simulator (Lab 03, traps line 2), so its values are numbers.
    int unsigned w_one = 25, w_mid = 50, w_max = 25, w_over = 0;
    constraint c_kind { kind dist {0 := w_one, 1 := w_mid, 2 := w_max, 3 := w_over}; }
    constraint c_len  { (kind == LEN_ONE)  -> len == 1;
                        (kind == LEN_MID)  -> len inside {[2:7]};
                        (kind == LEN_MAX)  -> len == 8;
                        (kind == LEN_OVER) -> len inside {[9:12]}; }

    function new(string name = "router_pkt");
      super.new(name);
    endfunction

    function void post_randomize();
      build(1);
    endfunction

    // Fill data and gap from hdr_dst, tag and len. The payload is random, and
    // with random_gaps 1 about one beat in four (gap_pct) waits 1 to 3 idle
    // cycles before it is offered, as in Lab 03; with 0 the beats go back to
    // back.
    function void build(bit random_gaps);
      data = new[len];
      gap  = new[len];
      foreach (data[i]) begin
        data[i] = (i == 0) ? {hdr_dst, tag} : 8'($urandom);
        gap[i]  = (random_gaps && $urandom_range(99) < gap_pct) ? $urandom_range(3, 1) : 0;
      end
    endfunction

    // A packet built by hand, without the solver: len beats for DST dst, back
    // to back. len may be more than 12.
    static function router_pkt make(bit [1:0] dst, int unsigned len, bit [5:0] tag = 0);
      router_pkt p = router_pkt::type_id::create("pkt");
      p.hdr_dst = dst;
      p.len     = len;
      p.tag     = tag;
      p.kind    = len == 1 ? LEN_ONE : len < 8 ? LEN_MID : len == 8 ? LEN_MAX : LEN_OVER;
      p.build(0);
      return p;
    endfunction

    // "dst 2, 3 beats: 85 3c f0", as Lab 03 printed a packet.
    virtual function string convert2string();
      string s = $sformatf("dst %0d, %0d beat%s:", hdr_dst, len, len == 1 ? string'("") : string'("s"));
      foreach (data[i]) s = {s, $sformatf(" %02h", data[i])};
      return s;
    endfunction
  endclass

  // A beat that moved: the monitors make one for every handshake.
  class stream_beat extends uvm_sequence_item;
    `uvm_object_utils(stream_beat)
    int          port;            // 0 or 1 for an output, -1 for the input
    bit [7:0]    data;
    bit          last;
    int unsigned cycle;           // the cycle of the handshake
    int unsigned waited;          // an output beat's cycles on offer before it (Lab 05)
    function new(string name = "stream_beat");
      super.new(name);
    endfunction
    virtual function string convert2string();
      return $sformatf("%02h%s in cycle %0d", data, last ? string'(" last") : string'(""), cycle);
    endfunction
  endclass

  // ── the input stream ──────────────────────────────────────────────────────
  // Lab 03's driver, as a uvm_driver: it takes each packet from the
  // sequencer instead of a mailbox, leaves the packet's idle gaps before its
  // beats, and offers each beat until in_ready is 1. Lab 03's driver gave up
  // on a beat after 1000 cycles; here the test's watchdog stops the run.
  class src_driver extends uvm_driver #(router_pkt);
    `uvm_component_utils(src_driver)
    virtual stream_src_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual stream_src_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "src_driver has no virtual stream_src_if")
    endfunction

    task run_phase(uvm_phase phase);
      vif.cb.valid <= 1'b0;
      forever begin
        seq_item_port.get_next_item(req);
        @(vif.cb);
        foreach (req.data[i]) begin
          if (req.gap[i] > 0) begin
            vif.cb.valid <= 1'b0;
            repeat (req.gap[i]) @(vif.cb);
          end
          vif.cb.valid <= 1'b1;
          vif.cb.data  <= req.data[i];
          vif.cb.last  <= (i == req.data.size() - 1);
          do @(vif.cb); while (!vif.cb.ready);   // the beat moves at this edge
        end
        vif.cb.valid <= 1'b0;
        seq_item_port.item_done();
      end
    endtask
  endclass

  // Lab 02's monitor, as a uvm_monitor: it writes each beat to an analysis
  // port as it moves, instead of putting whole packets in a mailbox, so any
  // number of subscribers can have it, and the monitor doesn't know who they
  // are.
  class src_monitor extends uvm_monitor;
    `uvm_component_utils(src_monitor)
    uvm_analysis_port #(stream_beat) ap;
    virtual stream_src_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual stream_src_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "src_monitor has no virtual stream_src_if")
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.rst_n && vif.mon_cb.valid && vif.mon_cb.ready) begin
          stream_beat b = stream_beat::type_id::create("beat");
          b.port  = -1;
          b.data  = vif.mon_cb.data;
          b.last  = vif.mon_cb.last;
          b.cycle = vif.mon_cb.cycle;
          ap.write(b);
        end
      end
    endtask
  endclass

  typedef uvm_sequencer #(router_pkt) src_sequencer;

  class src_agent extends uvm_agent;
    `uvm_component_utils(src_agent)
    src_sequencer sqr;
    src_driver    drv;
    src_monitor   mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = src_sequencer::type_id::create("sqr", this);
      drv = src_driver::type_id::create("drv", this);
      mon = src_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ── an output stream ──────────────────────────────────────────────────────
  // How an output's sink answers (Lab 05):
  //   SNK_PCT     Lab 04's sink: in every cycle out_ready is 1 with
  //               probability ready_pct percent, whatever is on the output,
  //               so 100 is a sink that is always ready and 0 is Lab 03's
  //               stall. Every test from Lab 04 runs in this mode.
  //   SNK_FAST    out_ready is already 1 when each beat appears
  //   SNK_RANDOM  each beat's answer drawn at random (out_ready_item)
  //   SNK_SLOW    each beat waits out a delay of 4 to 20 cycles
  typedef enum bit [1:0] {SNK_PCT, SNK_FAST, SNK_RANDOM, SNK_SLOW} snk_mode_e;

  // The knobs of one output agent. The test makes one per output and hands it
  // down through config_db; it keeps the handle, so it can change ready_pct
  // or mode in the middle of a run and the driver sees the change at the
  // next edge.
  class out_cfg extends uvm_object;
    `uvm_object_utils(out_cfg)
    int          port;              // 0 or 1: which output this agent watches
    int unsigned ready_pct = 100;   // percent of cycles out_ready is 1 in SNK_PCT; 0 stalls the output
    snk_mode_e   mode = SNK_PCT;    // how the sink answers (Lab 05)
    function new(string name = "out_cfg");
      super.new(name);
    endfunction
  endclass

  // What the sink does for one beat (Lab 05): out_ready is already 1 when the
  // beat appears (pre_ready), or it rises once the beat has been on offer for
  // delay cycles after the first. The delay's range is drawn in
  // pre_randomize() with randcase, and the solver picks the delay inside it.
  // A dist on delay would fail on this simulator as soon as a sequence
  // constrained delay as well, with randomize() with {...} (Lab 03, Part 3).
  class out_ready_item extends uvm_sequence_item;
    `uvm_object_utils(out_ready_item)
    bit               pre_ready;   // out_ready is already 1 when the beat appears
    bit [1:0]         dsel;        // which range delay comes from (pre_randomize)
    rand int unsigned delay;       // cycles the beat waits after its first cycle on offer
    constraint c_delay { (dsel == 2'd0) -> delay == 0;
                         (dsel == 2'd1) -> delay inside {[1:3]};
                         (dsel == 2'd2) -> delay inside {[4:12]}; }
    function new(string name = "out_ready_item");
      super.new(name);
    endfunction
    function void pre_randomize();
      pre_ready = 1'($urandom_range(1));
      randcase
        5: dsel = 2'd0;
        3: dsel = 2'd1;
        2: dsel = 2'd2;
      endcase
    endfunction
  endclass

  // The sink's sequence (Lab 05): one item per beat, forever, made the way
  // cfg.mode says at the moment the driver asks for it. The output agent
  // starts it when the run starts, and nothing waits for it to finish. In
  // SNK_PCT the driver asks for no items, so the sequence waits in
  // start_item() until a test or a virtual sequence changes the mode.
  class out_ready_seq extends uvm_sequence #(out_ready_item);
    `uvm_object_utils(out_ready_seq)
    out_cfg cfg;
    function new(string name = "out_ready_seq");
      super.new(name);
    endfunction
    task body();
      out_ready_item r;
      int            ok;
      forever begin
        r = out_ready_item::type_id::create("r");
        start_item(r);
        case (cfg.mode)
          SNK_FAST: begin
            r.pre_ready = 1;
            r.delay     = 0;
          end
          SNK_SLOW: begin
            r.pre_ready = 0;
            r.delay     = $urandom_range(20, 4);
          end
          default: begin
            ok = r.randomize();
            if (ok == 0) `uvm_fatal("RAND", "out_ready_item randomize() failed")
          end
        endcase
        finish_item(r);
      end
    endtask
  endclass

  typedef uvm_sequencer #(out_ready_item) out_sequencer;

  // Lab 03's sink, with its stall knob grown into a percentage in Lab 04,
  // and in Lab 05 a uvm_driver that can answer each beat with an item from
  // its sequence, as a reactive driver does: the router decides when a beat
  // appears, and the item says how the sink responds to it.
  //
  // In SNK_PCT it is Lab 04's driver: at every rising edge it sets out_ready
  // to 1 with probability ready_pct percent, and it asks for no items. In the
  // other modes it holds one item at a time, from when it gets it until the
  // beat that item answers is taken. It looks at the output at the falling
  // edge in the middle of each cycle, once out_valid has settled, and drives
  // the next cycle's out_ready through the clocking block just after the
  // rising edge. The monitor beside it reports every beat.
  class out_ready_driver extends uvm_driver #(out_ready_item);
    `uvm_component_utils(out_ready_driver)
    out_cfg cfg;
    virtual stream_snk_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(out_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "out_ready_driver has no out_cfg")
      if (!uvm_config_db#(virtual stream_snk_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "out_ready_driver has no virtual stream_snk_if")
    endfunction

    task run_phase(uvm_phase phase);
      out_ready_item r;            // the item for the beat on offer, or for the next beat
      bit            seen = 0;     // out_valid has been 1 for the beat r answers
      int unsigned   wait_left;    // cycles of r.delay still to wait
      bit            rdy = 0;      // out_ready in this cycle
      forever begin
        // The rising edge: out_ready for the cycle that starts here.
        @(vif.cb);
        if (cfg.mode == SNK_PCT) rdy = ($urandom_range(99) < cfg.ready_pct);
        vif.cb.ready <= rdy;
        // The middle of the cycle: did a beat move, and what does the sink
        // do in the next cycle?
        @(negedge vif.clk);
        if (vif.valid && rdy) begin          // the handshake: r has been answered
          if (r != null) seq_item_port.item_done();
          r = null;
        end else if (vif.valid && r != null) begin
          // The beat r answers is waiting. Its first cycle on offer starts
          // the wait; each cycle after that counts one off, down to 0.
          if (!seen) seen = 1;
          else if (wait_left > 0) wait_left--;
        end
        if (cfg.mode != SNK_PCT) begin
          if (r == null) begin
            seq_item_port.try_next_item(r);
            if (r != null) begin
              seen      = 0;
              wait_left = r.delay;
            end
          end
          // out_ready in the next cycle: never without an item; already, for
          // a pre_ready item; otherwise once the beat's wait is over.
          rdy = r != null && (r.pre_ready || (seen && wait_left == 0));
        end
      end
    endtask
  endclass

  // The monitor reports every beat taken from its output. In Lab 05 it also
  // stamps each beat with how long it waited: the cycles between the first
  // cycle it was on offer and the cycle it was taken.
  class out_monitor extends uvm_monitor;
    `uvm_component_utils(out_monitor)
    uvm_analysis_port #(stream_beat) ap;
    out_cfg cfg;
    virtual stream_snk_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(out_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "out_monitor has no out_cfg")
      if (!uvm_config_db#(virtual stream_snk_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "out_monitor has no virtual stream_snk_if")
    endfunction

    task run_phase(uvm_phase phase);
      int unsigned first;           // the first cycle the beat on offer was on offer
      bit          offering = 0;    // a beat is on offer and hasn't been taken
      forever begin
        @(vif.mon_cb);
        if (!vif.mon_cb.valid) offering = 0;
        else if (!offering) begin
          offering = 1;
          first    = vif.mon_cb.cycle;
        end
        if (vif.mon_cb.rst_n && vif.mon_cb.valid && vif.mon_cb.ready) begin
          stream_beat b = stream_beat::type_id::create("beat");
          b.port   = cfg.port;
          b.data   = vif.mon_cb.data;
          b.last   = vif.mon_cb.last;
          b.cycle  = vif.mon_cb.cycle;
          b.waited = b.cycle - first;
          offering = 0;
          ap.write(b);
        end
      end
    endtask
  endclass

  // One class, instantiated once per output. Everything that differs between
  // output 0 and output 1 (the interface, the port number, the ready knobs)
  // comes from config_db, set for this instance's path. In Lab 05 it has a
  // sequencer for the driver's items, and it starts the sink's sequence
  // itself, because a sink must answer every beat for the whole run whatever
  // the test does.
  class out_agent extends uvm_agent;
    `uvm_component_utils(out_agent)
    out_sequencer    sqr;
    out_ready_driver drv;
    out_monitor      mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // try_next_item() lets the sequence this many zero-time waits to hand
      // over its next item. The default, 1, is short for an item that is
      // randomized after start_item().
      uvm_config_db#(int)::set(this, "sqr", "wait_for_sequences_count", 4);
      sqr = out_sequencer::type_id::create("sqr", this);
      drv = out_ready_driver::type_id::create("drv", this);
      mon = out_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

    task run_phase(uvm_phase phase);
      out_ready_seq s = out_ready_seq::type_id::create("ready_seq");
      s.cfg = drv.cfg;
      s.start(sqr);
    endtask
  endclass

  // ── the APB port ──────────────────────────────────────────────────────────
  // Lab 03's apb_master, with Lab 02's write() and Lab 03's read(), as an
  // agent: a sequence item per transfer, a driver, and a monitor that
  // reports every transfer to the scoreboard.
  class apb_item extends uvm_sequence_item;
    `uvm_object_utils(apb_item)
    bit        write;
    bit [7:0]  addr;
    bit [31:0] wdata;
    bit [31:0] rdata;     // filled in when the transfer completes
    bit        slverr;
    int unsigned cycle;   // the cycle the transfer completed, from the monitor (Lab 05)
    function new(string name = "apb_item");
      super.new(name);
    endfunction
    virtual function string convert2string();
      return $sformatf("%s %02h data %08h%s", write ? string'("WRITE") : string'("READ "), addr,
                       write ? wdata : rdata, slverr ? string'(" PSLVERR") : string'(""));
    endfunction
  endclass

  // A setup cycle, then access cycles until pready (spec, APB).
  class apb_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_driver)
    virtual apb_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "apb_driver has no virtual apb_if")
    endfunction

    task run_phase(uvm_phase phase);
      vif.cb.psel    <= 1'b0;
      vif.cb.penable <= 1'b0;
      forever begin
        seq_item_port.get_next_item(req);
        @(vif.cb);
        vif.cb.psel    <= 1'b1;               // the setup cycle
        vif.cb.penable <= 1'b0;
        vif.cb.pwrite  <= req.write;
        vif.cb.paddr   <= req.addr;
        vif.cb.pwdata  <= req.wdata;
        @(vif.cb);
        vif.cb.penable <= 1'b1;               // the access cycles
        do @(vif.cb); while (!vif.cb.pready);
        req.rdata  = vif.cb.prdata;
        req.slverr = vif.cb.pslverr;
        vif.cb.psel    <= 1'b0;
        vif.cb.penable <= 1'b0;
        seq_item_port.item_done();
      end
    endtask
  endclass

  class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    uvm_analysis_port #(apb_item) ap;
    virtual apb_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "apb_monitor has no virtual apb_if")
    endfunction

    // One apb_item per completed transfer: an access cycle with pready = 1.
    task run_phase(uvm_phase phase);
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.rst_n && vif.mon_cb.psel && vif.mon_cb.penable && vif.mon_cb.pready) begin
          apb_item t = apb_item::type_id::create("apb_obs");
          t.write  = vif.mon_cb.pwrite;
          t.addr   = vif.mon_cb.paddr;
          t.wdata  = vif.mon_cb.pwdata;
          t.rdata  = vif.mon_cb.prdata;
          t.slverr = vif.mon_cb.pslverr;
          t.cycle  = vif.mon_cb.cycle;
          `uvm_info("APB", t.convert2string(), UVM_HIGH)
          ap.write(t);
        end
      end
    endtask
  endclass

  typedef uvm_sequencer #(apb_item) apb_sequencer;

  class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)
    apb_sequencer sqr;
    apb_driver    drv;
    apb_monitor   mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = apb_sequencer::type_id::create("sqr", this);
      drv = apb_driver::type_id::create("drv", this);
      mon = apb_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ── reset and the interrupt (Lab 06) ──────────────────────────────────────
  // What rst_n and irq were in one cycle. The sys monitor makes one for
  // every cycle, reset cycles included.
  class sys_sample extends uvm_sequence_item;
    `uvm_object_utils(sys_sample)
    int unsigned cycle;
    bit          rst_n;
    bit          irq;
    function new(string name = "sys_sample");
      super.new(name);
    endfunction
  endclass

  // A monitor with no agent around it: nothing in the testbench drives these
  // two signals, so there is no driver or sequencer to go with it.
  class sys_monitor extends uvm_monitor;
    `uvm_component_utils(sys_monitor)
    uvm_analysis_port #(sys_sample) ap;
    virtual router_sys_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual router_sys_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "sys_monitor has no virtual router_sys_if")
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        sys_sample s;
        @(vif.mon_cb);
        s = sys_sample::type_id::create("sys");
        s.cycle = vif.mon_cb.cycle;
        s.rst_n = vif.mon_cb.rst_n;
        s.irq   = vif.mon_cb.irq;
        ap.write(s);
      end
    endtask
  endclass

  // ── sequences ─────────────────────────────────────────────────────────────
  // Lab 03's generator. Each packet is made through the factory
  // (router_pkt::type_id::create), so a test can swap in a subclass of
  // router_pkt without touching this sequence. As in Lab 03, the tag is the
  // packet's number, so you can find a packet in a log by its header.
  // Lab 05 adds two knobs that it copies into every packet: how often a
  // beat waits (gap_pct) and the weight of oversize packets (w_over).
  class router_rand_seq extends uvm_sequence #(router_pkt);
    `uvm_object_utils(router_rand_seq)
    int unsigned n = 200;
    bit [3:0]    route_en = 4'hF;   // which routes are enabled now
    int unsigned first_tag = 0;
    int unsigned gap_pct = 25;      // router_pkt's own defaults, so Lab 04's tests are unchanged
    int unsigned w_over = 0;

    function new(string name = "router_rand_seq");
      super.new(name);
    endfunction

    task body();
      router_pkt p;
      int        ok;
      for (int k = 0; k < n; k++) begin
        p = router_pkt::type_id::create("pkt");
        p.route_en = route_en;
        p.tag      = 6'(first_tag + k);
        p.gap_pct  = gap_pct;
        p.w_over   = w_over;
        start_item(p);
        ok = p.randomize();
        if (ok == 0) `uvm_fatal("RAND", "router_pkt randomize() failed")
        finish_item(p);
      end
    endtask
  endclass

  // One packet that the test made itself, by hand or with randomize().
  class router_one_seq extends uvm_sequence #(router_pkt);
    `uvm_object_utils(router_one_seq)
    router_pkt pkt;
    function new(string name = "router_one_seq");
      super.new(name);
    endfunction
    task body();
      start_item(pkt);
      finish_item(pkt);
    endtask
  endclass

  // One APB transfer. After it finishes, `t` holds what came back.
  class apb_rw_seq extends uvm_sequence #(apb_item);
    `uvm_object_utils(apb_rw_seq)
    bit        write;
    bit [7:0]  addr;
    bit [31:0] wdata;
    apb_item   t;
    function new(string name = "apb_rw_seq");
      super.new(name);
    endfunction
    task body();
      t = apb_item::type_id::create("t");
      start_item(t);
      t.write = write;
      t.addr  = addr;
      t.wdata = wdata;
      finish_item(t);
    endtask
  endclass
endpackage
