# SELFTEST design for labs/common/selftest/selftest.py. Not a lab: a small ALU
# with three planted bugs and the fixture tests in tb/st_pkg.sv.
TOP           := st_top
DUT_SRCS      := rtl/st_alu.sv
TB_SRCS       := tb/st_if.sv tb/st_sva.sv tb/st_pkg.sv tb/st_top.sv
TESTS         := st_good_test st_empty_test
BUG_LIST      := B01 B02 B03
BUG_CATALOGUE := bugs.json
BUG_CONFIRM   := DD105-BUG: {id} enabled
PLUSARGS      ?= +N=300
RUN_TIMEOUT   ?= 60
include ../../uvm.mk
