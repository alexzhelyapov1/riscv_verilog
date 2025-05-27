`include "common/defines.svh"

module pipeline_control_tb (
    // Inputs to pipeline_control
    input  logic [`REG_ADDR_WIDTH-1:0] i_rs1_addr_d,
    input  logic [`REG_ADDR_WIDTH-1:0] i_rs2_addr_d,
    input  logic [`REG_ADDR_WIDTH-1:0] i_rd_addr_e,
    input  logic                       i_reg_write_e,
    input  logic [1:0]                 i_result_src_e,
    input  logic [`REG_ADDR_WIDTH-1:0] i_rd_addr_m,
    input  logic                       i_reg_write_m,
    input  logic [`REG_ADDR_WIDTH-1:0] i_rd_addr_w,
    input  logic                       i_reg_write_w,
    input  logic                       i_pc_src_e,

    // Outputs from pipeline_control
    output logic                       o_stall_f,
    output logic                       o_stall_d,
    output logic                       o_flush_d,
    output logic                       o_flush_e,
    output logic [1:0]                 o_forward_a_e,
    output logic [1:0]                 o_forward_b_e
);

    pipeline_control u_pipeline_control (
        .rs1_addr_d_i   (i_rs1_addr_d),
        .rs2_addr_d_i   (i_rs2_addr_d),
        .rd_addr_e_i    (i_rd_addr_e),
        .reg_write_e_i  (i_reg_write_e),
        .result_src_e_i (i_result_src_e),
        .rd_addr_m_i    (i_rd_addr_m),
        .reg_write_m_i  (i_reg_write_m),
        .rd_addr_w_i    (i_rd_addr_w),
        .reg_write_w_i  (i_reg_write_w),
        .pc_src_e_i     (i_pc_src_e),
        .stall_f_o      (o_stall_f),
        .stall_d_o      (o_stall_d),
        .flush_d_o      (o_flush_d),
        .flush_e_o      (o_flush_e),
        .forward_a_e_o  (o_forward_a_e),
        .forward_b_e_o  (o_forward_b_e)
    );

endmodule