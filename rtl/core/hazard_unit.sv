`include "common/defines.svh"

module hazard_unit (
    input  logic [`REG_ADDR_WIDTH-1:0] rs1_addr_ex_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rs2_addr_ex_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_ex_i,
    input  logic                       result_src_ex0_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rs1_addr_id_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rs2_addr_id_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_mem_i,
    input  logic                       reg_write_mem_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_wb_i,
    input  logic                       reg_write_wb_i,
    input  logic                       pc_src_ex_i,

    output logic [1:0]                 forward_a_ex_o,
    output logic [1:0]                 forward_b_ex_o,
    output logic                       stall_fetch_o,
    output logic                       stall_decode_o,
    output logic                       flush_decode_o,
    output logic                       flush_execute_o
);

    logic lw_stall_internal;

    always_comb begin
        if (reg_write_mem_i && (rd_addr_mem_i != `REG_ADDR_WIDTH'(0)) && (rd_addr_mem_i == rs1_addr_ex_i)) begin
            forward_a_ex_o = 2'b10;
        end else if (reg_write_wb_i && (rd_addr_wb_i != `REG_ADDR_WIDTH'(0)) && (rd_addr_wb_i == rs1_addr_ex_i)) begin
            forward_a_ex_o = 2'b01;
        end else begin
            forward_a_ex_o = 2'b00;
        end

        if (reg_write_mem_i && (rd_addr_mem_i != `REG_ADDR_WIDTH'(0)) && (rd_addr_mem_i == rs2_addr_ex_i)) begin
            forward_b_ex_o = 2'b10;
        end else if (reg_write_wb_i && (rd_addr_wb_i != `REG_ADDR_WIDTH'(0)) && (rd_addr_wb_i == rs2_addr_ex_i)) begin
            forward_b_ex_o = 2'b01;
        end else begin
            forward_b_ex_o = 2'b00;
        end

        lw_stall_internal = result_src_ex0_i &&
                            ( (rs1_addr_id_i == rd_addr_ex_i && rs1_addr_id_i != `REG_ADDR_WIDTH'(0) ) ||
                              (rs2_addr_id_i == rd_addr_ex_i && rs2_addr_id_i != `REG_ADDR_WIDTH'(0) ) );

        lw_stall_internal = result_src_ex0_i && (rd_addr_ex_i != `REG_ADDR_WIDTH'(0)) &&
                           ( (rs1_addr_id_i == rd_addr_ex_i) ||
                             (rs2_addr_id_i == rd_addr_ex_i) );

        stall_fetch_o  = lw_stall_internal;
        stall_decode_o = lw_stall_internal;

        flush_decode_o = pc_src_ex_i;
        flush_execute_o = lw_stall_internal || pc_src_ex_i;
    end

endmodule