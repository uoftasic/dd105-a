// DD105-A guide example, "Register models": the design.
//
// Four 16-bit registers on a bus with one-cycle transfers. A transfer is a
// cycle with sel = 1. The block answers in the same cycle (rdata and err),
// and a write takes effect at the rising edge that ends it.
//
//   0x0  ID     RO    16'h105A
//   0x4  CTRL   RW    [0] EN, [3:1] MODE; resets to 0
//   0x8  FLAGS  W1C   [0] OVF, [1] ERR; set by the ev_ovf and ev_err inputs
//   0xC  COUNT  RO    [7:0] events (ev_ovf or ev_err) since reset
//
// Any other address completes with err = 1: a read returns 0 and a write
// changes nothing. Bits that hold no field read 0.
//
// Two planted bugs, chosen at run time with +BUG=<name>:
//   mode_stuck   CTRL bit 3 (MODE[2]) can't be written, and stays 0
//   en_reset_1   CTRL.EN resets to 1

module regblk (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        sel,
  input  logic        we,
  input  logic [3:0]  addr,
  input  logic [15:0] wdata,
  output logic [15:0] rdata,
  output logic        err,
  input  logic        ev_ovf,
  input  logic        ev_err
);
  bit    bug_mode_stuck, bug_en_reset_1;
  string bug;
  initial begin
    if (!$value$plusargs("BUG=%s", bug)) bug = "none";
    bug_mode_stuck = (bug == "mode_stuck");
    bug_en_reset_1 = (bug == "en_reset_1");
  end

  logic       en;
  logic [2:0] mode;
  logic [1:0] flags;
  logic [7:0] count;

  wire good = (addr == 4'h0) || (addr == 4'h4) || (addr == 4'h8) || (addr == 4'hC);

  always_comb begin
    rdata = 16'h0000;
    if (sel && good)
      case (addr)
        4'h0: rdata = 16'h105A;
        4'h4: rdata = {12'h000, mode, en};
        4'h8: rdata = {14'h0000, flags};
        4'hC: rdata = {8'h00, count};
        default: rdata = 16'h0000;
      endcase
  end
  assign err = sel && !good;

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      en    <= bug_en_reset_1;
      mode  <= 3'd0;
      flags <= 2'b00;
      count <= 8'd0;
    end else begin
      if (sel && we && addr == 4'h4) begin
        en   <= wdata[0];
        mode <= bug_mode_stuck ? {1'b0, wdata[2:1]} : wdata[3:1];
      end
      // An event sets its flag; a write of 1 clears it, unless an event sets it again.
      flags <= (flags & ~((sel && we && addr == 4'h8) ? wdata[1:0] : 2'b00)) | {ev_err, ev_ovf};
      if (ev_ovf || ev_err) count <= count + 8'd1;
    end
endmodule
