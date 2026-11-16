// DD105-A guide example: Classes for testbenches
// (docs/guide/classes-for-testbenches.md).
//
// Plain SystemVerilog classes, no UVM. classes_tests_pkg.sv runs each
// demonstration from a UVM test so that `make run` works as in the labs.

package classes_demo_pkg;

  // One packet: its beats, header first, and a serial number. A smaller
  // version of the shape Lab 02's packet class has.
  class pkt;
    static int unsigned n_made;   // one variable, shared by every pkt
    int unsigned        id;       // one per object
    bit [7:0]           data[$];

    function new();
      id = n_made;
      n_made++;
    endfunction

    function string sprint();
      string s;
      s = $sformatf("pkt %0d:", id);
      foreach (data[i]) s = {s, $sformatf(" %02h", data[i])};
      return s;
    endfunction
  endclass

  // Handles: a declared handle, a second handle to the same object, and a
  // copy made with `new a`.
  function automatic void handles();
    pkt a, b, c;
    $display("a is %s", a == null ? string'("null") : string'("an object"));
    a = new();
    a.data = '{8'h80, 8'h11};
    b = a;
    b.data.push_back(8'h22);
    c = new a;
    c.data.push_back(8'h33);
    $display("a: %s", a.sprint());
    $display("b: %s", b.sprint());
    $display("c: %s", c.sprint());
    $display("a == b is %0b, a == c is %0b, pkt::n_made is %0d", a == b, a == c, pkt::n_made);
  endfunction

  // Two monitors that each see the same three packets go by and keep them in
  // a queue, as a scoreboard keeps the packets it expects. The first makes
  // one pkt and reuses it; the second makes a new one for every packet.
  function automatic void reuse();
    pkt kept_once[$], kept_new[$];
    pkt p;

    p = new();
    for (int k = 0; k < 3; k++) begin
      p.data.delete();
      p.data.push_back(8'(k));
      p.data.push_back(8'hA0 + 8'(k));
      kept_once.push_back(p);
    end

    for (int k = 0; k < 3; k++) begin
      p = new();
      p.data.push_back(8'(k));
      p.data.push_back(8'hA0 + 8'(k));
      kept_new.push_back(p);
    end

    foreach (kept_once[i]) $display("one pkt, reused:   [%0d] %s", i, kept_once[i].sprint());
    foreach (kept_new[i])  $display("a new pkt each:    [%0d] %s", i, kept_new[i].sprint());
  endfunction

  // A base class whose run() calls two methods, one virtual and one not, and
  // a class that overrides both. Lab 01's alu_base_test has the same shape:
  // its run_phase calls stimulus(), a virtual task its subclasses override.
  class base_test;
    function string name();
      return "base_test";
    endfunction
    virtual task stimulus();
      $display("  stimulus() of base_test: no stimulus");
    endtask
    task run();
      $display("run() of %s", name());
      stimulus();
    endtask
  endclass

  class rand_test extends base_test;
    function string name();
      return "rand_test";
    endfunction
    virtual task stimulus();
      $display("  stimulus() of rand_test: 2000 random vectors");
    endtask
  endclass

  task automatic dispatch();
    base_test t;
    rand_test r;
    r = new();
    t = r;                  // a base_test handle to a rand_test object
    $display("through a base_test handle:");
    t.run();
    $display("through a rand_test handle:");
    r.run();
  endtask

  // A packet handle that was never given an object, used as if it had one.
  function automatic void null_handle();
    pkt p;
    $display("p is null; asking for p.data.size()");
    $display("p.data.size() is %0d", p.data.size());
    $display("this line comes after the null access");
  endfunction

  // A function can't wait. Build with +define+FUNCTION_WAITS (make lint
  // VFLAGS="--timescale 1ns/1ps +define+FUNCTION_WAITS") to see the error.
`ifdef FUNCTION_WAITS
  function automatic void wait_a_cycle();
    #10;
  endfunction
`endif

endpackage
