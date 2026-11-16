// The input packet: a header and up to 11 more beats.
//
// Lab 03's solution. The length kind is a selector with weights, and the
// solver picks the length from the kind's range.

typedef enum bit [1:0] {LEN_ONE, LEN_MID, LEN_MAX, LEN_OVER} len_kind_e;

class packet;
  rand bit [1:0]    dst;    // the header's DST field: the routing table entry it uses
  rand bit [5:0]    tag;    // the header's other six bits (the tests put a count here)
  rand len_kind_e   kind;   // one beat, 2 to 7 beats, exactly 8, or oversize (9 to 12)
  rand int unsigned len;    // beats sent, header included

  // How often each kind comes out, in parts of the total (20/50/20/10 is 20 %,
  // 50 %, 20 % and 10 %). A test can change them before it calls randomize().
  int unsigned w_one = 20, w_mid = 50, w_max = 20, w_over = 10;

  // Idle cycles before a beat: gap_pct percent of beats wait 1 to max_gap cycles.
  int unsigned gap_pct = 25, max_gap = 3;

  // Built by build() from the fields above.
  bit [7:0]    data[];
  bit          last[];
  int unsigned gap[];

  // The weights go on kind, and len is solved from kind. On this simulator a
  // dist picks its value first and fails if another constraint rules that
  // value out (traps line 3), so the dist is kept off len, which a test may
  // constrain further. Its values are written as numbers: written as the
  // enum's names, the weights are ignored (traps line 2).
  constraint c_kind { kind dist {0 := w_one, 1 := w_mid, 2 := w_max, 3 := w_over}; }
  constraint c_len  { (kind == LEN_ONE)  -> len == 1;
                      (kind == LEN_MID)  -> len inside {[2:7]};
                      (kind == LEN_MAX)  -> len == 8;
                      (kind == LEN_OVER) -> len inside {[9:12]}; }

  function void post_randomize();
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
