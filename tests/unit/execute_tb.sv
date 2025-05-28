// tests/unit/execute_tb.sv
`include "common/pipeline_types.svh" // Includes id_ex_data_t, ex_mem_data_t

module execute_tb (
    // input  logic clk, // Not strictly used by execute.sv's logic but good for TB
    // input  logic rst_n, // Same as clk

    // Inputs to Execute Stage
    input  id_ex_data_t            i_id_ex_data,       // Input structure from ID/EX

    // Forwarding inputs (remain individual signals)
    input  logic [`DATA_WIDTH-1:0]     i_forward_data_mem,
    input  logic [`DATA_WIDTH-1:0]     i_forward_data_wb,
    input  logic [1:0]                 i_forward_a_e,
    input  logic [1:0]                 i_forward_b_e,

    // Outputs from Execute stage
    output ex_mem_data_t           o_ex_mem_data,      // Output structure to EX/MEM
    output logic                   o_pc_src,           // PCSrcE: 1 if branch/jump taken
    output logic [`DATA_WIDTH-1:0] o_pc_target_addr    // PCTargetE: target address
);

    execute u_execute_dut ( // Changed instance name for clarity
        .id_ex_data_i       (i_id_ex_data),       // Pass the whole structure

        .forward_data_mem_i (i_forward_data_mem),
        .forward_data_wb_i  (i_forward_data_wb),
        .forward_a_e_i      (i_forward_a_e),
        .forward_b_e_i      (i_forward_b_e),

        .ex_mem_data_o      (o_ex_mem_data),      // Receive the whole structure
        .pc_src_o           (o_pc_src),
        .pc_target_addr_o   (o_pc_target_addr)
    );

endmodule