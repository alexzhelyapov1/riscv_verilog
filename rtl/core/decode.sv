`include "common/pipeline_types.svh"
`include "common/riscv_opcodes.svh"

module decode (
    input  logic clk,
    input  logic rst_n,
    input  if_id_data_t     if_id_data_i,
    input  rf_write_data_t  writeback_data_i,

    output id_ex_data_t     id_ex_data_o,
    output logic [`REG_ADDR_WIDTH-1:0] rs1_addr_d_o,
    output logic [`REG_ADDR_WIDTH-1:0] rs2_addr_d_o
);

    logic [6:0] opcode;
    logic [`REG_ADDR_WIDTH-1:0] rs1_addr_instr;
    logic [`REG_ADDR_WIDTH-1:0] rs2_addr_instr;
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_instr;
    logic [2:0] funct3_instr;
    logic       funct7_5_instr;

    immediate_type_e imm_type_sel_internal;
    logic [`DATA_WIDTH-1:0] rs1_data_from_rf;
    logic [`DATA_WIDTH-1:0] rs2_data_from_rf;
    logic [`DATA_WIDTH-1:0] imm_ext_internal;

    assign opcode         = if_id_data_i.instr[6:0];
    assign rd_addr_instr  = if_id_data_i.instr[11:7];
    assign funct3_instr   = if_id_data_i.instr[14:12];
    assign rs1_addr_instr = if_id_data_i.instr[19:15];
    assign rs2_addr_instr = if_id_data_i.instr[24:20];
    assign funct7_5_instr = if_id_data_i.instr[30];

    control_unit u_control_unit (
        .op                    (opcode),
        .funct3                (funct3_instr),
        .funct7_5              (funct7_5_instr),
        .reg_write_d_o         (id_ex_data_o.reg_write),
        .result_src_d_o        (id_ex_data_o.result_src),
        .mem_write_d_o         (id_ex_data_o.mem_write),
        .jump_d_o              (id_ex_data_o.jump),
        .branch_d_o            (id_ex_data_o.branch),
        .alu_src_d_o           (id_ex_data_o.alu_src),
        .alu_control_d_o       (id_ex_data_o.alu_control),
        .imm_type_d_o          (imm_type_sel_internal),
        .funct3_d_o            (id_ex_data_o.funct3),
        .op_a_sel_d_o          (id_ex_data_o.op_a_sel),
        .pc_target_src_sel_d_o (id_ex_data_o.pc_target_src_sel)
    );

    register_file u_register_file (
        .clk               (clk),
        .rst_n             (rst_n),
        .rs1_addr_i        (rs1_addr_instr),
        .rs1_data_o        (rs1_data_from_rf),
        .rs2_addr_i        (rs2_addr_instr),
        .rs2_data_o        (rs2_data_from_rf),
        .rd_write_en_wb_i  (writeback_data_i.reg_write_en),
        .rd_addr_wb_i      (writeback_data_i.rd_addr),
        .rd_data_wb_i      (writeback_data_i.result_to_rf)
    );

    immediate_generator u_immediate_generator (
        .instr_i           (if_id_data_i.instr),
        .imm_type_sel_i    (imm_type_sel_internal),
        .imm_ext_o         (imm_ext_internal)
    );

    assign id_ex_data_o.pc         = if_id_data_i.pc;
    assign id_ex_data_o.pc_plus_4  = if_id_data_i.pc_plus_4;
    assign id_ex_data_o.rs1_data   = rs1_data_from_rf;
    assign id_ex_data_o.rs2_data   = rs2_data_from_rf;
    assign id_ex_data_o.imm_ext    = imm_ext_internal;
    assign id_ex_data_o.rs1_addr   = rs1_addr_instr;
    assign id_ex_data_o.rs2_addr   = rs2_addr_instr;
    assign id_ex_data_o.rd_addr    = rd_addr_instr;
    assign rs1_addr_d_o = rs1_addr_instr;
    assign rs2_addr_d_o = rs2_addr_instr;

endmodule