// DD105-A: waveforms on request, with no change to the lab's top module.
//
// uvm.mk compiles this file into every build with +define+DD105_TOP=<top>,
// and the bind below drops one instance of dd105_waves into the top module.
// It does nothing unless the run has +WAVES=<file>, which `make waves` adds:
// then it dumps every signal in the design to that VCD file, and make
// converts it to FST (the image's Verilator can't write FST itself).

module dd105_waves;
  string file;
  initial begin
    if ($value$plusargs("WAVES=%s", file)) begin
      $display("DD105: writing waves to %s", file);
      $dumpfile(file);
      $dumpvars;
    end
  end
endmodule

`ifdef DD105_TOP
bind `DD105_TOP dd105_waves dd105_waves_i ();
`endif
