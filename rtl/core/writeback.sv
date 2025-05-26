// rtl/core/writeback.sv
`include "common/defines.svh"

module writeback_stage ( // Renamed to writeback_stage for clarity
    // Inputs from MEM/WB Register
    input  logic [1:0] result_src_wb_i,   // Selects the source for writeback data

    input  logic [`DATA_WIDTH-1:0]     read_data_wb_i,  // Data read from memory
    input  logic [`DATA_WIDTH-1:0]     alu_result_wb_i, // Result from ALU
    input  logic [`DATA_WIDTH-1:0]     pc_plus_4_wb_i,  // PC+4 for JAL/JALR

    // Outputs that go to the Register File's write port
    // (These will be connected to register_file instance in the top pipeline module)
    output logic [`DATA_WIDTH-1:0]     result_w_o       // Data to be written to register file
);

    // MUX to select the data to be written back to the register file
    always_comb begin
        case (result_src_wb_i)
            2'b00:  result_w_o = alu_result_wb_i;    // Result from ALU
            2'b01:  result_w_o = read_data_wb_i;     // Data from memory
            2'b10:  result_w_o = pc_plus_4_wb_i;     // PC+4 for JAL/JALR
            default: result_w_o = `DATA_WIDTH'('x); // Should not happen with valid control
        endcase
    end

    // The following signals are also part of the Writeback "stage" conceptually,
    // but they are passed directly from MEM/WB to the register file in the top module:
    // - reg_write_wb_i (from MEM/WB) -> to register_file.rd_write_en_wb_i
    // - rd_addr_wb_i   (from MEM/WB) -> to register_file.rd_addr_wb_i

endmodule