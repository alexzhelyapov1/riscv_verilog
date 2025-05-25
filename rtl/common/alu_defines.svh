`ifndef ALU_DEFINES_SVH
`define ALU_DEFINES_SVH

`define ALU_OP_ADD      3'b000
`define ALU_OP_SUB      3'b001
`define ALU_OP_AND      3'b010
`define ALU_OP_OR       3'b011
`define ALU_OP_XOR      3'b100
`define ALU_OP_SLT_BASE 3'b101
`define ALU_OP_SLL      3'b110
`define ALU_OP_SR_BASE  3'b111

`define ALU_SELECT_SIGNED       1'b0
`define ALU_SELECT_UNSIGNED     1'b1

`define ALU_SELECT_LOGICAL_SR   1'b0
`define ALU_SELECT_ARITH_SR     1'b1

`endif