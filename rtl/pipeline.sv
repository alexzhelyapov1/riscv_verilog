// rtl/pipeline.sv
`default_nettype none
`timescale 1ns/1ps

`include "common/pipeline_types.svh"

module pipeline #(
    parameter string INSTR_MEM_INIT_FILE = "",
    parameter logic [`DATA_WIDTH-1:0] PC_START_ADDR = `PC_RESET_VALUE,
    parameter string DATA_MEM_INIT_FILE = ""
)(
    input  logic clk,
    input  logic rst_n,

    output logic [`DATA_WIDTH-1:0] debug_pc_f,
    output logic [`INSTR_WIDTH-1:0] debug_instr_f,
    output logic                   debug_reg_write_wb,
    output logic [`REG_ADDR_WIDTH-1:0] debug_rd_addr_wb,
    output logic [`DATA_WIDTH-1:0] debug_result_w
);

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

    // Individual hazard control signals from hazard_unit
    logic [1:0] forward_a_ex_signal;
    logic [1:0] forward_b_ex_signal;
    logic       stall_fetch_signal;
    logic       stall_decode_signal;
    logic       flush_decode_signal;
    logic       flush_execute_signal;

    logic [`REG_ADDR_WIDTH-1:0] rs1_addr_id_signal; // from decode stage
    logic [`REG_ADDR_WIDTH-1:0] rs2_addr_id_signal; // from decode stage

    fetch #(
        .INSTR_MEM_INIT_FILE_PARAM(INSTR_MEM_INIT_FILE),
        .PC_INIT_VALUE_PARAM(PC_START_ADDR)
    ) u_fetch (
        .clk                (clk),
        .rst_n              (rst_n),
        .stall_f_i          (stall_fetch_signal), // Connect to hazard unit output
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
        .rs1_addr_d_o       (rs1_addr_id_signal), // Output for hazard unit
        .rs2_addr_d_o       (rs2_addr_id_signal)  // Output for hazard unit
    );

    execute u_execute (
        .id_ex_data_i       (id_ex_data_q),
        .forward_data_mem_i (ex_mem_data_q.alu_result),
        .forward_data_wb_i  (rf_write_data_from_wb.result_to_rf),
        .forward_a_e_i      (forward_a_ex_signal), // Connect to hazard unit output
        .forward_b_e_i      (forward_b_ex_signal), // Connect to hazard unit output
        .ex_mem_data_o      (ex_mem_data_from_execute),
        .pc_src_o           (pc_src_ex_o),
        .pc_target_addr_o   (pc_target_ex_o)
    );

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

    // Instantiate new hazard_unit
    hazard_unit u_hazard_unit (
        .rs1_addr_ex_i    (id_ex_data_q.rs1_addr),
        .rs2_addr_ex_i    (id_ex_data_q.rs2_addr),
        .rd_addr_ex_i     (id_ex_data_q.rd_addr),
        .result_src_ex0_i (id_ex_data_q.result_src[0]),

        .rs1_addr_id_i    (rs1_addr_id_signal),
        .rs2_addr_id_i    (rs2_addr_id_signal),

        .rd_addr_mem_i    (ex_mem_data_q.rd_addr),
        .reg_write_mem_i  (ex_mem_data_q.reg_write),

        .rd_addr_wb_i     (mem_wb_data_q.rd_addr),
        .reg_write_wb_i   (mem_wb_data_q.reg_write),

        .pc_src_ex_i      (pc_src_ex_o),

        .forward_a_ex_o   (forward_a_ex_signal),
        .forward_b_ex_o   (forward_b_ex_signal),
        .stall_fetch_o    (stall_fetch_signal),
        .stall_decode_o   (stall_decode_signal),
        .flush_decode_o   (flush_decode_signal),
        .flush_execute_o  (flush_execute_signal)
    );

    // IF/ID Register Logic
    always_comb begin
        if (flush_decode_signal) begin // Use signal from hazard_unit
            if_id_data_d = NOP_IF_ID_DATA;
        end else if (stall_decode_signal) begin // Use signal from hazard_unit
            if_id_data_d = if_id_data_q; // Keep current data
        end else begin
            if_id_data_d = if_id_data_from_fetch; // Latch new data
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_data_q <= NOP_IF_ID_DATA;
            if_id_data_q.pc <= PC_START_ADDR;
            if_id_data_q.pc_plus_4 <= PC_START_ADDR + 4;
        end else begin
            if_id_data_q <= if_id_data_d;
        end
    end

    // ID/EX Register Logic
    always_comb begin
        if (flush_execute_signal) begin // Use signal from hazard_unit
            id_ex_data_d = NOP_ID_EX_DATA;
        end else begin
            id_ex_data_d = id_ex_data_from_decode;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_data_q <= NOP_ID_EX_DATA;
            id_ex_data_q.pc <= PC_START_ADDR;
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
        end else begin
            // EX/MEM register is not flushed by typical hazard conditions like load-use or branch.
            // It latches the (potentially NOP'd) output from ID/EX.
            ex_mem_data_q <= ex_mem_data_d;
        end
    end

    // MEM/WB Register Logic
    assign mem_wb_data_d = mem_wb_data_from_memory;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_data_q <= NOP_MEM_WB_DATA;
        end else begin
            mem_wb_data_q <= mem_wb_data_d;
        end
    end

    assign debug_pc_f         = if_id_data_from_fetch.pc; // or if_id_data_q.pc depending on what you want to see
    assign debug_instr_f      = if_id_data_from_fetch.instr; // or if_id_data_q.instr
    assign debug_reg_write_wb = rf_write_data_from_wb.reg_write_en;
    assign debug_rd_addr_wb   = rf_write_data_from_wb.rd_addr;
    assign debug_result_w     = rf_write_data_from_wb.result_to_rf;

endmodule