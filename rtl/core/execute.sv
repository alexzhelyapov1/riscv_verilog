// rtl/core/execute.sv
`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/riscv_opcodes.svh" // For FUNCT3 defines for branches
`include "common/control_signals_defines.svh"

module execute (
    // Inputs from ID/EX Register
    input  logic       reg_write_e_i,
    input  logic [1:0] result_src_e_i,
    input  logic       mem_write_e_i,
    input  logic       jump_e_i,
    input  logic       branch_e_i,
    input  logic       alu_src_e_i,      // Selects ALU Operand B (0: Reg_Rs2, 1: Imm)
    input  logic [`ALU_CONTROL_WIDTH-1:0] alu_control_e_i,
    input  logic [2:0] funct3_e_i,                // Pipelined funct3 from instruction
    input  alu_a_src_sel_e op_a_sel_e_i,       // Selects ALU Operand A's original source (RS1, PC, Zero)
    input  pc_target_src_sel_e pc_target_src_sel_e_i, // Selects PC Target calculation method

    input  logic [`DATA_WIDTH-1:0]  pc_e_i,
    input  logic [`DATA_WIDTH-1:0]  pc_plus_4_e_i,
    input  logic [`DATA_WIDTH-1:0]  rs1_data_e_i,   // Data from RF for Rs1 (before forwarding)
    input  logic [`DATA_WIDTH-1:0]  rs2_data_e_i,   // Data from RF for Rs2 (before forwarding)
    input  logic [`DATA_WIDTH-1:0]  imm_ext_e_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_e_i,

    // Inputs for Forwarding (from later stages, routed by top pipeline module)
    input  logic [`DATA_WIDTH-1:0]     forward_data_mem_i, // Data from EX/MEM output for forwarding
    input  logic [`DATA_WIDTH-1:0]     forward_data_wb_i,  // Data from MEM/WB output for forwarding
    input  logic [1:0]                 forward_a_e_i,      // Control for OpA forwarding MUX
    input  logic [1:0]                 forward_b_e_i,      // Control for OpB forwarding MUX

    // Outputs to EX/MEM Register
    output logic       reg_write_m_o,
    output logic [1:0] result_src_m_o,
    output logic       mem_write_m_o,
    output logic [`DATA_WIDTH-1:0] alu_result_m_o,
    output logic [`DATA_WIDTH-1:0] rs2_data_m_o,    // Original rs2_data_e_i passed through (for SW/SD)
    output logic [`REG_ADDR_WIDTH-1:0] rd_addr_m_o,
    output logic [`DATA_WIDTH-1:0] pc_plus_4_m_o,
    output logic [2:0] funct3_m_o,          // Pipelined funct3 passed through for memory stage

    // Outputs to Fetch Stage/PC update logic
    output logic       pc_src_e_o,           // PCSrcE: 1 if branch/jump taken
    output logic [`DATA_WIDTH-1:0] pc_target_addr_e_o // PCTargetE: target address
);

    logic [`DATA_WIDTH-1:0] alu_operand_a_mux_out; // Output of MUX for OpA source (PC, RS1, ZERO)
    logic [`DATA_WIDTH-1:0] alu_operand_a;         // Final Operand A after forwarding
    logic [`DATA_WIDTH-1:0] alu_operand_b_mux_out; // Output of MUX for OpB source (RS2, Imm)
    logic [`DATA_WIDTH-1:0] alu_operand_b;         // Final Operand B after forwarding

    logic [`DATA_WIDTH-1:0] alu_result_internal;
    logic                   alu_zero_flag_internal;

    // ALU Operand A Source MUX (selects original source before forwarding)
    always_comb begin
        case (op_a_sel_e_i)
            ALU_A_SRC_RS1:  alu_operand_a_mux_out = rs1_data_e_i;
            ALU_A_SRC_PC:   alu_operand_a_mux_out = pc_e_i;
            ALU_A_SRC_ZERO: alu_operand_a_mux_out = `DATA_WIDTH'(0);
            default:        alu_operand_a_mux_out = rs1_data_e_i; // Default to RS1 to be safe
        endcase
    end

    // ALU Operand A Forwarding MUX (selects final value for ALU Operand A)
    always_comb begin
        case (forward_a_e_i)
            2'b00:  alu_operand_a = alu_operand_a_mux_out; // No forward
            2'b10:  alu_operand_a = forward_data_mem_i;  // Forward from EX/MEM stage output
            2'b01:  alu_operand_a = forward_data_wb_i;   // Forward from MEM/WB stage output
            default: alu_operand_a = alu_operand_a_mux_out; // Should not happen with valid forward signals
        endcase
    end

    // ALU Operand B Source MUX (selects original source: Reg_Rs2 or Immediate)
    assign alu_operand_b_mux_out = alu_src_e_i ? imm_ext_e_i : rs2_data_e_i;

    // ALU Operand B Forwarding MUX (selects final value for ALU Operand B)
    always_comb begin
        if (alu_src_e_i) begin // If Operand B is an Immediate, no forwarding is applied to it
            alu_operand_b = imm_ext_e_i;
        end else begin // Operand B is from a register (rs2_data_e_i), forwarding might apply
            case (forward_b_e_i)
                2'b00:  alu_operand_b = alu_operand_b_mux_out; // No forward (use rs2_data_e_i)
                2'b10:  alu_operand_b = forward_data_mem_i;  // Forward from EX/MEM stage output
                2'b01:  alu_operand_b = forward_data_wb_i;   // Forward from MEM/WB stage output
                default: alu_operand_b = alu_operand_b_mux_out; // Should not happen
            endcase
        end
    end

    // ALU Instance
    alu u_alu (
        .operand_a   (alu_operand_a),
        .operand_b   (alu_operand_b),
        .alu_control (alu_control_e_i),
        .result      (alu_result_internal),
        .zero_flag   (alu_zero_flag_internal)
    );

    // PC Target Address Calculation
    logic [`DATA_WIDTH-1:0] target_addr_pc_plus_imm;
    logic [`DATA_WIDTH-1:0] target_addr_alu_jalr_masked;

    assign target_addr_pc_plus_imm = pc_e_i + imm_ext_e_i; // For JAL and Branches
    // For JALR: target = (ALU result of RS1 + Imm) & ~1
    // The ALU computes RS1 + Imm when op_a_sel_e_i = ALU_A_SRC_RS1, alu_src_e_i = 1 (Imm), alu_control_e_i = ADD
    // This result (alu_result_internal) is then masked.
    assign target_addr_alu_jalr_masked = alu_result_internal & ~(`DATA_WIDTH'(1));

    assign pc_target_addr_e_o = (pc_target_src_sel_e_i == PC_TARGET_SRC_ALU_JALR) ?
                                target_addr_alu_jalr_masked : target_addr_pc_plus_imm;

    // Branch Condition Logic
    logic take_branch;
    always_comb begin
        take_branch = 1'b0;
        if (branch_e_i) begin // Only if it's a branch instruction
            case (funct3_e_i) // Use pipelined funct3 to determine branch type
                `FUNCT3_BEQ:  take_branch = alu_zero_flag_internal;  // Taken if (rs1 - rs2) == 0
                `FUNCT3_BNE:  take_branch = ~alu_zero_flag_internal; // Taken if (rs1 - rs2) != 0
                `FUNCT3_BLT:  take_branch = alu_result_internal[0];  // Taken if SLT result is 1 (rs1 < rs2 signed)
                `FUNCT3_BGE:  take_branch = ~alu_result_internal[0]; // Taken if SLT result is 0 (rs1 >= rs2 signed)
                `FUNCT3_BLTU: take_branch = alu_result_internal[0];  // Taken if SLTU result is 1 (rs1 < rs2 unsigned)
                `FUNCT3_BGEU: take_branch = ~alu_result_internal[0]; // Taken if SLTU result is 0 (rs1 >= rs2 unsigned)
                default:      take_branch = 1'b0; // Should not occur for valid branch funct3
            endcase
        end
    end

    // PCSrcE signal: Controls MUX for next PC in Fetch stage
    assign pc_src_e_o = (jump_e_i) || (branch_e_i && take_branch);

    // Pass-through signals to EX/MEM Register
    assign reg_write_m_o  = reg_write_e_i;
    assign result_src_m_o = result_src_e_i;
    assign mem_write_m_o  = mem_write_e_i;
    assign alu_result_m_o = alu_result_internal; // Result of ALU operation
    assign rs2_data_m_o   = rs2_data_e_i;   // Original RS2 data (e.g., for Store instructions)
    assign rd_addr_m_o    = rd_addr_e_i;
    assign pc_plus_4_m_o  = pc_plus_4_e_i;
    assign funct3_m_o     = funct3_e_i;     // Pass funct3 for Memory stage (load/store type)

endmodule