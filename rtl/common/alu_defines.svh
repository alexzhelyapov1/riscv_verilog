`ifndef ALU_DEFINES_SVH
`define ALU_DEFINES_SVH

`define ALU_CONTROL_WIDTH 4

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

`endif