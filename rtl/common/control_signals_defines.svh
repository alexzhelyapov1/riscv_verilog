`ifndef CONTROL_SIGNALS_DEFINES_SVH
`define CONTROL_SIGNALS_DEFINES_SVH


typedef enum logic [1:0] {
    ALU_A_SRC_RS1,
    ALU_A_SRC_PC,
    ALU_A_SRC_ZERO
} alu_a_src_sel_e;

typedef enum logic [0:0] {
    PC_TARGET_SRC_PC_PLUS_IMM,
    PC_TARGET_SRC_ALU_JALR
} pc_target_src_sel_e;


`endif