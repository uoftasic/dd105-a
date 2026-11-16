// DD105-A Lab 03: the transaction, the test's knobs, and the random packet.
//
//   packet       one packet: its beats, header first (Lab 02's, unchanged)
//   router_cfg   the routing table and the knobs, read from plusargs
//   rand_packet  a packet whose DST and length the solver picks (Part 3)

// One packet. The generator fills in data and gap; a monitor fills in data,
// t_first and t_last from what it saw on the pins.
class packet;
  bit [7:0]    data[$];   // the beats; data[0] is the header, and DST is its bits 7:6
  int unsigned gap[$];    // stimulus only: idle cycles the driver leaves before each beat
  longint      t_first;   // monitors: the time (ns) of the first beat's handshake
  longint      t_last;    // monitors: the time (ns) of the last beat's handshake

  function bit [1:0] dst();
    return data[0][7:6];
  endfunction

  // Two packets are the same if they have the same beats. The gaps and the
  // times say how a packet travelled, not what it is, so they don't count.
  function bit same(packet other);
    if (data.size() != other.data.size()) return 0;
    foreach (data[i])
      if (data[i] != other.data[i]) return 0;
    return 1;
  endfunction

  // "dst 2, 3 beats: 85 3c f0"
  function string sprint();
    string s;
    s = $sformatf("dst %0d, %0d beat%s:", dst(), data.size(),
                  data.size() == 1 ? string'("") : string'("s"));
    foreach (data[i]) s = {s, $sformatf(" %02h", data[i])};
    return s;
  endfunction
endclass

// The knobs. Each has a plusarg, so `make run PLUSARGS="+N=16"` changes the
// test without rebuilding the simulator. Lab 02's +DSTS and +LEN are gone:
// rand_packet's constraints now choose the DST and the length.
//
// routes is also the routing table the router has: env.write_routes() changes
// both together, and the scoreboard and the tracker read it from here.
class router_cfg;
  int unsigned n_pkts = 100;     // +N=<n>       packets to send (per phase in router_rand_test)
  string       routes = "0110";  // +ROUTES=<abcd> ROUTE0 to ROUTE3: 0 or 1 is the output, - is disabled
  int unsigned show   = 0;       // +SHOW=<n>    each monitor prints the first n packets it sees

  function void from_plusargs();
    void'($value$plusargs("N=%d", n_pkts));
    void'($value$plusargs("ROUTES=%s", routes));
    void'($value$plusargs("SHOW=%d", show));
    check_routes(routes);
  endfunction

  function void check_routes(string r);
    if (r.len() != 4)
      $fatal(1, "+ROUTES=%s: give four characters, one per route, for example +ROUTES=0110", r);
    foreach (r[i])
      if (!(r[i] inside {"0", "1", "-"}))
        $fatal(1, "+ROUTES=%s: each character must be 0, 1 or - (disabled)", r);
  endfunction

  // ROUTE[d].EN and ROUTE[d].PORT, as the test configures them.
  function bit route_en(bit [1:0] d);
    return routes[int'(d)] != "-";
  endfunction

  function bit route_port(bit [1:0] d);
    return routes[int'(d)] == "1";
  endfunction

  function string describe();
    return $sformatf("%0d packets, routes %s", n_pkts, routes);
  endfunction
endclass

// ── the random packet ───────────────────────────────────────────────────────
// A packet whose header DST and length come from randomize(). The generator
// sets tag and route_en, randomizes it, and post_randomize() fills in data
// and gap from the fields, as Lab 02's generator filled them from $urandom.
//
// Its DST field is called hdr_dst, because packet::dst() already exists and
// the monitor and the scoreboard call it.

typedef enum bit [1:0] {LEN_ONE, LEN_MID, LEN_MAX} len_kind_e;

class rand_packet extends packet;
  rand bit [1:0]  hdr_dst;    // the header's DST: which routing table entry it uses
  rand len_kind_e kind;       // one beat, 2 to 7 beats, or exactly 8
  int unsigned    len;        // beats, header included
  bit [5:0]       tag;        // the header's other six bits: the generator's count
  bit [3:0]       route_en;   // set by the generator: bit d is ROUTE[d].EN

  // Only to enabled routes, so a random packet is never dropped as NOROUTE.
  // The bit is picked with a shift because the index, hdr_dst, is random.
  constraint c_dst { ((route_en >> hdr_dst) & 4'h1) == 4'h1; }

  // TODO (Part 3): weights for the three kinds, and a constraint that picks
  // len from kind. Then make len rand and delete its assignment below.

  // As shipped, nothing says how often each kind should come out, and len is
  // picked here, after the solver has picked kind.
  function void post_randomize();
    case (kind)
      LEN_ONE: len = 1;
      LEN_MID: len = $urandom_range(7, 2);
      default: len = 8;   // LEN_MAX
    endcase
    build(1);
  endfunction

  // Fill data and gap from hdr_dst, tag and len. The payload is random, and
  // with random_gaps 1 about one beat in four waits 1 to 3 idle cycles before
  // it is offered, as in Lab 02; with 0 the beats go back to back.
  function void build(bit random_gaps);
    data.delete();
    gap.delete();
    for (int i = 0; i < len; i++) begin
      data.push_back(i == 0 ? {hdr_dst, tag} : 8'($urandom));
      gap.push_back((random_gaps && $urandom_range(3) == 0) ? $urandom_range(3, 1) : 0);
    end
  endfunction

  // A packet built by hand, without the solver: len beats for DST dst, back
  // to back.
  static function rand_packet make(bit [1:0] dst, int unsigned len, bit [5:0] tag = 0);
    rand_packet p = new();
    p.hdr_dst = dst;
    p.len     = len;
    p.tag     = tag;
    p.kind    = len == 1 ? LEN_ONE : len < 8 ? LEN_MID : LEN_MAX;
    p.build(0);
    return p;
  endfunction
endclass
