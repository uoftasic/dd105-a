// A clocking-block drive issued right after the edge, and one issued after
// waiting for the NBA region in the same time step, as try_next_item() does.
interface pif (input logic clk);
  logic r = 0, s = 0;
  clocking cb @(posedge clk);
    default input #1step output #1;
    output r, s;
  endclocking
endinterface

package ppkg;
  class holder; static virtual pif v; endclass
  class drv;
    static int nba, next_nba;
    task run();
      virtual pif vif = holder::v;
      @(vif.cb);
      $display("%0t: drive r", $time);
      vif.cb.r <= 1;
      @(vif.cb);
      next_nba++; nba <= next_nba; @(nba);      // what uvm_wait_for_nba_region() does
      $display("%0t: drive s, after an NBA wait", $time);
      vif.cb.s <= 1;
    endtask
  endclass
endpackage

module top;
  import ppkg::*;
  logic clk = 0;
  always #5 clk = ~clk;
  pif p (clk);
  always @(posedge p.r) $display("%0t: r is 1", $time);
  always @(posedge p.s) $display("%0t: s is 1", $time);
  initial begin
    drv d = new();
    holder::v = p;
    fork d.run(); join_none
    repeat (4) @(posedge clk);
    $finish;
  end
endmodule
