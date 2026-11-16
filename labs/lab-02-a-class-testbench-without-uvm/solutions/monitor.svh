// DD105-A Lab 02: the monitor (reference solution).
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
    forever begin
      @(vif.cb);
      if (!vif.cb.rst_n) begin
        // A reset ends whatever was in progress; a half-assembled packet
        // never finishes, so drop it.
        p = null;
        continue;
      end
      if (vif.cb.valid && vif.cb.ready) begin
        if (p == null) begin
          p = new();
          p.t_first = $time;
        end
        p.data.push_back(vif.cb.data);
        n_beats++;
        if (vif.cb.last) begin
          p.t_last = $time;
          if (n_pkts < show)
            $display("[%s] %0d ns: %s", name, p.t_last, p.sprint());
          to_sb.put(p);
          n_pkts++;
          p = null;
        end
      end
    end
  endtask
endclass
