// rtl/core/execute.sv
`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/riscv_opcodes.svh"
`include "common/control_signals_defines.svh"

module execute (
    // Inputs from ID/EX Register
    input  logic       reg_write_e_i,
    input  logic [1:0] result_src_e_i,
    input  logic       mem_write_e_i,
    input  logic       jump_e_i,
    input  logic       branch_e_i,
    input  logic       alu_src_e_i,
    input  logic [`ALU_CONTROL_WIDTH-1:0] alu_control_e_i,
    input  logic [2:0] funct3_e_i,
    input  alu_a_src_sel_e op_a_sel_e_i,
    input  pc_target_src_sel_e pc_target_src_sel_e_i,

    input  logic [`DATA_WIDTH-1:0]  pc_e_i,
    input  logic [`DATA_WIDTH-1:0]  pc_plus_4_e_i,
    input  logic [`DATA_WIDTH-1:0]  rs1_data_e_i,   // Data from RF or earlier forward for Rs1
    input  logic [`DATA_WIDTH-1:0]  rs2_data_e_i,   // Data from RF or earlier forward for Rs2
    input  logic [`DATA_WIDTH-1:0]  imm_ext_e_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_e_i,

// change start
    // Inputs for Forwarding (from later stages, routed by top pipeline module)
    input  logic [`DATA_WIDTH-1:0]     forward_data_mem_i, // Data from EX/MEM output (ALUResultM or ReadDataM if load was in MEM)
                                                         // More accurately, this should be ALUResultM if ResultSrcM is ALU,
                                                         // or ReadDataM if ResultSrcM is Mem.
                                                         // For simplicity in forwarding to ALU, usually ALUResultM is forwarded if RegWriteM is true.
                                                         // If load completes in MEM, ReadDataM is what should be forwarded.
                                                         // Let's assume this is the value that would be written to RdM if RegWriteM is true.
                                                         // This could be ALUResultM or ReadDataW (after Mem read).
                                                         // To be precise: if forwarding from MEM stage for an ALU op: ALUResultM.
                                                         // If forwarding from MEM stage for a Load op: ReadDataM (from MEM/WB input).
                                                         // The P&H diagram often simplifies this to "ALUResultM" path, but it can be ReadDataM.
                                                         // Let's use a generic "data_from_mem_stage_output" for now.
    input  logic [`DATA_WIDTH-1:0]     forward_data_wb_i,  // Data from MEM/WB output (ResultW)

    // Forwarding control signals from Pipeline Control Unit
    input  logic [1:0]                 forward_a_e_i,
    input  logic [1:0]                 forward_b_e_i,
// change end

    // Outputs to EX/MEM Register
    output logic       reg_write_m_o,
    // ... (остальные выходы как были) ...
    output logic [2:0] funct3_m_o,

    // Outputs to Fetch Stage/PC update logic
    output logic       pc_src_e_o,
    output logic [`DATA_WIDTH-1:0] pc_target_addr_e_o
);

    logic [`DATA_WIDTH-1:0] alu_operand_a_mux_out; // Output of MUX for OpA source (PC, RS1, ZERO)
    logic [`DATA_WIDTH-1:0] alu_operand_a;         // Final Operand A after forwarding
    logic [`DATA_WIDTH-1:0] alu_operand_b_mux_out; // Output of MUX for OpB source (RS2, Imm)
    logic [`DATA_WIDTH-1:0] alu_operand_b;         // Final Operand B after forwarding

    logic [`DATA_WIDTH-1:0] alu_result_internal;
    logic                   alu_zero_flag_internal;

    // ALU Operand A Source MUX (before forwarding)
    always_comb begin
        case (op_a_sel_e_i)
            ALU_A_SRC_RS1:  alu_operand_a_mux_out = rs1_data_e_i;
            ALU_A_SRC_PC:   alu_operand_a_mux_out = pc_e_i;
            ALU_A_SRC_ZERO: alu_operand_a_mux_out = `DATA_WIDTH'(0);
            default:        alu_operand_a_mux_out = rs1_data_e_i;
        endcase
    end

    // ALU Operand A Forwarding MUX
// change start
    always_comb begin
        case (forward_a_e_i)
            2'b00:  alu_operand_a = alu_operand_a_mux_out;      // No forward, use data from ID/EX (or selected PC/Zero)
            2'b10:  alu_operand_a = forward_data_mem_i;       // Forward from MEM stage output (EX/MEM.ALUResult or EX/MEM.ReadData if load)
            2'b01:  alu_operand_a = forward_data_wb_i;        // Forward from WB stage output (MEM/WB.ResultW)
            default: alu_operand_a = alu_operand_a_mux_out;   // Should not happen
        endcase
    end
// change end

    // ALU Operand B Source MUX (before forwarding)
    assign alu_operand_b_mux_out = alu_src_e_i ? imm_ext_e_i : rs2_data_e_i;

    // ALU Operand B Forwarding MUX
    always_comb begin
        if (alu_src_e_i) begin // Operand B is Immediate
            alu_operand_b = imm_ext_e_i;
        end else begin // Operand B is Register (rs2_data_e_i)
            case (forward_b_e_i)
                2'b00:  alu_operand_b = alu_operand_b_mux_out; // alu_operand_b_mux_out is rs2_data_e_i here
                2'b10:  alu_operand_b = forward_data_mem_i;
                2'b01:  alu_operand_b = forward_data_wb_i;
                default: alu_operand_b = alu_operand_b_mux_out;
            endcase
        end
    end

    // ALU Instance (uses final operands after forwarding)
    alu u_alu (
        .operand_a   (alu_operand_a),
        .operand_b   (alu_operand_b),
        .alu_control (alu_control_e_i),
        .result      (alu_result_internal),
        .zero_flag   (alu_zero_flag_internal)
    );

    // ... (PC Target Address MUX, Branch Condition Logic, PCSrcE generation - остаются как были) ...
    // ... (Pass-through signals for EX/MEM register - остаются как были) ...

    // Pass-through signals for EX/MEM register
    assign reg_write_m_o  = reg_write_e_i;
    assign result_src_m_o = result_src_e_i;
    assign mem_write_m_o  = mem_write_e_i;
    assign alu_result_m_o = alu_result_internal;
    assign rs2_data_m_o   = rs2_data_e_i; // Note: This is original rs2_data from ID/EX, NOT forwarded rs2_data.
                                          // This is correct as it's the data to be STORED in memory.
    assign rd_addr_m_o    = rd_addr_e_i;
    assign pc_plus_4_m_o  = pc_plus_4_e_i;
    assign funct3_m_o     = funct3_e_i;

    // PC Target Address MUX
    logic [`DATA_WIDTH-1:0] target_addr_pc_plus_imm;
    logic [`DATA_WIDTH-1:0] target_addr_alu_jalr;

    assign target_addr_pc_plus_imm = pc_e_i + imm_ext_e_i;
    assign target_addr_alu_jalr    = alu_result_internal & ~(`DATA_WIDTH'(1));

    assign pc_target_addr_e_o = (pc_target_src_sel_e_i == PC_TARGET_SRC_ALU_JALR) ?
                                target_addr_alu_jalr : target_addr_pc_plus_imm;

    // Branch Condition Logic
    logic take_branch;
    always_comb begin
        take_branch = 1'b0;
        if (branch_e_i) begin
            case (funct3_e_i)
                `FUNCT3_BEQ:  take_branch = alu_zero_flag_internal;
                `FUNCT3_BNE:  take_branch = ~alu_zero_flag_internal;
                `FUNCT3_BLT:  take_branch = alu_result_internal[0];
                `FUNCT3_BGE:  take_branch = ~alu_result_internal[0];
                `FUNCT3_BLTU: take_branch = alu_result_internal[0];
                `FUNCT3_BGEU: take_branch = ~alu_result_internal[0];
                default:      take_branch = 1'b0;
            endcase
        end
    end

    assign pc_src_e_o = (jump_e_i) || (branch_e_i && take_branch);

endmodule