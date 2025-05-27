// rtl/pipeline.sv
`default_nettype none
`timescale 1ns/1ps

`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/control_signals_defines.svh"

module pipeline (
    input  logic clk,
    input  logic rst_n,

    output logic [`DATA_WIDTH-1:0] current_pc_debug,
    output logic [`INSTR_WIDTH-1:0] fetched_instr_debug
);

    // --- Signal Declarations ---
    // Fetch <-> IF/ID
    logic [`INSTR_WIDTH-1:0]    instr_f_to_ifid;
    logic [`DATA_WIDTH-1:0]     pc_f_to_ifid;
    logic [`DATA_WIDTH-1:0]     pc_plus_4_f_to_ifid;

    // IF/ID <-> Decode
    logic [`INSTR_WIDTH-1:0]    instr_ifid_to_d;
    logic [`DATA_WIDTH-1:0]     pc_ifid_to_d;
    logic [`DATA_WIDTH-1:0]     pc_plus_4_ifid_to_d;

    // Decode <-> ID/EX
    logic       reg_write_d_to_idex;
    logic [1:0] result_src_d_to_idex;
    logic       mem_write_d_to_idex;
    logic       jump_d_to_idex;
    logic       branch_d_to_idex;
    logic       alu_src_d_to_idex; // OpB sel
    logic [`ALU_CONTROL_WIDTH-1:0] alu_control_d_to_idex;
    logic [2:0] funct3_d_to_idex;
    alu_a_src_sel_e op_a_sel_d_to_idex;         // Corrected: Signal name different from type
    pc_target_src_sel_e pc_target_src_sel_d_to_idex; // Corrected
    logic [`DATA_WIDTH-1:0]  rs1_data_d_to_idex;
    logic [`DATA_WIDTH-1:0]  rs2_data_d_to_idex;
    logic [`DATA_WIDTH-1:0]  imm_ext_d_to_idex;
    logic [`REG_ADDR_WIDTH-1:0] rs1_addr_d_for_hu; // To Hazard Unit from Decode output
    logic [`REG_ADDR_WIDTH-1:0] rs2_addr_d_for_hu; // To Hazard Unit from Decode output
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_d_to_idex;

    // ID/EX <-> Execute
    logic       reg_write_idex_to_ex;
    logic [1:0] result_src_idex_to_ex;
    logic       mem_write_idex_to_ex;
    logic       jump_idex_to_ex;
    logic       branch_idex_to_ex;
    logic       alu_src_idex_to_ex;
    logic [`ALU_CONTROL_WIDTH-1:0] alu_control_idex_to_ex;
    logic [2:0] funct3_idex_to_ex;
    alu_a_src_sel_e op_a_sel_idex_to_ex;         // Corrected
    pc_target_src_sel_e pc_target_src_sel_idex_to_ex; // Corrected
    logic [`DATA_WIDTH-1:0]  pc_idex_to_ex;
    logic [`DATA_WIDTH-1:0]  pc_plus_4_idex_to_ex;
    logic [`DATA_WIDTH-1:0]  rs1_data_idex_to_ex;
    logic [`DATA_WIDTH-1:0]  rs2_data_idex_to_ex;
    logic [`DATA_WIDTH-1:0]  imm_ext_idex_to_ex;
    // logic [`REG_ADDR_WIDTH-1:0] rs1_addr_idex_to_ex; // Not directly used by EX, but HU needs ID/EX's rd_addr
    // logic [`REG_ADDR_WIDTH-1:0] rs2_addr_idex_to_ex;
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_idex_to_ex;  // RdE for Hazard Unit

    // Execute -> PC Update Logic & EX/MEM
    logic       pc_src_ex_to_fetch;
    logic [`DATA_WIDTH-1:0] pc_target_ex_to_fetch;
    logic       reg_write_ex_to_exmem;
    logic [1:0] result_src_ex_to_exmem;
    logic       mem_write_ex_to_exmem;
    logic [`DATA_WIDTH-1:0] alu_result_ex_to_exmem;
    logic [`DATA_WIDTH-1:0] rs2_data_ex_to_exmem; // Original rs2_data from ID/EX
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_ex_to_exmem;
    logic [`DATA_WIDTH-1:0] pc_plus_4_ex_to_exmem;
    logic [2:0] funct3_ex_to_exmem;

    // EX/MEM <-> Memory Stage
    logic       reg_write_exmem_to_mem;
    logic [1:0] result_src_exmem_to_mem;
    logic       mem_write_exmem_to_mem;
    logic [`DATA_WIDTH-1:0] alu_result_exmem_to_mem;
    logic [`DATA_WIDTH-1:0] rs2_data_exmem_to_mem;
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_exmem_to_mem; // RdM for Hazard Unit
    logic [`DATA_WIDTH-1:0] pc_plus_4_exmem_to_mem;
    logic [2:0] funct3_exmem_to_mem;

    // Memory Stage <-> MEM/WB
    logic       reg_write_mem_to_memwb;
    logic [1:0] result_src_mem_to_memwb;
    logic [`DATA_WIDTH-1:0] read_data_mem_to_memwb;
    logic [`DATA_WIDTH-1:0] alu_result_mem_to_memwb; // ALU result passed through MEM
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_mem_to_memwb;
    logic [`DATA_WIDTH-1:0] pc_plus_4_mem_to_memwb;

    // MEM/WB <-> Writeback Stage / RF
    logic       reg_write_memwb_to_wb; // RegWriteW for Hazard Unit & RF
    logic [1:0] result_src_memwb_to_wb;
    logic [`DATA_WIDTH-1:0] read_data_memwb_to_wb;
    logic [`DATA_WIDTH-1:0] alu_result_memwb_to_wb;
    logic [`REG_ADDR_WIDTH-1:0] rd_addr_memwb_to_wb;   // RdW for Hazard Unit & RF
    logic [`DATA_WIDTH-1:0] pc_plus_4_memwb_to_wb;

    // Writeback Stage -> RF
    logic [`DATA_WIDTH-1:0] result_data_wb_to_rf; // ResultW

    // Hazard Unit Control Signals
    logic stall_f_sig;
    logic stall_d_sig;
    logic flush_d_sig;
    logic flush_e_sig;
    logic [1:0] forward_a_e_sig;
    logic [1:0] forward_b_e_sig;

    // Debug outputs
    assign current_pc_debug    = pc_f_to_ifid;
    assign fetched_instr_debug = instr_f_to_ifid;

    // Forwarding data paths for Execute stage
    logic [`DATA_WIDTH-1:0] data_from_mem_stage_for_fwd_sig;
    assign data_from_mem_stage_for_fwd_sig = (result_src_exmem_to_mem == 2'b01) ? read_data_mem_to_memwb : alu_result_exmem_to_mem;


    // --- Instantiate Pipeline Stages and Registers ---

    fetch u_fetch (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall_f        (stall_f_sig),
        .pc_src_e       (pc_src_ex_to_fetch),
        .pc_target_e    (pc_target_ex_to_fetch),
        .instr_f_o      (instr_f_to_ifid),
        .pc_f_o         (pc_f_to_ifid),
        .pc_plus_4_f_o  (pc_plus_4_f_to_ifid)
    );

    if_id_register u_if_id_register (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall_d        (stall_d_sig),
        .flush_d        (flush_d_sig),
        .instr_f_i      (instr_f_to_ifid),
        .pc_f_i         (pc_f_to_ifid),
        .pc_plus_4_f_i  (pc_plus_4_f_to_ifid),
        .instr_id_o     (instr_ifid_to_d),
        .pc_id_o        (pc_ifid_to_d),
        .pc_plus_4_id_o (pc_plus_4_ifid_to_d)
    );

    decode u_decode (
        .clk                (clk),
        .rst_n              (rst_n),
        .instr_id_i         (instr_ifid_to_d),
        .pc_id_i            (pc_ifid_to_d),
        .pc_plus_4_id_i     (pc_plus_4_ifid_to_d),
        .rd_write_en_wb_i   (reg_write_memwb_to_wb), // from MEM/WB reg
        .rd_addr_wb_i       (rd_addr_memwb_to_wb),   // from MEM/WB reg
        .rd_data_wb_i       (result_data_wb_to_rf),  // from WB stage mux
        .reg_write_d_o      (reg_write_d_to_idex),
        .result_src_d_o     (result_src_d_to_idex),
        .mem_write_d_o      (mem_write_d_to_idex),
        .jump_d_o           (jump_d_to_idex),
        .branch_d_o         (branch_d_to_idex),
        .alu_src_d_o        (alu_src_d_to_idex),
        .alu_control_d_o    (alu_control_d_to_idex),
        .funct3_d_o         (funct3_d_to_idex),
        .op_a_sel_d_o       (op_a_sel_d_to_idex),
        .pc_target_src_sel_d_o (pc_target_src_sel_d_to_idex),
        .pc_d_y         (pc_ifid_to_d),
        .pc_plus_4_d_i  (pc_plus_4_ifid_to_d),
        .rs1_data_d_o       (rs1_data_d_to_idex),
        .rs2_data_d_o       (rs2_data_d_to_idex),
        .imm_ext_d_o        (imm_ext_d_to_idex),
        .rs1_addr_d_o       (rs1_addr_d_for_hu),
        .rs2_addr_d_o       (rs2_addr_d_for_hu),
        .rd_addr_d_o        (rd_addr_d_to_idex)
    );

    id_ex_register u_id_ex_register (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall_e        (1'b0), // StallE not directly controlled by HU in this scheme
        .flush_e        (flush_e_sig),
        .reg_write_d_i  (reg_write_d_to_idex),
        .result_src_d_i (result_src_d_to_idex),
        .mem_write_d_i  (mem_write_d_to_idex),
        .jump_d_i       (jump_d_to_idex),
        .branch_d_i     (branch_d_to_idex),
        .alu_src_d_i    (alu_src_d_to_idex),
        .alu_control_d_i(alu_control_d_to_idex),
        .funct3_d_i     (funct3_d_to_idex),
        .op_a_sel_d_i   (op_a_sel_d_to_idex),
        .pc_target_src_sel_d_i (pc_target_src_sel_d_to_idex),
        .pc_d_i         (pc_ifid_to_d), // Use PC from IF/ID
        .pc_plus_4_d_i  (pc_plus_4_ifid_to_d), // Use PC+4 from IF/ID
        .rs1_data_d_i   (rs1_data_d_to_idex),
        .rs2_data_d_i   (rs2_data_d_to_idex),
        .imm_ext_d_i    (imm_ext_d_to_idex),
        .rs1_addr_d_i   (rs1_addr_d_for_hu), // Pass original Rs1 Addr from Decode output
        .rs2_addr_d_i   (rs2_addr_d_for_hu), // Pass original Rs2 Addr from Decode output
        .rd_addr_d_i    (rd_addr_d_to_idex),
        .reg_write_e_o  (reg_write_idex_to_ex),
        .result_src_e_o (result_src_idex_to_ex),
        .mem_write_e_o  (mem_write_idex_to_ex),
        .jump_e_o       (jump_idex_to_ex),
        .branch_e_o     (branch_idex_to_ex),
        .alu_src_e_o    (alu_src_idex_to_ex),
        .alu_control_e_o(alu_control_idex_to_ex),
        .funct3_e_o     (funct3_idex_to_ex),
        .op_a_sel_e_o   (op_a_sel_idex_to_ex),
        .pc_target_src_sel_e_o (pc_target_src_sel_idex_to_ex),
        .pc_e_o         (pc_idex_to_ex),
        .pc_plus_4_e_o  (pc_plus_4_idex_to_ex),
        .rs1_data_e_o   (rs1_data_idex_to_ex),
        .rs2_data_e_o   (rs2_data_idex_to_ex),
        .imm_ext_e_o    (imm_ext_idex_to_ex),
        .rs1_addr_e_o   (rs1_addr_d_for_hu), // Not rs1_addr_idex_to_ex, pass original for HU
        .rs2_addr_e_o   (rs2_addr_d_for_hu), // Not rs2_addr_idex_to_ex, pass original for HU
        .rd_addr_e_o    (rd_addr_idex_to_ex)
    );

    execute u_execute (
        .reg_write_e_i  (reg_write_idex_to_ex),
        .result_src_e_i (result_src_idex_to_ex),
        .mem_write_e_i  (mem_write_idex_to_ex),
        .jump_e_i       (jump_idex_to_ex),
        .branch_e_i     (branch_idex_to_ex),
        .alu_src_e_i    (alu_src_idex_to_ex),
        .alu_control_e_i(alu_control_idex_to_ex),
        .funct3_e_i     (funct3_idex_to_ex),
        .op_a_sel_e_i   (op_a_sel_idex_to_ex),
        .pc_target_src_sel_e_i (pc_target_src_sel_idex_to_ex),
        .pc_e_i         (pc_idex_to_ex),
        .pc_plus_4_e_i  (pc_plus_4_idex_to_ex),
        .rs1_data_e_i   (rs1_data_idex_to_ex),
        .rs2_data_e_i   (rs2_data_idex_to_ex),
        .imm_ext_e_i    (imm_ext_idex_to_ex),
        .rd_addr_e_i    (rd_addr_idex_to_ex),
        .forward_data_mem_i (data_from_mem_stage_for_fwd_sig),
        .forward_data_wb_i  (result_data_wb_to_rf),
        .forward_a_e_i  (forward_a_e_sig),
        .forward_b_e_i  (forward_b_e_sig),
        .reg_write_m_o  (reg_write_ex_to_exmem),
        .result_src_m_o (result_src_ex_to_exmem),
        .mem_write_m_o  (mem_write_ex_to_exmem),
        .alu_result_m_o (alu_result_ex_to_exmem),
        .rs2_data_m_o   (rs2_data_ex_to_exmem),
        .rd_addr_m_o    (rd_addr_ex_to_exmem),
        .pc_plus_4_m_o  (pc_plus_4_ex_to_exmem),
        .funct3_m_o     (funct3_ex_to_exmem),
        .pc_src_e_o     (pc_src_ex_to_fetch),
        .pc_target_addr_e_o (pc_target_ex_to_fetch)
    );

    ex_mem_register u_ex_mem_register (
        .clk            (clk),
        .rst_n          (rst_n),
        .reg_write_e_i  (reg_write_ex_to_exmem),
        .result_src_e_i (result_src_ex_to_exmem),
        .mem_write_e_i  (mem_write_ex_to_exmem),
        .alu_result_e_i (alu_result_ex_to_exmem),
        .rs2_data_e_i   (rs2_data_ex_to_exmem),
        .rd_addr_e_i    (rd_addr_ex_to_exmem),
        .pc_plus_4_e_i  (pc_plus_4_ex_to_exmem),
        .funct3_e_i     (funct3_ex_to_exmem),
        .reg_write_m_o  (reg_write_exmem_to_mem),
        .result_src_m_o (result_src_exmem_to_mem),
        .mem_write_m_o  (mem_write_exmem_to_mem),
        .alu_result_m_o (alu_result_exmem_to_mem),
        .rs2_data_m_o   (rs2_data_exmem_to_mem),
        .rd_addr_m_o    (rd_addr_exmem_to_mem),
        .pc_plus_4_m_o  (pc_plus_4_exmem_to_mem),
        .funct3_m_o     (funct3_exmem_to_mem)
    );

    memory_stage u_memory_stage (
        .clk            (clk),
        .rst_n          (rst_n),
        .reg_write_m_i  (reg_write_exmem_to_mem),
        .result_src_m_i (result_src_exmem_to_mem),
        .mem_write_m_i  (mem_write_exmem_to_mem),
        .funct3_m_i     (funct3_exmem_to_mem),
        .alu_result_m_i (alu_result_exmem_to_mem),
        .rs2_data_m_i   (rs2_data_exmem_to_mem),
        .rd_addr_m_i    (rd_addr_exmem_to_mem),
        .pc_plus_4_m_i  (pc_plus_4_exmem_to_mem),
        .reg_write_w_o  (reg_write_mem_to_memwb),
        .result_src_w_o (result_src_mem_to_memwb),
        .read_data_w_o  (read_data_mem_to_memwb),
        .alu_result_w_o (alu_result_mem_to_memwb),
        .rd_addr_w_o    (rd_addr_mem_to_memwb),
        .pc_plus_4_w_o  (pc_plus_4_mem_to_memwb)
    );

    mem_wb_register u_mem_wb_register (
        .clk            (clk),
        .rst_n          (rst_n),
        .reg_write_m_i  (reg_write_mem_to_memwb),
        .result_src_m_i (result_src_mem_to_memwb),
        .read_data_m_i  (read_data_mem_to_memwb),
        .alu_result_m_i (alu_result_mem_to_memwb),
        .rd_addr_m_i    (rd_addr_mem_to_memwb),
        .pc_plus_4_m_i  (pc_plus_4_mem_to_memwb),
        .reg_write_wb_o (reg_write_memwb_to_wb),
        .result_src_wb_o(result_src_memwb_to_wb),
        .read_data_wb_o (read_data_memwb_to_wb),
        .alu_result_wb_o(alu_result_memwb_to_wb),
        .rd_addr_wb_o   (rd_addr_memwb_to_wb),
        .pc_plus_4_wb_o (pc_plus_4_memwb_to_wb)
    );

    writeback_stage u_writeback_stage (
        .result_src_wb_i (result_src_memwb_to_wb),
        .read_data_wb_i  (read_data_memwb_to_wb),
        .alu_result_wb_i (alu_result_memwb_to_wb),
        .pc_plus_4_wb_i  (pc_plus_4_memwb_to_wb),
        .result_w_o      (result_data_wb_to_rf)
    );

    pipeline_control u_pipeline_control (
        .rs1_addr_d_i   (rs1_addr_d_for_hu),
        .rs2_addr_d_i   (rs2_addr_d_for_hu),
        .rd_addr_e_i    (rd_addr_idex_to_ex),
        .reg_write_e_i  (reg_write_idex_to_ex),
        .result_src_e_i (result_src_idex_to_ex),
        .rd_addr_m_i    (rd_addr_exmem_to_mem),
        .reg_write_m_i  (reg_write_exmem_to_mem),
        .rd_addr_w_i    (rd_addr_memwb_to_wb),
        .reg_write_w_i  (reg_write_memwb_to_wb),
        .pc_src_e_i     (pc_src_ex_to_fetch),
        .stall_f_o      (stall_f_sig),
        .stall_d_o      (stall_d_sig),
        .flush_d_o      (flush_d_sig),
        .flush_e_o      (flush_e_sig),
        .forward_a_e_o  (forward_a_e_sig),
        .forward_b_e_o  (forward_b_e_sig)
    );

endmodule