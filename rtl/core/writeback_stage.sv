// rtl/core/writeback_stage.sv
`include "common/pipeline_types.svh"

module writeback_stage (
    // Input from Memory (latched by MEM/WB register in pipeline.sv)
    input  mem_wb_data_t           mem_wb_data_i,

    // Output to Register File write port (directly connected in pipeline.sv)
    output rf_write_data_t         rf_write_data_o
);

    logic [`DATA_WIDTH-1:0] result_selected_for_rf;

    // MUX to select the data to be written back to the register file
    always_comb begin
        case (mem_wb_data_i.result_src)
            2'b00:  result_selected_for_rf = mem_wb_data_i.alu_result;    // Result from ALU
            2'b01:  result_selected_for_rf = mem_wb_data_i.read_data_mem; // Data from memory
            2'b10:  result_selected_for_rf = mem_wb_data_i.pc_plus_4;     // PC+4 for JAL/JALR
            default: result_selected_for_rf = `DATA_WIDTH'('x); // Should not happen
        endcase
    end

    // Assign outputs for the register file write data structure
    assign rf_write_data_o.reg_write_en = mem_wb_data_i.reg_write;
    assign rf_write_data_o.rd_addr      = mem_wb_data_i.rd_addr;
    assign rf_write_data_o.result_to_rf = result_selected_for_rf;

endmodule