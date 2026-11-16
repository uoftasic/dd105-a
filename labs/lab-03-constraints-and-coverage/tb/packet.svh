// The input packet: a header and up to 11 more beats.
//
// From Lab 02, where nothing looked at what randomize() produced: the solver
// picks a length kind, and post_randomize() turns the kind into a length.
// Part 2 measures what that gives, and Part 3 replaces it with constraints.

typedef enum bit [1:0] {LEN_ONE, LEN_MID, LEN_MAX, LEN_OVER} len_kind_e;

class packet;
  rand bit [1:0]  dst;      // the header's DST field: the routing table entry it uses
  rand bit [5:0]  tag;      // the header's other six bits (the tests put a count here)
  rand len_kind_e kind;     // one beat, 2 to 7 beats, exactly 8, or oversize (9 to 12)
  int unsigned    len;      // beats sent, header included

  // Idle cycles before a beat: gap_pct percent of beats wait 1 to max_gap cycles.
  int unsigned gap_pct = 25, max_gap = 3;

  // Built by build() from the fields above.
  bit [7:0]    data[];
  bit          last[];
  int unsigned gap[];

  // TODO (Part 3): the constraints.

  function void post_randomize();
    case (kind)
      LEN_ONE:  len = 1;
      LEN_MID:  len = $urandom_range(7, 2);
      LEN_MAX:  len = 8;
      LEN_OVER: len = $urandom_range(12, 9);
    endcase
    build(1);
  endfunction

  // Fill data, last and gap from len, dst and tag. The payload is random;
  // with random_gaps 0 the beats go back to back.
  function void build(bit random_gaps);
    data = new[len];
    last = new[len];
    gap  = new[len];
    foreach (data[i]) begin
      data[i] = (i == 0) ? {dst, tag} : 8'($urandom);
      last[i] = (i == len - 1);
      gap[i]  = (random_gaps && $urandom_range(99) < gap_pct) ? $urandom_range(max_gap, 1) : 0;
    end
  endfunction

  // A packet built by hand, without the solver: len beats for DST dst.
  static function packet make(bit [1:0] dst, int unsigned len, bit [5:0] tag = 0);
    packet p = new();
    p.dst  = dst;
    p.tag  = tag;
    p.len  = len;
    p.kind = len == 1 ? LEN_ONE : len < 8 ? LEN_MID : len == 8 ? LEN_MAX : LEN_OVER;
    p.build(0);
    return p;
  endfunction

  function string convert2string();
    string s = $sformatf("dst %0d, %0d beats:", dst, len);
    foreach (data[i]) s = {s, $sformatf(" %02h", data[i])};
    return s;
  endfunction
endclass
