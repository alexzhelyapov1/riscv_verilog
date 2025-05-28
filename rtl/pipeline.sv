// rtl/pipeline.sv
`default_nettype none
`timescale 1ns/1ps

`include "common/pipeline_types.svh" // Includes all other necessary common files

module pipeline (
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
    // _q holds the current (stable) output of the register for this cycle
    // _d holds the input to the register, to be latched on the next clock edge
    if_id_data_t    if_id_data_q, if_id_data_d;
    id_ex_data_t    id_ex_data_q, id_ex_data_d;
    ex_mem_data_t   ex_mem_data_q, ex_mem_data_d;
    mem_wb_data_t   mem_wb_data_q, mem_wb_data_d;

    // Data coming out of the combinational stages
    if_id_data_t    if_id_data_from_fetch;
    id_ex_data_t    id_ex_data_from_decode;
    ex_mem_data_t   ex_mem_data_from_execute;
    mem_wb_data_t   mem_wb_data_from_memory;
    rf_write_data_t rf_write_data_from_wb; // Final data for Register File

    // Signals for PC update and Hazard Unit
    logic                   pc_src_ex_o;
    logic [`DATA_WIDTH-1:0] pc_target_ex_o;
    hazard_control_t        hazard_ctrl;

    // Extracted signals from Decode for Hazard Unit (rs1_addr_d, rs2_addr_d on diagram)
    logic [`REG_ADDR_WIDTH-1:0] rs1_addr_from_decode;
    logic [`REG_ADDR_WIDTH-1:0] rs2_addr_from_decode;


    // Pipeline Stage Instantiation
    fetch u_fetch (
        .clk                (clk),
        .rst_n              (rst_n),
        .stall_f_i          (hazard_ctrl.stall_f),
        .pc_src_e_i         (pc_src_ex_o),          // From Execute stage of previous cycle
        .pc_target_e_i      (pc_target_ex_o),       // From Execute stage of previous cycle
        .if_id_data_o       (if_id_data_from_fetch)
    );

    decode u_decode (
        .clk                (clk),
        .rst_n              (rst_n),
        .if_id_data_i       (if_id_data_q),         // Data from IF/ID latch
        .writeback_data_i   (rf_write_data_from_wb),// Data from Writeback stage
        .id_ex_data_o       (id_ex_data_from_decode),
        .rs1_addr_d_o       (rs1_addr_from_decode), // For Hazard Unit
        .rs2_addr_d_o       (rs2_addr_from_decode)  // For Hazard Unit
    );

    execute u_execute (
        // .clk             (clk), // Combinational
        // .rst_n           (rst_n),// Combinational
        .id_ex_data_i       (id_ex_data_q),         // Data from ID/EX latch
        .forward_data_mem_i (ex_mem_data_q.alu_result), // Data from EX/MEM latch (ALUResultM on diagram)
                                                        // If ex_mem_data_q was a load, its read_data is not ready yet for this path.
                                                        // P&H diagram implies ALUResultM for this path.
        .forward_data_wb_i  (rf_write_data_from_wb.result_to_rf), // Data from Writeback stage (ResultW)
        .forward_a_e_i      (hazard_ctrl.forward_a_e),
        .forward_b_e_i      (hazard_ctrl.forward_b_e),
        .ex_mem_data_o      (ex_mem_data_from_execute),
        .pc_src_o           (pc_src_ex_o),          // To Fetch and Hazard Unit
        .pc_target_addr_o   (pc_target_ex_o)        // To Fetch
    );

    memory_stage u_memory_stage (
        .clk                (clk),
        .rst_n              (rst_n),
        .ex_mem_data_i      (ex_mem_data_q),        // Data from EX/MEM latch
        .mem_wb_data_o      (mem_wb_data_from_memory)
    );

    writeback_stage u_writeback_stage (
        .mem_wb_data_i      (mem_wb_data_q),        // Data from MEM/WB latch
        .rf_write_data_o    (rf_write_data_from_wb)
    );

    pipeline_control u_pipeline_control (
        // Data needed by Hazard Unit.
        // These are the STABLE outputs of the pipeline registers (_q values)
        // or directly from instruction fields for the current ID stage.
        .if_id_data_i       (if_id_data_q),     // For rs1/rs2 addresses of instruction in ID
        .id_ex_data_i       (id_ex_data_q),     // For RdE, RegWriteE, ResultSrcE, Rs1E, Rs2E
        .ex_mem_data_i      (ex_mem_data_q),    // For RdM, RegWriteM
        .mem_wb_data_i      (mem_wb_data_q),    // For RdW, RegWriteW
        .pc_src_from_ex_i   (pc_src_ex_o),      // From Execute stage's output
        .hazard_ctrl_o      (hazard_ctrl)
    );


    // Logic for pipeline registers
    // IF/ID Register Logic
    always_comb begin
        if (hazard_ctrl.flush_d) begin
            if_id_data_d = NOP_IF_ID_DATA;
        end else if (hazard_ctrl.stall_d) begin // Stall_D means IF/ID holds its value
            if_id_data_d = if_id_data_q;
        end else begin
            if_id_data_d = if_id_data_from_fetch;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_data_q <= NOP_IF_ID_DATA;
        end else begin
            if_id_data_q <= if_id_data_d;
        end
    end

    // ID/EX Register Logic
    always_comb begin
        if (hazard_ctrl.flush_e) begin // Flush_E (from load-use or branch) clears ID/EX
            id_ex_data_d = NOP_ID_EX_DATA;
        end else begin // No stall_e in this P&H version, Hazard unit stalls earlier stages
            id_ex_data_d = id_ex_data_from_decode;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_data_q <= NOP_ID_EX_DATA;
        end else begin
            id_ex_data_q <= id_ex_data_d;
        end
    end

    // EX/MEM Register Logic (no explicit flush/stall inputs from P&H diagram for this reg)
    // Flushes/stalls propagate by NOPing data in earlier stages.
    assign ex_mem_data_d = ex_mem_data_from_execute;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_data_q <= NOP_EX_MEM_DATA;
        end else begin
            ex_mem_data_q <= ex_mem_data_d;
        end
    end

    // MEM/WB Register Logic (no explicit flush/stall inputs)
    assign mem_wb_data_d = mem_wb_data_from_memory;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_data_q <= NOP_MEM_WB_DATA;
        end else begin
            mem_wb_data_q <= mem_wb_data_d;
        end
    end

    // Debug outputs
    assign debug_pc_f         = if_id_data_from_fetch.pc; // PC from current fetch output
    assign debug_instr_f      = if_id_data_from_fetch.instr;
    assign debug_reg_write_wb = rf_write_data_from_wb.reg_write_en;
    assign debug_rd_addr_wb   = rf_write_data_from_wb.rd_addr;
    assign debug_result_w     = rf_write_data_from_wb.result_to_rf;

endmodule