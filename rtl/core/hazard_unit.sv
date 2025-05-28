// rtl/core/hazard_unit.sv
`include "common/defines.svh"

module hazard_unit (
    // Inputs from ID/EX register values (current EX stage instruction)
    input  logic [`REG_ADDR_WIDTH-1:0] rs1_addr_ex_i,    // Rs1E from id_ex_data_q.rs1_addr
    input  logic [`REG_ADDR_WIDTH-1:0] rs2_addr_ex_i,    // Rs2E from id_ex_data_q.rs2_addr
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_ex_i,     // RdE from id_ex_data_q.rd_addr
    input  logic                       result_src_ex0_i, // LSB of ResultSrc from id_ex_data_q.result_src[0] (1 if load)

    // Inputs from instruction in ID stage (next EX stage instruction if not stalled/flushed)
    input  logic [`REG_ADDR_WIDTH-1:0] rs1_addr_id_i,    // Rs1D from decode.rs1_addr_d_o
    input  logic [`REG_ADDR_WIDTH-1:0] rs2_addr_id_i,    // Rs2D from decode.rs2_addr_d_o

    // Inputs from EX/MEM register values
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_mem_i,     // RdM from ex_mem_data_q.rd_addr
    input  logic                       reg_write_mem_i,   // RegWriteM from ex_mem_data_q.reg_write

    // Inputs from MEM/WB register values
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_wb_i,     // RdW from mem_wb_data_q.rd_addr
    input  logic                       reg_write_wb_i,   // RegWriteW from mem_wb_data_q.reg_write

    // Input from Execute stage output
    input  logic                       pc_src_ex_i,       // PCSrcE from execute.pc_src_o

    // Outputs for pipeline control
    output logic [1:0]                 forward_a_ex_o,
    output logic [1:0]                 forward_b_ex_o,
    output logic                       stall_fetch_o,
    output logic                       stall_decode_o,
    output logic                       flush_decode_o,
    output logic                       flush_execute_o
);

    logic lw_stall_internal;

    always_comb begin
        // Forwarding for Operand A in Execute Stage
        // Priority: MEM stage hazard, then WB stage hazard
        if (reg_write_mem_i && (rd_addr_mem_i != `REG_ADDR_WIDTH'(0)) && (rd_addr_mem_i == rs1_addr_ex_i)) begin
            forward_a_ex_o = 2'b10; // Forward from EX/MEM stage data path
        end else if (reg_write_wb_i && (rd_addr_wb_i != `REG_ADDR_WIDTH'(0)) && (rd_addr_wb_i == rs1_addr_ex_i)) begin
            forward_a_ex_o = 2'b01; // Forward from MEM/WB stage data path
        end else begin
            forward_a_ex_o = 2'b00; // No forwarding for Operand A
        end

        // Forwarding for Operand B in Execute Stage
        // Priority: MEM stage hazard, then WB stage hazard
        if (reg_write_mem_i && (rd_addr_mem_i != `REG_ADDR_WIDTH'(0)) && (rd_addr_mem_i == rs2_addr_ex_i)) begin
            forward_b_ex_o = 2'b10; // Forward from EX/MEM stage data path
        end else if (reg_write_wb_i && (rd_addr_wb_i != `REG_ADDR_WIDTH'(0)) && (rd_addr_wb_i == rs2_addr_ex_i)) begin
            forward_b_ex_o = 2'b01; // Forward from MEM/WB stage data path
        end else begin
            forward_b_ex_o = 2'b00; // No forwarding for Operand B
        end

        // Load-Use Stall detection (based on book's simpler logic)
        // Stall if:
        // 1. Instruction currently in EX stage (id_ex_data_q) is a load (result_src_ex0_i == 1'b1).
        // 2. Its destination register (rd_addr_ex_i) is one of the source registers (rs1_addr_id_i or rs2_addr_id_i)
        //    of the instruction currently in ID stage (if_id_data_q).
        lw_stall_internal = result_src_ex0_i &&
                            ( (rs1_addr_id_i == rd_addr_ex_i && rs1_addr_id_i != `REG_ADDR_WIDTH'(0) ) ||    // check rs1_addr_id_i is not x0
                              (rs2_addr_id_i == rd_addr_ex_i && rs2_addr_id_i != `REG_ADDR_WIDTH'(0) ) );   // check rs2_addr_id_i is not x0
        // Added checks for rsX_addr_id_i != 0 to prevent stalling if ID stage reads x0.
        // The rd_addr_ex_i != 0 check is implicitly handled if rsX_addr_id_i matches and is not x0.
        // If rd_addr_ex_i is x0, a load to x0 should not cause a stall if ID reads x0.
        // If rd_addr_ex_i is x0, and ID reads a non-x0 register, no match, no stall.
        // If rd_addr_ex_i is non-x0, and ID reads x0, no match, no stall.
        // The condition `rd_addr_ex_i != 0` is also important for loads to x0.
        // Let's refine: stall if load in EX writes to non-x0, and ID reads that non-x0.
        lw_stall_internal = result_src_ex0_i && (rd_addr_ex_i != `REG_ADDR_WIDTH'(0)) &&
                           ( (rs1_addr_id_i == rd_addr_ex_i) ||
                             (rs2_addr_id_i == rd_addr_ex_i) );
        // This version aligns with: stall if EX is load to actual reg (not x0), and ID reads that same reg.
        // The check `rsX_addr_id_i != 0` is implicitly covered because if `rsX_addr_id_i == 0`, it cannot match `rd_addr_ex_i` (which is !=0).

        stall_fetch_o  = lw_stall_internal; // Stall PC and IF/ID register fetch
        stall_decode_o = lw_stall_internal; // Stall IF/ID register latch (prevents ID from getting new instr)

        // Flush logic
        flush_decode_o = pc_src_ex_i; // Flush instruction in Decode if branch/jump taken in EX
        flush_execute_o = lw_stall_internal || pc_src_ex_i; // Flush instruction in Execute if load-use stall OR branch/jump taken
    end

endmodule