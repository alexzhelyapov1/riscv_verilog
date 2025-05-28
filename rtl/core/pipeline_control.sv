// rtl/core/pipeline_control.sv
`include "common/pipeline_types.svh"

module pipeline_control (
    // Inputs from various pipeline stages (latched values in pipeline.sv)
    input  if_id_data_t    if_id_data_i,     // For rs1_addr_d, rs2_addr_d (extracted from instr)
    input  id_ex_data_t    id_ex_data_i,     // For RdE, RegWriteE, ResultSrcE (load-use) and Rs1E, Rs2E (for forwarding)
    input  ex_mem_data_t   ex_mem_data_i,    // For RdM, RegWriteM (forwarding)
    input  mem_wb_data_t   mem_wb_data_i,    // For RdW, RegWriteW (forwarding)

    input  logic           pc_src_from_ex_i, // PCSrcE from Execute stage output

    // Output structure with all hazard control signals
    output hazard_control_t hazard_ctrl_o
);

    logic load_use_hazard;
    logic is_load_in_ex; // This is RdE, MemReadE

    // Extract rs1_addr and rs2_addr for the instruction currently in Decode stage,
    // which will be in Execute stage when these forwarding/stall signals are applied.
    // These correspond to Rs1D and Rs2D from the diagram for load-use hazard detection.
    logic [`REG_ADDR_WIDTH-1:0] rs1_addr_d_from_instr; // This is Rs1_ID
    logic [`REG_ADDR_WIDTH-1:0] rs2_addr_d_from_instr; // This is Rs2_ID

    assign rs1_addr_d_from_instr = if_id_data_i.instr[19:15]; // Correct: rs1 of instruction in ID
    assign rs2_addr_d_from_instr = if_id_data_i.instr[24:20]; // Correct: rs2 of instruction in ID


    // ** 1. Load-Use Hazard Detection & Stall Generation **
    // An instruction in EX is a load, and its destination (RdE) is a source for an instruction in ID.
    assign is_load_in_ex = (id_ex_data_i.result_src == 2'b01); // Data from memory -> indicates a Load instruction in EX

    // load_use_hazard occurs if instruction in EX is a load, it writes to a register (RdE != x0),
    // AND that RdE is a source (Rs1D or Rs2D) for the instruction currently in Decode.
    assign load_use_hazard = is_load_in_ex && id_ex_data_i.reg_write && (id_ex_data_i.rd_addr != 0) &&
                             ((id_ex_data_i.rd_addr == rs1_addr_d_from_instr) || (id_ex_data_i.rd_addr == rs2_addr_d_from_instr));

    assign hazard_ctrl_o.stall_f = load_use_hazard; // Stall PC and IF/ID fetch
    assign hazard_ctrl_o.stall_d = load_use_hazard; // Stall IF/ID register (holds current content), preventing ID stage from getting new instr.

    // ** 2. Flush Generation **
    // FlushD (IF/ID output becomes NOP): if branch/jump taken in EX.
    // FlushE (ID/EX output becomes NOP): if load-use stall OR branch/jump taken in EX.
    assign hazard_ctrl_o.flush_d = pc_src_from_ex_i; // Correct: Flush instruction in Decode if branch taken
    assign hazard_ctrl_o.flush_e = load_use_hazard || pc_src_from_ex_i; // Correct: Flush instruction in Execute


    // ** 3. Forwarding Logic **
    // Forwarding for instruction currently in Execute stage.
    // Rs1E and Rs2E for the current EX instruction are id_ex_data_i.rs1_addr and id_ex_data_i.rs2_addr.

    // Forward for Operand A (connected to ALU operand A input in Execute)
    always_comb begin
        hazard_ctrl_o.forward_a_e = 2'b00; // Default: No forward

        // Check EX/MEM stage hazard: if instr in MEM writes to RdM, and RdM is Rs1 of instr in EX
        // AND the result from EX/MEM is NOT from a memory read (i.e., it's an ALU result suitable for forwarding)
        if (ex_mem_data_i.reg_write && (ex_mem_data_i.rd_addr != 5'd0) && (ex_mem_data_i.rd_addr == id_ex_data_i.rs1_addr) &&
             (ex_mem_data_i.result_src != 2'b01) ) begin // <-- ADDED CHECK: Not a memory read result
            hazard_ctrl_o.forward_a_e = 2'b10; // Forward ALU_Result from EX/MEM
        end
        // Check MEM/WB stage hazard: if instr in WB writes to RdW, and RdW is Rs1 of instr in EX
        // (and not already covered by EX/MEM forward)
        else if (mem_wb_data_i.reg_write && (mem_wb_data_i.rd_addr != 0) &&
                 (mem_wb_data_i.rd_addr == id_ex_data_i.rs1_addr)) begin
            // Data from MEM/WB (mem_wb_data_i) can be either ALU result or Memory Read Data, selected by its own result_src.
            // The rf_write_data_from_wb.result_to_rf in pipeline.sv already handles this selection.
            hazard_ctrl_o.forward_a_e = 2'b01; // Forward final result from MEM/WB
        end
    end

    // Forward for Operand B (connected to ALU operand B input in Execute, if not an immediate)
    always_comb begin
        hazard_ctrl_o.forward_b_e = 2'b00; // Default: No forward

        if (ex_mem_data_i.reg_write && (ex_mem_data_i.rd_addr != 0) &&
            (ex_mem_data_i.rd_addr == id_ex_data_i.rs2_addr) &&
            (ex_mem_data_i.result_src != 2'b01) ) begin // <-- ADDED CHECK
            hazard_ctrl_o.forward_b_e = 2'b10; // Forward ALU_Result from EX/MEM
        end
        else if (mem_wb_data_i.reg_write && (mem_wb_data_i.rd_addr != 0) &&
                 (mem_wb_data_i.rd_addr == id_ex_data_i.rs2_addr)) begin
            hazard_ctrl_o.forward_b_e = 2'b01; // Forward final result from MEM/WB
        end
    end
endmodule