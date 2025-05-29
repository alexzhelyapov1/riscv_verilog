`ifndef RISCV_OPCODES_SVH
`define RISCV_OPCODES_SVH

`define OPCODE_LUI        7'b0110111
`define OPCODE_AUIPC      7'b0010111
`define OPCODE_JAL        7'b1101111
`define OPCODE_JALR       7'b1100111
`define OPCODE_BRANCH     7'b1100011
`define OPCODE_LOAD       7'b0000011
`define OPCODE_STORE      7'b0100011
`define OPCODE_OP_IMM   7'b0010011
`define OPCODE_OP         7'b0110011
`define OPCODE_MISC_MEM 7'b0001111
`define OPCODE_SYSTEM     7'b1110011

`define FUNCT3_ADDI       3'b000
`define FUNCT3_ADD_SUB    3'b000
`define FUNCT3_SLLI       3'b001
`define FUNCT3_SLL        3'b001
`define FUNCT3_SLTI       3'b010
`define FUNCT3_SLT        3'b010
`define FUNCT3_SLTIU      3'b011
`define FUNCT3_SLTU       3'b011
`define FUNCT3_XORI       3'b100
`define FUNCT3_XOR        3'b100
`define FUNCT3_SRLI_SRAI  3'b101
`define FUNCT3_SRL_SRA    3'b101
`define FUNCT3_ORI        3'b110
`define FUNCT3_OR         3'b110
`define FUNCT3_ANDI       3'b111
`define FUNCT3_AND        3'b111

`define FUNCT3_BEQ        3'b000
`define FUNCT3_BNE        3'b001
`define FUNCT3_BLT        3'b100
`define FUNCT3_BGE        3'b101
`define FUNCT3_BLTU       3'b110
`define FUNCT3_BGEU       3'b111

`define FUNCT3_LB         3'b000
`define FUNCT3_LH         3'b001
`define FUNCT3_LW         3'b010
`define FUNCT3_LD         3'b011
`define FUNCT3_LBU        3'b100
`define FUNCT3_LHU        3'b101
`define FUNCT3_LWU        3'b110

`define FUNCT3_SB         3'b000
`define FUNCT3_SH         3'b001
`define FUNCT3_SW         3'b010
`define FUNCT3_SD         3'b011

`define FUNCT3_JALR       3'b000
`define FUNCT7_5_SUB_ALT  1'b1
`define FUNCT7_5_ADD_MAIN 1'b0


`endif