`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/immediate_types.svh"
`include "common/control_signals_defines.svh"

module control_unit_tb (
    // Inputs to control_unit
    input  logic [6:0] i_op,
    input  logic [2:0] i_funct3,
    input  logic       i_funct7_5,

    // Outputs from control_unit
    output logic       o_reg_write_d,
    output logic [1:0] o_result_src_d,
    output logic       o_mem_write_d,
    output logic       o_jump_d,
    output logic       o_branch_d,
    output logic       o_alu_src_d,
    output logic [`ALU_CONTROL_WIDTH-1:0] o_alu_control_d,
    output immediate_type_e o_imm_type_d,
    output logic [2:0] o_funct3_d,
    output alu_a_src_sel_e o_op_a_sel_d,
    output pc_target_src_sel_e o_pc_target_src_sel_d
);

    control_unit u_control_unit (
        .op                (i_op),
        .funct3            (i_funct3),
        .funct7_5          (i_funct7_5),

        .reg_write_d_o     (o_reg_write_d),
        .result_src_d_o    (o_result_src_d),
        .mem_write_d_o     (o_mem_write_d),
        .jump_d_o          (o_jump_d),
        .branch_d_o        (o_branch_d),
        .alu_src_d_o       (o_alu_src_d),
        .alu_control_d_o   (o_alu_control_d),
        .imm_type_d_o      (o_imm_type_d),
        .funct3_d_o        (o_funct3_d),
        .op_a_sel_d_o      (o_op_a_sel_d),
        .pc_target_src_sel_d_o (o_pc_target_src_sel_d)
    );

endmodule