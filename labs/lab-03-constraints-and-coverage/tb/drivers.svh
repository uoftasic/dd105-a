// The drivers: the APB master, the source on the input stream, and a sink on
// each output. Each one drives its pins through the interface's clocking
// block, 1 ns after a rising edge.

// ── APB master ──────────────────────────────────────────────────────────────
// The test calls write() and read() directly, one transfer at a time. A
// transfer is a setup cycle and then access cycles until pready, which the
// clocking block samples as it was in the cycle that just ended.
class apb_master;
  virtual apb_if vif;
  int unsigned   max_wait = 16;   // access cycles to wait for pready before giving up

  function new(virtual apb_if vif);
    this.vif = vif;
  endfunction

  task xfer(bit write, bit [7:0] addr, bit [31:0] wdata, output bit [31:0] rdata, output bit slverr);
    int unsigned waited = 0;
    @(vif.cb);
    vif.cb.psel    <= 1'b1;
    vif.cb.penable <= 1'b0;
    vif.cb.pwrite  <= write;
    vif.cb.paddr   <= addr;
    vif.cb.pwdata  <= write ? wdata : 32'($urandom);   // pwdata means nothing in a read
    @(vif.cb);
    vif.cb.penable <= 1'b1;
    do begin
      @(vif.cb);
      waited++;
    end while (!vif.cb.pready && waited < max_wait);
    if (!vif.cb.pready)
      `uvm_error("APB", $sformatf("no pready after %0d access cycles of %s at %02h", waited,
                 write ? string'("a write") : string'("a read"), addr))
    rdata  = vif.cb.prdata;
    slverr = vif.cb.pslverr;
    vif.cb.psel    <= 1'b0;
    vif.cb.penable <= 1'b0;
  endtask

  task write(bit [7:0] addr, bit [31:0] data);
    bit [31:0] rdata;
    bit        slverr;
    xfer(1'b1, addr, data, rdata, slverr);
  endtask

  task read(bit [7:0] addr, output bit [31:0] data);
    bit slverr;
    xfer(1'b0, addr, 32'h0, data, slverr);
  endtask
endclass

// ── source ──────────────────────────────────────────────────────────────────
// Takes packets from its mailbox and offers them beat by beat. It decides at
// the falling edge in the middle of each cycle (did the beat move? what goes
// out next?) and drives right after the rising edge. While in_valid is 0 it
// puts random values on in_data and in_last, which the router must ignore.
// A beat that waits max_wait cycles for in_ready is reported and the packet
// given up, so a router that stops answering can't hang the test.
class src_driver;
  virtual stream_src_if vif;
  mailbox #(packet)     pkts = new();
  int unsigned          max_wait = 4000;
  packet                cur;          // the packet being sent, or null
  int unsigned          n_sent;

  function new(virtual stream_src_if vif);
    this.vif = vif;
  endfunction

  function bit idle();
    return pkts.num() == 0 && cur == null;
  endfunction

  task run();
    int          i;                  // the beat of cur on offer, or next to offer
    int unsigned gap_left, waited;
    bit          offering = 0;       // in_valid is 1 in this cycle
    bit          drive_beat;
    vif.cb.valid <= 1'b0;
    forever begin
      @(negedge vif.clk);
      drive_beat = 0;
      if (!vif.rst_n) begin
        // Rule I3: a reset abandons the packet; the next beat offered is a header.
        cur = null;
        offering = 0;
      end else if (offering) begin
        if (vif.ready) begin             // the handshake: the beat moves at this edge
          offering = 0;
          i++;
          if (i == cur.data.size()) begin
            cur = null;
            n_sent++;
          end else begin
            gap_left = cur.gap[i];
          end
        end else if (++waited >= max_wait) begin
          `uvm_error("SRC", $sformatf("beat %0d of a packet (%02h) waited %0d cycles for in_ready; giving the packet up",
                     i, cur.data[i], waited))
          offering = 0;
          cur = null;
        end
      end
      if (vif.rst_n && !offering) begin
        if (cur == null && pkts.try_get(cur)) begin
          i = 0;
          gap_left = cur.gap[0];
          waited = 0;
        end
        if (cur != null) begin
          if (gap_left > 0) gap_left--;
          else begin
            drive_beat = 1;
            offering = 1;
            waited = 0;
          end
        end
      end
      @(vif.cb);
      if (drive_beat) begin
        vif.cb.valid <= 1'b1;
        vif.cb.data  <= cur.data[i];
        vif.cb.last  <= cur.last[i];
      end else if (!offering) begin
        vif.cb.valid <= 1'b0;
        vif.cb.data  <= 8'($urandom);
        vif.cb.last  <= 1'($urandom);
      end
    end
  endtask
endclass

// ── sink ────────────────────────────────────────────────────────────────────
// Drives out_ready every cycle: 1 in ready_pct percent of cycles, chosen at
// random, and 0 in every cycle while stall is 1. A change to either knob
// reaches the pin at the next rising edge.
class snk_driver;
  virtual stream_snk_if vif;
  int unsigned          ready_pct = 100;
  bit                   stall = 0;

  function new(virtual stream_snk_if vif);
    this.vif = vif;
  endfunction

  task run();
    vif.cb.ready <= 1'b0;
    forever begin
      @(vif.cb);
      vif.cb.ready <= !stall && ($urandom_range(99) < ready_pct);
    end
  endtask
endclass
