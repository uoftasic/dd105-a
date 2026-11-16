// DD105-A Lab 07: an APB3 master agent.
//
//   apb_item       one transfer: what to send, and what came back
//   apb_driver     the master: setup cycle, access cycles until pready
//   apb_monitor    one apb_item per completed transfer, with its cycle numbers
//   apb_agent      the three, plus a sequencer
//   apb_rw_seq     one raw transfer, for addresses the register model can't
//                  reach (the bad ones)
//
// The register model (router_ral_pkg) sends its reads and writes through
// this agent's sequencer, and its predictor listens to the monitor.
//
// The virtual interface type is written out in full (`virtual apb_if`) and
// never through a typedef. On this simulator (5.050), a class in a package
// that reaches an interface through a typedef'd virtual interface type reads
// 0 from every clocking-block input, forever, with no warning.

package apb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class apb_item extends uvm_sequence_item;
    `uvm_object_utils(apb_item)

    rand bit          write;
    rand bit [7:0]    addr;
    rand bit [31:0]   wdata;
    // Idle cycles (psel = 0) before this transfer's setup cycle. 0 starts it
    // in the cycle after the previous transfer completes, which rule A3 allows.
    rand int unsigned idle;

    // What the transfer returned (the driver fills these in).
    bit [31:0]   rdata;
    bit          slverr;

    // The cycles of the setup, the first access and the completion. The
    // monitor fills these in; the scoreboard needs the first access cycle,
    // because that's the cycle whose register value a read returns.
    int unsigned setup_cycle, access_cycle, end_cycle;

    constraint c_idle { idle inside {[0:3]}; }

    function new(string name = "apb_item");
      super.new(name);
    endfunction

    virtual function string convert2string();
      return $sformatf("%s %02h data %08h%s (cycles %0d-%0d)", write ? string'("WRITE") : string'("READ "),
                       addr, write ? wdata : rdata, slverr ? string'(" PSLVERR") : string'(""),
                       setup_cycle, end_cycle);
    endfunction
  endclass

  typedef uvm_sequencer #(apb_item) apb_sequencer;

  class apb_cfg extends uvm_object;
    `uvm_object_utils(apb_cfg)
    virtual apb_if      vif;
    // A transfer whose pready hasn't come after this many access cycles is
    // reported and abandoned, so a router that never answers can't hang the test.
    int unsigned max_wait = 16;
    function new(string name = "apb_cfg");
      super.new(name);
    endfunction
  endclass

  // ── driver ────────────────────────────────────────────────────────────────
  // The driver works in two steps per clock cycle. At the falling edge in the
  // middle of cycle n, when every signal of cycle n has settled, it looks at
  // the bus (did the transfer complete?), asks the sequencer for the next item
  // if it needs one, and decides what the bus does in cycle n+1. Right after
  // the rising edge that ends cycle n, it drives that through the clocking
  // block. The split matters on this simulator: try_next_item() waits for the
  // NBA region, and a clocking-block drive issued after that wait, in the same
  // time step as the edge, lands at the next edge instead, a cycle late.
  //
  // A transfer that a reset interrupts is abandoned and started again after
  // the reset, as rule A4 describes.
  class apb_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_driver)
    apb_cfg cfg;
    virtual apb_if vif;

    typedef enum {IDLE, SETUP, ACCESS} phase_e;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(apb_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "apb_driver has no apb_cfg")
      vif = cfg.vif;
    endfunction

    // Called in the middle of cycle n: must the bus be idle in cycle n+1? Yes
    // while rst_n is 0, and from the cycle a scheduled reset starts.
    function bit hold();
      return !vif.rst_n || (vif.hold_at != 0 && vif.cycle + 1 >= vif.hold_at);
    endfunction

    task run_phase(uvm_phase phase);
      apb_item     t;
      phase_e      now = IDLE, next;
      int unsigned idle_left, waited;
      vif.cb.psel    <= 1'b0;
      vif.cb.penable <= 1'b0;
      forever begin
        @(negedge vif.clk);
        // What happened in this cycle.
        if (now == ACCESS && vif.rst_n) begin
          waited++;
          if (vif.pready) begin
            t.rdata  = vif.prdata;
            t.slverr = vif.pslverr;
            seq_item_port.item_done();
            t = null;
            now = IDLE;
          end else if (waited >= cfg.max_wait) begin
            `uvm_error("APB", $sformatf("no pready after %0d access cycles of %s at %02h",
                       waited, t.write ? string'("a write") : string'("a read"), t.addr))
            t.rdata  = 32'h0;
            t.slverr = 1'b1;
            seq_item_port.item_done();
            t = null;
            now = IDLE;
          end
        end
        // What the bus does in the next cycle.
        if (hold()) begin
          next = IDLE;                    // a transfer in progress is abandoned; t is kept
        end else if (now == SETUP) begin
          next = ACCESS;
        end else if (now == ACCESS) begin
          next = ACCESS;
        end else begin
          if (t == null) begin
            seq_item_port.try_next_item(t);
            if (t != null) idle_left = t.idle;
          end
          if (t == null) next = IDLE;
          else if (idle_left > 0) begin
            idle_left--;
            next = IDLE;
          end else next = SETUP;
        end
        // Drive it, just after the edge.
        @(vif.cb);
        case (next)
          IDLE: begin
            vif.cb.psel    <= 1'b0;
            vif.cb.penable <= 1'b0;
          end
          SETUP: begin
            vif.cb.psel    <= 1'b1;
            vif.cb.penable <= 1'b0;
            vif.cb.pwrite  <= t.write;
            vif.cb.paddr   <= t.addr;
            vif.cb.pwdata  <= t.write ? t.wdata : $urandom;   // pwdata means nothing in a read
          end
          ACCESS: begin
            if (now == SETUP) waited = 0;
            vif.cb.penable <= 1'b1;
          end
        endcase
        now = next;
      end
    endtask
  endclass

  // ── monitor ───────────────────────────────────────────────────────────────
  class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    uvm_analysis_port #(apb_item) ap;
    apb_cfg cfg;
    virtual apb_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(apb_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("NOCFG", "apb_monitor has no apb_cfg")
      vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
      apb_item cur;
      bit in_xfer = 0, first = 0;
      forever begin
        @(vif.mon_cb);
        if (!vif.mon_cb.rst_n) begin      // a reset abandons any transfer
          in_xfer = 0;
          continue;
        end
        if (vif.mon_cb.psel && !vif.mon_cb.penable) begin
          cur = apb_item::type_id::create("apb_obs");
          cur.write       = vif.mon_cb.pwrite;
          cur.addr        = vif.mon_cb.paddr;
          cur.wdata       = vif.mon_cb.pwdata;
          cur.setup_cycle = vif.mon_cb.cycle;
          in_xfer = 1;
          first   = 1;
        end else if (vif.mon_cb.psel && vif.mon_cb.penable && in_xfer) begin
          if (first) cur.access_cycle = vif.mon_cb.cycle;
          first = 0;
          if (vif.mon_cb.pready) begin
            cur.rdata     = vif.mon_cb.prdata;
            cur.slverr    = vif.mon_cb.pslverr;
            cur.end_cycle = vif.mon_cb.cycle;
            `uvm_info("APB", cur.convert2string(), UVM_HIGH)
            ap.write(cur);
            in_xfer = 0;
          end
        end else begin
          in_xfer = 0;
        end
      end
    endtask
  endclass

  // ── agent ─────────────────────────────────────────────────────────────────
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
  // One transfer to any address. The register model covers the ten good
  // addresses; this reaches the other 246.
  class apb_rw_seq extends uvm_sequence #(apb_item);
    `uvm_object_utils(apb_rw_seq)
    bit          write;
    bit [7:0]    addr;
    bit [31:0]   wdata;
    int unsigned idle;
    apb_item     rsp_item;    // the finished transfer: rdata and slverr

    function new(string name = "apb_rw_seq");
      super.new(name);
    endfunction

    task body();
      apb_item t = apb_item::type_id::create("t");
      start_item(t);
      t.write = write;
      t.addr  = addr;
      t.wdata = wdata;
      t.idle  = idle;
      finish_item(t);
      rsp_item = t;
    endtask
  endclass
endpackage
