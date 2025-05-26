// rtl/core/mem_wb_register.sv
`include "common/defines.svh"

module mem_wb_register (
    input  logic clk,
    input  logic rst_n,

    // Inputs from Memory Stage
    input  logic       reg_write_m_i,    // RegWriteW on diagram
    input  logic [1:0] result_src_m_i,   // ResultSrcW on diagram

    input  logic [`DATA_WIDTH-1:0]     read_data_m_i,  // ReadDataW on diagram
    input  logic [`DATA_WIDTH-1:0]     alu_result_m_i, // ALUResultW (passed from EX/MEM to MEM/WB)
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_m_i,    // RdW on diagram
    input  logic [`DATA_WIDTH-1:0]     pc_plus_4_m_i,  // PCPlus4W on diagram

    // Outputs to Writeback Stage
    output logic       reg_write_wb_o,
    output logic [1:0] result_src_wb_o,

    output logic [`DATA_WIDTH-1:0]     read_data_wb_o,
    output logic [`DATA_WIDTH-1:0]     alu_result_wb_o,
    output logic [`REG_ADDR_WIDTH-1:0] rd_addr_wb_o,
    output logic [`DATA_WIDTH-1:0]     pc_plus_4_wb_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_write_wb_o  <= 1'b0;
            result_src_wb_o <= 2'b00; // Default to ALUResult path

            read_data_wb_o  <= {`DATA_WIDTH{1'b0}};
            alu_result_wb_o <= {`DATA_WIDTH{1'b0}};
            rd_addr_wb_o    <= {`REG_ADDR_WIDTH{1'b0}};
            pc_plus_4_wb_o  <= {`DATA_WIDTH{1'b0}};
        end else begin
            // No stall/flush inputs to this register in the P&H diagram for simplicity
            // Stalls usually handled before EX, flushes clear earlier stages.
            reg_write_wb_o  <= reg_write_m_i;
            result_src_wb_o <= result_src_m_i;

            read_data_wb_o  <= read_data_m_i;
            alu_result_wb_o <= alu_result_m_i;
            rd_addr_wb_o    <= rd_addr_m_i;
            pc_plus_4_wb_o  <= pc_plus_4_m_i;
        end
    end
endmodule