// tests/unit/decode_tb.sv
`include "common/defines.svh"
`include "common/alu_defines.svh"          // For ALU_CONTROL_WIDTH
`include "common/control_signals_defines.svh" // For alu_a_src_sel_e, pc_target_src_sel_e

module decode_tb (
    input  logic clk,
    input  logic rst_n,

    // Inputs to control the test environment
    // To IF/ID register
    input  logic                       i_if_id_stall_d, // Stall for if_id register
    input  logic                       i_if_id_flush_d, // Flush for if_id register
    input  logic [`INSTR_WIDTH-1:0]    i_instr_f,       // Instruction from a virtual "fetch"
    input  logic [`DATA_WIDTH-1:0]     i_pc_f,          // PC from a virtual "fetch"
    input  logic [`DATA_WIDTH-1:0]     i_pc_plus_4_f,   // PC+4 from a virtual "fetch"

    // To Register File (for initialization during test, and Writeback simulation)
    input  logic                       i_wb_write_en,
    input  logic [`REG_ADDR_WIDTH-1:0] i_wb_rd_addr,
    input  logic [`DATA_WIDTH-1:0]     i_wb_rd_data,

    // Outputs from Decode stage (to observe)
    // Control Signals
    output logic       o_reg_write_d,
    output logic [1:0] o_result_src_d,
    output logic       o_mem_write_d,
    output logic       o_jump_d,
    output logic       o_branch_d,
    output logic       o_alu_src_d, // Selects ALU Operand B
    output logic [`ALU_CONTROL_WIDTH-1:0] o_alu_control_d,
    output logic [2:0] o_funct3_d,
    output alu_a_src_sel_e o_op_a_sel_d,
    output pc_target_src_sel_e o_pc_target_src_sel_d,

    // Data
    output logic [`DATA_WIDTH-1:0]  o_pc_d,
    output logic [`DATA_WIDTH-1:0]  o_pc_plus_4_d,
    output logic [`DATA_WIDTH-1:0]  o_rs1_data_d,
    output logic [`DATA_WIDTH-1:0]  o_rs2_data_d,
    output logic [`DATA_WIDTH-1:0]  o_imm_ext_d,

    // Register addresses
    output logic [`REG_ADDR_WIDTH-1:0] o_rs1_addr_d,
    output logic [`REG_ADDR_WIDTH-1:0] o_rs2_addr_d,
    output logic [`REG_ADDR_WIDTH-1:0] o_rd_addr_d,

    // Output from IF/ID for sanity check
    output logic [`INSTR_WIDTH-1:0]    o_instr_id,
    output logic [`DATA_WIDTH-1:0]     o_pc_id,
    output logic [`DATA_WIDTH-1:0]     o_pc_plus_4_id
);

    // Signals between IF/ID and Decode
    logic [`INSTR_WIDTH-1:0]    instr_id_val;
    logic [`DATA_WIDTH-1:0]     pc_id_val;
    logic [`DATA_WIDTH-1:0]     pc_plus_4_id_val;

    // IF/ID Register instance
    if_id_register u_if_id_reg (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall_d        (i_if_id_stall_d),
        .flush_d        (i_if_id_flush_d),
        .instr_f_i      (i_instr_f),
        .pc_f_i         (i_pc_f),
        .pc_plus_4_f_i  (i_pc_plus_4_f),
        .instr_id_o     (instr_id_val),
        .pc_id_o        (pc_id_val),
        .pc_plus_4_id_o (pc_plus_4_id_val)
    );

    // Decode Stage instance
    decode u_decode (
        .clk                (clk),
        .rst_n              (rst_n),
        .instr_id_i         (instr_id_val),
        .pc_id_i            (pc_id_val),
        .pc_plus_4_id_i     (pc_plus_4_id_val),
        .rd_write_en_wb_i   (i_wb_write_en),
        .rd_addr_wb_i       (i_wb_rd_addr),
        .rd_data_wb_i       (i_wb_rd_data),

        .reg_write_d_o      (o_reg_write_d),
        .result_src_d_o     (o_result_src_d),
        .mem_write_d_o      (o_mem_write_d),
        .jump_d_o           (o_jump_d),
        .branch_d_o         (o_branch_d),
        .alu_src_d_o        (o_alu_src_d),
        .alu_control_d_o    (o_alu_control_d),
        .funct3_d_o         (o_funct3_d),
        .op_a_sel_d_o       (o_op_a_sel_d),
        .pc_target_src_sel_d_o (o_pc_target_src_sel_d),

        .pc_d_o             (o_pc_d),
        .pc_plus_4_d_o      (o_pc_plus_4_d),
        .rs1_data_d_o       (o_rs1_data_d),
        .rs2_data_d_o       (o_rs2_data_d),
        .imm_ext_d_o        (o_imm_ext_d),
        .rs1_addr_d_o       (o_rs1_addr_d),
        .rs2_addr_d_o       (o_rs2_addr_d),
        .rd_addr_d_o        (o_rd_addr_d)
    );

    // Assign IF/ID outputs for observation
    assign o_instr_id     = instr_id_val;
    assign o_pc_id        = pc_id_val;
    assign o_pc_plus_4_id = pc_plus_4_id_val;

endmodule