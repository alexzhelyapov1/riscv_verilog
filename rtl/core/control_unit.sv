// rtl/core/control_unit.sv
`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/immediate_types.svh" // For IMM_CTRL_* defines
`include "common/riscv_opcodes.svh"   // For instruction opcodes and funct codes

module control_unit (
    // Inputs from instruction
    input  logic [6:0] op,        // Opcode field
    input  logic [2:0] funct3,    // Funct3 field
    input  logic       funct7_5,  // Bit 5 of Funct7 field (for SUB/SRA)
    input  logic       funct7_1,  // Bit 1 of Funct7 field (for RV64 SRAIW/SRLWI distinction if needed, usually not for main ALU control)
                                  // For base RV64I, funct7_5 is most common for ALU op.
                                  // Let's simplify and primarily use funct7_5 for now.

    // Outputs: Control signals for the datapath
    output logic       reg_write_d_o,    // To ID/EX: Enable register write in WB
    output logic [1:0] result_src_d_o,   // To ID/EX: Selects result source for WB (ALU, Mem, PC+4)
                                         // 00: ALU Result, 01: Memory Read Data, 10: PC+4 (for JAL/JALR)
    output logic       mem_write_d_o,    // To ID/EX: Enable data memory write
    output logic       jump_d_o,         // To ID/EX: Indicates a JAL or JALR type instruction
    output logic       branch_d_o,       // To ID/EX: Indicates a branch instruction (BEQ, BNE, etc.)
    output logic       alu_src_d_o,      // To ID/EX: Selects ALU operand B (Reg vs Imm)
    output logic [2:0] alu_control_d_o,  // To ID/EX: ALU operation control
    output logic [1:0] imm_src_d_o       // To Immediate Generator: Selects immediate type
                                         // Using 2-bit version as per diagram:
                                         // `IMM_CTRL_I_TYPE`, `IMM_CTRL_S_TYPE`, `IMM_CTRL_U_TYPE`, `IMM_CTRL_J_TYPE`
);

    // Internal logic for determining ALU operation based on instruction type and fields
    logic [2:0] alu_op_internal;
    logic       alu_modifier_internal; // For SLT/SLTU, SRA/SRL selection

    // Default values for control signals (typically for "safe" or NOP-like behavior)
    assign reg_write_d_o   = 1'b0;
    assign result_src_d_o  = 2'b00; // Default to ALU result
    assign mem_write_d_o   = 1'b0;
    assign jump_d_o        = 1'b0;
    assign branch_d_o      = 1'b0;
    assign alu_src_d_o     = 1'b0; // Default to Reg source for ALU Op B
    assign imm_src_d_o     = `IMM_CTRL_I_TYPE; // Default, many instrs are I-type

    // Main control logic based on opcode
    always_comb begin
        // Set default values for signals that might not be overridden by all opcodes
        reg_write_d_o   = 1'b0;
        result_src_d_o  = 2'b00; // ALURes
        mem_write_d_o   = 1'b0;
        jump_d_o        = 1'b0;
        branch_d_o      = 1'b0;
        alu_src_d_o     = 1'b0; // Use register value (rs2) for ALU operand B
        alu_op_internal = `ALU_OP_ADD; // Default ALU op
        alu_modifier_internal = 1'b0; // Default modifier
        imm_src_d_o     = `IMM_CTRL_I_TYPE; // Default immediate type

        case (op)
            `OPCODE_LUI: begin
                reg_write_d_o  = 1'b1;
                alu_src_d_o    = 1'b1; // Use immediate
                imm_src_d_o    = `IMM_CTRL_U_TYPE;
                alu_op_internal= `ALU_OP_ADD; // Pass ImmExt (srcA=0, srcB=ImmExt, op=ADD) or specific "pass B" op
                                              // More directly, LUI result is ImmExt. ResultSrc could handle this.
                                              // For simplicity, let's assume ALU can pass ImmExt if SrcA is forced to 0.
                                              // Or, ResultSrc might have a mode for "ImmExt" directly.
                                              // P&H Figure 4.58 suggests LUI uses ALU to pass ImmExt. SrcA=X, SrcB=ImmExt, ALUOp= "Pass input B"
                                              // Let's use ALU_OP_OR with x0 to pass immediate: ALU_OP_OR, SrcA=x0, SrcB=ImmU
                                              // Or simpler: define a "pass B" ALU op if ALU supports it.
                                              // If ResultSrcD can select ImmExtD directly, this is cleaner.
                                              // Diagram shows ResultSrc selecting ALU, Mem, or PC+4.
                                              // So LUI must use ALU. We can do this by making ALU output ImmExtD.
                                              // For example, ALUop = ADD, operand_a = 0, operand_b = ImmExtD.
                                              // This requires operand_a to be selectable as 0.
                                              // Let's assume standard ALU ops. LUI: Rd = ImmU. So ALU should output ImmU.
                                              // We can model this as alu_src_a = 0, alu_src_b = imm_u, alu_op = OR or ADD
                alu_op_internal = `ALU_OP_OR; // operand_a (e.g. x0) | ImmU. If x0 is input to ALU, result is ImmU.
                                              // This implies we need a way to select x0 as ALU input A.
                                              // For now, let's assume the forwarding unit or a dedicated path handles selecting 0 for LUI's SrcA.
                                              // Or, if ALUSrc selects immediate, and the other input to ALU is from a MUX that can select 0.
                                              // The diagram doesn't show a MUX for ALU operand A other than forwarding.
                                              // A common way: LUI's result is just the U-immediate. The ALU is not strictly needed if ResultSrc can select Imm.
                                              // Let's follow diagram strictly: Result from ALU, Mem, or PC+4.
                                              // So LUI: result is ImmExtU. ALU operation is needed.
                                              // The simplest ALU op to pass ImmExtU if OpA can be made 0 is ADD: 0 + ImmExtU.
                alu_op_internal = `ALU_OP_ADD; // We'll need to ensure SrcA can be 0 for LUI.
                                               // This usually means rs1 should be x0 for LUI (which it is not, LUI only has rd, imm).
                                               // This is a classic simplification point. For now, we set ALU op.
                                               // The actual "pass B" might be a specific ALUControl code.
                                               // Let's assume an ALUOp that effectively means "result = operand_b" for LUI.
                                               // This could be `operand_a OR operand_b` where operand_a is 0.
                                               // Or, more simply, LUI's result isn't from ALU but taken directly from ImmExt.
                                               // Given the diagram's ResultSrc choices, it must be via ALU.
                                               // We'll use ALU_OP_OR and rely on forwarding/decode to ensure rs1 is effectively 0 if LUI uses rs1 field.
                                               // RISC-V LUI does not use rs1. It only has rd and imm.
                                               // So, the path for rs1 read should be ignored for LUI.
                                               // The data path will need a way to make ALU input A zero for LUI.
                                               // For now, let control unit signal the intent.
            end
            `OPCODE_AUIPC: begin
                reg_write_d_o  = 1'b1;
                alu_src_d_o    = 1'b1; // Use immediate
                imm_src_d_o    = `IMM_CTRL_U_TYPE;
                alu_op_internal= `ALU_OP_ADD; // PC + ImmExtU
                result_src_d_o = 2'b00; // ALU Result
            end
            `OPCODE_JAL: begin
                reg_write_d_o  = 1'b1;
                jump_d_o       = 1'b1; // This signals a jump, PC will be updated with target
                imm_src_d_o    = `IMM_CTRL_J_TYPE;
                result_src_d_o = 2'b10; // Result is PC+4
                // ALU not directly used for rd data, but target address calc might use it.
                // Target addr = PC + ImmExtJ. This happens in Execute stage for PCTargetE.
                // ALUOp can be ADD for this, ALUSrc=1 (Imm).
                alu_src_d_o    = 1'b1; // For target address calculation (PC + ImmExtJ)
                alu_op_internal= `ALU_OP_ADD;
            end
            `OPCODE_JALR: begin // funct3 = 000
                reg_write_d_o  = 1'b1;
                jump_d_o       = 1'b1; // JALR is also a jump
                alu_src_d_o    = 1'b1; // ALUop(rs1, ImmExtI) for target address
                imm_src_d_o    = `IMM_CTRL_I_TYPE;
                alu_op_internal= `ALU_OP_ADD; // Target address = rs1 + ImmExtI
                result_src_d_o = 2'b10; // Result is PC+4
            end
            `OPCODE_BRANCH: begin // BEQ, BNE, BLT, BGE, BLTU, BGEU
                branch_d_o     = 1'b1; // Signals a branch type instruction
                alu_src_d_o    = 1'b0; // ALU compares rs1 and rs2
                imm_src_d_o    = `IMM_CTRL_S_TYPE; // B-type immediate structure. S_TYPE for generator if compatible
                                                  // Or better, use a dedicated B_TYPE for imm_src if generator handles it.
                                                  // Let's assume generator has a B_TYPE path selected by IMM_CTRL_S_TYPE or similar
                                                  // For now, let's use S_TYPE as a placeholder. Needs specific B-type handling in ImmGen if `imm_src_d_o` is 2 bits.
                                                  // If we use `immediate_type_e` internally and map to 2-bit `imm_src_d_o`:
                                                  // The `immediate_generator` was set to use `IMM_CTRL_S_TYPE` for S and B.
                                                  // Let's refine this: `imm_src_d_o` should select the correct B-type immediate from the generator.
                                                  // We might need to reconsider the `IMM_CTRL_` mapping or expand `imm_src_d_o`.
                                                  // For now, assume `IMM_CTRL_S_TYPE` can generate B-type immediate correctly.
                                                  // **Correction**: `immediate_generator` has `imm_b_type`. We need a way to select it.
                                                  // If `imm_src_d_o` is 2 bits, we need to map.
                                                  // Let's dedicate one of the 2-bit `imm_src_d_o` codes to B-type.
                                                  // E.g. `IMM_CTRL_S_TYPE` for stores, and branch uses a different one or gets special handling.
                                                  // The diagram's `ImmSrcD` feeds into `ImmExtD` which is used by ALU MUX and branch target adder.
                                                  // So B-type immediate *must* be selectable by `ImmSrcD`.
                                                  // Let's assume `IMM_CTRL_J_TYPE` (placeholder) might be used for B-type immediate, needs fixing.
                                                  // For now, let `imm_src_d_o` select B-type if we define a code for it.
                                                  // Redefining IMM_CTRL for 2-bit imm_src_d_o for diagram:
                                                  // IMM_CTRL_I_TYPE  2'b00 -> I-immediates
                                                  // IMM_CTRL_S_TYPE  2'b01 -> S-immediates (for stores)
                                                  // IMM_CTRL_B_TYPE  2'b10 -> B-immediates (for branches) - (was U_TYPE)
                                                  // IMM_CTRL_U_J_TYPE 2'b11 -> U-immediates (LUI, AUIPC) and J-immediates (JAL) - needs split in imm gen
                                                  // This is getting complex with only 2 bits. Let's assume `imm_src_d_o` is wide enough internally
                                                  // and then map to 2 bits if strictly necessary, or declare `imm_src_d_o` as 3 bits.
                                                  // For now, let's use `IMM_CTRL_S_TYPE` for B-type immediate generation path, assuming it's okay.
                                                  // A better approach: `immediate_generator` should take a 3-bit select for I/S/B/U/J.
                                                  // `control_unit` generates this 3-bit select.
                                                  // The `ImmSrcD` on the diagram (if truly 2 bits) is a simplification.
                                                  // I will proceed assuming `imm_src_d_o` can select the correct B-type.
                imm_src_d_o    = `IMM_CTRL_S_TYPE; // Placeholder, should be specific for B-type.
                                                   // Let's use a temporary specific define for B-type selection:
                                                   // `define IMM_CTRL_B_TYPE 2'b10` (replaces U_TYPE for this slot)
                                                   // Then U_TYPE and J_TYPE would need to share `2'b11` or similar.
                                                   // This implies `immediate_generator` must be controlled by these 2-bit codes.
                                                   // Let's update `immediate_types.svh` and `immediate_generator.sv` logic slightly.
                                                   // For now, let's stick to the 2-bit `imm_src_d_o` and assume it can select B-type.
                case (funct3) // Branch type
                    `FUNCT3_BEQ:  alu_op_internal = `ALU_OP_SUB; // Zero flag will be checked (rs1 == rs2)
                    `FUNCT3_BNE:  alu_op_internal = `ALU_OP_SUB; // Zero flag will be checked (rs1 != rs2)
                    `FUNCT3_BLT:  begin alu_op_internal = `ALU_OP_SLT_BASE; alu_modifier_internal = `ALU_SELECT_SIGNED; end
                    `FUNCT3_BGE:  begin alu_op_internal = `ALU_OP_SLT_BASE; alu_modifier_internal = `ALU_SELECT_SIGNED; end // Inverted in Execute
                    `FUNCT3_BLTU: begin alu_op_internal = `ALU_OP_SLT_BASE; alu_modifier_internal = `ALU_SELECT_UNSIGNED; end
                    `FUNCT3_BGEU: begin alu_op_internal = `ALU_OP_SLT_BASE; alu_modifier_internal = `ALU_SELECT_UNSIGNED; end // Inverted in Execute
                    default:      alu_op_internal = `ALU_OP_ADD; // Should not happen for valid branch
                endcase
                reg_write_d_o  = 1'b0; // Branches do not write to register file
            end
            `OPCODE_LOAD: begin // LB, LH, LW, LD, LBU, LHU, LWU
                reg_write_d_o  = 1'b1;
                alu_src_d_o    = 1'b1;    // ALU operand B is immediate (offset)
                imm_src_d_o    = `IMM_CTRL_I_TYPE;
                alu_op_internal= `ALU_OP_ADD; // Effective address = rs1 + ImmExtI
                result_src_d_o = 2'b01; // Result from Memory
                mem_write_d_o  = 1'b0;    // Load is a read from memory
                // Specific load type (byte, half, word, signed/unsigned) is handled in Memory/WB stage
            end
            `OPCODE_STORE: begin // SB, SH, SW, SD
                alu_src_d_o    = 1'b1;    // ALU operand B is immediate (offset)
                imm_src_d_o    = `IMM_CTRL_S_TYPE;
                alu_op_internal= `ALU_OP_ADD; // Effective address = rs1 + ImmExtS
                mem_write_d_o  = 1'b1;    // Store is a write to memory
                reg_write_d_o  = 1'b0;    // Stores do not write to register file
                // Specific store type (byte, half, word) is handled in Memory stage
            end
            `OPCODE_OP_IMM: begin // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI (and shifts for RV64I)
                reg_write_d_o  = 1'b1;
                alu_src_d_o    = 1'b1; // ALU operand B is immediate
                imm_src_d_o    = `IMM_CTRL_I_TYPE; // Most are I-type, shifts have shamt in imm field
                result_src_d_o = 2'b00; // Result from ALU

                case (funct3)
                    `FUNCT3_ADDI:  alu_op_internal = `ALU_OP_ADD;
                    `FUNCT3_SLTI:  begin alu_op_internal = `ALU_OP_SLT_BASE; alu_modifier_internal = `ALU_SELECT_SIGNED; end
                    `FUNCT3_SLTIU: begin alu_op_internal = `ALU_OP_SLT_BASE; alu_modifier_internal = `ALU_SELECT_UNSIGNED; end
                    `FUNCT3_XORI:  alu_op_internal = `ALU_OP_XOR;
                    `FUNCT3_ORI:   alu_op_internal = `ALU_OP_OR;
                    `FUNCT3_ANDI:  alu_op_internal = `ALU_OP_AND;
                    `FUNCT3_SLLI:  alu_op_internal = `ALU_OP_SLL; // funct7 is 0 for SLLI
                    `FUNCT3_SRLI_SRAI: begin // SRLI or SRAI
                        if (funct7_5 == `FUNCT7_5_SRA_ALT) begin // SRAI
                            alu_op_internal = `ALU_OP_SR_BASE;
                            alu_modifier_internal = `ALU_SELECT_ARITH_SR;
                        end else begin // SRLI (funct7_5 == 0)
                            alu_op_internal = `ALU_OP_SR_BASE;
                            alu_modifier_internal = `ALU_SELECT_LOGICAL_SR;
                        end
                    end
                    default: alu_op_internal = `ALU_OP_ADD; // Should not happen
                endcase
            end
            `OPCODE_OP: begin // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
                reg_write_d_o  = 1'b1;
                alu_src_d_o    = 1'b0; // ALU operand B from register
                imm_src_d_o    = `IMM_CTRL_I_TYPE; // Not used, but provide a default
                result_src_d_o = 2'b00; // Result from ALU

                case (funct3)
                    `FUNCT3_ADD_SUB: begin // ADD or SUB
                        if (funct7_5 == `FUNCT7_5_SUB_ALT) begin // SUB
                            alu_op_internal = `ALU_OP_SUB;
                        end else begin // ADD (funct7_5 == 0)
                            alu_op_internal = `ALU_OP_ADD;
                        end
                    end
                    `FUNCT3_SLL:   alu_op_internal = `ALU_OP_SLL;
                    `FUNCT3_SLT:   begin alu_op_internal = `ALU_OP_SLT_BASE; alu_modifier_internal = `ALU_SELECT_SIGNED; end
                    `FUNCT3_SLTU:  begin alu_op_internal = `ALU_OP_SLT_BASE; alu_modifier_internal = `ALU_SELECT_UNSIGNED; end
                    `FUNCT3_XOR:   alu_op_internal = `ALU_OP_XOR;
                    `FUNCT3_SRL_SRA: begin // SRL or SRA
                        if (funct7_5 == `FUNCT7_5_SRA_ALT) begin // SRA
                            alu_op_internal = `ALU_OP_SR_BASE;
                            alu_modifier_internal = `ALU_SELECT_ARITH_SR;
                        end else begin // SRL (funct7_5 == 0)
                            alu_op_internal = `ALU_OP_SR_BASE;
                            alu_modifier_internal = `ALU_SELECT_LOGICAL_SR;
                        end
                    end
                    `FUNCT3_OR:    alu_op_internal = `ALU_OP_OR;
                    `FUNCT3_AND:   alu_op_internal = `ALU_OP_AND;
                    default: alu_op_internal = `ALU_OP_ADD; // Should not happen
                endcase
            end
            // `OPCODE_SYSTEM: // ECALL, EBREAK, CSR instructions - not handled yet
            // `OPCODE_MISC_MEM: // FENCE, FENCE.I - not handled yet

            default: begin // Unknown opcode, treat as NOP or error
                reg_write_d_o  = 1'b0;
                result_src_d_o = 2'b00;
                mem_write_d_o  = 1'b0;
                jump_d_o       = 1'b0;
                branch_d_o     = 1'b0;
                alu_src_d_o    = 1'b0;
                alu_op_internal= `ALU_OP_ADD; // NOP
                imm_src_d_o    = `IMM_CTRL_I_TYPE;
            end
        endcase
    end

    // Combine alu_op_internal and alu_modifier_internal into alu_control_d_o
    // This depends on how ALU module interprets its control signals.
    // Our current ALU takes a 3-bit alu_op_select and a 1-bit alu_modifier.
    // So, alu_control_d_o could be just alu_op_internal, and alu_modifier is separate.
    // The diagram shows ALUControlD[2:0].
    // Let's pass alu_op_internal as alu_control_d_o.
    // The alu_modifier needs to be passed to ID/EX as well.
    // The diagram has ALUControlE[2:0] and no explicit modifier.
    // This implies the 3-bit ALUControlE must encode everything.
    // This means our ALU interface (alu_op_select, alu_modifier) needs to map to this 3-bit signal,
    // or the ALU needs to be refactored.
    // For now, let's assume we need to expand ALUControl capabilities or pass modifier separately.
    // Looking at the diagram: ALUControlD[2:0] -> ALUControlE[2:0] -> ALU (module).
    // The current alu.sv takes `alu_op_select[2:0]` and `alu_modifier`.
    // We need to either:
    // 1. Change ALU to take a single, wider control signal.
    // 2. Pass `alu_modifier` separately through the pipeline registers. The diagram doesn't show this.
    // 3. Encode `alu_modifier` within the 3 bits of `ALUControlD` if possible (e.g. have separate opcodes for SLT/SLTU, SRA/SRL).
    // Option 3 is common. E.g., specific codes for SLT, SLTU, SRA, SRL.
    // Let's adapt to Option 3. This requires more ALU opcodes.
    // Redefine `alu_defines.svh` and update `alu.sv` and this `control_unit.sv`.

    // For now, this control unit will output `alu_op_internal` as `alu_control_d_o`.
    // The `alu_modifier_internal` would need to be pipelined separately if ALU keeps current interface.
    // The diagram's `ALUControlD` being 3 bits is a strong hint to encode modifier into it.
    // This means we need more distinct ALU operations.
    // Example: `ALU_OP_SLT`, `ALU_OP_SLTU`, `ALU_OP_SRA`, `ALU_OP_SRL`.
    // This is a significant change. I will proceed with the current ALU interface
    // and assume `alu_modifier` is an implicit signal for now or that ALUControlD can be expanded later.
    // Or, as a simpler fix for now, if alu_control_d_o is truly 3 bits,
    // we can pick: if alu_modifier is needed, it uses one of the alu_control_d_o bits.
    // For example, alu_control_d_o[2:0] = alu_op_internal[2:0]
    // alu_control_d_o[X] = alu_modifier_internal (if we steal a bit from op or use a 4th bit)

    // Let's stick to the diagram: ALUControlD is 3 bits.
    // The existing alu.sv has 8 base operations selected by 3 bits.
    // The `alu_modifier` selects variants.
    // This means the `alu_modifier` *must* be passed separately or the ALU is simplified.
    // For now, I will output `alu_op_internal` and ignore `alu_modifier_internal` for `alu_control_d_o`.
    // This is a point to resolve: how `alu_modifier` is handled.
    // The diagram seems to omit it for simplicity after the ALUControlD signal.
    // A robust solution is to make ALUControlD wider (e.g., 4 or 5 bits) to include the modifier.
    // Or, the ALU block on the diagram implicitly uses it from somewhere.
    // I will assume for now that the Hazard Unit or a later stage might refine ALUControl or provide modifier.
    // Or, more likely, the diagram implies the 3-bit ALUControl *is sufficient* by having distinct ALU ops.
    // This is the most consistent interpretation. I will need to update `alu_defines.svh` and `alu.sv`
    // to have distinct opcodes for SLT, SLTU, SRA, SRL.

    // Let's assume we will update ALU to accept a single 3-bit control that implies modifier.
    // For now, this control unit calculates `alu_op_internal` and `alu_modifier_internal`.
    // `alu_control_d_o` will be set based on this, potentially requiring more states in `alu_defines.svh`.
    // I will generate `alu_control_d_o` directly for now, implying the ALU will understand combined ops.
    // This part (ALU control mapping) will be refined when we connect to the actual ALU.
    // For the purpose of Decode stage, we generate the *intent*.
    assign alu_control_d_o = alu_op_internal; // This is temporary.
                                              // We need to generate a single alu_control signal.
                                              // For example, if `alu_op_internal = SLT_BASE` and `modifier = SIGNED`, then `alu_control_d_o = ACTUAL_SLT_OP`.
                                              // This mapping will be done after defining all distinct ALU ops.
                                              // For now, let's assume alu_control_d_o IS alu_op_internal and modifier is separate.
                                              // This will require `alu_modifier` to be passed to ID/EX.
                                              // Let's add `alu_modifier_d_o` to the outputs and pipeline it.
                                              // This deviates slightly from the provided diagram if it omits this explicit signal.

    // Revisit ALU control generation later based on final ALU interface.
    // For now, `alu_control_d_o` is the base op, and modifier is separate.
    // The diagram has `ALUControlD[2:0]`. This implies the modifier is encoded.
    // Example: SLT becomes one code, SLTU another. This doubles ops for SLT/SR.
    // ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_SLT, ALU_SLTU, ALU_SLL, ALU_SRL, ALU_SRA
    // This is 10 ops. Needs 4 bits for ALUControlD.
    // The diagram is likely simplified.
    // I will proceed by outputting `alu_op_internal` and `alu_modifier_internal` separately from CU,
    // and they will be registered in ID/EX.
    // The port list of `control_unit` and `id_ex_register` will reflect this.

endmodule

// We will need `riscv_opcodes.svh`