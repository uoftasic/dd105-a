// The monitors. Each samples its pins at every rising edge through the
// interface's mon_cb, which gives each signal's value in the cycle that just
// ended, and puts what it saw into a mailbox, stamped with the cycle number.

// ── streams ─────────────────────────────────────────────────────────────────
// The same code watches the input stream and both outputs. The two stream
// interfaces are different types, so sampling the pins is a virtual task that
// the two subclasses below implement.
class stream_monitor;
  string         name;
  mailbox #(beat) beats;           // the scoreboard's mailbox; the env sets it

  function new(string name);
    this.name = name;
  endfunction

  virtual task sample(output bit rst_n, valid, ready, last, output bit [7:0] data,
                      output int unsigned cycle);
    `uvm_fatal("MON", "stream_monitor::sample is not implemented")
  endtask

  task run();
    bit          rst_n, valid, ready, last;
    bit [7:0]    data;
    int unsigned t, first = 0;
    bit          offering = 0;
    forever begin
      sample(rst_n, valid, ready, last, data, t);
      if (!rst_n) begin
        offering = 0;
        continue;
      end
      if (valid && !offering) begin
        offering = 1;
        first = t;
      end
      if (valid && ready) begin
        beat b = new();
        b.data = data;
        b.last = last;
        b.cycle = t;
        b.first_cycle = first;
        beats.put(b);
        offering = 0;
      end
      if (!valid) offering = 0;
    end
  endtask
endclass

class src_monitor extends stream_monitor;
  virtual stream_src_if vif;
  function new(string name, virtual stream_src_if vif);
    super.new(name);
    this.vif = vif;
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

class snk_monitor extends stream_monitor;
  virtual stream_snk_if vif;
  function new(string name, virtual stream_snk_if vif);
    super.new(name);
    this.vif = vif;
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

// ── APB ─────────────────────────────────────────────────────────────────────
// One apb_xfer per completed transfer, with the cycles of its setup, its first
// access and its completion.
class apb_monitor;
  virtual apb_if       vif;
  mailbox #(apb_xfer)  xfers;      // the scoreboard's mailbox; the env sets it

  function new(virtual apb_if vif);
    this.vif = vif;
  endfunction

  task run();
    apb_xfer cur;
    bit in_xfer = 0, first = 0;
    forever begin
      @(vif.mon_cb);
      if (!vif.mon_cb.rst_n) begin
        in_xfer = 0;
        continue;
      end
      if (vif.mon_cb.psel && !vif.mon_cb.penable) begin
        cur = new();
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
          xfers.put(cur);
          in_xfer = 0;
        end
      end else begin
        in_xfer = 0;
      end
    end
  endtask
endclass

// ── reset and irq ───────────────────────────────────────────────────────────
// One sample every cycle. The scoreboard uses them as its clock.
class sys_monitor;
  virtual router_sys_if  vif;
  mailbox #(sys_sample)  samples;  // the scoreboard's mailbox; the env sets it

  function new(virtual router_sys_if vif);
    this.vif = vif;
  endfunction

  task run();
    forever begin
      sys_sample s;
      @(vif.mon_cb);
      s = new();
      s.cycle = vif.mon_cb.cycle;
      s.rst_n = vif.mon_cb.rst_n;
      s.irq   = vif.mon_cb.irq;
      samples.put(s);
    end
  endtask
endclass
