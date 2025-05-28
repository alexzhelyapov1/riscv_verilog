// rtl/core/memory_stage.sv
`include "common/pipeline_types.svh"

module memory_stage (
    input  logic clk,
    input  logic rst_n,

    // Input from Execute (latched by EX/MEM register in pipeline.sv)
    input  ex_mem_data_t           ex_mem_data_i,

    // Output to Writeback (to be latched by MEM/WB register in pipeline.sv)
    output mem_wb_data_t           mem_wb_data_o
);

    logic [`DATA_WIDTH-1:0] mem_read_data_internal;

    // Data Memory Instance
    // Parameters for data_memory (like DATA_MEM_INIT_FILE) will be set
    // when data_memory is instantiated within this module, or if data_memory
    // itself is parameterized and those parameters are passed down from the top.
    // For now, assuming default data_memory instantiation.
    data_memory u_data_memory (
        .clk            (clk),
        .rst_n          (rst_n),
        .addr_i         (ex_mem_data_i.alu_result),   // Address from ALU result in EX stage
        .write_data_i   (ex_mem_data_i.rs2_data),     // Data to write is from rs2 (passed through EX)
        .mem_write_en_i (ex_mem_data_i.mem_write),    // Write enable from control unit (passed through EX)
        .funct3_i       (ex_mem_data_i.funct3),       // For load/store type and size
        .read_data_o    (mem_read_data_internal)      // Data read from memory
    );

    // Assign outputs to MEM/WB data structure
    // Control signals passed through
    assign mem_wb_data_o.reg_write      = ex_mem_data_i.reg_write;
    assign mem_wb_data_o.result_src     = ex_mem_data_i.result_src;

    // Data
    assign mem_wb_data_o.read_data_mem  = mem_read_data_internal;
    assign mem_wb_data_o.alu_result     = ex_mem_data_i.alu_result; // Pass ALU result through
    assign mem_wb_data_o.pc_plus_4      = ex_mem_data_i.pc_plus_4;  // Pass PC+4 through

    // Register address passed through
    assign mem_wb_data_o.rd_addr        = ex_mem_data_i.rd_addr;

endmodule