// rtl/common/immediate_types.svh
`ifndef IMMEDIATE_TYPES_SVH
`define IMMEDIATE_TYPES_SVH

// For imm_src_sel_i (ImmSrcD on diagram)
// This determines how the immediate field of an instruction is expanded.
// The diagram shows ImmSrcD as 2 bits, meaning 4 types.
// RISC-V has I, S, B, U, J types. We need to map them.
// A common mapping for a simplified ImmSrc (if limited to 2 bits):
// - I-type (ADDI, LW, JALR)
// - S-type (SW)
// - B-type (Branches) - often combined with S or handled slightly differently
// - J-TYPE (JAL)
// - U-TYPE (LUI, AUIPC)
// Let's define more distinct types and the control unit will select.
// For a 2-bit ImmSrcD, we might have:
// `define IMM_SRC_ITYPE  2'b00 // For I-type (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI, LB, LH, LW, LD, LBU, LHU, LWU, JALR)
// `define IMM_SRC_STYPE  2'b01 // For S-type (SB, SH, SW, SD)
// `define IMM_SRC_BTYPE  2'b01 // B-type can reuse S-type path if structure is same for imm gen, or needs its own
// `define IMM_SRC_UTYPE  2'b10 // For U-type (LUI, AUIPC)
// `define IMM_SRC_JTYPE  2'b11 // For J-type (JAL)

// Let's use distinct values for clarity in immediate_generator,
// the control unit will map opcodes to these.
// If ImmSrcD is 2 bits, we need to choose which types are directly selected by it.
// The diagram's ImmSrcD[1:0] implies 4 choices for the immediate that goes to the ALU.
// 1. I-immediate (for arithmetic-I, load, jalr)
// 2. S-immediate (for store)
// 3. B-immediate (for branch conditional) - structure is different
// 4. J-immediate (for jal)
// U-immediate (lui, auipc) is also needed. LUI often bypasses ALU for immediate, AUIPC uses ALU.
// If ImmSrcD controls the mux *before* the ALU for operand B, then U-type for AUIPC must be selectable.
// Let's assume ImmSrcD can distinguish all necessary types for the ALU's second operand.
// For a 2-bit ImmSrcD as per diagram:
`define IMM_SRC_DEFAULT 2'b00 // e.g. R-type, no immediate or handled differently
`define IMM_SRC_I     2'b00 // For ADDI, LW, JALR etc.
`define IMM_SRC_S     2'b01 // For SW etc. (B-type also, if structure aligns or control unit pre-processes)
                            // Or perhaps B type has a separate path for PC target calculation not using this ImmExtD for ALU.
                            // But diagram shows one ImmExtD path for branches.
`define IMM_SRC_U     2'b10 // For LUI, AUIPC
// `define IMM_SRC_J     2'b11 // For JAL
// Wait, the diagram page 1's text block for control unit outputs: ImmSrcD[1:0].
// The types of immediate are usually I, S, B, U, J.
// Let's refine the `immediate_generator` to use specific encodings for these 5 types,
// and the control unit will generate a, say, 3-bit signal for it.
// Then, if `ImmSrcD` on the diagram is truly 2 bits, it means some types are grouped
// or one type is not generated through this specific path.

// For now, let's define distinct enum-like values for internal use in control_unit,
// and immediate_generator will use them.
// The actual ImmSrcD signal on the datapath can be narrower if types are grouped.

typedef enum logic [2:0] {
    IMM_TYPE_NONE, // For R-type or when immediate is not used by ALU operand B
    IMM_TYPE_I,
    IMM_TYPE_S,
    IMM_TYPE_B,
    IMM_TYPE_U,
    IMM_TYPE_J
} immediate_type_e;

// If ImmSrcD is 2-bits on the datapath as per diagram:
`define IMM_CTRL_I_TYPE  2'b00 // selects imm_i_type
`define IMM_CTRL_S_TYPE  2'b01 // selects imm_s_type (and B-type if B-type imm is passed here)
`define IMM_CTRL_U_TYPE  2'b10 // selects imm_u_type
`define IMM_CTRL_J_TYPE  2'b11 // selects imm_j_type
// This mapping implies that B-type immediate, if it goes to ALU as operand B, might share `IMM_CTRL_S_TYPE` if the structure is compatible,
// or it's handled differently (e.g., PC + Imm for branch target is calculated elsewhere or uses a dedicated path).
// Given the diagram, PCTargetE is calculated using an adder fed by PC and ImmExtE. This ImmExtE would be the B-type or J-type immediate.
// So, B-type and J-type immediates *must* be selectable by ImmSrcD.
// Let's adjust `immediate_generator` to take `immediate_type_e` and map it based on how many distinct paths `ImmSrcD` can select.
// For now, assume `imm_src_sel_i` in `immediate_generator` is `ImmSrcD` from the diagram (2 bits).

`endif // IMMEDIATE_TYPES_SVH