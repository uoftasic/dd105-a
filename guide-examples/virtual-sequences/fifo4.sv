// DD105-A guide example, "Virtual sequences": the design.
//
// A four-beat FIFO with a valid/ready stream on each side. in_ready is 1
// while it holds fewer than four beats, and out_valid while it holds any.

module fifo4 (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       in_valid,
  output logic       in_ready,
  input  logic [7:0] in_data,
  output logic       out_valid,
  input  logic       out_ready,
  output logic [7:0] out_data,
  output logic [2:0] level
);
  logic [7:0] mem [4];
  logic [1:0] wr, rd;

  assign in_ready  = (level != 3'd4);
  assign out_valid = (level != 3'd0);
  assign out_data  = mem[rd];

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      wr    <= 2'd0;
      rd    <= 2'd0;
      level <= 3'd0;
    end else begin
      if (in_valid && in_ready) begin
        mem[wr] <= in_data;
        wr      <= wr + 2'd1;
      end
      if (out_valid && out_ready) rd <= rd + 2'd1;
      level <= level + 3'(in_valid && in_ready) - 3'(out_valid && out_ready);
    end
endmodule
