// Stub de macros de asserção para infraestrutura OpenTitan/CIP
`ifndef PRIM_ASSERT_SV
`define PRIM_ASSERT_SV

`define ASSERT(__name, __prop, __clk = 1'b1, __rst = 1'b0)
`define ASSERT_I(__name, __prop)
`define ASSERT_INIT(__name, __prop)
`define ASSERT_FINAL(__name, __prop)
`define ASSERT_KNOWN(__name, __signal, __clk = 1'b1, __rst = 1'b0)

`define COVER(__name, __prop, __clk = 1'b1, __rst = 1'b0)
`define COVER_I(__name, __prop)

`define ASSUME(__name, __prop, __clk = 1'b1, __rst = 1'b0)
`define ASSUME_I(__name, __prop)

`endif // PRIM_ASSERT_SV
