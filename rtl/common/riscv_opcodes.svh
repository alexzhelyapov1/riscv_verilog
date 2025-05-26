// rtl/common/riscv_opcodes.svh
`ifndef RISCV_OPCODES_SVH
`define RISCV_OPCODES_SVH

// Opcodes (bottom 7 bits of instruction)
`define OPCODE_LUI        7'b0110111 // Load Upper Immediate
`define OPCODE_AUIPC      7'b0010111 // Add Upper Immediate to PC
`define OPCODE_JAL        7'b1101111 // Jump and Link
`define OPCODE_JALR       7'b1100111 // Jump and Link Register
`define OPCODE_BRANCH     7'b1100011 // Conditional Branches (BEQ, BNE, etc.)
`define OPCODE_LOAD       7'b0000011 // Loads (LB, LH, LW, LD, LBU, LHU, LWU)
`define OPCODE_STORE      7'b0100011 // Stores (SB, SH, SW, SD)
`define OPCODE_OP_IMM   7'b0010011 // Immediate Arithmetic/Logic (ADDI, SLTI, etc.)
`define OPCODE_OP         7'b0110011 // Register-Register Arithmetic/Logic (ADD, SUB, etc.)
`define OPCODE_MISC_MEM 7'b0001111 // FENCE, FENCE.I
`define OPCODE_SYSTEM     7'b1110011 // ECALL, EBREAK, CSR instructions

// Funct3 codes for OP_IMM, OP, BRANCH, LOAD, STORE, JALR
// For OP_IMM & OP
`define FUNCT3_ADDI       3'b000 // ADDI
`define FUNCT3_ADD_SUB    3'b000 // ADD/SUB (OP)
`define FUNCT3_SLLI       3'b001 // SLLI (OP_IMM)
`define FUNCT3_SLL        3'b001 // SLL (OP)
`define FUNCT3_SLTI       3'b010 // SLTI (OP_IMM)
`define FUNCT3_SLT        3'b010 // SLT (OP)
`define FUNCT3_SLTIU      3'b011 // SLTIU (OP_IMM)
`define FUNCT3_SLTU       3'b011 // SLTU (OP)
`define FUNCT3_XORI       3'b100 // XORI (OP_IMM)
`define FUNCT3_XOR        3'b100 // XOR (OP)
`define FUNCT3_SRLI_SRAI  3'b101 // SRLI/SRAI (OP_IMM) - Distinguish by funct7
`define FUNCT3_SRL_SRA    3'b101 // SRL/SRA (OP)     - Distinguish by funct7
`define FUNCT3_ORI        3'b110 // ORI (OP_IMM)
`define FUNCT3_OR         3'b110 // OR (OP)
`define FUNCT3_ANDI       3'b111 // ANDI (OP_IMM)
`define FUNCT3_AND        3'b111 // AND (OP)

// For BRANCH
`define FUNCT3_BEQ        3'b000
`define FUNCT3_BNE        3'b001
`define FUNCT3_BLT        3'b100
`define FUNCT3_BGE        3'b101
`define FUNCT3_BLTU       3'b110
`define FUNCT3_BGEU       3'b111

// For LOAD
`define FUNCT3_LB         3'b000
`define FUNCT3_LH         3'b001
`define FUNCT3_LW         3'b010
`define FUNCT3_LD         3'b011 // RV64
`define FUNCT3_LBU        3'b100
`define FUNCT3_LHU        3'b101
`define FUNCT3_LWU        3'b110 // RV64

// For STORE
`define FUNCT3_SB         3'b000
`define FUNCT3_SH         3'b001
`define FUNCT3_SW         3'b010
`define FUNCT3_SD         3'b011 // RV64

// For JALR
`define FUNCT3_JALR       3'b000

// Funct7 codes (or relevant bits)
// For ADD/SUB and SRA/SRL distinction in OP and OP_IMM type instructions.
// For R-type (OP) and I-type shifts (OP_IMM), bit 5 of funct7 (instr[30]) is often used.
`define FUNCT7_5_SUB_ALT  1'b1 // For SUB, SRA, SRAI (funct7[5])
`define FUNCT7_5_ADD_MAIN 1'b0 // For ADD, SRL, SRLI (funct7[5])
// `define FUNCT7_SRL        7'b0000000 (SRL, SRLI, SRLW, SRLIW)
// `define FUNCT7_SRA        7'b0100000 (SRA, SRAI, SRAW, SRAIW)
// `define FUNCT7_ADD        7'b0000000
// `define FUNCT7_SUB        7'b0100000

`endif // RISCV_OPCODES_SVH