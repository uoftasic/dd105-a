// What the monitors report, and the record the scoreboard keeps for each packet.

// A beat that moved on a stream: its data, the cycle of its handshake, and
// the first cycle it was offered (valid = 1). For an output beat, first_cycle
// is the cycle it appeared on the pins, which rule O8 predicts.
class beat;
  bit [7:0]    data;
  bit          last;
  int unsigned cycle;
  int unsigned first_cycle;
  function string convert2string();
    return $sformatf("%02h%s (offered from cycle %0d, taken in cycle %0d)", data,
                     last ? string'(" last") : string'(""), first_cycle, cycle);
  endfunction
endclass

// One completed APB transfer. A read returns the register's value in its
// first access cycle (rule A8), so the scoreboard needs access_cycle.
class apb_xfer;
  bit          write;
  bit [7:0]    addr;
  bit [31:0]   wdata;
  bit [31:0]   rdata;
  bit          slverr;
  int unsigned setup_cycle, access_cycle, end_cycle;
  function string convert2string();
    return $sformatf("%s %02h data %08h%s (cycles %0d-%0d)", write ? string'("WRITE") : string'("READ "),
                     addr, write ? wdata : rdata, slverr ? string'(" PSLVERR") : string'(""),
                     setup_cycle, end_cycle);
  endfunction
endclass

// rst_n and irq in one cycle. The sys monitor sends one of these every cycle,
// and the scoreboard uses them as its clock.
class sys_sample;
  int unsigned cycle;
  bit          rst_n;
  bit          irq;
endclass

// What happened to one input packet, as the model decided it in its header's
// cycle. The scoreboard hands one to the coverage when the packet's last beat
// is accepted.
typedef enum int {FATE_NOROUTE = 0, FATE_FULL = 1, FATE_OUT0 = 2, FATE_OUT1 = 3} fate_e;

class router_pkt_info;
  bit [1:0]    dst;
  fate_e       fate;
  int          level;        // the level of output ROUTE[DST].PORT in the header's cycle
  int unsigned len;          // beats accepted, header included
  bit          oversize;
  int unsigned hdr_cycle;
endclass
