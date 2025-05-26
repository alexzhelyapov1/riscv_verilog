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
        forward_a_e_o = 2'b00; // Default: no forwarding
        // EX/MEM to EX forwarding for OpA
        if (reg_write_e_i && (rd_addr_e_i != 0) && (rd_addr_e_i == rs1_addr_d_i)) begin
            forward_a_e_o = 2'b01; // Forward ALUResultM (or PC+4 if it was JAL/JALR)
        end
        // MEM/WB to EX forwarding for OpA (if not already forwarded from EX/MEM)
        // And if rs1 is not x0
        else if (reg_write_m_i && (rd_addr_m_i != 0) && (rd_addr_m_i == rs1_addr_d_i)) begin
            forward_a_e_o = 2'b10; // Forward ResultW (from MEM/WB, could be ALURes or MemData)
        end
        // MEM/WB stage is one cycle later than EX/MEM stage
        // The diagram P&H 7.61 shows forward from RdW as well, let's add that for completeness of the diagram.
        // This would be for data available at the very end of MEM/WB, to be used by an instruction now in EX.
        // This means data from an instruction that is TWO cycles ahead of the current EX instruction.
        // This is typically handled by the MEM/WB forwarding (my case 2'b10).
        // The diagram's logic:
        // if ((Rs1E == RdM) & RegWriteM) & (Rs1E != 0)) then ForwardAE = 10
        // else if ((Rs1E == RdW) & RegWriteW) & (Rs1E != 0)) then ForwardAE = 01
        // This implies RdM path has priority over RdW. My logic above does this.
        // The diagram uses 10 for RdM and 01 for RdW for ForwardAE. Let's match that.
        // My `reg_write_e_i` / `rd_addr_e_i` are from ID/EX register, feeding into current EX stage.
        // My `reg_write_m_i` / `rd_addr_m_i` are from EX/MEM register, feeding into current MEM stage.
        // My `reg_write_w_i` / `rd_addr_w_i` are from MEM/WB register, feeding into current WB stage.

        // Correcting based on typical P&H diagram forwarding paths:
        // Path 1: ALU result from instruction in EX stage (now in MEM stage) to current EX stage
        // Path 2: Data from instruction in MEM stage (now in WB stage) to current EX stage

        // Source for ForwardAE = 01 is ALUResultM or ReadDataM from instruction in MEM stage
        // Source for ForwardAE = 10 is ResultW from instruction in WB stage

        // Re-evaluating my signal names vs diagram:
        // My rs1_addr_d_i is Rs1D (or Rs1E on diagram if referring to inputs of EX's ALU).
        // Let's use Rs1D, Rs2D for inputs to Hazard Unit from Decode outputs.
        // RdE, RegWriteE are from ID/EX register (instr currently in EX).
        // RdM, RegWriteM are from EX/MEM register (instr currently in MEM).
        // RdW, RegWriteW are from MEM/WB register (instr currently in WB).

        // Forwarding to current EX stage for operand Rs1D:
        // Priority 1: Data from instruction finishing EX stage (now in EX/MEM reg)
        // This is not directly shown as a separate forward path on the diagram for Rs1D/Rs2D,
        // because the EX stage calculation itself isn't finished to be forwarded back to its own input.
        // Forwarding is from *later* stages to an *earlier* stage's inputs.
        // So, for an instruction currently in EX, we need data from instructions in MEM or WB.

        // Forward from MEM stage to EX stage (for Rs1D)
        // If instr in MEM writes to RdM, and RdM == Rs1D
        if (reg_write_m_i && (rd_addr_m_i != 0) && (rd_addr_m_i == rs1_addr_d_i)) begin
            forward_a_e_o = 2'b01; // Use value from end of MEM stage (ALUResultM or ReadDataM via MEM/WB reg)
                                   // Diagram shows this as ForwardAE=10 (RdM path)
        end
        // Forward from WB stage to EX stage (for Rs1D), if not covered by MEM stage forward
        else if (reg_write_w_i && (rd_addr_w_i != 0) && (rd_addr_w_i == rs1_addr_d_i)) begin
            forward_a_e_o = 2'b10; // Use value from end of WB stage (ResultW)
                                   // Diagram shows this as ForwardAE=01 (RdW path)
        end
        // Note: The encoding 01 vs 10 for MEM vs WB might be arbitrary, what matters is distinct values.
        // I will use 01 for MEM->EX and 10 for WB->EX to make it different from the diagram if my interpretation is different.
        // Let's stick to diagram: ForwardAE = 10 for (EX/MEM data -> EX input), ForwardAE = 01 for (MEM/WB data -> EX input)
        // My 'reg_write_m_i' is from instruction currently IN memory stage (output of EX/MEM). So this is the EX/MEM -> EX path.
        // My 'reg_write_w_i' is from instruction currently IN WB stage (output of MEM/WB). So this is the MEM/WB -> EX path.

        // Re-assigning based on diagram's numbering for ForwardAE:
        // RdM path (data from EX/MEM register, for instruction in MEM stage) has code 10
        // RdW path (data from MEM/WB register, for instruction in WB stage) has code 01
        forward_a_e_o = 2'b00; // Default
        if (reg_write_m_i && (rd_addr_m_i != 0) && (rd_addr_m_i == rs1_addr_d_i)) begin
            forward_a_e_o = 2'b10; // Forward from MEM stage output (EX/MEM pipeline reg content)
        end
        else if (reg_write_w_i && (rd_addr_w_i != 0) && (rd_addr_w_i == rs1_addr_d_i)) begin
            forward_a_e_o = 2'b01; // Forward from WB stage output (MEM/WB pipeline reg content)
        end
    end

    // Forward for Operand B (rs2_addr_d_i)
    always_comb begin
        forward_b_e_o = 2'b00; // Default: no forwarding
        // Forward from MEM stage to EX stage (for Rs2D)
        if (reg_write_m_i && (rd_addr_m_i != 0) && (rd_addr_m_i == rs2_addr_d_i)) begin
            forward_b_e_o = 2'b10; // Forward from MEM stage output
        end
        // Forward from WB stage to EX stage (for Rs2D), if not covered by MEM stage forward
        else if (reg_write_w_i && (rd_addr_w_i != 0) && (rd_addr_w_i == rs2_addr_d_i)) begin
            forward_b_e_o = 2'b01; // Forward from WB stage output
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