// Clocking-block inputs read through virtual interfaces from a class in a
// package. Each clocking block is read one way only: mon_a through the type
// written out (virtual pif), mon_b through a typedef of the same type.
interface pif (input logic clk);
  int unsigned cycle = 1;
  always @(posedge clk) cycle <= cycle + 1;
  clocking mon_a @(posedge clk);
    default input #1step;
    input cycle;
  endclocking
  clocking mon_b @(posedge clk);
    default input #1step;
    input cycle;
  endclocking
endinterface

package ppkg;
  typedef virtual pif pif_vif;
  class holder;
    static virtual pif plain;
    static pif_vif     typed;
  endclass
  class watcher;
    virtual pif plain;
    pif_vif     typed;
    task run();
      plain = holder::plain;
      typed = holder::typed;
      repeat (4) begin
        @(plain.mon_a);
        $display("edge %0d: through virtual pif, mon_a.cycle = %0d; through the typedef, mon_b.cycle = %0d",
                 plain.cycle - 1, plain.mon_a.cycle, typed.mon_b.cycle);
      end
    endtask
  endclass
endpackage

module top;
  import ppkg::*;
  logic clk = 0;
  always #5 clk = ~clk;
  pif p (clk);
  initial begin
    watcher w = new();
    holder::plain = p;
    holder::typed = p;
    w.run();
    $finish;
  end
endmodule
