// The router as the specification describes it, one cycle at a time.
//
// The scoreboard calls, for each cycle in order: accept() for the input beat
// that moved, reg_write() for a write that completed, take() for each output
// beat that moved, and then end_cycle(), which applies the edge at the end of
// the cycle. In between it reads in_ready(), irq() and reg_value() to check
// what the router did in that cycle.

class exp_beat;
  bit [7:0]    data;
  bit          last;
  int unsigned t_in;         // the cycle of its input handshake
endclass

// One output buffer, as the model sees it.
class out_state;
  exp_beat q[$];             // beats written and not yet taken, oldest first
  int      level;            // the level in the cycle being processed
  longint  h_prev;           // the cycle the previous beat was taken; -1 since reset
  function new();
    h_prev = -1;
  endfunction
endclass

class router_model;
  // Registers, as they are in the cycle being processed.
  bit       ctrl_en;
  bit [2:0] status;
  bit [2:0] int_en;
  bit [7:0] nr_cnt, full_cnt;
  bit       route_en[4];
  bit       route_port[4];
  out_state outs[2];

  // The input side.
  bit             in_pkt;      // a header is in and its in_last beat isn't
  int unsigned    beats;       // beats of the current packet accepted so far
  fate_e          fate;        // what happens to the current packet
  bit             cutting;     // past the 8th beat of an oversize packet
  router_pkt_info info;        // the current packet, for the coverage

  // What the cycle being processed does, applied by end_cycle().
  bit [2:0] ev_status;
  bit       ev_nr, ev_full;
  int       wr[2], tk[2];

  function new();
    outs[0] = new();
    outs[1] = new();
    reset();
  endfunction

  // The register map's reset values, empty buffers, and no packet.
  function void reset();
    ctrl_en  = 0;
    status   = 0;
    int_en   = 0;
    nr_cnt   = 0;
    full_cnt = 0;
    foreach (route_en[n]) begin
      route_en[n]   = 0;
      route_port[n] = 0;
    end
    foreach (outs[p]) begin
      outs[p].q.delete();
      outs[p].level  = 0;
      outs[p].h_prev = -1;
    end
    in_pkt  = 0;
    beats   = 0;
    cutting = 0;
    info    = null;
    begin_cycle();
  endfunction

  static function bit good_addr(bit [7:0] a);
    return a inside {8'h00, 8'h04, 8'h08, 8'h0C, 8'h10, 8'h14, 8'h20, 8'h24, 8'h28, 8'h2C};
  endfunction

  static function string reg_name(bit [7:0] a);
    case (a)
      8'h00: return "ID";
      8'h04: return "CTRL";
      8'h08: return "STATUS";
      8'h0C: return "INT_EN";
      8'h10: return "DROP_CNT";
      8'h14: return "LEVEL";
      8'h20: return "ROUTE0";
      8'h24: return "ROUTE1";
      8'h28: return "ROUTE2";
      8'h2C: return "ROUTE3";
      default: return "a bad address";
    endcase
  endfunction

  // What a read of address a returns in this cycle (0 for a bad address).
  function bit [31:0] reg_value(bit [7:0] a);
    case (a)
      8'h00: return 32'hD105_0001;
      8'h04: return {31'b0, ctrl_en};
      8'h08: return {29'b0, status};
      8'h0C: return {29'b0, int_en};
      8'h10: return {16'b0, full_cnt, nr_cnt};
      8'h14: return {19'b0, 5'(outs[1].level), 3'b0, 5'(outs[0].level)};
      8'h20: return {30'b0, route_port[0], route_en[0]};
      8'h24: return {30'b0, route_port[1], route_en[1]};
      8'h28: return {30'b0, route_port[2], route_en[2]};
      8'h2C: return {30'b0, route_port[3], route_en[3]};
      default: return 32'h0;
    endcase
  endfunction

  // in_ready in this cycle: 1 inside a packet, CTRL.EN between packets.
  function bit in_ready();
    return in_pkt || ctrl_en;
  endfunction

  // irq in this cycle: a plain combination of STATUS and INT_EN.
  function bit irq();
    return |(status & int_en);
  endfunction

  function void begin_cycle();
    ev_status = 0;
    ev_nr     = 0;
    ev_full   = 0;
    wr[0] = 0; wr[1] = 0;
    tk[0] = 0; tk[1] = 0;
  endfunction

  function void push(int p, bit [7:0] data, bit last, int unsigned t);
    exp_beat b = new();
    b.data = data;
    b.last = last;
    b.t_in = t;
    outs[p].q.push_back(b);
    wr[p]++;
  endfunction

  // A beat accepted in cycle t. Returns the packet's record when this beat
  // ends the packet (its in_last beat), and null otherwise.
  function router_pkt_info accept(bit [7:0] data, bit last, int unsigned t);
    router_pkt_info done = null;
    if (!in_pkt) begin
      // The header. The decision uses ROUTE[DST] and the output's level as
      // they are in this cycle; a write completing now changes neither yet.
      bit [1:0] d = data[7:6];
      int p = route_port[d];
      info = new();
      info.dst = d;
      info.hdr_cycle = t;
      info.level = outs[p].level;
      beats = 1;
      cutting = 0;
      if (!route_en[d]) begin
        fate = FATE_NOROUTE;
        ev_nr = 1;
        ev_status[0] = 1;
      end else if (outs[p].level > 8) begin
        fate = FATE_FULL;
        ev_full = 1;
        ev_status[1] = 1;
      end else begin
        fate = p ? FATE_OUT1 : FATE_OUT0;
        push(p, data, last, t);
      end
      info.fate = fate;
      in_pkt = !last;
    end else begin
      beats++;
      if (cutting) begin
        // An oversize packet's tail: taken and thrown away.
      end else if (beats == 8 && !last) begin
        // The 8th beat isn't the last: the packet is oversize. A forwarded
        // one ends here, with out_last on this beat.
        ev_status[2] = 1;
        cutting = 1;
        info.oversize = 1;
        if (fate == FATE_OUT0 || fate == FATE_OUT1) push(fate == FATE_OUT1, data, 1'b1, t);
      end else if (fate == FATE_OUT0 || fate == FATE_OUT1) begin
        push(fate == FATE_OUT1, data, last, t);
      end
      if (last) in_pkt = 0;
    end
    if (!in_pkt) begin
      info.len = beats;
      done = info;
      info = null;
    end
    return done;
  endfunction

  // A write to a good address, completing in this cycle. It takes effect at
  // the edge that ends the cycle. STATUS's write-1-to-clear is applied here
  // and this cycle's events are OR'ed in afterwards, so an event wins; the
  // DROP_CNT clear is applied here and this cycle's drop is counted after it.
  function void reg_write(bit [7:0] a, bit [31:0] d);
    case (a)
      8'h04: ctrl_en = d[0];
      8'h08: status  = status & ~d[2:0];
      8'h0C: int_en  = d[2:0];
      8'h10: begin nr_cnt = 0; full_cnt = 0; end
      8'h20: begin route_en[0] = d[0]; route_port[0] = d[1]; end
      8'h24: begin route_en[1] = d[0]; route_port[1] = d[1]; end
      8'h28: begin route_en[2] = d[0]; route_port[2] = d[1]; end
      8'h2C: begin route_en[3] = d[0]; route_port[3] = d[1]; end
      default: ;   // ID and LEVEL ignore writes
    endcase
  endfunction

  // The beat at the front of output p, taken in this cycle (null if none).
  function exp_beat take(int p);
    tk[p]++;
    if (outs[p].q.size() == 0) return null;
    return outs[p].q.pop_front();
  endfunction

  // The edge that ends the cycle.
  function void end_cycle();
    status |= ev_status;
    if (ev_nr   && nr_cnt   != 8'd255) nr_cnt++;
    if (ev_full && full_cnt != 8'd255) full_cnt++;
    foreach (outs[p]) begin
      outs[p].level += wr[p] - tk[p];
      if (outs[p].level < 0) outs[p].level = 0;
    end
    begin_cycle();
  endfunction

  function bit idle();
    return outs[0].q.size() == 0 && outs[1].q.size() == 0 && !in_pkt;
  endfunction
endclass
