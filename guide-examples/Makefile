# DD105-A guide examples: every example folder in turn, in course-path order.
#
#   make -C guide-examples          make build in each folder
#   make -C guide-examples clean    make clean in each folder (the ccache is kept)
#
# Each folder's own Makefile, through labs/common/uvm.mk, does the work.
# README.md lists the commands behind every output a guide page quotes.
# The folders build one at a time: each build already uses both CPUs.

EXAMPLES := \
  from-cocotb-to-systemverilog-classes \
  classes-for-testbenches \
  interfaces-clocking-blocks-and-virtual-interfaces \
  threads-mailboxes-and-events \
  constrained-random-on-verilator \
  functional-coverage-you-can-read \
  the-uvm-skeleton \
  sequences-sequencers-and-drivers \
  monitors-analysis-ports-and-scoreboards \
  the-factory-and-config-db \
  assertions-for-interface-rules \
  reactive-agents-and-backpressure \
  virtual-sequences \
  register-models \
  regressions-and-seeds

.NOTPARALLEL:
.PHONY: all build clean $(EXAMPLES)

all: build

build: $(EXAMPLES)

$(EXAMPLES):
	@$(MAKE) --no-print-directory -C $@ build

clean:
	@for d in $(EXAMPLES); do $(MAKE) --no-print-directory -C $$d clean; done
