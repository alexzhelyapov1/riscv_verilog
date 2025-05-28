// tests/unit/pipeline_tb.sv
`default_nettype none
`timescale 1ns/1ps

`include "common/pipeline_types.svh"

module pipeline_tb (
    input  logic clk,
    input  logic rst_n,

    // Debug outputs from pipeline
    output logic [`DATA_WIDTH-1:0]     debug_pc_f_o,
    output logic [`INSTR_WIDTH-1:0]    debug_instr_f_o,
    output logic                       debug_reg_write_wb_o,
    output logic [`REG_ADDR_WIDTH-1:0] debug_rd_addr_wb_o,
    output logic [`DATA_WIDTH-1:0]     debug_result_w_o,

    // If we want to observe pipeline register contents for detailed debugging:
    // These would need to be made outputs of the 'pipeline' module itself.
    // For now, we rely on the specific debug signals provided by 'pipeline.sv'.
    // output if_id_data_t    debug_if_id_data_q_o,
    // output id_ex_data_t    debug_id_ex_data_q_o,
    // output ex_mem_data_t   debug_ex_mem_data_q_o,
    // output mem_wb_data_t   debug_mem_wb_data_q_o

    // Output from RF for checking (requires DPI or making RF content visible)
    // For now, we check writeback via debug_reg_write_wb_o etc.
    output logic [`DATA_WIDTH-1:0]     debug_rf_x1, // Example: Value of register x1
    output logic [`DATA_WIDTH-1:0]     debug_rf_x2,
    output logic [`DATA_WIDTH-1:0]     debug_rf_x3,
    output logic [`DATA_WIDTH-1:0]     debug_rf_x4
);

    // Instantiate the pipeline
    // Parameters for memory init files can be passed here if 'pipeline' module is parameterized
    pipeline u_pipeline (
        .clk                  (clk),
        .rst_n                (rst_n),
        .debug_pc_f           (debug_pc_f_o),
        .debug_instr_f        (debug_instr_f_o),
        .debug_reg_write_wb   (debug_reg_write_wb_o),
        .debug_rd_addr_wb     (debug_rd_addr_wb_o),
        .debug_result_w       (debug_result_w_o)
        // .debug_if_id_q_o    (debug_if_id_data_q_o), // Example if pipeline exposes these
        // .debug_id_ex_q_o    (debug_id_ex_data_q_o),
        // .debug_ex_mem_q_o   (debug_ex_mem_data_q_o),
        // .debug_mem_wb_q_o   (debug_mem_wb_data_q_o)
    );

    // For observing register file content, we'd typically need DPI access
    // or to instantiate the register file separately here and mirror writes.
    // As a simplification for this basic test, we can add specific 'export'
    // signals directly from the register_file.sv if we modify it, or use Verilator's
    // ability to access internal signals via their hierarchical path in C++.
    //
    // Let's assume for now we use Verilator's public signal access from C++
    // or we add `export` to register file if needed.
    // For this Verilog TB, we are just providing ports for C++ to read.
    // The C++ side will use Verilator's features to peek into u_pipeline.u_decode.u_register_file.regs[x]

    // These are placeholders; actual values will be read by C++ from internal signals
    assign debug_rf_x1 = u_pipeline.u_decode.u_register_file.regs[1];
    assign debug_rf_x2 = u_pipeline.u_decode.u_register_file.regs[2];
    assign debug_rf_x3 = u_pipeline.u_decode.u_register_file.regs[3];
    assign debug_rf_x4 = u_pipeline.u_decode.u_register_file.regs[4];

endmodule