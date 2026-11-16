// SELFTEST -- the Verilator 5.050 nonblocking-assignment trap, and where it
// does not reach. After labs/common/solutions/verilator_nba_repro.sv on the
// router branch, which found it.
//
// Each xfer raises a signal, waits for a clock edge and lowers it, three
// times back to back. Each "<= 1" runs after the previous "<= 0", in the same
// time step, so by the standard the signal stays high: 3 of 3 edges.
//
//   a  module task, called in a loop from an initial block    5.050: 1 of 3
//   b  the same module task, three calls written out           5.050: 3 of 3
//   c  class loop driving vif.c <= through a virtual interface 5.050: 3 of 3
//   g  interface task that loops over its beats, called from a class: 3 of 3
//
// Icarus 14.0 gives 3 of 3 for a and b. In a, the two assignments are the
// same two statements, and Verilator commits them in source order (<= 1
// before <= 0) instead of the order they ran. Class code, which is where a
// UVM driver lives, kept every assignment in every shape tried (selftest.py
// also runs two UVM drivers that drive with <=). selftest.py builds this file
// and fails if any number changes, because then the course text is wrong.
interface nba_bfm_if (input logic clk);
  logic c = 1'b0, g = 1'b0;
  task automatic send_g(int n); repeat (n) begin g <= 1'b1; @(posedge clk); g <= 1'b0; end endtask
endinterface

class nba_drv;
  virtual nba_bfm_if vif;
  task loop_c(); repeat (3) begin vif.c <= 1'b1; @(posedge vif.clk); vif.c <= 1'b0; end endtask
  task beats_g(); vif.send_g(3); endtask
endclass

module nba_repro;
  logic clk = 1'b0, a = 1'b0, b = 1'b0;
  int seen_a = 0, seen_b = 0, seen_c = 0, seen_g = 0;
  always #5 clk = ~clk;
  nba_bfm_if p (clk);
  always @(posedge clk) begin
    seen_a += int'(a); seen_b += int'(b); seen_c += int'(p.c); seen_g += int'(p.g);
  end
  task automatic xfer_a(); a <= 1'b1; @(posedge clk); a <= 1'b0; endtask
  task automatic xfer_b(); b <= 1'b1; @(posedge clk); b <= 1'b0; endtask
  initial begin
    static nba_drv d = new;
    d.vif = p;
    @(posedge clk); repeat (3) xfer_a();
    @(posedge clk); xfer_b(); xfer_b(); xfer_b();
    @(posedge clk); d.loop_c();
    @(posedge clk); d.beats_g();
    repeat (2) @(posedge clk);
    $display("a %0d of 3, b %0d of 3, c %0d of 3, g %0d of 3", seen_a, seen_b, seen_c, seen_g);
    $finish;
  end
endmodule
