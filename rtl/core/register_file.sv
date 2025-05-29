`include "common/defines.svh"

module register_file (
    input  logic clk,
    input  logic rst_n,
    input  logic [`REG_ADDR_WIDTH-1:0] rs1_addr_i,
    output logic [`DATA_WIDTH-1:0]     rs1_data_o,

    input  logic [`REG_ADDR_WIDTH-1:0] rs2_addr_i,
    output logic [`DATA_WIDTH-1:0]     rs2_data_o,

    input  logic                       rd_write_en_wb_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_wb_i,
    input  logic [`DATA_WIDTH-1:0]     rd_data_wb_i
);

    logic [`DATA_WIDTH-1:0] regs[31:0] /* verilator public */;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                regs[i] <= `DATA_WIDTH'(0);
            end
        end else begin
            if (rd_write_en_wb_i && (rd_addr_wb_i != `REG_ADDR_WIDTH'(0))) begin
                regs[rd_addr_wb_i] <= rd_data_wb_i;
            end
        end
    end

    logic [`DATA_WIDTH-1:0] rs1_data_from_array;
    assign rs1_data_from_array = (rs1_addr_i == `REG_ADDR_WIDTH'(0)) ? `DATA_WIDTH'(0) : regs[rs1_addr_i];

    logic [`DATA_WIDTH-1:0] rs2_data_from_array;
    assign rs2_data_from_array = (rs2_addr_i == `REG_ADDR_WIDTH'(0)) ? `DATA_WIDTH'(0) : regs[rs2_addr_i];

    assign rs1_data_o = (rd_write_en_wb_i && (rd_addr_wb_i != 0) && (rs1_addr_i == rd_addr_wb_i))
                        ? rd_data_wb_i
                        : rs1_data_from_array;

    assign rs2_data_o = (rd_write_en_wb_i && (rd_addr_wb_i != 0) && (rs2_addr_i == rd_addr_wb_i))
                        ? rd_data_wb_i
                        : rs2_data_from_array;

    initial begin
        for (int i = 0; i < 2**`REG_ADDR_WIDTH; i++) begin
            regs[i] = `DATA_WIDTH'b0;
        end
    end

endmodule