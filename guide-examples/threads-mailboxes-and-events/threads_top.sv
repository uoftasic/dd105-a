// DD105-A guide example: the top module. No design, no clock: run_test()
// builds the test named by +UVM_TESTNAME, and the test runs one demonstration.
//
// With +STATIC_LOOP (and static_loop_test), the initial block below runs
// capture_demo's second loop outside a class. Variables in a module's initial
// block are static unless declared automatic.
module threads_top;
  import uvm_pkg::*;
  import threads_tests_pkg::*;

  initial run_test();

  initial if ($test$plusargs("STATIC_LOOP")) begin
    $display("%0d ns: in a module's initial block, int j = i", $time);
    for (int i = 0; i < 3; i++) begin
      int j = i;
      fork
        #1 $display("%0d ns:   j = %0d", $time, j);
      join_none
    end
    #5;
    $display("%0d ns: in a module's initial block, automatic int j = i", $time);
    for (int i = 0; i < 3; i++) begin
      automatic int j = i;
      fork
        #1 $display("%0d ns:   j = %0d", $time, j);
      join_none
    end
  end
endmodule
