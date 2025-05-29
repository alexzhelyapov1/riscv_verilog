`include "common/pipeline_types.svh"

module fetch #(
    parameter string INSTR_MEM_INIT_FILE_PARAM = "",
    parameter logic [`DATA_WIDTH-1:0] PC_INIT_VALUE_PARAM = `PC_RESET_VALUE
)(
    input  logic clk,
    input  logic rst_n,
    input  logic                       stall_f_i,
    input  logic                       pc_src_e_i,
    input  logic [`DATA_WIDTH-1:0]     pc_target_e_i,

    output if_id_data_t                if_id_data_o
);

    logic [`DATA_WIDTH-1:0] pc_reg;
    logic [`DATA_WIDTH-1:0] pc_next;
    logic [`DATA_WIDTH-1:0] pc_plus_4_temp;
    logic [`INSTR_WIDTH-1:0] instr_mem_data;

    instruction_memory #(
        .INSTR_MEM_INIT_FILE_PARAM(INSTR_MEM_INIT_FILE_PARAM)
    ) i_instr_mem (
        .address     (pc_reg),
        .instruction (instr_mem_data)
    );

    assign pc_plus_4_temp = pc_reg + 4;
    assign pc_next = pc_src_e_i ? pc_target_e_i : pc_plus_4_temp;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= PC_INIT_VALUE_PARAM;
        end else if (!stall_f_i) begin
            pc_reg <= pc_next;
        end
    end

    assign if_id_data_o.instr      = instr_mem_data;
    assign if_id_data_o.pc         = pc_reg;
    assign if_id_data_o.pc_plus_4  = pc_plus_4_temp;

endmodule