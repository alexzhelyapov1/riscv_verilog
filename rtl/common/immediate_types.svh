`ifndef IMMEDIATE_TYPES_SVH
`define IMMEDIATE_TYPES_SVH

typedef enum logic [2:0] {
    IMM_TYPE_NONE, // For R-type or when immediate is not used by ALU operand B or for address calculation
    IMM_TYPE_I,    // I-type (ADDI, LW, JALR)
    IMM_TYPE_S,    // S-type (SW)
    IMM_TYPE_B,    // B-type (Branches)
    IMM_TYPE_U,    // U-type (LUI, AUIPC)
    IMM_TYPE_J,     // J-type (JAL)
    IMM_TYPE_ISHIFT // SLLI, SRLI, SRAI
} immediate_type_e;

`endif