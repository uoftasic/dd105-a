// The scoreboard: runs the model on what the monitors saw and reports every
// place the router disagrees with it.
//
// It is cycle-exact, because the specification is. Every monitor stamps what
// it reports with the cycle number, and the sys monitor sends one sample per
// cycle, which is the scoreboard's clock: when the sample for cycle t
// arrives, everything from cycle t-1 is already in the mailboxes (it was put
// there at the edge that ended cycle t-1), so the scoreboard runs the model
// through cycle t-1.
//
// What it checks, every cycle: irq; in_ready, in every cycle a beat was
// offered; every output beat's data and out_last, and the cycle it appeared
// (rule O8); pslverr, and the value of every register read as it was in the
// read's first access cycle, STATUS, DROP_CNT and LEVEL included. At the end
// it reports any beat routed to an output that never came out.
//
// For every packet it also hands a router_pkt_info to the coverage.

// Register values in one cycle, for reads whose first access cycle it was.
class reg_snap;
  bit [31:0] v[12];          // indexed by address / 4, 0x00 to 0x2C
endclass

class router_scoreboard;
  // Filled by the monitors.
  mailbox #(beat)       in_mb   = new();
  mailbox #(beat)       out_mb[2];
  mailbox #(apb_xfer)   apb_mb  = new();
  mailbox #(sys_sample) sys_mb  = new();

  router_model    m = new();
  router_coverage cov;        // the env sets it

  // What has arrived and not been processed yet, by cycle.
  beat       in_at[int unsigned];
  beat       out_at[2][int unsigned];
  apb_xfer   apb_at[int unsigned];
  sys_sample sys_at[int unsigned];
  reg_snap   snaps[int unsigned];

  int unsigned next_cycle = 1;     // the next cycle to process
  int unsigned last_seen  = 0;     // the latest cycle a sample arrived for
  longint      last_rdy1  = -1;    // the latest processed cycle with in_ready predicted 1
  bit          in_reset   = 1;
  bit          irq_bad    = 0;     // irq was wrong in the previous cycle

  // Totals for the report.
  int unsigned n_in_beats, n_pkts, n_fwd, n_noroute, n_full, n_oversize;
  int unsigned n_out_beats, n_reads, n_writes, n_bad, n_resets, n_cycles, n_irq_bad;

  function new();
    out_mb[0] = new();
    out_mb[1] = new();
  endfunction

  // ── collecting ─────────────────────────────────────────────────────────────
  function void collect();
    beat     b;
    apb_xfer a;
    while (in_mb.try_get(b)) in_at[b.cycle] = b;
    for (int p = 0; p < 2; p++)
      while (out_mb[p].try_get(b)) out_at[p][b.cycle] = b;
    while (apb_mb.try_get(a)) apb_at[a.end_cycle] = a;
  endfunction

  task run();
    sys_sample s;
    forever begin
      sys_mb.get(s);
      collect();
      sys_at[s.cycle] = s;
      if (s.cycle > last_seen) last_seen = s.cycle;
      while (next_cycle < s.cycle) begin
        process(next_cycle);
        next_cycle++;
      end
    end
  endtask

  // No beat is expected anywhere and none is waiting to be processed.
  function bit idle();
    return m.idle() && in_at.num() == 0 && out_at[0].num() == 0 && out_at[1].num() == 0 &&
           in_mb.num() == 0 && out_mb[0].num() == 0 && out_mb[1].num() == 0;
  endfunction

  // ── one cycle ──────────────────────────────────────────────────────────────
  function void process(int unsigned t);
    sys_sample      s;
    beat            ib, ob[2];
    apb_xfer        a;
    router_pkt_info done;
    bit             rdy, exp_irq;

    if (!sys_at.exists(t)) return;
    s = sys_at[t];
    sys_at.delete(t);
    if (in_at.exists(t))     begin ib    = in_at[t];     in_at.delete(t);     end
    if (out_at[0].exists(t)) begin ob[0] = out_at[0][t]; out_at[0].delete(t); end
    if (out_at[1].exists(t)) begin ob[1] = out_at[1][t]; out_at[1].delete(t); end
    if (apb_at.exists(t))    begin a     = apb_at[t];    apb_at.delete(t);    end
    if (t > 64 && snaps.exists(t - 64)) snaps.delete(t - 64);
    n_cycles++;

    // A reset cycle: everything is gone, and nothing moves.
    if (!s.rst_n) begin
      if (!in_reset) n_resets++;
      in_reset = 1;
      m.reset();
      if (s.irq) `uvm_error("SB", $sformatf("irq is 1 in cycle %0d, a reset cycle", t))
      if (ib != null || ob[0] != null || ob[1] != null || a != null)
        `uvm_error("SB", $sformatf("a monitor saw a transfer in cycle %0d, a reset cycle", t))
      irq_bad = 0;
      return;
    end
    in_reset = 0;

    // The register values in this cycle, for a read whose first access it is.
    begin
      reg_snap r = new();
      for (int i = 0; i < 12; i++) r.v[i] = m.reg_value(8'(4 * i));
      snaps[t] = r;
    end

    // irq. A wrong irq is reported in the first cycle it's wrong, not in
    // every cycle after; n_irq_bad counts the cycles.
    exp_irq = m.irq();
    if (s.irq != exp_irq) begin
      if (!irq_bad)
        `uvm_error("SB", $sformatf("irq is %0d from cycle %0d, but STATUS = %03b and INT_EN = %03b make it %0d",
                   s.irq, t, m.status, m.int_en, exp_irq))
      irq_bad = 1;
      n_irq_bad++;
    end else begin
      irq_bad = 0;
    end

    // The input: in_ready, then the beat.
    rdy = m.in_ready();
    if (ib != null) begin
      n_in_beats++;
      if (!rdy) begin
        `uvm_error("SB", $sformatf("the router accepted %02h in cycle %0d, but in_ready should be 0 then: it is between packets and CTRL.EN is 0 (rule I5)",
                   ib.data, t))
      end else if (ib.first_cycle < t && last_rdy1 >= longint'(ib.first_cycle)) begin
        `uvm_error("SB", $sformatf("beat %02h was offered from cycle %0d and taken in cycle %0d, but in_ready should have been 1 in cycle %0d (%s)",
                   ib.data, ib.first_cycle, t, last_rdy1,
                   m.in_pkt ? string'("inside a packet, rule I6") : string'("between packets with CTRL.EN = 1, rule I5")))
      end
      done = m.accept(ib.data, ib.last, t);
    end
    if (rdy) last_rdy1 = t;

    // APB.
    if (a != null) check_apb(a, t);

    // The outputs.
    for (int p = 0; p < 2; p++)
      if (ob[p] != null) check_out(p, ob[p], t);

    m.end_cycle();

    if (done != null) begin
      n_pkts++;
      case (done.fate)
        FATE_NOROUTE: n_noroute++;
        FATE_FULL:    n_full++;
        default:      n_fwd++;
      endcase
      if (done.oversize) n_oversize++;
      if (cov != null) cov.sample_pkt(done);
    end
  endfunction

  function void check_apb(apb_xfer a, int unsigned t);
    bit bad = !router_model::good_addr(a.addr);
    string what = $sformatf("%s of %s (%02h), completing in cycle %0d",
                            a.write ? string'("a write") : string'("a read"),
                            router_model::reg_name(a.addr), a.addr, t);
    if (bad) n_bad++;
    if (a.slverr != bad)
      `uvm_error("SB", $sformatf("%s: pslverr is %0d, but %02h is %s address", what, a.slverr, a.addr,
                 bad ? string'("a bad") : string'("a good")))
    if (!a.write) begin
      bit [31:0] exp = 32'h0;
      n_reads++;
      if (!bad) begin
        if (!snaps.exists(a.access_cycle)) begin
          `uvm_info("SB", $sformatf("%s: no record of cycle %0d, so it isn't checked", what,
                    a.access_cycle), UVM_LOW)
          return;
        end
        exp = snaps[a.access_cycle].v[a.addr >> 2];
      end
      if (a.rdata != exp)
        `uvm_error("SB", $sformatf("%s returned %08h; it should return %08h, %s", what, a.rdata, exp,
                   bad ? string'("as every bad read does") :
                   $sformatf("the value in cycle %0d (its first access cycle)", a.access_cycle)))
      return;
    end
    n_writes++;
    if (!bad) m.reg_write(a.addr, a.wdata);
  endfunction

  function void check_out(int p, beat ob, int unsigned t);
    longint  h_prev = m.outs[p].h_prev;
    exp_beat e = m.take(p);
    m.outs[p].h_prev = t;
    n_out_beats++;
    if (e == null) begin
      `uvm_error("SB", $sformatf("output %0d delivered %s, but no beat was waiting for it there",
                 p, ob.convert2string()))
      return;
    end
    if (ob.data != e.data || ob.last != e.last) begin
      `uvm_error("SB", $sformatf("output %0d delivered %02h with out_last = %0d in cycle %0d; it should be %02h with out_last = %0d (accepted in cycle %0d)",
                 p, ob.data, ob.last, t, e.data, e.last, e.t_in))
      return;
    end
    begin
      longint a_k = longint'(e.t_in) + 2;
      if (h_prev + 1 > a_k) a_k = h_prev + 1;
      if (longint'(ob.first_cycle) != a_k)
        `uvm_error("SB", $sformatf("output %0d: beat %02h appeared in cycle %0d, but rule O8 puts it in cycle %0d (accepted in cycle %0d; the beat before it was taken in cycle %0d)",
                   p, ob.data, ob.first_cycle, a_k, e.t_in, h_prev))
    end
  endfunction

  // ── the end of the test ────────────────────────────────────────────────────
  function void final_check();
    // The last cycles: their samples are all in.
    collect();
    while (next_cycle <= last_seen) begin
      process(next_cycle);
      next_cycle++;
    end
    foreach (m.outs[p])
      if (m.outs[p].q.size() > 0)
        `uvm_error("SB", $sformatf("%0d beats routed to output %0d never came out; the first is %02h, accepted in cycle %0d",
                   m.outs[p].q.size(), p, m.outs[p].q[0].data, m.outs[p].q[0].t_in))
    if (n_in_beats == 0 && n_reads == 0)
      `uvm_error("SB", "the router accepted no beats and no register was read, so nothing was checked")
  endfunction

  function void report();
    `uvm_info("SB", $sformatf("%0d cycles; %0d input beats in %0d packets: %0d forwarded, %0d NOROUTE, %0d FULL, %0d oversize; %0d output beats",
              n_cycles, n_in_beats, n_pkts, n_fwd, n_noroute, n_full, n_oversize, n_out_beats), UVM_LOW)
    `uvm_info("SB", $sformatf("%0d register reads checked, %0d writes; irq wrong in %0d cycles",
              n_reads, n_writes, n_irq_bad), UVM_LOW)
  endfunction
endclass
