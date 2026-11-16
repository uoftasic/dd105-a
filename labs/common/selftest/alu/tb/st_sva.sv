// SELFTEST -- the zero flag is checked ONLY here, by an assertion bound into
// the design, so bug B02 can be caught by nothing but a failing assertion.
// That proves verdict.py counts "Assertion failed in ..." as a check.
module st_alu_sva (
  input logic       clk, rst_n, out_valid, zero,
  input logic [7:0] result
);
  a_zero_flag: assert property (@(posedge clk) disable iff (!rst_n)
                                out_valid |-> zero == (result == 8'd0))
    else $error("zero flag is %0b for result %02h", zero, result);
endmodule

bind st_alu st_alu_sva u_sva (.clk(clk), .rst_n(rst_n), .out_valid(out_valid),
                              .zero(zero), .result(result));
