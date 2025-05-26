`include "common/defines.svh"

module fetch (
    input  logic clk,
    input  logic rst_n,

    // Control signals from Hazard Unit / Execute Stage
    input  logic                       stall_f,     // Stall PC and instruction fetch
    input  logic                       pc_src_e,    // Selects PC source (PC+4 or branch/jump target)
    input  logic [`DATA_WIDTH-1:0]     pc_target_e, // Branch/jump target address from EX stage

    // Outputs to IF/ID pipeline register
    output logic [`INSTR_WIDTH-1:0]    instr_f_o,
    output logic [`DATA_WIDTH-1:0]     pc_plus_4_f_o,
    output logic [`DATA_WIDTH-1:0]     pc_f_o          // Current PC fetched
);

    logic [`DATA_WIDTH-1:0] pc_reg;
    logic [`DATA_WIDTH-1:0] pc_next;
    logic [`DATA_WIDTH-1:0] pc_plus_4_temp;

    // Instruction Memory instance
    instruction_memory i_instr_mem (
        .address     (pc_reg),
        .instruction (instr_f_o)
    );

    // Adder for PC + 4
    assign pc_plus_4_temp = pc_reg + 4;

    // MUX for next PC selection
    assign pc_next = pc_src_e ? pc_target_e : pc_plus_4_temp;

    // PC Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= {`DATA_WIDTH{1'b0}}; // Reset PC to 0
        end else if (!stall_f) begin // If not stalled, update PC
            pc_reg <= pc_next;
        end
        // If stalled (stall_f = 1), PC holds its value
    end

    assign pc_plus_4_f_o = pc_plus_4_temp;
    assign pc_f_o        = pc_reg; // Output current PC

endmodule