// tests/unit/common_pipeline_types_tb.h
#ifndef COMMON_PIPELINE_TYPES_TB_H
#define COMMON_PIPELINE_TYPES_TB_H

#include <cstdint>

// Mirroring SystemVerilog structures for C++ testbenches

// From common/defines.svh
const uint32_t NOP_INSTRUCTION_TB = 0x00000013;
const uint64_t PC_RESET_VALUE_TB = 0x00000000; // Or whatever PC_RESET_VALUE is

// From common/control_signals_defines.svh
typedef enum {
    ALU_A_SRC_RS1_TB,
    ALU_A_SRC_PC_TB,
    ALU_A_SRC_ZERO_TB
} alu_a_src_sel_e_tb;

typedef enum {
    PC_TARGET_SRC_PC_PLUS_IMM_TB,
    PC_TARGET_SRC_ALU_JALR_TB
} pc_target_src_sel_e_tb;

// From common/alu_defines.svh
const uint8_t ALU_OP_ADD_TB = 0x0; // Example, add more if needed for defaults

// From common/pipeline_types.svh
typedef struct {
    uint32_t    instr;
    uint64_t    pc;
    uint64_t    pc_plus_4;
} IfIdDataTb;

typedef struct {
    bool        reg_write;
    uint8_t     result_src; // 2 bits
    bool        mem_write;
    bool        jump;
    bool        branch;
    bool        alu_src;    // Selects ALU OpB
    uint8_t     alu_control; // ALU_CONTROL_WIDTH bits
    uint8_t     op_a_sel; // alu_a_src_sel_e_tb
    uint8_t     pc_target_src_sel; // pc_target_src_sel_e_tb
    uint8_t     funct3;

    uint64_t    pc;
    uint64_t    pc_plus_4;
    uint64_t    rs1_data;
    uint64_t    rs2_data;
    uint64_t    imm_ext;

    uint8_t     rs1_addr; // REG_ADDR_WIDTH bits
    uint8_t     rs2_addr;
    uint8_t     rd_addr;
} IdExDataTb;

typedef struct {
    bool        reg_write;
    uint8_t     result_src; // 2 bits
    bool        mem_write;
    uint8_t     funct3;

    uint64_t    alu_result;
    uint64_t    rs2_data;
    uint64_t    pc_plus_4;

    uint8_t     rd_addr;
} ExMemDataTb;

typedef struct {
    bool        reg_write;
    uint8_t     result_src; // 2 bits

    uint64_t    read_data_mem;
    uint64_t    alu_result;
    uint64_t    pc_plus_4;

    uint8_t     rd_addr;
} MemWbDataTb;

typedef struct {
    bool        stall_f;
    bool        stall_d;
    bool        flush_d;
    bool        flush_e;
    uint8_t     forward_a_e; // 2 bits
    uint8_t     forward_b_e; // 2 bits
} HazardControlTb;


// Define ResultSrc values for clarity (matching control_unit logic)
const uint8_t RESULT_SRC_ALU_TB    = 0b00;
const uint8_t RESULT_SRC_MEM_TB    = 0b01; // Indicates a Load instruction
const uint8_t RESULT_SRC_PC_PLUS4_TB = 0b10;


#endif // COMMON_PIPELINE_TYPES_TB_H