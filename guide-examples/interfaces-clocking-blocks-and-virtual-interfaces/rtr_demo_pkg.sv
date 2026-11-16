// DD105-A guide example: the classes. No UVM in them.

package rtr_demo_pkg;

  // Drives the router through rtr_pins_if's clocking block, and prints what
  // it sampled at each rising edge next to what the pin holds at that moment.
  class edge_demo;
    virtual rtr_pins_if vif;

    function new(virtual rtr_pins_if vif);
      this.vif = vif;
    endfunction

    // One APB write: a setup cycle, then access cycles until pready.
    task apb_write(bit [7:0] addr, bit [31:0] data);
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

    // At every rising edge: the clocking block's sample, and the pin.
    task watch(int unsigned n_edges);
      repeat (n_edges) begin
        @(vif.cb);
        $display("%0d ns edge: in_ready cb %0b pin %0b | in_valid pin %0b | out0_valid cb %0b pin %0b",
                 $time, vif.cb.in_ready, vif.in_ready, vif.in_valid,
                 vif.cb.out0_valid, vif.out0_valid);
      end
    endtask

    // Offer one beat until the router takes it: drive right after an edge,
    // then look at what the next edge sampled.
    task send_beat(bit [7:0] data, bit last);
      vif.cb.in_valid <= 1'b1;
      vif.cb.in_data  <= data;
      vif.cb.in_last  <= last;
      do @(vif.cb); while (!vif.cb.in_ready);
      $display("%0d ns: handshake on beat %02h", $time, data);
    endtask

    task run();
      do @(vif.cb); while (!vif.cb.rst_n);
      apb_write(8'h20, 32'h1);        // ROUTE0: EN = 1, PORT = 0
      $display("%0d ns: ROUTE0 written; now CTRL.EN", $time);
      fork
        watch(8);
      join_none
      apb_write(8'h04, 32'h1);        // CTRL.EN = 1
      $display("%0d ns: CTRL.EN written", $time);
      send_beat(8'h00, 1'b0);         // header: DST 0, packet 0
      send_beat(8'h5a, 1'b1);
      vif.cb.in_valid <= 1'b0;
      wait fork;
    endtask
  endclass

  // Two monitors that differ only in how they name the interface type.
  typedef virtual rtr_mon_if rtr_mon_vif_t;

  class mon_full_type;
    virtual rtr_mon_if vif;            // the type written out
    function new(virtual rtr_mon_if vif);
      this.vif = vif;
    endfunction
    task run(int unsigned n_edges);
      repeat (n_edges) begin
        @(vif.cb_a);
        $display("%0d ns: virtual rtr_mon_if: rst_n %0b in_ready %0b out0_valid %0b",
                 $time, vif.cb_a.rst_n, vif.cb_a.in_ready, vif.cb_a.out0_valid);
      end
    endtask
  endclass

  class mon_typedef;
    rtr_mon_vif_t vif;                 // the same type, through a typedef
    function new(rtr_mon_vif_t vif);
      this.vif = vif;
    endfunction
    task run(int unsigned n_edges);
      repeat (n_edges) begin
        @(vif.cb_b);
        $display("%0d ns: rtr_mon_vif_t:      rst_n %0b in_ready %0b out0_valid %0b",
                 $time, vif.cb_b.rst_n, vif.cb_b.in_ready, vif.cb_b.out0_valid);
      end
    endtask
  endclass

endpackage
