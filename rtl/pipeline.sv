// rtl/pipeline.sv
`default_nettype none
`timescale 1ns/1ps

`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/control_signals_defines.svh"
// `include "common/immediate_types.svh" // Not directly needed at top level, submodules use it
// `include "common/riscv_opcodes.svh"  // Not directly needed at top level

module pipeline (
    input  logic clk,
    input  logic rst_n,

    // Outputs for observing/testing (optional)
    output logic [`DATA_WIDTH-1:0] current_pc_debug, // Current PC from Fetch stage
    output logic [`INSTR_WIDTH-1:0] fetched_instr_debug // Instruction fetched
);

    // Signals between Fetch and IF/ID Register
    logic [`INSTR_WIDTH-1:0]    instr_f;
    logic [`DATA_WIDTH-1:0]     pc_f;
    logic [`DATA_WIDTH-1:0]     pc_plus_4_f;

    // Signals between IF/ID Register and Decode Stage
    logic [`INSTR_WIDTH-1:0]    instr_id;
    logic [`DATA_WIDTH-1:0]     pc_id;
    logic [`DATA_WIDTH-1:0]     pc_plus_4_id;

    // Signals between Decode Stage and ID/EX Register
    logic       reg_write_d;
    logic [1:0] result_src_d;
    logic       mem_write_d;
    logic       jump_d;
    logic       branch_d;
    logic       alu_src_d;
    logic [`ALU_CONTROL_WIDTH-1:0] alu_control_d;
    logic [2:0] funct3_d;
    alu_a_src_sel_e op_a_sel_d;
    pc_target_src_sel_e pc_target_src_sel_d;
    logic [`DATA_WIDTH-1:0]  rs1_data_d;
    logic [`DATA_WIDTH-1:0]  rs2_data_d;
    logic [`DATA_WIDTH-1:0]  imm_ext_d;
    logic [`REG_ADDR_WIDTH-1:0] rs1_addr_d; // To Hazard Unit
    logic [`REG_ADDR_WIDTH-1:0] rs2_addr_d; // To Hazard Unit
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_d;  // To ID/EX

    // Signals between ID/EX Register and Execute Stage
    logic       reg_write_e;
    logic [1:0] result_src_e;
    logic       mem_write_e;
    logic       jump_e;
    logic       branch_e;
    logic       alu_src_e;
    logic [`ALU_CONTROL_WIDTH-1:0] alu_control_e;
    logic [2:0] funct3_e;
    alu_a_src_sel_e op_a_sel_e;
    pc_target_src_sel_e pc_target_src_sel_e;
    logic [`DATA_WIDTH-1:0]  pc_e;
    logic [`DATA_WIDTH-1:0]  pc_plus_4_e;
    logic [`DATA_WIDTH-1:0]  rs1_data_e;
    logic [`DATA_WIDTH-1:0]  rs2_data_e;
    logic [`DATA_WIDTH-1:0]  imm_ext_e;
    logic [`REG_ADDR_WIDTH-1:0] rs1_addr_e; // From ID/EX for Hazard Unit
    logic [`REG_ADDR_WIDTH-1:0] rs2_addr_e; // From ID/EX for Hazard Unit
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_e;  // To Hazard Unit & EX/MEM

    // Signals from Execute Stage (to Hazard Unit & EX/MEM Register)
    logic       pc_src_from_ex;          // Output from Execute, PCSrcE on diagram
    logic [`DATA_WIDTH-1:0] pc_target_addr_from_ex; // Output from Execute, PCTargetE on diagram

    // Signals between Execute Stage and EX/MEM Register
    logic       reg_write_m_ex_out;      // RegWriteM from Execute
    logic [1:0] result_src_m_ex_out;   // ResultSrcM from Execute
    logic       mem_write_m_ex_out;      // MemWriteM from Execute
    logic [`DATA_WIDTH-1:0] alu_result_m_ex_out; // ALUResultM from Execute
    logic [`DATA_WIDTH-1:0] rs2_data_m_ex_out;   // WriteDataM from Execute (original rs2 data)
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_m_ex_out;    // RdM from Execute
    logic [`DATA_WIDTH-1:0] pc_plus_4_m_ex_out;  // PCPlus4M from Execute
    logic [2:0] funct3_m_ex_out;         // Funct3 from Execute

    // Signals between EX/MEM Register and Memory Stage
    logic       reg_write_m;
    logic [1:0] result_src_m;
    logic       mem_write_m;
    logic [`DATA_WIDTH-1:0] alu_result_m;
    logic [`DATA_WIDTH-1:0] rs2_data_m;
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_m;  // To Hazard Unit & MEM/WB
    logic [`DATA_WIDTH-1:0] pc_plus_4_m;
    logic [2:0] funct3_m;

    // Signals between Memory Stage and MEM/WB Register
    logic       reg_write_w_mem_out;
    logic [1:0] result_src_w_mem_out;
    logic [`DATA_WIDTH-1:0] read_data_w_mem_out;
    logic [`DATA_WIDTH-1:0] alu_result_w_mem_out;
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_w_mem_out;
    logic [`DATA_WIDTH-1:0] pc_plus_4_w_mem_out;

    // Signals between MEM/WB Register and Writeback Stage
    logic       reg_write_wb;
    logic [1:0] result_src_wb;
    logic [`DATA_WIDTH-1:0] read_data_wb;
    logic [`DATA_WIDTH-1:0] alu_result_wb;
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_wb;  // To Hazard Unit
    logic [`DATA_WIDTH-1:0] pc_plus_4_wb;

    // Signal from Writeback stage to Register File
    logic [`DATA_WIDTH-1:0] result_w;      // ResultW on diagram

    // Hazard Unit Control Signals
    logic stall_f;
    logic stall_d;
    logic flush_d;
    logic flush_e;
    logic [1:0] forward_a_e;
    logic [1:0] forward_b_e;

    // Assign debug outputs
    assign current_pc_debug = pc_f;
    assign fetched_instr_debug = instr_f;

    logic [`DATA_WIDTH-1:0] data_from_mem_stage_for_fwd;
    assign data_from_mem_stage_for_fwd = (result_src_m == 2'b01) ? read_data_w_mem_out : alu_result_m;

    // Instantiate Pipeline Stages and Registers

    // FETCH STAGE
    fetch u_fetch (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall_f        (stall_f),          // From Hazard Unit
        .pc_src_e       (pc_src_from_ex),   // From Execute Stage
        .pc_target_e    (pc_target_addr_from_ex), // From Execute Stage
        .instr_f_o      (instr_f),
        .pc_f_o         (pc_f),
        .pc_plus_4_f_o  (pc_plus_4_f)
    );

    // IF/ID REGISTER
    if_id_register u_if_id_register (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall_d        (stall_d),          // From Hazard Unit
        .flush_d        (flush_d),          // From Hazard Unit
        .instr_f_i      (instr_f),
        .pc_f_i         (pc_f),
        .pc_plus_4_f_i  (pc_plus_4_f),
        .instr_id_o     (instr_id),
        .pc_id_o        (pc_id),
        .pc_plus_4_id_o (pc_plus_4_id)
    );

    // DECODE STAGE
    // Register file write port is connected from MEM/WB register outputs
    decode u_decode (
        .clk                (clk),
        .rst_n              (rst_n),
        .instr_id_i         (instr_id),
        .pc_id_i            (pc_id),
        .pc_plus_4_id_i     (pc_plus_4_id),
        .rd_write_en_wb_i   (reg_write_wb),     // From MEM/WB (final write enable)
        .rd_addr_wb_i       (rd_addr_wb),       // From MEM/WB (final rd address)
        .rd_data_wb_i       (result_w),         // From Writeback MUX (final data to write)
        .reg_write_d_o      (reg_write_d),
        .result_src_d_o     (result_src_d),
        .mem_write_d_o      (mem_write_d),
        .jump_d_o           (jump_d),
        .branch_d_o         (branch_d),
        .alu_src_d_o        (alu_src_d),
        .alu_control_d_o    (alu_control_d),
        .funct3_d_o         (funct3_d),
        .op_a_sel_d_o       (op_a_sel_d),
        .pc_target_src_sel_d_o (pc_target_src_sel_d),
        .pc_d_o             (pc_id),            // pc_d_o is just pc_id_i passed through
        .pc_plus_4_d_o      (pc_plus_4_id),     // pc_plus_4_d_o is just pc_plus_4_id_i passed through
        .rs1_data_d_o       (rs1_data_d),
        .rs2_data_d_o       (rs2_data_d),
        .imm_ext_d_o        (imm_ext_d),
        .rs1_addr_d_o       (rs1_addr_d),
        .rs2_addr_d_o       (rs2_addr_d),
        .rd_addr_d_o        (rd_addr_d)
    );

    // ID/EX REGISTER
    id_ex_register u_id_ex_register (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall_e        (1'b0),             // stall_e not used per P&H diagram if forwarding handles all, else from HU
        .flush_e        (flush_e),          // From Hazard Unit
        .reg_write_d_i  (reg_write_d),
        .result_src_d_i (result_src_d),
        .mem_write_d_i  (mem_write_d),
        .jump_d_i       (jump_d),
        .branch_d_i     (branch_d),
        .alu_src_d_i    (alu_src_d),
        .alu_control_d_i(alu_control_d),
        .funct3_d_i     (funct3_d),
        .op_a_sel_d_i   (op_a_sel_d),
        .pc_target_src_sel_d_i (pc_target_src_sel_d),
        .pc_d_i         (pc_id),            // pc_d_i from Decode (which is pc_id)
        .pc_plus_4_d_i  (pc_plus_4_id),
        .rs1_data_d_i   (rs1_data_d),
        .rs2_data_d_i   (rs2_data_d),
        .imm_ext_d_i    (imm_ext_d),
        .rs1_addr_d_i   (rs1_addr_d),       // Pass Rs1 Addr
        .rs2_addr_d_i   (rs2_addr_d),       // Pass Rs2 Addr
        .rd_addr_d_i    (rd_addr_d),
        .reg_write_e_o  (reg_write_e),
        .result_src_e_o (result_src_e),
        .mem_write_e_o  (mem_write_e),
        .jump_e_o       (jump_e),
        .branch_e_o     (branch_e),
        .alu_src_e_o    (alu_src_e),
        .alu_control_e_o(alu_control_e),
        .funct3_e_o     (funct3_e),
        .op_a_sel_e_o   (op_a_sel_e),
        .pc_target_src_sel_e_o (pc_target_src_sel_e),
        .pc_e_o         (pc_e),
        .pc_plus_4_e_o  (pc_plus_4_e),
        .rs1_data_e_o   (rs1_data_e),
        .rs2_data_e_o   (rs2_data_e),
        .imm_ext_e_o    (imm_ext_e),
        .rs1_addr_e_o   (rs1_addr_e),
        .rs2_addr_e_o   (rs2_addr_e),
        .rd_addr_e_o    (rd_addr_e)
    );

    // EXECUTE STAGE
    execute u_execute (
        .reg_write_e_i  (reg_write_e),
        .result_src_e_i (result_src_e),
        .mem_write_e_i  (mem_write_e),
        .jump_e_i       (jump_e),
        .branch_e_i     (branch_e),
        .alu_src_e_i    (alu_src_e),
        .alu_control_e_i(alu_control_e),
        .funct3_e_i     (funct3_e),
        .op_a_sel_e_i   (op_a_sel_e),
        .pc_target_src_sel_e_i (pc_target_src_sel_e),
        .pc_e_i         (pc_e),
        .pc_plus_4_e_i  (pc_plus_4_e),
        .rs1_data_e_i   (rs1_data_e),
        .rs2_data_e_i   (rs2_data_e),
        .imm_ext_e_i    (imm_ext_e),
        .rd_addr_e_i    (rd_addr_e),
        .forward_data_mem_i (data_from_mem_stage_for_fwd),
        .forward_data_wb_i  (result_w),         // Data from WB output (ResultW)
        .forward_a_e_i  (forward_a_e),      // From Hazard Unit
        .forward_b_e_i  (forward_b_e),      // From Hazard Unit
        .reg_write_m_o  (reg_write_m_ex_out),
        .result_src_m_o (result_src_m_ex_out),
        .mem_write_m_o  (mem_write_m_ex_out),
        .alu_result_m_o (alu_result_m_ex_out),
        .rs2_data_m_o   (rs2_data_m_ex_out),
        .rd_addr_m_o    (rd_addr_m_ex_out),
        .pc_plus_4_m_o  (pc_plus_4_m_ex_out),
        .funct3_m_o     (funct3_m_ex_out),
        .pc_src_e_o     (pc_src_from_ex),
        .pc_target_addr_e_o (pc_target_addr_from_ex)
    );

    // EX/MEM REGISTER
    ex_mem_register u_ex_mem_register (
        .clk            (clk),
        .rst_n          (rst_n),
        .reg_write_e_i  (reg_write_m_ex_out),
        .result_src_e_i (result_src_m_ex_out),
        .mem_write_e_i  (mem_write_m_ex_out),
        .alu_result_e_i (alu_result_m_ex_out),
        .rs2_data_e_i   (rs2_data_m_ex_out),
        .rd_addr_e_i    (rd_addr_m_ex_out),
        .pc_plus_4_e_i  (pc_plus_4_m_ex_out),
        .funct3_e_i     (funct3_m_ex_out),
        .reg_write_m_o  (reg_write_m),
        .result_src_m_o (result_src_m),
        .mem_write_m_o  (mem_write_m),
        .alu_result_m_o (alu_result_m),
        .rs2_data_m_o   (rs2_data_m),
        .rd_addr_m_o    (rd_addr_m),
        .pc_plus_4_m_o  (pc_plus_4_m),
        .funct3_m_o     (funct3_m)
    );

    // MEMORY STAGE
    memory_stage u_memory_stage (
        .clk            (clk),
        .rst_n          (rst_n),
        .reg_write_m_i  (reg_write_m),
        .result_src_m_i (result_src_m),
        .mem_write_m_i  (mem_write_m),
        .funct3_m_i     (funct3_m),
        .alu_result_m_i (alu_result_m),
        .rs2_data_m_i   (rs2_data_m),
        .rd_addr_m_i    (rd_addr_m),
        .pc_plus_4_m_i  (pc_plus_4_m),
        .reg_write_w_o  (reg_write_w_mem_out),
        .result_src_w_o (result_src_w_mem_out),
        .read_data_w_o  (read_data_w_mem_out),
        .alu_result_w_o (alu_result_w_mem_out), // Pass ALU result through
        .rd_addr_w_o    (rd_addr_w_mem_out),
        .pc_plus_4_w_o  (pc_plus_4_w_mem_out)
    );

    // MEM/WB REGISTER
    mem_wb_register u_mem_wb_register (
        .clk            (clk),
        .rst_n          (rst_n),
        .reg_write_m_i  (reg_write_w_mem_out),
        .result_src_m_i (result_src_w_mem_out),
        .read_data_m_i  (read_data_w_mem_out),
        .alu_result_m_i (alu_result_w_mem_out),
        .rd_addr_m_i    (rd_addr_w_mem_out),
        .pc_plus_4_m_i  (pc_plus_4_w_mem_out),
        .reg_write_wb_o (reg_write_wb),
        .result_src_wb_o(result_src_wb),
        .read_data_wb_o (read_data_wb),
        .alu_result_wb_o(alu_result_wb),
        .rd_addr_wb_o   (rd_addr_wb),
        .pc_plus_4_wb_o (pc_plus_4_wb)
    );

    // WRITEBACK STAGE
    writeback_stage u_writeback_stage (
        .result_src_wb_i (result_src_wb),
        .read_data_wb_i  (read_data_wb),
        .alu_result_wb_i (alu_result_wb),
        .pc_plus_4_wb_i  (pc_plus_4_wb),
        .result_w_o      (result_w)
    );

    // HAZARD UNIT (Pipeline Control)
    pipeline_control u_pipeline_control (
        .rs1_addr_d_i   (rs1_addr_d),    // Rs1D from Decode
        .rs2_addr_d_i   (rs2_addr_d),    // Rs2D from Decode

        .rd_addr_e_i    (rd_addr_e),     // RdE from ID/EX output
        .reg_write_e_i  (reg_write_e),   // RegWriteE from ID/EX output
        .result_src_e_i (result_src_e),  // ResultSrcE from ID/EX output (for load detection)

        .rd_addr_m_i    (rd_addr_m),     // RdM from EX/MEM output
        .reg_write_m_i  (reg_write_m),   // RegWriteM from EX/MEM output

        .rd_addr_w_i    (rd_addr_wb),    // RdW from MEM/WB output
        .reg_write_w_i  (reg_write_wb),  // RegWriteW from MEM/WB output

        .pc_src_e_i     (pc_src_from_ex), // PCSrcE from Execute stage output

        .stall_f_o      (stall_f),
        .stall_d_o      (stall_d),
        .flush_d_o      (flush_d),
        .flush_e_o      (flush_e),
        .forward_a_e_o  (forward_a_e),
        .forward_b_e_o  (forward_b_e)
    );

endmodule