`include "common/defines.svh"

module register_file (
    input  logic clk,
    input  logic rst_n,

    // Read Port 1
    input  logic [`REG_ADDR_WIDTH-1:0] rs1_addr_i,
    output logic [`DATA_WIDTH-1:0]     rs1_data_o,

    // Read Port 2
    input  logic [`REG_ADDR_WIDTH-1:0] rs2_addr_i,
    output logic [`DATA_WIDTH-1:0]     rs2_data_o,

    // Write Port (from Writeback stage)
    input  logic                       rd_write_en_wb_i, // RegWriteW
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_wb_i,    // RdW
    input  logic [`DATA_WIDTH-1:0]     rd_data_wb_i     // ResultW
);

    // 32 registers, each DATA_WIDTH bits wide
    // reg[0] is hardwired to zero
    logic [`DATA_WIDTH-1:0] regs[31:0];

    // Asynchronous read for rs1_data_o and rs2_data_o
    // Reading register 0 always yields 0
    assign rs1_data_o = (rs1_addr_i == `REG_ADDR_WIDTH'(0)) ? `DATA_WIDTH'(0) : regs[rs1_addr_i];
    assign rs2_data_o = (rs2_addr_i == `REG_ADDR_WIDTH'(0)) ? `DATA_WIDTH'(0) : regs[rs2_addr_i];

    // Synchronous write on positive clock edge
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers to 0 on reset (optional, good for simulation)
            for (int i = 0; i < 32; i++) begin
                regs[i] <= `DATA_WIDTH'(0);
            end
        end else begin
            if (rd_write_en_wb_i && (rd_addr_wb_i != `REG_ADDR_WIDTH'(0))) begin
                regs[rd_addr_wb_i] <= rd_data_wb_i;
            end
        end
    end

    // For simulation, to observe register values (not synthesizable this way usually for direct tb access)
    // Or use DPI for more robust testbench access
`ifdef VERILATOR
    // Provide a way to dump registers for Verilator testing if needed
    // This is a simplification; direct access for writing/reading from testbench
    // might be complex or require specific Verilator features like public_flat.
`endif

endmodule