`include "common/defines.svh"

module writeback_stage_tb (
    // Inputs to writeback_stage
    input  logic [1:0]                 i_result_src_wb,
    input  logic [`DATA_WIDTH-1:0]     i_read_data_wb,
    input  logic [`DATA_WIDTH-1:0]     i_alu_result_wb,
    input  logic [`DATA_WIDTH-1:0]     i_pc_plus_4_wb,

    // Output from writeback_stage
    output logic [`DATA_WIDTH-1:0]     o_result_w
);

    writeback_stage u_writeback_stage (
        .result_src_wb_i (i_result_src_wb),
        .read_data_wb_i  (i_read_data_wb),
        .alu_result_wb_i (i_alu_result_wb),
        .pc_plus_4_wb_i  (i_pc_plus_4_wb),
        .result_w_o      (o_result_w)
    );

endmodule