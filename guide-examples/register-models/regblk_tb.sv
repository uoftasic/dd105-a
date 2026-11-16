// DD105-A guide example, "Register models": the testbench.
//
// A bus agent (sequencer, driver, monitor), a register model of regblk's four
// registers, the adapter between them, and a predictor. +PREDICT= picks how
// the model's mirror follows the design:
//
//   predictor  (default) a uvm_reg_predictor on the monitor's analysis port
//   auto       auto-predict on the map: only the model's own operations
//   none       neither
//
// Tests:
//   reg_reset_test    uvm_reg_hw_reset_seq
//   reg_bitbash_test  uvm_reg_bit_bash_seq
//   reg_mirror_test   a model write, a raw bus write, mirror(UVM_CHECK) on CTRL
//                     and on FLAGS, and set() with update()

interface rb_if (input logic clk, input logic rst_n);
  logic        sel, we, err, ev_ovf, ev_err;
  logic [3:0]  addr;
  logic [15:0] wdata, rdata;
  clocking cb @(posedge clk);
    default input #1step output #1;
    output sel, we, addr, wdata, ev_ovf, ev_err;
    input  rdata, err;
  endclocking
  clocking mon_cb @(posedge clk);
    default input #1step;
    input sel, we, addr, wdata, rdata, err;
  endclocking
endinterface

package rb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ── the bus agent ─────────────────────────────────────────────────────────
  class bus_item extends uvm_sequence_item;
    `uvm_object_utils(bus_item)
    bit        we, err;
    bit [3:0]  addr;
    bit [15:0] wdata, rdata;
    function new(string name = "bus_item");
      super.new(name);
    endfunction
    function string convert2string();
      return we ? $sformatf("write %h <- %h%s", addr, wdata, err ? " (err)" : "")
                : $sformatf("read %h -> %h%s", addr, rdata, err ? " (err)" : "");
    endfunction
  endclass

  class bus_driver extends uvm_driver #(bus_item);
    `uvm_component_utils(bus_driver)
    virtual rb_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      vif.cb.sel <= 1'b0;
      forever begin
        seq_item_port.get_next_item(req);
        @(vif.cb);                    // drive from a clock edge
        vif.cb.sel   <= 1'b1;
        vif.cb.we    <= req.we;
        vif.cb.addr  <= req.addr;
        vif.cb.wdata <= req.wdata;
        @(vif.cb);                    // the edge that ends the transfer
        req.rdata = vif.cb.rdata;
        req.err   = vif.cb.err;
        vif.cb.sel <= 1'b0;
        seq_item_port.item_done();
      end
    endtask
  endclass

  class bus_monitor extends uvm_monitor;
    `uvm_component_utils(bus_monitor)
    virtual rb_if vif;
    uvm_analysis_port #(bus_item) ap;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    task run_phase(uvm_phase phase);
      bus_item it;
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.sel) begin
          it       = bus_item::type_id::create("it");
          it.we    = vif.mon_cb.we;
          it.addr  = vif.mon_cb.addr;
          it.wdata = vif.mon_cb.wdata;
          it.rdata = vif.mon_cb.rdata;
          it.err   = vif.mon_cb.err;
          ap.write(it);
        end
      end
    endtask
  endclass

  class bus_agent extends uvm_agent;
    `uvm_component_utils(bus_agent)
    uvm_sequencer #(bus_item) sqr;
    bus_driver                drv;
    bus_monitor               mon;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      virtual rb_if vif;
      super.build_phase(phase);
      if (!uvm_config_db#(virtual rb_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "no virtual rb_if in config_db")
      sqr = uvm_sequencer#(bus_item)::type_id::create("sqr", this);
      drv = bus_driver::type_id::create("drv", this);
      mon = bus_monitor::type_id::create("mon", this);
      drv.vif = vif;
      mon.vif = vif;
    endfunction
    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // One raw transfer, which goes around the register model.
  class bus_rw_seq extends uvm_sequence #(bus_item);
    `uvm_object_utils(bus_rw_seq)
    bit        we;
    bit [3:0]  addr;
    bit [15:0] wdata;
    function new(string name = "bus_rw_seq");
      super.new(name);
    endfunction
    task body();
      bus_item it = bus_item::type_id::create("it");
      start_item(it);
      it.we    = we;
      it.addr  = addr;
      it.wdata = wdata;
      finish_item(it);
    endtask
  endclass

  // ── the register model ────────────────────────────────────────────────────
  // configure(parent, size, lsb, access, volatile, reset, has_reset, is_rand,
  //           individually_accessible)
  class reg_id extends uvm_reg;
    `uvm_object_utils(reg_id)
    uvm_reg_field id;
    function new(string name = "reg_id");
      super.new(name, 16, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      id = uvm_reg_field::type_id::create("id");
      id.configure(this, 16, 0, "RO", 0, uvm_reg_data_t'('h105A), 1, 0, 1);
    endfunction
  endclass

  class reg_ctrl extends uvm_reg;
    `uvm_object_utils(reg_ctrl)
    rand uvm_reg_field en, mode;
    function new(string name = "reg_ctrl");
      super.new(name, 16, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      en   = uvm_reg_field::type_id::create("en");
      mode = uvm_reg_field::type_id::create("mode");
      en.configure  (this, 1, 0, "RW", 0, 0, 1, 1, 0);
      mode.configure(this, 3, 1, "RW", 0, 0, 1, 1, 0);
    endfunction
  endclass

  class reg_flags extends uvm_reg;
    `uvm_object_utils(reg_flags)
    uvm_reg_field ovf, err;
    function new(string name = "reg_flags");
      super.new(name, 16, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      ovf = uvm_reg_field::type_id::create("ovf");
      err = uvm_reg_field::type_id::create("err");
      ovf.configure(this, 1, 0, "W1C", 1, 0, 1, 0, 0);   // volatile: the design sets it
      err.configure(this, 1, 1, "W1C", 1, 0, 1, 0, 0);
    endfunction
  endclass

  class reg_count extends uvm_reg;
    `uvm_object_utils(reg_count)
    uvm_reg_field count;
    function new(string name = "reg_count");
      super.new(name, 16, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      count = uvm_reg_field::type_id::create("count");
      count.configure(this, 8, 0, "RO", 1, 0, 1, 0, 1);  // volatile: the design counts
    endfunction
  endclass

  class regs_block extends uvm_reg_block;
    `uvm_object_utils(regs_block)
    rand reg_id    id;
    rand reg_ctrl  ctrl;
    rand reg_flags flags;
    rand reg_count count;
    function new(string name = "regs_block");
      super.new(name, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      id    = reg_id::type_id::create("ID");
      ctrl  = reg_ctrl::type_id::create("CTRL");
      flags = reg_flags::type_id::create("FLAGS");
      count = reg_count::type_id::create("COUNT");
      id.configure(this);    id.build();
      ctrl.configure(this);  ctrl.build();
      flags.configure(this); flags.build();
      count.configure(this); count.build();
      // 2 bytes per register, byte addresses
      default_map = create_map("map", 0, 2, UVM_LITTLE_ENDIAN, 1);
      default_map.add_reg(id,    'h0, "RO");
      default_map.add_reg(ctrl,  'h4, "RW");
      default_map.add_reg(flags, 'h8, "RW");
      default_map.add_reg(count, 'hC, "RO");
    endfunction
  endclass

  // A register operation becomes one bus_item, and a finished bus_item
  // becomes a register operation again.
  class bus_adapter extends uvm_reg_adapter;
    `uvm_object_utils(bus_adapter)
    function new(string name = "bus_adapter");
      super.new(name);
    endfunction
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
      bus_item it = bus_item::type_id::create("it");
      it.we    = (rw.kind == UVM_WRITE);
      it.addr  = rw.addr[3:0];
      it.wdata = rw.data[15:0];
      return it;
    endfunction
    virtual function void bus2reg(uvm_sequence_item bus_item_h, ref uvm_reg_bus_op rw);
      bus_item it;
      if (!$cast(it, bus_item_h)) `uvm_fatal("ADAPTER", "bus2reg was given something that isn't a bus_item")
      rw.kind   = it.we ? UVM_WRITE : UVM_READ;
      rw.addr   = uvm_reg_addr_t'(it.addr);
      rw.data   = it.we ? uvm_reg_data_t'(it.wdata) : uvm_reg_data_t'(it.rdata);
      rw.status = it.err ? UVM_NOT_OK : UVM_IS_OK;
    endfunction
  endclass

  class rb_env extends uvm_env;
    `uvm_component_utils(rb_env)
    bus_agent                     agent;
    regs_block                    regs;
    bus_adapter                   adapter;
    uvm_reg_predictor #(bus_item) predictor;
    string                        predict = "predictor";
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      void'($value$plusargs("PREDICT=%s", predict));
      agent     = bus_agent::type_id::create("agent", this);
      predictor = uvm_reg_predictor#(bus_item)::type_id::create("predictor", this);
      adapter   = bus_adapter::type_id::create("adapter");
      regs      = regs_block::type_id::create("regs");
      regs.configure(null, "");
      regs.build();
      regs.lock_model();
    endfunction
    function void connect_phase(uvm_phase phase);
      regs.default_map.set_sequencer(agent.sqr, adapter);
      regs.default_map.set_auto_predict(predict == "auto");
      if (predict == "predictor") begin
        predictor.map     = regs.default_map;
        predictor.adapter = adapter;
        agent.mon.ap.connect(predictor.bus_in);
      end
      `uvm_info("RAL", $sformatf("the mirror follows the design through: %s", predict), UVM_LOW)
    endfunction
  endclass

  // ── the tests ─────────────────────────────────────────────────────────────
  class rb_base_test extends dd105_pkg::dd105_base_test;
    `uvm_component_utils(rb_base_test)
    rb_env        env;
    virtual rb_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual rb_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "no virtual rb_if in config_db")
      uvm_config_db#(virtual rb_if)::set(this, "env.agent", "vif", vif);
      env = rb_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      vif.cb.ev_ovf <= 1'b0;
      vif.cb.ev_err <= 1'b0;
      @(posedge vif.rst_n);
      @(vif.cb);
      body();
      repeat (2) @(vif.cb);
      phase.drop_objection(this);
    endtask
    virtual task body();
    endtask
    function string hex(uvm_reg_data_t v);
      return $sformatf("%h", v[15:0]);
    endfunction
  endclass

  class reg_reset_test extends rb_base_test;
    `uvm_component_utils(reg_reset_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task body();
      uvm_reg_hw_reset_seq s = uvm_reg_hw_reset_seq::type_id::create("s");
      s.model = env.regs;
      s.start(null);
    endtask
  endclass

  class reg_bitbash_test extends rb_base_test;
    `uvm_component_utils(reg_bitbash_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task body();
      uvm_reg_bit_bash_seq s = uvm_reg_bit_bash_seq::type_id::create("s");
      s.model = env.regs;
      s.start(null);
    endtask
  endclass

  class reg_mirror_test extends rb_base_test;
    `uvm_component_utils(reg_mirror_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    task body();
      uvm_status_e status;
      bus_rw_seq   raw;
      regs_block   regs = env.regs;

      regs.ctrl.write(status, uvm_reg_data_t'('h0005));
      `uvm_info("RAL", {"after the model writes 0005 to CTRL, its mirror is ", hex(regs.ctrl.get_mirrored_value())}, UVM_LOW)

      raw = bus_rw_seq::type_id::create("raw");
      raw.we = 1; raw.addr = 4'h4; raw.wdata = 16'h000B;
      raw.start(env.agent.sqr);
      `uvm_info("RAL", {"after a raw bus write of 000b to CTRL, the mirror is ", hex(regs.ctrl.get_mirrored_value())}, UVM_LOW)

      regs.ctrl.mirror(status, UVM_CHECK);
      `uvm_info("RAL", {"after mirror(UVM_CHECK) reads CTRL, the mirror is ", hex(regs.ctrl.get_mirrored_value())}, UVM_LOW)

      // The design sets FLAGS.OVF on its own. Drive the pulse from a clock
      // edge, as every driver in the labs does.
      @(vif.cb);
      vif.cb.ev_ovf <= 1'b1;
      @(vif.cb);
      vif.cb.ev_ovf <= 1'b0;
      @(vif.cb);
      `uvm_info("RAL", {"after an overflow event, the mirror of FLAGS is ", hex(regs.flags.get_mirrored_value())}, UVM_LOW)
      regs.flags.mirror(status, UVM_CHECK);
      `uvm_info("RAL", {"after mirror(UVM_CHECK) reads FLAGS, the mirror is ", hex(regs.flags.get_mirrored_value())}, UVM_LOW)

      // set() changes the desired value only; update() writes the register.
      regs.ctrl.mode.set(uvm_reg_data_t'(3));
      `uvm_info("RAL", $sformatf("after set(3) on CTRL.MODE: desired %s, mirror %s, needs_update %0d",
                hex(regs.ctrl.get()), hex(regs.ctrl.get_mirrored_value()), regs.ctrl.needs_update()), UVM_LOW)
      regs.ctrl.update(status);
      `uvm_info("RAL", $sformatf("after update(): desired %s, mirror %s, needs_update %0d",
                hex(regs.ctrl.get()), hex(regs.ctrl.get_mirrored_value()), regs.ctrl.needs_update()), UVM_LOW)
    endtask
  endclass
endpackage

module regblk_tb_top;
  import uvm_pkg::*;
  import rb_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst_n = 1'b0;
  initial begin
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;
  end

  rb_if bif (clk, rst_n);
  regblk dut (
    .clk(clk), .rst_n(rst_n),
    .sel(bif.sel), .we(bif.we), .addr(bif.addr), .wdata(bif.wdata),
    .rdata(bif.rdata), .err(bif.err), .ev_ovf(bif.ev_ovf), .ev_err(bif.ev_err)
  );

  initial begin
    uvm_config_db#(virtual rb_if)::set(null, "uvm_test_top", "vif", bif);
    run_test();
  end
endmodule
