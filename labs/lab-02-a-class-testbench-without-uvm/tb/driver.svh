// DD105-A Lab 02: the classes that drive the router's pins.
//
//   driver      the input stream's source: takes packets from the generator's
//               mailbox and offers them beat by beat
//   sink        an output stream's sink: holds ready at 1, and counts beats
//   apb_master  writes a register over APB
//
// All three drive through their interface's clocking block, `vif.cb`. A
// drive such as `vif.cb.valid <= 1` changes the pin 1 ns after the next
// rising edge, and `@(vif.cb)` waits for that edge, so a loop of the form
// "drive, @(vif.cb), look at what was sampled" does one clock cycle per
// iteration and never races the router's flip-flops.
//
// The virtual interface types are written out in full (`virtual
// stream_src_if`) and never through a typedef. On this simulator (Verilator
// 5.050), a class in a package that reaches an interface through a typedef of
// a virtual interface reads 0 from every clocking-block input, with no warning.

class driver;
  virtual stream_src_if vif;
  mailbox #(packet)     from_gen;
  int unsigned          n_pkts, n_beats;  // what went into the router
  int unsigned          n_errors;
  int unsigned          max_wait = 1000;  // cycles a beat may wait for in_ready

  function new(virtual stream_src_if vif, mailbox #(packet) from_gen);
    this.vif      = vif;
    this.from_gen = from_gen;
  endfunction

  // Send n packets, then return. Call it at a rising edge. A beat is offered
  // (valid = 1) until a cycle in which ready is also 1: that cycle is the
  // handshake, and the beat moves at the edge that ends it.
  task run(int unsigned n);
    packet       p;
    int unsigned waited;
    repeat (n) begin
      from_gen.get(p);
      foreach (p.data[i]) begin
        if (p.gap[i] > 0) begin
          vif.cb.valid <= 1'b0;
          repeat (p.gap[i]) @(vif.cb);
        end
        vif.cb.valid <= 1'b1;
        vif.cb.data  <= p.data[i];
        vif.cb.last  <= (i == p.data.size() - 1);
        waited = 0;
        do begin
          @(vif.cb);
          waited++;
        end while (!vif.cb.ready && waited < max_wait);
        if (!vif.cb.ready) begin
          n_errors++;
          $error("driver: in_ready stayed 0 for %0d cycles with beat %0d of %s on offer; stopping",
                 waited, i, p.sprint());
          vif.cb.valid <= 1'b0;
          return;
        end
        n_beats++;
      end
      n_pkts++;
    end
    vif.cb.valid <= 1'b0;
  endtask
endclass

class sink;
  virtual stream_snk_if vif;
  int unsigned          n_beats;   // beats the router handed over

  function new(virtual stream_snk_if vif);
    this.vif = vif;
  endfunction

  // Hold ready at 1 for the whole test, so every beat the router offers is
  // taken in the cycle it appears. Then a beat is taken at every edge where
  // valid was 1.
  task run();
    vif.cb.ready <= 1'b1;
    forever begin
      @(vif.cb);
      if (vif.cb.rst_n && vif.cb.valid) n_beats++;
    end
  endtask
endclass

class apb_master;
  virtual apb_if vif;

  function new(virtual apb_if vif);
    this.vif = vif;
  endfunction

  // One write: a setup cycle, then access cycles until pready.
  task write(bit [7:0] addr, bit [31:0] data);
    @(vif.cb);
    vif.cb.psel    <= 1'b1;
    vif.cb.penable <= 1'b0;
    vif.cb.pwrite  <= 1'b1;
    vif.cb.paddr   <= addr;
    vif.cb.pwdata  <= data;
    @(vif.cb);
    vif.cb.penable <= 1'b1;
    do @(vif.cb); while (!vif.cb.pready);
    vif.cb.psel    <= 1'b0;
    vif.cb.penable <= 1'b0;
  endtask

  task wait_for_reset();
    do @(vif.cb); while (!vif.cb.rst_n);
  endtask
endclass
