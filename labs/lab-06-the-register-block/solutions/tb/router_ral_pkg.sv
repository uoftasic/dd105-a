// DD105-A Lab 06: the router's register model, finished.
//
// One uvm_reg per register in the specification's register map, with the
// access policies and volatility from its table:
//
//   ID          RO                 0x00   reset 0xD105_0001
//   CTRL.EN     RW                 0x04
//   STATUS.*    W1C, volatile      0x08   hardware sets the bits
//   INT_EN.*    RW                 0x0C
//   DROP_CNT.*  WC, volatile       0x10   hardware counts; any write clears
//   LEVEL.*     RO, volatile       0x14   follows the buffers
//   ROUTEn.*    RW                 0x20 + 4n
//
// UVM doesn't compare a volatile field when it reads one, so the register
// layer checks only ID, CTRL, INT_EN and ROUTE0 to ROUTE3. The scoreboard's
// reference model checks every read, the volatile registers included.
//
// The adapter turns register operations into apb_items and back; PSLVERR
// becomes UVM_NOT_OK. Prediction is explicit: a uvm_reg_predictor (in the
// environment) updates the model from every transfer the APB monitor sees,
// whoever started it.
//
// CTRL, STATUS, INT_EN and DROP_CNT also have HDL paths, for the back door:
// router_backdoor_test reads and writes them through uvm_hdl, which reaches
// the signals named in tb/router_regs.vlt. Nothing else uses the back door.

package router_ral_pkg;
  import uvm_pkg::*;
  import apb_pkg::*;
  `include "uvm_macros.svh"

  // configure(parent, size, lsb, access, volatile, reset, has_reset, is_rand,
  //           individually_accessible)

  class router_reg_id extends uvm_reg;
    `uvm_object_utils(router_reg_id)
    rand uvm_reg_field id;
    function new(string name = "ID");
      super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      id = uvm_reg_field::type_id::create("id");
      id.configure(this, 32, 0, "RO", 0, 32'hD105_0001, 1, 0, 1);
    endfunction
  endclass

  class router_reg_ctrl extends uvm_reg;
    `uvm_object_utils(router_reg_ctrl)
    rand uvm_reg_field en;
    function new(string name = "CTRL");
      super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      en = uvm_reg_field::type_id::create("en");
      en.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 1);
    endfunction
  endclass

  class router_reg_int_en extends uvm_reg;
    `uvm_object_utils(router_reg_int_en)
    rand uvm_reg_field noroute, full, oversize;
    function new(string name = "INT_EN");
      super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      noroute  = uvm_reg_field::type_id::create("noroute");
      full     = uvm_reg_field::type_id::create("full");
      oversize = uvm_reg_field::type_id::create("oversize");
      noroute.configure (this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
      full.configure    (this, 1, 1, "RW", 0, 1'b0, 1, 1, 0);
      oversize.configure(this, 1, 2, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
  endclass

  // STATUS has the same three bits as INT_EN. Hardware sets them, so they
  // are volatile, and writing 1 clears one.
  class router_reg_status extends uvm_reg;
    `uvm_object_utils(router_reg_status)
    rand uvm_reg_field noroute, full, oversize;
    function new(string name = "STATUS");
      super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      noroute  = uvm_reg_field::type_id::create("noroute");
      full     = uvm_reg_field::type_id::create("full");
      oversize = uvm_reg_field::type_id::create("oversize");
      noroute.configure (this, 1, 0, "W1C", 1, 1'b0, 1, 0, 0);
      full.configure    (this, 1, 1, "W1C", 1, 1'b0, 1, 0, 0);
      oversize.configure(this, 1, 2, "W1C", 1, 1'b0, 1, 0, 0);
    endfunction
  endclass

  // Two counters that hardware increments (volatile), and any write clears
  // both (WC).
  class router_reg_drop_cnt extends uvm_reg;
    `uvm_object_utils(router_reg_drop_cnt)
    rand uvm_reg_field noroute_cnt, full_cnt;
    function new(string name = "DROP_CNT");
      super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      noroute_cnt = uvm_reg_field::type_id::create("noroute_cnt");
      full_cnt    = uvm_reg_field::type_id::create("full_cnt");
      noroute_cnt.configure(this, 8, 0, "WC", 1, 8'h00, 1, 0, 0);
      full_cnt.configure   (this, 8, 8, "WC", 1, 8'h00, 1, 0, 0);
    endfunction
  endclass

  // The two buffer levels: read-only, and they change on their own.
  class router_reg_level extends uvm_reg;
    `uvm_object_utils(router_reg_level)
    rand uvm_reg_field level0, level1;
    function new(string name = "LEVEL");
      super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      level0 = uvm_reg_field::type_id::create("level0");
      level1 = uvm_reg_field::type_id::create("level1");
      level0.configure(this, 5, 0, "RO", 1, 5'd0, 1, 0, 0);
      level1.configure(this, 5, 8, "RO", 1, 5'd0, 1, 0, 0);
    endfunction
  endclass

  // One routing table entry: EN in bit 0 and PORT in bit 1.
  class router_reg_route extends uvm_reg;
    `uvm_object_utils(router_reg_route)
    rand uvm_reg_field en, port;
    function new(string name = "ROUTE");
      super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      en   = uvm_reg_field::type_id::create("en");
      port = uvm_reg_field::type_id::create("port");
      en.configure  (this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
      port.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
  endclass

  class router_reg_block extends uvm_reg_block;
    `uvm_object_utils(router_reg_block)
    rand router_reg_id       id;
    rand router_reg_ctrl     ctrl;
    rand router_reg_status   status;
    rand router_reg_int_en   int_en;
    rand router_reg_drop_cnt drop_cnt;
    rand router_reg_level    level;
    rand router_reg_route    route[4];

    function new(string name = "router_regs");
      super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
      // Byte addresses, 4 bytes per register.
      default_map = create_map("map", 0, 4, UVM_LITTLE_ENDIAN, 1);
      id       = router_reg_id::type_id::create("ID");
      ctrl     = router_reg_ctrl::type_id::create("CTRL");
      status   = router_reg_status::type_id::create("STATUS");
      int_en   = router_reg_int_en::type_id::create("INT_EN");
      drop_cnt = router_reg_drop_cnt::type_id::create("DROP_CNT");
      level    = router_reg_level::type_id::create("LEVEL");
      id.configure(this);       id.build();
      ctrl.configure(this);     ctrl.build();
      status.configure(this);   status.build();
      int_en.configure(this);   int_en.build();
      drop_cnt.configure(this); drop_cnt.build();
      level.configure(this);    level.build();
      // The rights in the map: ID and LEVEL are read-only, so the model
      // expects a write to them to change nothing.
      default_map.add_reg(id,       'h00, "RO");
      default_map.add_reg(ctrl,     'h04, "RW");
      default_map.add_reg(status,   'h08, "RW");
      default_map.add_reg(int_en,   'h0C, "RW");
      default_map.add_reg(drop_cnt, 'h10, "RW");
      default_map.add_reg(level,    'h14, "RO");
      foreach (route[n]) begin
        route[n] = router_reg_route::type_id::create($sformatf("ROUTE%0d", n));
        route[n].configure(this);
        route[n].build();
        default_map.add_reg(route[n], 'h20 + 4 * n, "RW");
      end

      // The back door: where each register lives in the design. A slice is
      // (signal, lsb, width) inside router_regs.
      add_hdl_path("router_tb_top.dut.u_regs");
      ctrl.add_hdl_path_slice("en_q", 0, 1);
      status.add_hdl_path_slice("status_q", 0, 3);
      int_en.add_hdl_path_slice("int_en_q", 0, 3);
      drop_cnt.add_hdl_path_slice("cnt_noroute_q", 0, 8);
      drop_cnt.add_hdl_path_slice("cnt_full_q", 8, 8);

      lock_model();
    endfunction
  endclass

  // Register operations to APB transfers and back.
  class router_reg_adapter extends uvm_reg_adapter;
    `uvm_object_utils(router_reg_adapter)
    function new(string name = "router_reg_adapter");
      super.new(name);
      supports_byte_enable = 0;
      provides_responses   = 0;
    endfunction

    // A register read or write becomes one apb_item for the APB sequencer.
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
      apb_item t = apb_item::type_id::create("reg_apb");
      t.write = (rw.kind == UVM_WRITE);
      t.addr  = rw.addr[7:0];
      t.wdata = rw.data[31:0];
      t.idle  = $urandom_range(2, 0);
      return t;
    endfunction

    // A finished apb_item, from the driver or the monitor, becomes the
    // register operation it carried out.
    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
      apb_item t;
      if (!$cast(t, bus_item)) begin
        `uvm_fatal("ADAPTER", "bus2reg was given something that isn't an apb_item")
        return;
      end
      rw.kind   = t.write ? UVM_WRITE : UVM_READ;
      rw.addr   = t.addr;
      rw.data   = t.write ? t.wdata : t.rdata;
      rw.status = t.slverr ? UVM_NOT_OK : UVM_IS_OK;
    endfunction
  endclass
endpackage
