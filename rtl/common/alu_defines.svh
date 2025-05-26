// rtl/common/alu_defines.svh
`ifndef ALU_DEFINES_SVH
`define ALU_DEFINES_SVH

`define ALU_CONTROL_WIDTH 4 // Needs 4 bits for ~10 operations

// Unified ALU Control Signals
// R-Type / I-Type Arithmetic
`define ALU_OP_ADD  4'b0000 // Addition
`define ALU_OP_SUB  4'b0001 // Subtraction
`define ALU_OP_SLL  4'b0010 // Shift Left Logical
`define ALU_OP_SLT  4'b0011 // Set Less Than (Signed)
`define ALU_OP_SLTU 4'b0100 // Set Less Than (Unsigned)
`define ALU_OP_XOR  4'b0101 // XOR
`define ALU_OP_SRL  4'b0110 // Shift Right Logical
`define ALU_OP_SRA  4'b0111 // Shift Right Arithmetic
`define ALU_OP_OR   4'b1000 // OR
`define ALU_OP_AND  4'b1001 // AND

// Potentially other operations for specific instructions if needed, e.g., pass Operand B
// `define ALU_OP_PASS_B 4'b1010 // Pass operand_b directly (e.g., for LUI if srcA is 0)
// For LUI, it's rd = imm. If ALU is used, srcA=0, srcB=imm, op=ADD. So ALU_OP_ADD works.
// For AUIPC, it's rd = pc + imm. srcA=PC, srcB=imm, op=ADD. So ALU_OP_ADD works.

`endif // ALU_DEFINES_SVH