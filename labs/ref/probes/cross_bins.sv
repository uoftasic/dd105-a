// The same array of bins on two coverpoints of one value, one of them crossed.
package ppkg;
  class c;
    covergroup cg with function sample(int v, int w);
      cp_crossed: coverpoint v { bins a[] = {[0:3]}; }
      cp_w:       coverpoint w { bins lo = {0}; bins hi = {1}; }
      x:          cross cp_crossed, cp_w;
      cp_alone:   coverpoint v { bins b[] = {[0:3]}; }
    endgroup
    function new(); cg = new(); endfunction
  endclass
endpackage

module top;
  import ppkg::*;
  initial begin
    c o = new();
    for (int i = 0; i < 8; i++) o.cg.sample(i % 4, i / 4);
    $finish;
  end
endmodule
