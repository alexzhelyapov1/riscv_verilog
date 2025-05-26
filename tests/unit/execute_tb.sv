// tests/unit/execute_tb.sv

`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/control_signals_defines.svh"

module execute_tb (
    input  logic clk,
    input  logic rst_n,

    // Inputs to control Execute stage behavior (from a virtual ID/EX)
    input  logic       i_reg_write_e,
    input  logic [1:0] i_result_src_e,
    input  logic       i_mem_write_e,
    input  logic       i_jump_e,
    input  logic       i_branch_e,
    input  logic       i_alu_src_e,
    input  logic [`ALU_CONTROL_WIDTH-1:0] i_alu_control_e,
    input  logic [2:0] i_funct3_e,
    input  alu_a_src_sel_e i_op_a_sel_e,
    input  pc_target_src_sel_e i_pc_target_src_sel_e,

    input  logic [`DATA_WIDTH-1:0]  i_pc_e,
    input  logic [`DATA_WIDTH-1:0]  i_pc_plus_4_e,
    input  logic [`DATA_WIDTH-1:0]  i_rs1_data_e,
    input  logic [`DATA_WIDTH-1:0]  i_rs2_data_e,
    input  logic [`DATA_WIDTH-1:0]  i_imm_ext_e,
    input  logic [`REG_ADDR_WIDTH-1:0] i_rd_addr_e,

    // Outputs from Execute stage (to observe, these go to EX/MEM)
    output logic       o_reg_write_m,
    output logic [1:0] o_result_src_m,
    output logic       o_mem_write_m,
    output logic [`DATA_WIDTH-1:0] o_alu_result_m,
    output logic [`DATA_WIDTH-1:0] o_rs2_data_m,
    output logic [`REG_ADDR_WIDTH-1:0] o_rd_addr_m,
    output logic [`DATA_WIDTH-1:0] o_pc_plus_4_m,
    output logic [2:0] o_funct3_m,

    // Outputs that affect PC
    output logic       o_pc_src_e,
    output logic [`DATA_WIDTH-1:0] o_pc_target_addr_e
);

    // Instantiate Execute stage
    execute u_execute (
        .clk            (clk), // clk/rst_n not used by execute.sv currently, but good to have for future
        .rst_n          (rst_n),

        .reg_write_e_i  (i_reg_write_e),
        .result_src_e_i (i_result_src_e),
        .mem_write_e_i  (i_mem_write_e),
        .jump_e_i       (i_jump_e),
        .branch_e_i     (i_branch_e),
        .alu_src_e_i    (i_alu_src_e),
        .alu_control_e_i(i_alu_control_e),
        .funct3_e_i     (i_funct3_e),
        .op_a_sel_e_i   (i_op_a_sel_e),
        .pc_target_src_sel_e_i (i_pc_target_src_sel_e),
        .pc_e_i         (i_pc_e),
        .pc_plus_4_e_i  (i_pc_plus_4_e),
        .rs1_data_e_i   (i_rs1_data_e),
        .rs2_data_e_i   (i_rs2_data_e),
        .imm_ext_e_i    (i_imm_ext_e),
        .rd_addr_e_i    (i_rd_addr_e),

        .reg_write_m_o  (o_reg_write_m),
        .result_src_m_o (o_result_src_m),
        .mem_write_m_o  (o_mem_write_m),
        .alu_result_m_o (o_alu_result_m),
        .rs2_data_m_o   (o_rs2_data_m),
        .rd_addr_m_o    (o_rd_addr_m),
        .pc_plus_4_m_o  (o_pc_plus_4_m),
        .funct3_m_o     (o_funct3_m),
        .pc_src_e_o     (o_pc_src_e),
        .pc_target_addr_e_o (o_pc_target_addr_e)
    );

endmodule