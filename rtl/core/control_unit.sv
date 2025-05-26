// rtl/core/control_unit.sv
`include "common/defines.svh"
`include "common/alu_defines.svh"      // For new `ALU_OP_*` and `ALU_CONTROL_WIDTH`
`include "common/immediate_types.svh" // For `immediate_type_e`
`include "common/riscv_opcodes.svh"   // For instruction opcodes and funct codes

module control_unit (
    // Inputs from instruction
    input  logic [6:0] op,       // Opcode field
    input  logic [2:0] funct3,   // Funct3 field
    input  logic       funct7_5, // Bit 5 of Funct7 field (instr[30])

    // Outputs: Control signals for the datapath
    output logic       reg_write_d_o,    // To ID/EX: Enable register write in WB
    output logic [1:0] result_src_d_o,   // To ID/EX: Selects result source for WB
                                         // 00: ALU Result, 01: Memory Read Data, 10: PC+4
    output logic       mem_write_d_o,    // To ID/EX: Enable data memory write
    output logic       jump_d_o,         // To ID/EX: Indicates a JAL or JALR type instruction
    output logic       branch_d_o,       // To ID/EX: Indicates a branch instruction
    output logic       alu_src_d_o,      // To ID/EX: Selects ALU operand B (Reg vs Imm)
    output logic [`ALU_CONTROL_WIDTH-1:0] alu_control_d_o, // To ID/EX: Unified ALU operation control
    output immediate_type_e imm_type_d_o      // To Immediate Generator: Selects immediate type
);

    // Default values for control signals
    assign reg_write_d_o   = 1'b0;
    assign result_src_d_o  = 2'b00;
    assign mem_write_d_o   = 1'b0;
    assign jump_d_o        = 1'b0;
    assign branch_d_o      = 1'b0;
    assign alu_src_d_o     = 1'b0;
    assign alu_control_d_o = `ALU_OP_ADD; // Default to ADD (NOP-like if other signals are off)
    assign imm_type_d_o    = IMM_TYPE_NONE;

    always_comb begin
        // Initialize signals to a known "safe" or default state for each instruction type
        reg_write_d_o   = 1'b0;
        result_src_d_o  = 2'b00; // Default: Result from ALU
        mem_write_d_o   = 1'b0;
        jump_d_o        = 1'b0;
        branch_d_o      = 1'b0;
        alu_src_d_o     = 1'b0; // Default: ALU Operand B from Register File (rs2)
        alu_control_d_o = `ALU_OP_ADD; // Default ALU operation
        imm_type_d_o    = IMM_TYPE_NONE; // Default: No immediate used or relevant for ImmGen path to ALU

        case (op)
            `OPCODE_LUI: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1; // ALU operand B is immediate
                imm_type_d_o    = IMM_TYPE_U;
                alu_control_d_o = `ALU_OP_ADD; // ALU does 0 + ImmExtU. Source A needs to be zero.
                                               // This relies on datapath providing 0 for SrcA for LUI.
                                               // Alternative: `ALU_OP_PASS_B` if ALU supported it and SrcA was not needed.
                result_src_d_o  = 2'b00; // Result from ALU
            end
            `OPCODE_AUIPC: begin
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1; // ALU operand B is immediate
                imm_type_d_o    = IMM_TYPE_U;
                alu_control_d_o = `ALU_OP_ADD; // ALU does PC + ImmExtU
                result_src_d_o  = 2'b00; // Result from ALU
            end
            `OPCODE_JAL: begin
                reg_write_d_o   = 1'b1;
                jump_d_o        = 1'b1;
                imm_type_d_o    = IMM_TYPE_J;    // For calculating branch target (PC + ImmExtJ)
                alu_src_d_o     = 1'b1;          // Target address calculation needs immediate
                alu_control_d_o = `ALU_OP_ADD;   // PC + ImmExtJ for target. Not for rd data.
                result_src_d_o  = 2'b10;       // Result to be written (rd) is PC+4
            end
            `OPCODE_JALR: begin // funct3 must be 000
                reg_write_d_o   = 1'b1;
                jump_d_o        = 1'b1;
                alu_src_d_o     = 1'b1; // ALU operand B is immediate (offset)
                imm_type_d_o    = IMM_TYPE_I;
                alu_control_d_o = `ALU_OP_ADD;   // Target address is rs1 + ImmExtI
                result_src_d_o  = 2'b10;       // Result to be written (rd) is PC+4
            end
            `OPCODE_BRANCH: begin // BEQ, BNE, BLT, BGE, BLTU, BGEU
                branch_d_o      = 1'b1;
                alu_src_d_o     = 1'b0; // ALU compares rs1 and rs2
                imm_type_d_o    = IMM_TYPE_B; // For branch offset calculation (PC + ImmExtB)
                reg_write_d_o   = 1'b0; // Branches do not write to RF

                case (funct3)
                    `FUNCT3_BEQ:  alu_control_d_o = `ALU_OP_SUB; // Zero flag checked for equality
                    `FUNCT3_BNE:  alu_control_d_o = `ALU_OP_SUB; // Zero flag checked for inequality
                    `FUNCT3_BLT:  alu_control_d_o = `ALU_OP_SLT;
                    `FUNCT3_BGE:  alu_control_d_o = `ALU_OP_SLT;  // Condition for BGE is !(rs1 < rs2)
                    `FUNCT3_BLTU: alu_control_d_o = `ALU_OP_SLTU;
                    `FUNCT3_BGEU: alu_control_d_o = `ALU_OP_SLTU; // Condition for BGEU is !(rs1 < rs2)unsigned
                    default:      alu_control_d_o = `ALU_OP_ADD; // Should not happen for valid branch
                endcase
            end
            `OPCODE_LOAD: begin // LB, LH, LW, LD, LBU, LHU, LWU
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1;    // ALU operand B is immediate (offset)
                imm_type_d_o    = IMM_TYPE_I;
                alu_control_d_o = `ALU_OP_ADD; // Effective address = rs1 + ImmExtI
                result_src_d_o  = 2'b01;   // Result from Memory
                mem_write_d_o   = 1'b0;    // Load is a read
            end
            `OPCODE_STORE: begin // SB, SH, SW, SD
                alu_src_d_o     = 1'b1;    // ALU operand B is immediate (offset)
                imm_type_d_o    = IMM_TYPE_S;
                alu_control_d_o = `ALU_OP_ADD; // Effective address = rs1 + ImmExtS
                mem_write_d_o   = 1'b1;    // Store is a write
                reg_write_d_o   = 1'b0;    // Stores do not write to RF
            end
            `OPCODE_OP_IMM: begin // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b1; // ALU operand B is immediate
                imm_type_d_o    = IMM_TYPE_I; // Includes shamt for shifts
                result_src_d_o  = 2'b00; // Result from ALU

                case (funct3)
                    `FUNCT3_ADDI:  alu_control_d_o = `ALU_OP_ADD;
                    `FUNCT3_SLTI:  alu_control_d_o = `ALU_OP_SLT;
                    `FUNCT3_SLTIU: alu_control_d_o = `ALU_OP_SLTU;
                    `FUNCT3_XORI:  alu_control_d_o = `ALU_OP_XOR;
                    `FUNCT3_ORI:   alu_control_d_o = `ALU_OP_OR;
                    `FUNCT3_ANDI:  alu_control_d_o = `ALU_OP_AND;
                    `FUNCT3_SLLI: begin
                        alu_control_d_o = `ALU_OP_SLL;
                        imm_type_d_o    = IMM_TYPE_ISHIFT;
                    end
                    `FUNCT3_SRLI_SRAI: begin // SRLI or SRAI
                        if (funct7_5 == `FUNCT7_5_SUB_ALT) begin // SRAI (funct7[5]==1 for I-type SRAI)
                            alu_control_d_o = `ALU_OP_SRA;
                        end else begin // SRLI (funct7[5]==0 for I-type SRLI)
                            alu_control_d_o = `ALU_OP_SRL;
                        end
                        imm_type_d_o    = IMM_TYPE_ISHIFT;
                    end
                    default: alu_control_d_o = `ALU_OP_ADD; // Should not happen
                endcase
            end
            `OPCODE_OP: begin // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
                reg_write_d_o   = 1'b1;
                alu_src_d_o     = 1'b0; // ALU operand B from register
                imm_type_d_o    = IMM_TYPE_NONE; // No immediate for ALU path
                result_src_d_o  = 2'b00;   // Result from ALU

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
                    default:       alu_control_d_o = `ALU_OP_ADD; // Should not happen
                endcase
            end
            default: begin // Unknown opcode, treat as NOP
                reg_write_d_o   = 1'b0;
                result_src_d_o  = 2'b00;
                mem_write_d_o   = 1'b0;
                jump_d_o        = 1'b0;
                branch_d_o      = 1'b0;
                alu_src_d_o     = 1'b0;
                alu_control_d_o = `ALU_OP_ADD; // Effectively NOP if rd is x0 or RegWriteD is 0
                imm_type_d_o    = IMM_TYPE_NONE;
            end
        endcase
    end
endmodule