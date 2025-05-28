// rtl/pipeline.sv
`default_nettype none
`timescale 1ns/1ps

`include "common/pipeline_types.svh"

module pipeline #(
    parameter string INSTR_MEM_INIT_FILE = "",
    parameter logic [`DATA_WIDTH-1:0] PC_START_ADDR = `PC_RESET_VALUE,
    parameter string DATA_MEM_INIT_FILE = "" // Added for data memory initialization
)(
    input  logic clk,
    input  logic rst_n,

    // Optional debug outputs
    output logic [`DATA_WIDTH-1:0] debug_pc_f,
    output logic [`INSTR_WIDTH-1:0] debug_instr_f,
    output logic                   debug_reg_write_wb,
    output logic [`REG_ADDR_WIDTH-1:0] debug_rd_addr_wb,
    output logic [`DATA_WIDTH-1:0] debug_result_w
);

    // Pipeline stage data registers (latches between stages)
    if_id_data_t    if_id_data_q, if_id_data_d;
    id_ex_data_t    id_ex_data_q, id_ex_data_d;
    ex_mem_data_t   ex_mem_data_q, ex_mem_data_d;
    mem_wb_data_t   mem_wb_data_q, mem_wb_data_d;

    if_id_data_t    if_id_data_from_fetch;
    id_ex_data_t    id_ex_data_from_decode;
    ex_mem_data_t   ex_mem_data_from_execute;
    mem_wb_data_t   mem_wb_data_from_memory;
    rf_write_data_t rf_write_data_from_wb;

    logic                   pc_src_ex_o;
    logic [`DATA_WIDTH-1:0] pc_target_ex_o;
    hazard_control_t        hazard_ctrl;

    logic [`REG_ADDR_WIDTH-1:0] rs1_addr_from_decode;
    logic [`REG_ADDR_WIDTH-1:0] rs2_addr_from_decode;

    fetch #(
        .INSTR_MEM_INIT_FILE_PARAM(INSTR_MEM_INIT_FILE),
        .PC_INIT_VALUE_PARAM(PC_START_ADDR)
    ) u_fetch (
        .clk                (clk),
        .rst_n              (rst_n),
        .stall_f_i          (hazard_ctrl.stall_f),
        .pc_src_e_i         (pc_src_ex_o),
        .pc_target_e_i      (pc_target_ex_o),
        .if_id_data_o       (if_id_data_from_fetch)
    );

    decode u_decode (
        .clk                (clk),
        .rst_n              (rst_n),
        .if_id_data_i       (if_id_data_q),
        .writeback_data_i   (rf_write_data_from_wb),
        .id_ex_data_o       (id_ex_data_from_decode),
        .rs1_addr_d_o       (rs1_addr_from_decode),
        .rs2_addr_d_o       (rs2_addr_from_decode)
    );

    execute u_execute (
        .id_ex_data_i       (id_ex_data_q),
        .forward_data_mem_i (ex_mem_data_q.alu_result),
        .forward_data_wb_i  (rf_write_data_from_wb.result_to_rf),
        .forward_a_e_i      (hazard_ctrl.forward_a_e),
        .forward_b_e_i      (hazard_ctrl.forward_b_e),
        .ex_mem_data_o      (ex_mem_data_from_execute),
        .pc_src_o           (pc_src_ex_o),
        .pc_target_addr_o   (pc_target_ex_o)
    );

    // Pass DATA_MEM_INIT_FILE to memory_stage
    memory_stage #(
        .DATA_MEM_INIT_FILE_PARAM(DATA_MEM_INIT_FILE)
    ) u_memory_stage (
        .clk                (clk),
        .rst_n              (rst_n),
        .ex_mem_data_i      (ex_mem_data_q),
        .mem_wb_data_o      (mem_wb_data_from_memory)
    );

    writeback_stage u_writeback_stage (
        .mem_wb_data_i      (mem_wb_data_q),
        .rf_write_data_o    (rf_write_data_from_wb)
    );

    pipeline_control u_pipeline_control (
        .if_id_data_i       (if_id_data_q),
        .id_ex_data_i       (id_ex_data_q),
        .ex_mem_data_i      (ex_mem_data_q),
        .mem_wb_data_i      (mem_wb_data_q),
        .pc_src_from_ex_i   (pc_src_ex_o),
        .hazard_ctrl_o      (hazard_ctrl)
    );

    // Pipeline register logic (same as before)
    // IF/ID Register Logic
    always_comb begin
        if (hazard_ctrl.flush_d) begin
            if_id_data_d = NOP_IF_ID_DATA;
            // Если flush, PC в NOP должен быть "разумным", NOP_IF_ID_DATA.pc уже PC_RESET_VALUE
            // Если PC_START_ADDR != PC_RESET_VALUE, то NOP_IF_ID_DATA.pc может быть не тем, что мы хотим для PC_START_ADDR
            // Однако, pc_reg в fetch уже инициализирован PC_START_ADDR.
            // if_id_data_from_fetch.pc будет PC_START_ADDR на первом такте.
        end else if (hazard_ctrl.stall_d) begin
            if_id_data_d = if_id_data_q;
        end else begin
            if_id_data_d = if_id_data_from_fetch;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_data_q <= NOP_IF_ID_DATA; // NOP_IF_ID_DATA.pc == PC_RESET_VALUE
            // Явно установим PC поля, если PC_START_ADDR отличается от PC_RESET_VALUE
            // или если хотим гарантировать PC_START_ADDR при сбросе этого регистра
            if_id_data_q.pc <= PC_START_ADDR;
            if_id_data_q.pc_plus_4 <= PC_START_ADDR + 4;
        end else begin
            if_id_data_q <= if_id_data_d;
        end
    end

    // ID/EX Register Logic
    always_comb begin
        if (hazard_ctrl.flush_e) begin
            id_ex_data_d = NOP_ID_EX_DATA; // NOP_ID_EX_DATA.pc == PC_RESET_VALUE
        end else begin
            id_ex_data_d = id_ex_data_from_decode;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_data_q <= NOP_ID_EX_DATA;
            // Аналогично для ID/EX
            id_ex_data_q.pc <= PC_START_ADDR; // PC инструкции, которая была бы здесь при сбросе
            id_ex_data_q.pc_plus_4 <= PC_START_ADDR + 4;
        end else begin
            id_ex_data_q <= id_ex_data_d;
        end
    end

    // EX/MEM Register Logic
    assign ex_mem_data_d = ex_mem_data_from_execute;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_data_q <= NOP_EX_MEM_DATA;
            // PC поля в NOP_EX_MEM_DATA также могут нуждаться в PC_START_ADDR
            // ex_mem_data_q.pc_plus_4 <= PC_START_ADDR + 4; // Если pc_plus_4 хранится и здесь
        end else begin
            ex_mem_data_q <= ex_mem_data_d;
        end
    end

    // MEM/WB Register Logic
    assign mem_wb_data_d = mem_wb_data_from_memory;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_data_q <= NOP_MEM_WB_DATA;
            // mem_wb_data_q.pc_plus_4 <= PC_START_ADDR + 4; // Если pc_plus_4 хранится и здесь
        end else begin
            mem_wb_data_q <= mem_wb_data_d;
        end
    end

    assign debug_pc_f         = if_id_data_from_fetch.pc;
    assign debug_instr_f      = if_id_data_from_fetch.instr;
    assign debug_reg_write_wb = rf_write_data_from_wb.reg_write_en;
    assign debug_rd_addr_wb   = rf_write_data_from_wb.rd_addr;
    assign debug_result_w     = rf_write_data_from_wb.result_to_rf;

endmodule