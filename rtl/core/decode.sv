// rtl/core/decode.sv
`include "common/defines.svh"
`include "common/immediate_types.svh"
`include "common/alu_defines.svh" // For ALU_CONTROL_WIDTH
`include "common/control_signals_defines.svh"

module decode (
    // Inputs from IF/ID Register
    input  logic [`INSTR_WIDTH-1:0] instr_id_i,
    input  logic [`DATA_WIDTH-1:0]  pc_id_i,
    input  logic [`DATA_WIDTH-1:0]  pc_plus_4_id_i,

    // Inputs from Writeback Stage (for register file write)
    input  logic                       rd_write_en_wb_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_wb_i,
    input  logic [`DATA_WIDTH-1:0]     rd_data_wb_i,

    // Clock and Reset
    input  logic clk,
    input  logic rst_n,

    // Outputs to ID/EX Register
    // Control Signals
    output logic       reg_write_d_o,
    output logic [1:0] result_src_d_o,
    output logic       mem_write_d_o,
    output logic       jump_d_o,
    output logic       branch_d_o,
    output logic       alu_src_d_o,
    output logic [`ALU_CONTROL_WIDTH-1:0] alu_control_d_o, // Unified ALU control
    output logic [2:0] funct3_d_o,
    output alu_a_src_sel_e op_a_sel_d_o,
    output pc_target_src_sel_e pc_target_src_sel_d_o,

    // Data
    output logic [`DATA_WIDTH-1:0]  pc_d_o,
    output logic [`DATA_WIDTH-1:0]  pc_plus_4_d_o,
    output logic [`DATA_WIDTH-1:0]  rs1_data_d_o,
    output logic [`DATA_WIDTH-1:0]  rs2_data_d_o,
    output logic [`DATA_WIDTH-1:0]  imm_ext_d_o,

    // Register addresses (for hazard unit)
    output logic [`REG_ADDR_WIDTH-1:0] rs1_addr_d_o,
    output logic [`REG_ADDR_WIDTH-1:0] rs2_addr_d_o,
    output logic [`REG_ADDR_WIDTH-1:0] rd_addr_d_o
);

    // Instruction fields
    logic [6:0] opcode;
    logic [`REG_ADDR_WIDTH-1:0] rs1_addr_instr;
    logic [`REG_ADDR_WIDTH-1:0] rs2_addr_instr;
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_instr;
    logic [2:0] funct3;
    logic       funct7_5;

    // Intermediate signals
    immediate_type_e imm_type_sel_internal;

    // Decompose instruction
    assign opcode         = instr_id_i[6:0];
    assign rd_addr_instr  = instr_id_i[11:7];
    assign funct3         = instr_id_i[14:12];
    assign rs1_addr_instr = instr_id_i[19:15];
    assign rs2_addr_instr = instr_id_i[24:20];
    assign funct7_5       = instr_id_i[30]; // Bit 5 of funct7

    // Control Unit instance
    control_unit u_control_unit (
        .op                (opcode),
        .funct3            (funct3),
        .funct7_5          (funct7_5),

        .reg_write_d_o     (reg_write_d_o),
        .result_src_d_o    (result_src_d_o),
        .mem_write_d_o     (mem_write_d_o),
        .jump_d_o          (jump_d_o),
        .branch_d_o        (branch_d_o),
        .alu_src_d_o       (alu_src_d_o),
        .alu_control_d_o   (alu_control_d_o), // Now unified
        .imm_type_d_o      (imm_type_sel_internal),
        .funct3_d_o        (funct3_d_o), // Connect to new output from CU
        .op_a_sel_d_o      (op_a_sel_d_o),
        .pc_target_src_sel_d_o (pc_target_src_sel_d_o)
    );

    // Register File instance
    register_file u_register_file (
        .clk               (clk),
        .rst_n             (rst_n),
        .rs1_addr_i        (rs1_addr_instr),
        .rs1_data_o        (rs1_data_d_o),
        .rs2_addr_i        (rs2_addr_instr),
        .rs2_data_o        (rs2_data_d_o),
        .rd_write_en_wb_i  (rd_write_en_wb_i),
        .rd_addr_wb_i      (rd_addr_wb_i),
        .rd_data_wb_i      (rd_data_wb_i)
    );

    // Immediate Generator instance
    immediate_generator u_immediate_generator (
        .instr_i           (instr_id_i),
        .imm_type_sel_i    (imm_type_sel_internal),
        .imm_ext_o         (imm_ext_d_o)
    );

    // Pass through PC values
    assign pc_d_o        = pc_id_i;
    assign pc_plus_4_d_o = pc_plus_4_id_i;

    // Pass through register addresses for hazard detection and forwarding
    assign rs1_addr_d_o  = rs1_addr_instr;
    assign rs2_addr_d_o  = rs2_addr_instr;
    assign rd_addr_d_o   = rd_addr_instr;

endmodule