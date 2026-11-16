// SELFTEST -- the top module: clock, the ALU, the interface, run_test().
module st_top;
  import uvm_pkg::*;
  logic clk = 0;
  always #5 clk = ~clk;
  st_if sif (clk);
  st_alu u_alu (.clk(clk), .rst_n(sif.rst_n), .in_valid(sif.in_valid), .op(sif.op),
                .a(sif.a), .b(sif.b), .out_valid(sif.out_valid), .result(sif.result),
                .carry(sif.carry), .zero(sif.zero));
  initial begin
    uvm_config_db#(virtual st_if.DRV)::set(null, "uvm_test_top*", "drv_vif", sif.DRV);
    uvm_config_db#(virtual st_if.MON)::set(null, "uvm_test_top*", "mon_vif", sif.MON);
    // the whole interface, for st_nba_driver, which drives the pins directly
    uvm_config_db#(virtual st_if)::set(null, "uvm_test_top*", "pin_vif", sif);
    run_test();
  end
endmodule
