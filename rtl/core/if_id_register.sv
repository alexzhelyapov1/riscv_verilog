`include "common/defines.svh"

module if_id_register (
    input  logic clk,
    input  logic rst_n,

    // Control signals from Hazard Unit
    input  logic stall_d, // Stall: keeps current values
    input  logic flush_d, // Flush: clears register (outputs NOP-like values)

    // Data inputs from Fetch Stage
    input  logic [`INSTR_WIDTH-1:0] instr_f_i,
    input  logic [`DATA_WIDTH-1:0]  pc_plus_4_f_i,
    input  logic [`DATA_WIDTH-1:0]  pc_f_i,          // Current PC from Fetch

    // Data outputs to Decode Stage
    output logic [`INSTR_WIDTH-1:0] instr_id_o,
    output logic [`DATA_WIDTH-1:0]  pc_plus_4_id_o,
    output logic [`DATA_WIDTH-1:0]  pc_id_o           // Current PC to Decode
);

    // NOP instruction (addi x0, x0, 0) for RISC-V
    localparam NOP_INSTRUCTION = `INSTR_WIDTH'h00000013;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_id_o     <= NOP_INSTRUCTION;
            pc_plus_4_id_o <= {`DATA_WIDTH{1'b0}};
            pc_id_o        <= {`DATA_WIDTH{1'b0}};
        end else if (flush_d) begin
            instr_id_o     <= NOP_INSTRUCTION; // Flush with NOP
            pc_plus_4_id_o <= {`DATA_WIDTH{1'b0}}; // Or a defined "safe" PC+4
            pc_id_o        <= {`DATA_WIDTH{1'b0}}; // Or a defined "safe" PC
        end else if (!stall_d) begin // If not stalled and not flushed, pass inputs
            instr_id_o     <= instr_f_i;
            pc_plus_4_id_o <= pc_plus_4_f_i;
            pc_id_o        <= pc_f_i;
        end
        // If stalled (stall_d = 1) and not flushed, register holds its value
    end

endmodule