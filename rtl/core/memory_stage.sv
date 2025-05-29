`include "common/pipeline_types.svh"

module memory_stage #(
    parameter string DATA_MEM_INIT_FILE_PARAM = ""
)(
    input  logic clk,
    input  logic rst_n,
    input  ex_mem_data_t           ex_mem_data_i,
    output mem_wb_data_t           mem_wb_data_o
);

    logic [`DATA_WIDTH-1:0] mem_read_data_internal;

    data_memory #(
        .DATA_MEM_INIT_FILE(DATA_MEM_INIT_FILE_PARAM)
    ) u_data_memory (
        .clk            (clk),
        .rst_n          (rst_n),
        .addr_i         (ex_mem_data_i.alu_result),
        .write_data_i   (ex_mem_data_i.rs2_data),
        .mem_write_en_i (ex_mem_data_i.mem_write),
        .funct3_i       (ex_mem_data_i.funct3),
        .read_data_o    (mem_read_data_internal)
    );

    assign mem_wb_data_o.reg_write      = ex_mem_data_i.reg_write;
    assign mem_wb_data_o.result_src     = ex_mem_data_i.result_src;
    assign mem_wb_data_o.read_data_mem  = mem_read_data_internal;
    assign mem_wb_data_o.alu_result     = ex_mem_data_i.alu_result;
    assign mem_wb_data_o.pc_plus_4      = ex_mem_data_i.pc_plus_4;
    assign mem_wb_data_o.rd_addr        = ex_mem_data_i.rd_addr;

endmodule