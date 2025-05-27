// rtl/core/pipeline_control.sv
`include "common/defines.svh"
// `include "common/control_signals_defines.svh" // Если нужны enum для Forward MUX

module pipeline_control (
    // Inputs from IF/ID Stage (register addresses read in Decode)
    input  logic [`REG_ADDR_WIDTH-1:0] rs1_addr_d_i, // Rs1D on diagram
    input  logic [`REG_ADDR_WIDTH-1:0] rs2_addr_d_i, // Rs2D on diagram

    // Inputs from ID/EX Stage (destination register and control signals from Execute)
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_e_i,    // RdE
    input  logic                       reg_write_e_i,  // RegWriteE
    input  logic [1:0]                 result_src_e_i, // ResultSrcE (bit 0 indicates load if =1 for ResultSrc=MemRead)

    // Inputs from EX/MEM Stage
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_m_i,    // RdM
    input  logic                       reg_write_m_i,  // RegWriteM

    // Inputs from MEM/WB Stage (for forwarding, as per diagram)
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_w_i,    // RdW
    input  logic                       reg_write_w_i,  // RegWriteW

    // Input from Execute Stage indicating branch taken or jump
    input  logic                       pc_src_e_i,     // PCSrcE

    // Outputs to control the pipeline
    output logic                       stall_f_o,      // Stall PC and IF/ID input
    output logic                       stall_d_o,      // Stall IF/ID register (keep current values)
    output logic                       flush_d_o,      // Clear IF/ID register
    output logic                       flush_e_o,      // Clear ID/EX register

    output logic [1:0]                 forward_a_e_o,  // Forwarding MUX select for ALU OpA
                                                     // 00: No forward (from ID/EX rs1_data)
                                                     // 01: Forward from EX/MEM (ALUResultM or PCPlus4M if JAL/JALR was in EX)
                                                     // 10: Forward from MEM/WB (ResultW)
    output logic [1:0]                 forward_b_e_o   // Forwarding MUX select for ALU OpB
);

    // Internal signals for hazards
    logic load_use_hazard;

    // ** 1. Load-Use Hazard Detection & Stall Generation **
    // Stall if instruction in Decode uses a register that an instruction in Execute
    // is loading from memory.
    // ResultSrcE[0] is 1 if ResultSrcE is MEM_READ (01) or PC_PLUS_4 (10).
    // We are interested in MEM_READ (01). So ResultSrcE == 2'b01.
    // Let's assume ResultSrcE[0] = 1 implies a memory read for simplicity as per some diagrams,
    // OR more accurately, if (ResultSrcE == 2'b01) which means data from memory.
    // The diagram uses ResultSrcE0 (bit 0 of ResultSrcE).
    // If ResultSrcE = 01 (MemRead), then ResultSrcE[0] = 1.
    // If ResultSrcE = 10 (PC+4), then ResultSrcE[0] = 0. This is not a load.
    // So we need to be more specific: result_src_e_i == 2'b01 indicates a load.
    logic is_load_in_ex;
    assign is_load_in_ex = (result_src_e_i == 2'b01); // Data from memory for writeback

    assign load_use_hazard = is_load_in_ex && reg_write_e_i && (rd_addr_e_i != 0) &&
                             ((rd_addr_e_i == rs1_addr_d_i) || (rd_addr_e_i == rs2_addr_d_i));

    assign stall_f_o = load_use_hazard;
    assign stall_d_o = load_use_hazard; // Stall IF/ID, which means ID stage also stalls.

    // ** 2. Flush Generation **
    // FlushD: Clear IF/ID register if branch taken in EX or if load-use stall bubbles EX.
    // FlushE: Clear ID/EX register if branch taken in EX or if load-use stall.
    // The diagram says: FlushD = PCSrcE
    //                 FlushE = lwStall | PCSrcE
    assign flush_d_o = pc_src_e_i;
    assign flush_e_o = load_use_hazard || pc_src_e_i;


    // ** 3. Forwarding Logic **
    // ForwardAE / ForwardBE
    // Priority:
    // 1. EX/MEM hazard (if RegWriteE and RdE matches Rs1D/Rs2D)
    // 2. MEM/WB hazard (if RegWriteM and RdM matches Rs1D/Rs2D, and not covered by EX/MEM forward)
    // 3. (Diagram also shows WB/?? hazard if RegWriteW and RdW matches)

    // Forward for Operand A (rs1_addr_d_i)
    always_comb begin
        forward_a_e_o = 2'b00; // Default

        // EX/MEM Hazard (data from instruction currently in MEM stage)
        if (reg_write_m_i && (rd_addr_m_i != 0) && (rd_addr_m_i == rs1_addr_d_i)) begin
            forward_a_e_o = 2'b10; // P&H diagram code for RdM path
        end
        // MEM/WB Hazard (data from instruction currently in WB stage)
        // This path is taken only if the EX/MEM hazard doesn't apply to this rs1.
        else if (reg_write_w_i && (rd_addr_w_i != 0) && (rd_addr_w_i == rs1_addr_d_i)) begin
            forward_a_e_o = 2'b01; // P&H diagram code for RdW path
        end
    end

    // Forward for Operand B (rs2_addr_d_i)
    always_comb begin
        forward_b_e_o = 2'b00; // Default

        if (reg_write_m_i && (rd_addr_m_i != 0) && (rd_addr_m_i == rs2_addr_d_i)) begin
            forward_b_e_o = 2'b10;
        end
        else if (reg_write_w_i && (rd_addr_w_i != 0) && (rd_addr_w_i == rs2_addr_d_i)) begin
            forward_b_e_o = 2'b01;
        end
    end

    // The diagram also shows ForwardAE/BE signals from EX stage (RdE).
    // This would be for an instruction in EX forwarding its result to a *subsequent* cycle's EX stage,
    // which is effectively what the reg_write_m_i/rd_addr_m_i path handles (as this instruction moves to MEM).
    // The diagram text "if ((Rs1E == RdM) & RegWriteM)..." means Rs1 of *current EX* vs Rd of *instr in MEM*.
    // The diagram text "if ((Rs1E == RdW) & RegWriteW)..." means Rs1 of *current EX* vs Rd of *instr in WB*.
    // There is no explicit "Rs1E == RdE" forwarding in the text snippet on the diagram for ForwardAE/BE.
    // However, if an ALU op in EX immediately needs its own result (not possible in simple pipeline)
    // or if there's a very tight loop not handled by these, more forwarding might be needed.
    // The standard P&H 5-stage forwarding covers EX/MEM->EX and MEM/WB->EX.

endmodule