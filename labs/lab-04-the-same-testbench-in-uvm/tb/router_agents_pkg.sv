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
//   router_one_seq   one packet built by hand
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
  // Lab 03's packet as a sequence item. Its length kind is drawn with randcase
  // in pre_randomize() rather than with a dist constraint, which this
  // simulator's solver gets wrong (Lab 03); the solver then picks len from the
  // kind's range. Packets are 1 to 8 beats: nothing here is oversize.
  class router_pkt extends uvm_sequence_item;
    `uvm_object_utils(router_pkt)

    rand bit [1:0]    dst;        // the header's DST field: which route
    rand bit [5:0]    tag;        // the header's other six bits
    rand int unsigned len;        // beats, header included
    rand int unsigned idle;       // idle cycles before the header
    bit [1:0]         kind;       // 0: one beat, 1: 2 to 7, 2: eight (pre_randomize)
    bit [3:0]         route_en;   // set by the sequence: bit d is ROUTE[d].EN
    bit [7:0]         data[];     // the beats, built by post_randomize() or make()

    constraint c_len  { (kind == 0) -> len == 1;
                        (kind == 1) -> len inside {[2:7]};
                        (kind == 2) -> len == 8; }
    constraint c_idle { idle inside {[0:3]}; }
    // Only to enabled routes. A packet for a disabled route is dropped, and
    // Lab 03's random traffic never sent one.
    constraint c_dst  { ((route_en >> dst) & 4'h1) == 4'h1; }

    function new(string name = "router_pkt");
      super.new(name);
    endfunction

    function void pre_randomize();
      randcase
        25: kind = 0;
        50: kind = 1;
        25: kind = 2;
      endcase
    endfunction

    function void post_randomize();
      build();
    endfunction

    function void build();
      data = new[len];
      foreach (data[i]) data[i] = (i == 0) ? {dst, tag} : 8'($urandom);
    endfunction

    // A packet built by hand, for the directed steps.
    static function router_pkt make(bit [1:0] dst, int unsigned len, bit [5:0] tag = 0);
      router_pkt p = router_pkt::type_id::create("pkt");
      p.dst  = dst;
      p.tag  = tag;
      p.len  = len;
      p.idle = 0;
      p.build();
      return p;
    endfunction

    virtual function string convert2string();
      string s = $sformatf("DST %0d, %0d beats:", dst, len);
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
  // Lab 02's driver, as a uvm_driver: it takes a packet from the sequencer
  // instead of a mailbox, and sends its beats back to back.
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
        repeat (req.idle) @(vif.cb);
        foreach (req.data[i]) begin
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
  // port instead of putting it in a mailbox, so any number of subscribers
  // can have it, and the monitor doesn't know who they are.
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

  // Lab 02's sink. It takes no items, so it's a plain component rather than a
  // uvm_driver: every cycle it sets out_ready to 1 with probability
  // ready_pct percent. (Lab 05 replaces it with a reactive driver that
  // answers each beat.)
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
  // Lab 02's register tasks, apb_write() and apb_read(), as an agent.
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
  // router_pkt without touching this sequence.
  class router_rand_seq extends uvm_sequence #(router_pkt);
    `uvm_object_utils(router_rand_seq)
    int unsigned n = 60;
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
        start_item(p);
        ok = p.randomize() with { tag == 6'(first_tag + k); };
        if (ok == 0) `uvm_fatal("RAND", "router_pkt randomize() failed")
        finish_item(p);
      end
    endtask
  endclass

  // One packet, built by hand.
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
