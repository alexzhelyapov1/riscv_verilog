`include "common/defines.svh"
`include "common/immediate_types.svh"

module immediate_generator (
    input  logic [`INSTR_WIDTH-1:0] instr_i,
    input  immediate_type_e         imm_type_sel_i,
    output logic [`DATA_WIDTH-1:0]  imm_ext_o
);

    logic [`DATA_WIDTH-1:0] imm_i_type;
    logic [`DATA_WIDTH-1:0] imm_s_type;
    logic [`DATA_WIDTH-1:0] imm_b_type;
    logic [`DATA_WIDTH-1:0] imm_u_type;
    logic [`DATA_WIDTH-1:0] imm_j_type;
    logic [`DATA_WIDTH-1:0] imm_ishift_type;

    assign imm_i_type = {{(`DATA_WIDTH-12){instr_i[31]}}, instr_i[31:20]};
    assign imm_s_type = {{(`DATA_WIDTH-12){instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
    assign imm_b_type = {{(`DATA_WIDTH-13){instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
    assign imm_u_type = {{(`DATA_WIDTH-32){instr_i[31]}}, instr_i[31:12], 12'h000};
    assign imm_j_type = {{(`DATA_WIDTH-21){instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
    assign imm_ishift_type = `DATA_WIDTH'(instr_i[25:20]);

    always_comb begin
        case (imm_type_sel_i)
            IMM_TYPE_I:    imm_ext_o = imm_i_type;
            IMM_TYPE_S:    imm_ext_o = imm_s_type;
            IMM_TYPE_B:    imm_ext_o = imm_b_type;
            IMM_TYPE_U:    imm_ext_o = imm_u_type;
            IMM_TYPE_J:    imm_ext_o = imm_j_type;
            IMM_TYPE_ISHIFT: imm_ext_o = imm_ishift_type;
            IMM_TYPE_NONE: imm_ext_o = `DATA_WIDTH'(0);
            default:       imm_ext_o = `DATA_WIDTH'('x);
        endcase
    end

endmodule