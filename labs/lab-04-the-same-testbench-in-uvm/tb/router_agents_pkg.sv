// DD105-A Lab 04: the agents. One agent per kind of port, each with the same
// shape: a driver that wiggles the pins, a monitor that reports what moved on
// them, and (for the two that take items) a sequencer.
//
//   router_pkt       one input packet: the item the source driver sends
//   stream_beat      one beat a monitor saw move, stamped with its cycle
//   src_agent        the input stream: sequencer, driver, monitor
//   out_cfg          one output's knobs: which output, and how often it's ready
//   out_agent        an output stream: a ready driver and a monitor; the
//                    environment makes two of them, one per output
//   apb_item         one APB transfer
//   apb_agent        the APB port: sequencer, driver, monitor
//   router_rand_seq  n random packets
//   router_one_seq   one packet that the test made itself
//   apb_rw_seq       one APB transfer
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
  // weights the three length kinds 25/50/25, and c_len solves len from kind.
  // The DST field is still called hdr_dst. post_randomize() fills in the
  // beats and the idle gaps before them, as Lab 03's build() did. Packets are
  // 1 to 8 beats: nothing here is oversize.
  typedef enum bit [1:0] {LEN_ONE, LEN_MID, LEN_MAX} len_kind_e;

  class router_pkt extends uvm_sequence_item;
    `uvm_object_utils(router_pkt)

    rand bit [1:0]    hdr_dst;    // the header's DST: which routing table entry it uses
    rand len_kind_e   kind;       // one beat, 2 to 7 beats, or exactly 8
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
    int unsigned w_one = 25, w_mid = 50, w_max = 25;
    constraint c_kind { kind dist {0 := w_one, 1 := w_mid, 2 := w_max}; }
    constraint c_len  { (kind == LEN_ONE) -> len == 1;
                        (kind == LEN_MID) -> len inside {[2:7]};
                        (kind == LEN_MAX) -> len == 8; }

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
    // to back.
    static function router_pkt make(bit [1:0] dst, int unsigned len, bit [5:0] tag = 0);
      router_pkt p = router_pkt::type_id::create("pkt");
      p.hdr_dst = dst;
      p.len     = len;
      p.tag     = tag;
      p.kind    = len == 1 ? LEN_ONE : len < 8 ? LEN_MID : LEN_MAX;
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
  // The knobs of one output agent. The test makes one per output and hands it
  // down through config_db; it keeps the handle, so it can change ready_pct
  // in the middle of a run and the driver sees the change at the next edge.
  class out_cfg extends uvm_object;
    `uvm_object_utils(out_cfg)
    int          port;              // 0 or 1: which output this agent watches
    int unsigned ready_pct = 100;   // percent of cycles out_ready is 1; 0 stalls the output
    function new(string name = "out_cfg");
      super.new(name);
    endfunction
  endclass

  // Lab 03's sink, with its stall knob grown into a percentage: every cycle
  // it sets out_ready to 1 with probability ready_pct percent, so 100 is the
  // sink that is always ready and 0 is Lab 03's stall. It takes no items, so
  // it's a plain component rather than a uvm_driver, and it counts nothing:
  // the monitor beside it reports every beat. (Lab 05 replaces it with a
  // reactive driver that answers each beat.)
  class out_ready_driver extends uvm_component;
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
      forever begin
        @(vif.cb);
        vif.cb.ready <= ($urandom_range(99) < cfg.ready_pct);
      end
    endtask
  endclass

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
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.rst_n && vif.mon_cb.valid && vif.mon_cb.ready) begin
          stream_beat b = stream_beat::type_id::create("beat");
          b.port  = cfg.port;
          b.data  = vif.mon_cb.data;
          b.last  = vif.mon_cb.last;
          b.cycle = vif.mon_cb.cycle;
          ap.write(b);
        end
      end
    endtask
  endclass

  // One class, instantiated once per output. Everything that differs between
  // output 0 and output 1 (the interface, the port number, the ready knob)
  // comes from config_db, set for this instance's path.
  class out_agent extends uvm_agent;
    `uvm_component_utils(out_agent)
    out_ready_driver drv;
    out_monitor      mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      drv = out_ready_driver::type_id::create("drv", this);
      mon = out_monitor::type_id::create("mon", this);
    endfunction
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

  // ── sequences ─────────────────────────────────────────────────────────────
  // Lab 03's generator. Each packet is made through the factory
  // (router_pkt::type_id::create), so a test can swap in a subclass of
  // router_pkt without touching this sequence. As in Lab 03, the tag is the
  // packet's number, so you can find a packet in a log by its header.
  class router_rand_seq extends uvm_sequence #(router_pkt);
    `uvm_object_utils(router_rand_seq)
    int unsigned n = 200;
    bit [3:0]    route_en = 4'hF;   // which routes are enabled now
    int unsigned first_tag = 0;

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
