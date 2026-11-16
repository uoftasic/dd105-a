// DD105-A Lab 02: the monitor. You write run() (Part 2 of the lab).
//
// Watches one valid/ready stream and turns what moves on it into packets.
// The environment makes two: `in` on the router's input and `out0` on its
// output 0. Both are this class; only the interface they are given differs.
//
// A beat moves in a cycle where valid and ready are both 1 (a handshake), at
// the rising edge that ends that cycle. A packet is the beats from one
// handshake after the last packet's end up to and including the handshake
// whose beat has last = 1. Each finished packet goes into the mailbox to_sb.
//
// The interface is a stream_mon_if, whose signals are all inputs: a monitor
// watches and never drives. Its type is written out in full, `virtual
// stream_mon_if`, never through a typedef (see driver.svh).

class monitor;
  string                name;      // "in" or "out0", for messages
  virtual stream_mon_if vif;
  mailbox #(packet)     to_sb;
  int unsigned          show;      // print the first `show` packets
  int unsigned          n_pkts, n_beats;

  function new(string name, virtual stream_mon_if vif, mailbox #(packet) to_sb,
               int unsigned show = 0);
    this.name  = name;
    this.vif   = vif;
    this.to_sb = to_sb;
    this.show  = show;
  endfunction

  // Watch the stream forever, one rising edge at a time. vif.cb.valid and
  // the other clocking-block inputs are the values in the cycle that the
  // edge just ended.
  task run();
    packet p;   // the packet being assembled, or null between packets
    // TODO (Part 2): forever, wait for the next edge with @(vif.cb), then
    //  - while vif.cb.rst_n is 0, drop any half-assembled packet (p = null);
    //  - in a handshake cycle (vif.cb.valid and vif.cb.ready both 1):
    //      start a new packet if p is null, and set p.t_first = $time;
    //      push vif.cb.data onto p.data and count the beat in n_beats;
    //      if vif.cb.last is 1, the packet is finished: set p.t_last = $time,
    //      print it if n_pkts < show, as
    //        $display("[%s] %0d ns: %s", name, p.t_last, p.sprint());
    //      put it in to_sb, count it in n_pkts, and set p = null.
  endtask
endclass
