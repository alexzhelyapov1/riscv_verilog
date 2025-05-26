// rtl/common/control_signals_defines.svh
`ifndef CONTROL_SIGNALS_DEFINES_SVH
`define CONTROL_SIGNALS_DEFINES_SVH

// Selector for ALU Operand A
typedef enum logic [1:0] {
    ALU_A_SRC_RS1,   // Select RS1 data
    ALU_A_SRC_PC,    // Select PC
    ALU_A_SRC_ZERO   // Select constant Zero (for LUI: 0 + Imm)
    // ALU_A_SRC_FWD // Will be handled by forwarding logic, this selects the *original* source
} alu_a_src_sel_e;

// Selector for PC Target Address source in Execute stage
typedef enum logic [0:0] { // Only two main sources for now
    PC_TARGET_SRC_PC_PLUS_IMM, // Target = PC + Immediate (for Branch, JAL)
    PC_TARGET_SRC_ALU_JALR     // Target = (ALU_Result from RS1+Imm) & ~1 (for JALR)
} pc_target_src_sel_e;

`endif // CONTROL_SIGNALS_DEFINES_SVH