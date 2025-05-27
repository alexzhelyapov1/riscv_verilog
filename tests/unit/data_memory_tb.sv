`include "common/defines.svh"

module data_memory_tb (
    input  logic clk,
    input  logic rst_n,

    // Inputs to data_memory
    input  logic [`DATA_WIDTH-1:0]     i_addr,
    input  logic [`DATA_WIDTH-1:0]     i_write_data,
    input  logic                       i_mem_write_en,
    input  logic [2:0]                 i_funct3,

    // Output from data_memory
    output logic [`DATA_WIDTH-1:0]     o_read_data
);

    data_memory u_data_mem (
        .clk            (clk),
        .rst_n          (rst_n),
        .addr_i         (i_addr),
        .write_data_i   (i_write_data),
        .mem_write_en_i (i_mem_write_en),
        .funct3_i       (i_funct3),
        .read_data_o    (o_read_data)
    );

endmodule