// DD105-A guide example, "Reactive agents and backpressure": the design.
//
// A stream source. It numbers its beats 0, 1, 2, ... and decides on its own
// when each one appears: after a handshake its output is idle for 1 to 4
// cycles, picked by an LFSR, and then the next beat appears and stays on the
// output, with valid at 1, until the sink takes it.

module beat_src (
  input  logic       clk,
  input  logic       rst_n,
  output logic       valid,
  input  logic       ready,
  output logic [7:0] data
);
  logic [7:0] lfsr;
  logic [1:0] gap;     // idle cycles still to go before the next beat

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      valid <= 1'b0;
      data  <= 8'h00;
      lfsr  <= 8'h5A;
      gap   <= 2'd0;
    end else begin
      lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
      if (valid && ready) begin
        valid <= 1'b0;
        data  <= data + 8'd1;
        gap   <= lfsr[1:0];
      end else if (!valid) begin
        if (gap == 2'd0) valid <= 1'b1;
        else             gap   <= gap - 2'd1;
      end
    end
endmodule
