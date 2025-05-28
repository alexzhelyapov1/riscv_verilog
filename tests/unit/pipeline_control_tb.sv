// tests/unit/pipeline_control_tb.sv
`include "common/pipeline_types.svh"

module pipeline_control_tb (
    // Inputs to pipeline_control module
    input  if_id_data_t    i_if_id_data,
    input  id_ex_data_t    i_id_ex_data,
    input  ex_mem_data_t   i_ex_mem_data,
    input  mem_wb_data_t   i_mem_wb_data,
    input  logic           i_pc_src_from_ex,

    // Output from pipeline_control module
    output hazard_control_t o_hazard_ctrl
);

    pipeline_control u_pipeline_control_dut (
        .if_id_data_i     (i_if_id_data),
        .id_ex_data_i     (i_id_ex_data),
        .ex_mem_data_i    (i_ex_mem_data),
        .mem_wb_data_i    (i_mem_wb_data),
        .pc_src_from_ex_i (i_pc_src_from_ex),
        .hazard_ctrl_o    (o_hazard_ctrl)
    );

endmodule