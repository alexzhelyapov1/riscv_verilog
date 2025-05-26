// rtl/core/memory.sv (Memory Stage Logic)
`include "common/defines.svh"

module memory_stage ( // Changed module name to memory_stage to avoid conflict with data_memory if in same scope
    input  logic clk,
    input  logic rst_n,

    // Inputs from EX/MEM Register
    input  logic       reg_write_m_i,
    input  logic [1:0] result_src_m_i, // 00:ALU, 01:MemRead, 10:PC+4
    input  logic       mem_write_m_i,    // Enable for data memory write
    input  logic [2:0] funct3_m_i,       // For load/store type

    input  logic [`DATA_WIDTH-1:0]     alu_result_m_i, // Address for memory or result from ALU
    input  logic [`DATA_WIDTH-1:0]     rs2_data_m_i,   // Data to store in memory
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_m_i,
    input  logic [`DATA_WIDTH-1:0]     pc_plus_4_m_i,

    // Outputs to MEM/WB Register
    output logic       reg_write_w_o,
    output logic [1:0] result_src_w_o,
    // mem_write is consumed here

    output logic [`DATA_WIDTH-1:0]     read_data_w_o,  // Data read from memory
    output logic [`DATA_WIDTH-1:0]     alu_result_w_o, // ALU result passed through
    output logic [`REG_ADDR_WIDTH-1:0] rd_addr_w_o,
    output logic [`DATA_WIDTH-1:0]     pc_plus_4_w_o
);

    logic [`DATA_WIDTH-1:0] mem_read_data_internal;

    // Data Memory Instance
    data_memory u_data_memory (
        .clk            (clk),
        .rst_n          (rst_n),
        .addr_i         (alu_result_m_i),   // Address is ALU result
        .write_data_i   (rs2_data_m_i),     // Data to write is from rs2
        .mem_write_en_i (mem_write_m_i),    // Write enable
        .funct3_i       (funct3_m_i),       // For store type (SB/SH/SW/SD) and load type
        .read_data_o    (mem_read_data_internal) // Data read
    );

    // Pass through control signals
    assign reg_write_w_o  = reg_write_m_i;
    assign result_src_w_o = result_src_m_i;

    // Pass through data
    assign read_data_w_o  = mem_read_data_internal;
    assign alu_result_w_o = alu_result_m_i;
    assign rd_addr_w_o    = rd_addr_m_i;
    assign pc_plus_4_w_o  = pc_plus_4_m_i;

endmodule