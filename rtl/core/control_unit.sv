`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/immediate_types.svh"
`include "common/riscv_opcodes.svh"
`include "common/control_signals_defines.svh"

module control_unit (
    input  logic [6:0] op,
    input  logic [2:0] funct3,
    input  logic       funct7_5,

    output logic       reg_write_d_o,
    output logic [1:0] result_src_d_o,
    output logic       mem_write_d_o,
    output logic       jump_d_o,
    output logic       branch_d_o,
    output logic       alu_src_d_o,
    output logic [`ALU_CONTROL_WIDTH-1:0] alu_control_d_o,
    output immediate_type_e imm_type_d_o,
    output logic [2:0] funct3_d_o,
    output alu_a_src_sel_e op_a_sel_d_o,
    output pc_target_src_sel_e pc_target_src_sel_d_o
);

    assign funct3_d_o = funct3;

    always_comb begin
        reg_write_d_o   = 1'b0;
        result_src_d_o  = 2'b00;
        mem_write_d_o   = 1'b0;
        jump_d_o        = 1'b0;
        branch_d_o      = 1'b0;
        alu_src_d_o     = 1'b0;
        alu_control_d_o = `ALU_OP_ADD;
        imm_type_d_o    = IMM_TYPE_NONE;
        op_a_sel_d_o    = ALU_A_SRC_RS1;
        pc_target_src_sel_d_o = PC_TARGET_SRC_PC_PLUS_IMM;

        case (op)
            `OPCODE_LUI: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1;
                imm_type_d_o    = IMM_TYPE_U;
                op_a_sel_d_o    = ALU_A_SRC_ZERO;
                alu_control_d_o = `ALU_OP_ADD;
                result_src_d_o  = 2'b00;
            end
            `OPCODE_AUIPC: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1;
                imm_type_d_o    = IMM_TYPE_U;
                op_a_sel_d_o    = ALU_A_SRC_PC;
                alu_control_d_o = `ALU_OP_ADD;
                result_src_d_o  = 2'b00;
            end
            `OPCODE_JAL: begin
                reg_write_d_o   = 1'b1;
                jump_d_o        = 1'b1;
                imm_type_d_o    = IMM_TYPE_J;
                result_src_d_o  = 2'b10;
                pc_target_src_sel_d_o = PC_TARGET_SRC_PC_PLUS_IMM;
                op_a_sel_d_o    = ALU_A_SRC_PC;
                alu_src_d_o     = 1'b1;
                alu_control_d_o = `ALU_OP_ADD;
            end
            `OPCODE_JALR: begin
                reg_write_d_o   = 1'b1;
                jump_d_o        = 1'b1;
                alu_src_d_o     = 1'b1;
                imm_type_d_o    = IMM_TYPE_I;
                op_a_sel_d_o    = ALU_A_SRC_RS1;
                alu_control_d_o = `ALU_OP_ADD;
                result_src_d_o  = 2'b10;
                pc_target_src_sel_d_o = PC_TARGET_SRC_ALU_JALR;
            end
            `OPCODE_BRANCH: begin
                branch_d_o      = 1'b1;
                alu_src_d_o     = 1'b0;
                op_a_sel_d_o    = ALU_A_SRC_RS1;
                imm_type_d_o    = IMM_TYPE_B;
                reg_write_d_o   = 1'b0;
                pc_target_src_sel_d_o = PC_TARGET_SRC_PC_PLUS_IMM;
                case (funct3)
                    `FUNCT3_BEQ:  alu_control_d_o = `ALU_OP_SUB;
                    `FUNCT3_BNE:  alu_control_d_o = `ALU_OP_SUB;
                    `FUNCT3_BLT:  alu_control_d_o = `ALU_OP_SLT;
                    `FUNCT3_BGE:  alu_control_d_o = `ALU_OP_SLT;
                    `FUNCT3_BLTU: alu_control_d_o = `ALU_OP_SLTU;
                    `FUNCT3_BGEU: alu_control_d_o = `ALU_OP_SLTU;
                    default:      alu_control_d_o = `ALU_OP_ADD;
                endcase
            end
            `OPCODE_LOAD: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1;
                imm_type_d_o    = IMM_TYPE_I;
                op_a_sel_d_o    = ALU_A_SRC_RS1;
                alu_control_d_o = `ALU_OP_ADD;
                result_src_d_o  = 2'b01;
                mem_write_d_o   = 1'b0;
            end
            `OPCODE_STORE: begin
                alu_src_d_o     = 1'b1;
                imm_type_d_o    = IMM_TYPE_S;
                op_a_sel_d_o    = ALU_A_SRC_RS1;
                alu_control_d_o = `ALU_OP_ADD;
                mem_write_d_o   = 1'b1;
                reg_write_d_o   = 1'b0;
            end
            `OPCODE_OP_IMM: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1;
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
                alu_src_d_o     = 1'b0;
                op_a_sel_d_o    = ALU_A_SRC_RS1;
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
        endcase
    end
endmodule