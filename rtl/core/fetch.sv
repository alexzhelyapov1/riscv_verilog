// rtl/core/fetch.sv
`include "common/pipeline_types.svh" // Includes common/defines.svh indirectly

module fetch (
    input  logic clk,
    input  logic rst_n,

    // Control signals
    input  logic                       stall_f_i,
    input  logic                       pc_src_e_i,         // From Execute: select PC source
    input  logic [`DATA_WIDTH-1:0]     pc_target_e_i,      // From Execute: target address for branch/jump

    // Output to Decode (via pipeline register in top)
    output if_id_data_t                if_id_data_o
);

    logic [`DATA_WIDTH-1:0] pc_reg;
    logic [`DATA_WIDTH-1:0] pc_next;
    logic [`DATA_WIDTH-1:0] pc_plus_4_temp;
    logic [`INSTR_WIDTH-1:0] instr_mem_data;

    instruction_memory i_instr_mem (
        .address     (pc_reg), // Use current PC for fetch
        .instruction (instr_mem_data)
    );

    assign pc_plus_4_temp = pc_reg + 4;
    assign pc_next = pc_src_e_i ? pc_target_e_i : pc_plus_4_temp;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= `PC_RESET_VALUE;
        end else if (!stall_f_i) begin
            pc_reg <= pc_next;
        end
        // If stall_f_i is asserted, pc_reg holds its value
    end

    // Assign outputs for the current cycle
    // These values will be latched by the IF/ID pipeline register in the main pipeline module
    assign if_id_data_o.instr      = instr_mem_data;
    assign if_id_data_o.pc         = pc_reg;         // PC of the fetched instruction
    assign if_id_data_o.pc_plus_4  = pc_plus_4_temp; // PC+4 of the fetched instruction

endmodule