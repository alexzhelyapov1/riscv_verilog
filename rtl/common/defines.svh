`ifndef COMMON_DEFINES_SVH
`define COMMON_DEFINES_SVH

`define DATA_WIDTH 64
`define INSTR_WIDTH 32
`define REG_ADDR_WIDTH 5
`define PC_RESET_VALUE 64'h00000000 // Standard PC reset value
`define NOP_INSTRUCTION 32'h00000013 // addi x0, x0, 0

`endif