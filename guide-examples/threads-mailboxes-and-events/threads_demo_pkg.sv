// DD105-A guide example: Threads, mailboxes and events
// (docs/guide/threads-mailboxes-and-events.md).
//
// Plain SystemVerilog classes, no UVM. Each class is one demonstration, and
// threads_tests_pkg.sv runs each one from a UVM test so that `make run`
// works as it does in the labs. Times are printed with $time, in ns.

package threads_demo_pkg;

  // fork...join, fork...join_any and fork...join_none, with the same three
  // threads each time: they finish 10, 20 and 30 ns after they start.
  class fork_demo;
    task run();
      $display("%0d ns: fork...join", $time);
      fork
        #10 $display("%0d ns:   A finished", $time);
        #20 $display("%0d ns:   B finished", $time);
        #30 $display("%0d ns:   C finished", $time);
      join
      $display("%0d ns: the parent goes on after join", $time);

      $display("%0d ns: fork...join_any", $time);
      fork
        #10 $display("%0d ns:   A finished", $time);
        #20 $display("%0d ns:   B finished", $time);
        #30 $display("%0d ns:   C finished", $time);
      join_any
      $display("%0d ns: the parent goes on after join_any", $time);
      wait fork;
      $display("%0d ns: wait fork returns", $time);

      $display("%0d ns: fork...join_none", $time);
      fork
        #10 $display("%0d ns:   A finished", $time);
        #20 $display("%0d ns:   B finished", $time);
        #30 $display("%0d ns:   C finished", $time);
      join_none
      $display("%0d ns: the parent goes on after join_none", $time);
      wait fork;
      $display("%0d ns: wait fork returns", $time);
    endtask
  endclass

  // A generator and a driver joined by a mailbox. The generator makes four
  // items as fast as it can; the driver takes 10 ns over each one. bound = 0
  // makes an unbounded mailbox, and bound = 1 one that holds a single item.
  class mailbox_demo;
    mailbox #(int) mb;

    function new(int bound);
      mb = new(bound);
    endfunction

    task gen();
      for (int k = 0; k < 4; k++) begin
        mb.put(k);
        $display("%0d ns: gen put %0d", $time, k);
      end
      $display("%0d ns: gen has made all four", $time);
    endtask

    task drv();
      int x;
      repeat (4) begin
        mb.get(x);
        $display("%0d ns:   drv got %0d", $time, x);
        #10;
      end
    endtask

    task run();
      fork
        gen();
        drv();
      join
    endtask
  endclass

  // Threads forked in a loop, each printing the loop variable 1 ns later.
  class capture_demo;
    task run();
      $display("%0d ns: three threads print the loop variable i", $time);
      for (int i = 0; i < 3; i++)
        fork
          #1 $display("%0d ns:   i = %0d", $time, i);
        join_none
      #5;
      $display("%0d ns: three threads print j, a copy made in each pass", $time);
      for (int i = 0; i < 3; i++) begin
        int j = i;
        fork
          #1 $display("%0d ns:   j = %0d", $time, j);
        join_none
      end
      #5;
    endtask
  endclass

  // @ against .triggered, for a wait that starts in the same time step as
  // the trigger but after it.
  class event_demo;
    event done;

    task run();
      fork
        begin
          #10 ->done;
          $display("%0d ns: ->done", $time);
          fork
            begin @done;                 $display("%0d ns:   @done returns", $time); end
            begin wait (done.triggered); $display("%0d ns:   wait (done.triggered) returns", $time); end
          join_none
        end
      join
      #20;
      $display("%0d ns: end of the demo", $time);
    endtask
  endclass

  // A monitor started with join_none, then a wait with a timeout: fork two
  // threads, take whichever finishes first, and kill the other. Once with a
  // bare `disable fork`, and once with the wait in a fork of its own.
  class disable_demo;
    int unsigned ticks;

    task monitor();
      forever #10 ticks++;
    endtask

    task wait_with_timeout();
      fork
        #25  $display("%0d ns:   the thing we waited for happened", $time);
        #100 $display("%0d ns:   timeout", $time);
      join_any
      disable fork;
    endtask

    task run(bit isolate);
      ticks = 0;
      fork
        monitor();
      join_none
      if (isolate) begin
        fork
          wait_with_timeout();
        join
      end else begin
        wait_with_timeout();
      end
      #50;
      $display("%0d ns: %s: the monitor has counted %0d ticks",
               $time, isolate ? string'("with the wait in its own fork") : string'("with a bare disable fork"),
               ticks);
      disable fork;
    endtask
  endclass

endpackage
