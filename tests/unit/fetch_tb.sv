`include "common/defines.svh"

module fetch_tb (
    input  logic clk,
    input  logic rst_n,

    // Inputs to control fetch stage behavior
    input  logic                       i_stall_f,
    input  logic                       i_pc_src_e,
    input  logic [`DATA_WIDTH-1:0]     i_pc_target_e,
    input  logic                       i_stall_d,
    input  logic                       i_flush_d,

    // Outputs from IF/ID register (to observe)
    output logic [`INSTR_WIDTH-1:0]    o_instr_id,
    output logic [`DATA_WIDTH-1:0]     o_pc_plus_4_id,
    output logic [`DATA_WIDTH-1:0]     o_pc_id,
    output logic [`DATA_WIDTH-1:0]     o_current_pc_f // For observing PC in fetch stage itself
);

    logic [`INSTR_WIDTH-1:0]    instr_f_val;
    logic [`DATA_WIDTH-1:0]     pc_plus_4_f_val;
    logic [`DATA_WIDTH-1:0]     pc_f_val;

    fetch u_fetch (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall_f        (i_stall_f),
        .pc_src_e       (i_pc_src_e),
        .pc_target_e    (i_pc_target_e),
        .instr_f_o      (instr_f_val),
        .pc_plus_4_f_o  (pc_plus_4_f_val),
        .pc_f_o         (pc_f_val)
    );

    assign o_current_pc_f = pc_f_val;

endmodule