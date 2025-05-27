`include "common/defines.svh"

module register_file_tb (
    input  logic clk,
    input  logic rst_n,

    // Inputs to Register File
    // Read Port 1
    input  logic [`REG_ADDR_WIDTH-1:0] i_rs1_addr,
    // Read Port 2
    input  logic [`REG_ADDR_WIDTH-1:0] i_rs2_addr,
    // Write Port
    input  logic                       i_rd_write_en_wb,
    input  logic [`REG_ADDR_WIDTH-1:0] i_rd_addr_wb,
    input  logic [`DATA_WIDTH-1:0]     i_rd_data_wb,

    // Outputs from Register File
    output logic [`DATA_WIDTH-1:0]     o_rs1_data,
    output logic [`DATA_WIDTH-1:0]     o_rs2_data
);

    register_file u_register_file (
        .clk               (clk),
        .rst_n             (rst_n),
        .rs1_addr_i        (i_rs1_addr),
        .rs1_data_o        (o_rs1_data),
        .rs2_addr_i        (i_rs2_addr),
        .rs2_data_o        (o_rs2_data),
        .rd_write_en_wb_i  (i_rd_write_en_wb),
        .rd_addr_wb_i      (i_rd_addr_wb),
        .rd_data_wb_i      (i_rd_data_wb)
    );

endmodule