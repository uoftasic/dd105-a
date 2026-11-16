// DD105-A guide example: From cocotb to SystemVerilog classes
// (docs/guide/from-cocotb-to-systemverilog-classes.md).
//
// DD104 Lab 03's t01 (Lab 01's cocotb/test_alu.py) written again in
// SystemVerilog, as one class with no UVM in it: spec() becomes predict(),
// the alu() coroutine becomes a task, and each assert becomes an $error.

package alu_t01_pkg;

  typedef enum bit [2:0] {ADD, SUB, OR, NAND, SHL, SHR} alu_op_e;

  // What cocotb's spec() returns as a tuple (out, N, Z).
  typedef struct packed {
    bit [7:0] out;
    bit       n;
    bit       z;
  } alu_result_t;

  class alu_t01;
    virtual alu_pins_if vif;

    function new(virtual alu_pins_if vif);
      this.vif = vif;
    endfunction

    // spec(), from SimProc's instruction set. out is 8 bits wide, so every
    // result wraps at 256 by itself: no `& 0xFF`.
    function alu_result_t predict(alu_op_e op, bit [7:0] a, bit [7:0] b);
      alu_result_t r;
      case (op)
        ADD:     r.out = a + b;
        SUB:     r.out = a - b;
        OR:      r.out = a | b;
        NAND:    r.out = ~(a & b);
        SHL:     r.out = a << b[1:0];
        SHR:     r.out = a >> b[1:0];
        default: r.out = 8'h00;
      endcase
      r.n = r.out[7];
      r.z = (r.out == 8'h00);
      return r;
    endfunction

    // alu(): drive one vector, wait 1 ns, read the three outputs back.
    task drive_and_read(alu_op_e op, bit [7:0] a, bit [7:0] b, output alu_result_t got);
      vif.ALUop = op;
      vif.A     = a;
      vif.B     = b;
      #1;
      got = '{vif.ALUout, vif.N, vif.Z};
    endtask

    task t01_one_vector_per_operation();
      alu_op_e     ops[6] = '{ADD, SUB, OR, NAND, SHL, SHR};
      bit [7:0]    as[6]  = '{200, 200, 8'hF0, 8'hC3, 8'h21, 8'hF8};
      bit [7:0]    bs[6]  = '{60, 60, 8'h0F, 8'h1D, 2, 3};
      alu_result_t got, want;
      foreach (ops[i]) begin
        drive_and_read(ops[i], as[i], bs[i], got);
        want = predict(ops[i], as[i], bs[i]);
        if (got != want)
          $error("%s(0x%02X, 0x%02X) gave out=0x%02X N=%0d Z=%0d, expected out=0x%02X N=%0d Z=%0d",
                 ops[i].name(), as[i], bs[i], got.out, got.n, got.z, want.out, want.n, want.z);
      end
      $display("t01: %0d directed vectors checked", $size(ops));
    endtask
  endclass

  // Widths: the same sum, 200 + 60, in three places.
  function automatic void widths();
    bit [7:0] a = 200, b = 60;
    bit [7:0] sum8;
    bit [8:0] sum9;
    sum8 = a + b;
    sum9 = a + b;
    $display("sum8 = a + b      -> %0d", sum8);
    $display("sum9 = a + b      -> %0d", sum9);
    $display("$display(a + b)   -> %0d", a + b);
  endfunction

  // A string literal is a number until something makes it a string.
  function automatic void literals();
    int unsigned n = 1;
    $display("[%0d beat%s]", n, n == 1 ? "" : "s");
    $display("[%0d beat%s]", n, n == 1 ? string'("") : string'("s"));
  endfunction

endpackage
