// rtl/core/immediate_generator.sv
`include "common/defines.svh"
`include "common/immediate_types.svh" // We'll define immediate types here

module immediate_generator (
    input  logic [`INSTR_WIDTH-1:0] instr_i,     // Full instruction
    input  logic [1:0]              imm_src_sel_i, // ImmSrcD from control unit
    output logic [`DATA_WIDTH-1:0]  imm_ext_o      // Sign-extended immediate
);

    logic [`DATA_WIDTH-1:0] imm_i_type;
    logic [`DATA_WIDTH-1:0] imm_s_type;
    logic [`DATA_WIDTH-1:0] imm_b_type;
    logic [`DATA_WIDTH-1:0] imm_u_type;
    logic [`DATA_WIDTH-1:0] imm_j_type;

    // I-type immediate: instr[31:20] (12 bits)
    // Sign-extend from bit 11 of the immediate (instr[31])
    assign imm_i_type = {{(`DATA_WIDTH-12){instr_i[31]}}, instr_i[31:20]};

    // S-type immediate: instr[31:25], instr[11:7] (12 bits)
    // Sign-extend from bit 11 of the immediate (instr[31])
    assign imm_s_type = {{(`DATA_WIDTH-12){instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

    // B-type immediate: instr[31], instr[7], instr[30:25], instr[11:8], 1'b0 (13 bits, for PC-relative branch)
    // Immediate is for word-aligned targets, so it's shifted left by 1.
    // Sign-extend from bit 12 of the immediate (instr[31])
    assign imm_b_type = {{(`DATA_WIDTH-13){instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};

    // U-type immediate: instr[31:12], 12'b0 (32 bits, upper 20 bits)
    // For LUI, AUIPC. No sign extension needed as it forms upper bits.
    // For RV64, the lower 12 bits are zero, and the upper bits are instr[31:12].
    assign imm_u_type = {instr_i[31:12], 12'h000};
    // If DATA_WIDTH > 32, the U-type immediate is sign-extended from bit 31 of the original 32-bit instruction
    // However, LUI result is bits [31:12] shifted left by 12.
    // For RV64, the standard interpretation of LUI's immediate is that it forms bits 31:12 of the result.
    // For AUIPC, it's added to PC.
    // The scheme uses ImmExtD directly. For LUI, the value is instr[31:12] << 12.
    // For RV64, this means {instr[31], {19{instr[31]}}, instr[30:12], 12'b0} if sign-extended from bit 31.
    // Or just {instr[31:12], 12'b0} zero-extended to DATA_WIDTH.
    // Let's assume direct formation as per Patterson & Hennessy: {instr[31:12], 12'b0} then sign extend the full 32-bit value if needed.
    // For RV64, U-immediates are sign-extended from bit 31 of the full 32-bit immediate value.
    // So, { { (`DATA_WIDTH-32){instr_i[31]} }, instr_i[31:12], 12'h000}
    // The diagram's "Расширение знака" suggests sign extension is common.
    // But LUI is special: it loads the 20-bit immediate into bits 31-12 of rd, zeroing rd[11:0].
    // AUIPC: adds 20-bit immediate (shifted left by 12) to PC.
    // Let's stick to Patterson & Hennessy diagram logic: ImmExtD is a general sign-extended value.
    // For U-type, the diagram would imply that AluSrc=1 and the ALU operation does something with PC and ImmExtD (for AUIPC)
    // or AluSrc=1 and ALU op passes ImmExtD through (for LUI, but this happens later).
    // For simplicity, let's use the common RISC-V spec definition:
    assign imm_u_type = {{(`DATA_WIDTH-32){instr_i[31]}}, instr_i[31:12], 12'b0};


    // J-type immediate: instr[31], instr[19:12], instr[20], instr[30:21], 1'b0 (21 bits, for PC-relative jump)
    // Immediate is for word-aligned targets, so it's shifted left by 1.
    // Sign-extend from bit 20 of the immediate (instr[31])
    assign imm_j_type = {{(`DATA_WIDTH-21){instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};

    always_comb begin
        case (imm_src_sel_i)
            `IMM_SRC_I:     imm_ext_o = imm_i_type;
            `IMM_SRC_S:     imm_ext_o = imm_s_type;
            `IMM_SRC_B:     imm_ext_o = imm_b_type;
            `IMM_SRC_J:     imm_ext_o = imm_j_type; // U and J are often grouped differently or U is special
                                                   // Diagram has ImmSrcD[1:0], implying 4 types.
                                                   // Let's assume J is one of them. U is handled by ALU op or ResultSrc.
                                                   // Based on the diagram, ImmSrcD selects the source for ImmExtD that goes to ALUSrc MUX.
                                                   // For LUI/AUIPC (U-type), ImmExtD is typically {instr[31:12], 12'b0}.
            `IMM_SRC_U:     imm_ext_o = imm_u_type; // Adding a specific U-type based on common practice. Need to adjust ImmSrc bits if so.
                                                   // If ImmSrcD is 2 bits, we map RISC-V types to these.
                                                   // Let's align with a common interpretation for a 2-bit ImmSrcD:
                                                   // 00: I-type
                                                   // 01: S-type (store) / B-type (branch) - often share structure
                                                   // 10: U-type (LUI/AUIPC)
                                                   // 11: J-type (JAL)
                                                   // For B-type, the immediate structure is different from S.
                                                   // So, the diagram's 2-bit ImmSrcD might be simplified.
                                                   // We'll need a more detailed `control_unit` to map opcodes to `imm_src_sel_i`.
                                                   // For now, let's assume `imm_src_sel_i` can select any of these.
                                                   // This requires `imm_src_sel_i` to be wider (e.g., 3 bits).
                                                   // If `ImmSrcD` is strictly 2 bits like in the diagram, we have to make choices.
                                                   // Let's assume:
                                                   // `IMM_SRC_I_TYPE` (00)
                                                   // `IMM_SRC_S_TYPE` (01)
                                                   // `IMM_SRC_U_TYPE` (10) -> used for LUI, AUIPC
                                                   // `IMM_SRC_J_TYPE` (11) -> used for JAL (B-type for branches has its own path often)
                                                   // Branch immediate calculation is often separate or uses one of these and then is added to PC.
                                                   // The diagram shows ImmExtD feeding into the ALU. For branches, (PC + ImmExtD) is calculated.
                                                   // This means B-type should use ImmExtD.
                                                   // Let's use the defines from immediate_types.svh
            default:        imm_ext_o = `DATA_WIDTH'(0); // Default or error
        endcase
    end

endmodule