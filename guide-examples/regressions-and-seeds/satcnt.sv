// DD105-A guide example, "Regressions and seeds": the design.
//
// A 4-bit counter. clr sets it to 0; otherwise inc adds one, and at 15 the
// counter stays at 15. With +BUG=wrap it wraps from 15 to 0 instead, which
// only a test that gets the counter to 15 and then increments it can see.

module satcnt (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       inc,
  input  logic       clr,
  output logic [3:0] count
);
  bit bug_wrap;
  initial bug_wrap = $test$plusargs("BUG=wrap");

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)                                count <= 4'd0;
    else if (clr)                              count <= 4'd0;
    else if (inc && (count != 4'd15 || bug_wrap)) count <= count + 4'd1;
endmodule
