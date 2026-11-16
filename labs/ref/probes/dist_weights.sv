// Weights 20/50/20/10 on a selector that picks a packet length, 1,000 draws
// each. The same class four ways: the selector's values as an enum, as
// package localparams, as literals, and drawn with randcase instead of dist.
package dp;
  typedef enum bit [1:0] {E_ONE, E_MID, E_EIGHT, E_OVER} kind_e;
  localparam bit [1:0] K_ONE = 2'd0, K_MID = 2'd1, K_EIGHT = 2'd2, K_OVER = 2'd3;

  class enum_sel;
    rand kind_e       kind;
    rand int unsigned len;
    constraint c_kind { kind dist {E_ONE := 20, E_MID := 50, E_EIGHT := 20, E_OVER := 10}; }
    constraint c_len  { (kind == E_ONE) -> len == 1; (kind == E_MID) -> len inside {[2:7]};
                        (kind == E_EIGHT) -> len == 8; (kind == E_OVER) -> len inside {[9:14]}; }
  endclass

  class named_sel;
    rand bit [1:0]    kind;
    rand int unsigned len;
    constraint c_kind { kind dist {K_ONE := 20, K_MID := 50, K_EIGHT := 20, K_OVER := 10}; }
    constraint c_len  { (kind == K_ONE) -> len == 1; (kind == K_MID) -> len inside {[2:7]};
                        (kind == K_EIGHT) -> len == 8; (kind == K_OVER) -> len inside {[9:14]}; }
  endclass

  class literal_sel;
    rand bit [1:0]    kind;
    rand int unsigned len;
    constraint c_kind { kind dist {0 := 20, 1 := 50, 2 := 20, 3 := 10}; }
    constraint c_len  { (kind == 0) -> len == 1; (kind == 1) -> len inside {[2:7]};
                        (kind == 2) -> len == 8; (kind == 3) -> len inside {[9:14]}; }
  endclass

  class randcase_sel;
    bit [1:0]         kind;
    rand int unsigned len;
    constraint c_len  { (kind == K_ONE) -> len == 1; (kind == K_MID) -> len inside {[2:7]};
                        (kind == K_EIGHT) -> len == 8; (kind == K_OVER) -> len inside {[9:14]}; }
    function void pre_randomize();
      randcase 20: kind = K_ONE; 50: kind = K_MID; 20: kind = K_EIGHT; 10: kind = K_OVER; endcase
    endfunction
  endclass
endpackage

module top;
  import dp::*;
  initial begin
    int e[4], n[4], l[4], r[4], fails = 0;
    enum_sel es = new(); named_sel ns = new(); literal_sel ls = new(); randcase_sel rs = new();
    repeat (1000) begin
      if (!es.randomize()) fails++; e[es.kind]++;
      if (!ns.randomize()) fails++; n[ns.kind]++;
      if (!ls.randomize()) fails++; l[ls.kind]++;
      if (!rs.randomize()) fails++; r[rs.kind]++;
    end
    $display("enum values, dist:       %0d %0d %0d %0d", e[0], e[1], e[2], e[3]);
    $display("localparam values, dist: %0d %0d %0d %0d", n[0], n[1], n[2], n[3]);
    $display("literal values, dist:    %0d %0d %0d %0d", l[0], l[1], l[2], l[3]);
    $display("randcase:                %0d %0d %0d %0d", r[0], r[1], r[2], r[3]);
    $display("randomize() failures:    %0d", fails);
    $finish;
  end
endmodule
