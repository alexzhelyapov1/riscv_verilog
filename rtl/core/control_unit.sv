// rtl/core/control_unit.sv
`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/immediate_types.svh"
`include "common/riscv_opcodes.svh"
`include "common/control_signals_defines.svh" // New include

module control_unit (
    // Inputs from instruction
    input  logic [6:0] op,
    input  logic [2:0] funct3,
    input  logic       funct7_5,

    // Outputs: Control signals
    output logic       reg_write_d_o,
    output logic [1:0] result_src_d_o,
    output logic       mem_write_d_o,
    output logic       jump_d_o,
    output logic       branch_d_o,
    output logic       alu_src_d_o,      // Selects ALU operand B (Reg vs Imm)
    output logic [`ALU_CONTROL_WIDTH-1:0] alu_control_d_o,
    output immediate_type_e imm_type_d_o,
    output logic [2:0] funct3_d_o,             // Pass funct3 for branch logic in EX & mem access type in MEM
    output alu_a_src_sel_e op_a_sel_d_o,        // Selects ALU operand A source
    output pc_target_src_sel_e pc_target_src_sel_d_o // Selects PC target source for EX
);

    // Pass funct3 directly as it's needed in later stages
    assign funct3_d_o = funct3;

    always_comb begin
        // Initialize signals to a known "safe" or default state for each instruction type
        reg_write_d_o   = 1'b0;
        result_src_d_o  = 2'b00; // Default: Result from ALU
        mem_write_d_o   = 1'b0;
        jump_d_o        = 1'b0;
        branch_d_o      = 1'b0;
        alu_src_d_o     = 1'b0; // Default: ALU Operand B from Register File (rs2)
        alu_control_d_o = `ALU_OP_ADD; // Default ALU operation
        imm_type_d_o    = IMM_TYPE_NONE;
        op_a_sel_d_o    = ALU_A_SRC_RS1; // Default
        pc_target_src_sel_d_o = PC_TARGET_SRC_PC_PLUS_IMM; // Default

        case (op)
            `OPCODE_LUI: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1; // Imm for OpB
                imm_type_d_o    = IMM_TYPE_U;
                op_a_sel_d_o    = ALU_A_SRC_ZERO; // ALU OpA = 0
                alu_control_d_o = `ALU_OP_ADD;    // ALU = 0 + Imm
                result_src_d_o  = 2'b00;
            end
            `OPCODE_AUIPC: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1; // Imm for OpB
                imm_type_d_o    = IMM_TYPE_U;
                op_a_sel_d_o    = ALU_A_SRC_PC;   // ALU OpA = PC
                alu_control_d_o = `ALU_OP_ADD;    // ALU = PC + Imm
                result_src_d_o  = 2'b00;
            end
            `OPCODE_JAL: begin
                reg_write_d_o   = 1'b1;
                jump_d_o        = 1'b1;
                imm_type_d_o    = IMM_TYPE_J;
                result_src_d_o  = 2'b10;      // rd = PC+4
                pc_target_src_sel_d_o = PC_TARGET_SRC_PC_PLUS_IMM; // Target = PC + ImmJ
                // ALU might be idle or used by a separate adder for PC+Imm.
                // To keep ALU control consistent if it *were* used for target:
                op_a_sel_d_o    = ALU_A_SRC_PC; // If ALU calculated PC+ImmJ
                alu_src_d_o     = 1'b1;
                alu_control_d_o = `ALU_OP_ADD;
            end
            `OPCODE_JALR: begin
                reg_write_d_o   = 1'b1;
                jump_d_o        = 1'b1;
                alu_src_d_o     = 1'b1; // Imm for OpB
                imm_type_d_o    = IMM_TYPE_I;
                op_a_sel_d_o    = ALU_A_SRC_RS1;  // ALU OpA = RS1
                alu_control_d_o = `ALU_OP_ADD;    // ALU = RS1 + Imm (for target calculation)
                result_src_d_o  = 2'b10;      // rd = PC+4
                pc_target_src_sel_d_o = PC_TARGET_SRC_ALU_JALR; // Target from ALU result & ~1
            end
            `OPCODE_BRANCH: begin
                branch_d_o      = 1'b1;
                alu_src_d_o     = 1'b0; // OpB = RS2 for comparison
                op_a_sel_d_o    = ALU_A_SRC_RS1; // OpA = RS1 for comparison
                imm_type_d_o    = IMM_TYPE_B;    // For PC + ImmB target calculation
                reg_write_d_o   = 1'b0;
                pc_target_src_sel_d_o = PC_TARGET_SRC_PC_PLUS_IMM; // Target is PC+ImmB
                case (funct3)
                    `FUNCT3_BEQ:  alu_control_d_o = `ALU_OP_SUB;
                    `FUNCT3_BNE:  alu_control_d_o = `ALU_OP_SUB;
                    `FUNCT3_BLT:  alu_control_d_o = `ALU_OP_SLT;
                    `FUNCT3_BGE:  alu_control_d_o = `ALU_OP_SLT;
                    `FUNCT3_BLTU: alu_control_d_o = `ALU_OP_SLTU;
                    `FUNCT3_BGEU: alu_control_d_o = `ALU_OP_SLTU;
                    default:      alu_control_d_o = `ALU_OP_ADD; // Or some invalid op
                endcase
            end
            `OPCODE_LOAD: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1; // Imm for OpB (offset)
                imm_type_d_o    = IMM_TYPE_I;
                op_a_sel_d_o    = ALU_A_SRC_RS1;  // OpA = RS1 (base address)
                alu_control_d_o = `ALU_OP_ADD;    // ALU = RS1 + offset (address calculation)
                result_src_d_o  = 2'b01;      // Result from Memory
                mem_write_d_o   = 1'b0;
            end
            `OPCODE_STORE: begin
                alu_src_d_o     = 1'b1; // Imm for OpB (offset)
                imm_type_d_o    = IMM_TYPE_S;
                op_a_sel_d_o    = ALU_A_SRC_RS1;  // OpA = RS1 (base address)
                alu_control_d_o = `ALU_OP_ADD;    // ALU = RS1 + offset (address calculation)
                mem_write_d_o   = 1'b1;
                reg_write_d_o   = 1'b0;
            end
            `OPCODE_OP_IMM: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1; // Imm for OpB
                imm_type_d_o    = (funct3 == `FUNCT3_SLLI || funct3 == `FUNCT3_SRLI_SRAI) ? IMM_TYPE_ISHIFT : IMM_TYPE_I;
                op_a_sel_d_o    = ALU_A_SRC_RS1;
                result_src_d_o  = 2'b00;
                case (funct3)
                    `FUNCT3_ADDI:  alu_control_d_o = `ALU_OP_ADD;
                    `FUNCT3_SLTI:  alu_control_d_o = `ALU_OP_SLT;
                    `FUNCT3_SLTIU: alu_control_d_o = `ALU_OP_SLTU;
                    `FUNCT3_XORI:  alu_control_d_o = `ALU_OP_XOR;
                    `FUNCT3_ORI:   alu_control_d_o = `ALU_OP_OR;
                    `FUNCT3_ANDI:  alu_control_d_o = `ALU_OP_AND;
                    `FUNCT3_SLLI:  alu_control_d_o = `ALU_OP_SLL;
                    `FUNCT3_SRLI_SRAI: begin
                        if (funct7_5 == `FUNCT7_5_SUB_ALT) alu_control_d_o = `ALU_OP_SRA;
                        else                               alu_control_d_o = `ALU_OP_SRL;
                    end
                    default:       alu_control_d_o = `ALU_OP_ADD;
                endcase
            end
            `OPCODE_OP: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b0; // OpB = RS2
                op_a_sel_d_o    = ALU_A_SRC_RS1; // OpA = RS1
                imm_type_d_o    = IMM_TYPE_NONE;
                result_src_d_o  = 2'b00;
                case (funct3)
                    `FUNCT3_ADD_SUB: begin
                        if (funct7_5 == `FUNCT7_5_SUB_ALT) alu_control_d_o = `ALU_OP_SUB;
                        else                               alu_control_d_o = `ALU_OP_ADD;
                    end
                    `FUNCT3_SLL:   alu_control_d_o = `ALU_OP_SLL;
                    `FUNCT3_SLT:   alu_control_d_o = `ALU_OP_SLT;
                    `FUNCT3_SLTU:  alu_control_d_o = `ALU_OP_SLTU;
                    `FUNCT3_XOR:   alu_control_d_o = `ALU_OP_XOR;
                    `FUNCT3_SRL_SRA: begin
                        if (funct7_5 == `FUNCT7_5_SUB_ALT) alu_control_d_o = `ALU_OP_SRA;
                        else                               alu_control_d_o = `ALU_OP_SRL;
                    end
                    `FUNCT3_OR:    alu_control_d_o = `ALU_OP_OR;
                    `FUNCT3_AND:   alu_control_d_o = `ALU_OP_AND;
                    default:       alu_control_d_o = `ALU_OP_ADD;
                endcase
            end
            default: begin // NOP / Unknown
                // Default assignments from above cover this
            end
        endcase
    end
endmodule