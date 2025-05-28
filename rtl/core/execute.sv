// rtl/core/execute.sv
`include "common/pipeline_types.svh"
`include "common/riscv_opcodes.svh" // For FUNCT3 defines for branches

module execute (
    // Clock and Reset (potentially unused if purely combinational)
    // input  logic clk,
    // input  logic rst_n,

    // Input from Decode (latched by ID/EX register in pipeline.sv)
    input  id_ex_data_t            id_ex_data_i,

    // Forwarding signals from Hazard Unit and data from later stages
    input  logic [`DATA_WIDTH-1:0] forward_data_mem_i, // Data from EX/MEM output (ALUResultM or ReadDataM)
    input  logic [`DATA_WIDTH-1:0] forward_data_wb_i,  // Data from MEM/WB output (ResultW)
    input  logic [1:0]             forward_a_e_i,      // Control for OpA forwarding MUX
    input  logic [1:0]             forward_b_e_i,      // Control for OpB forwarding MUX

    // Output to Memory stage (to be latched by EX/MEM register in pipeline.sv)
    output ex_mem_data_t           ex_mem_data_o,

    // Outputs to Fetch Stage / PC update logic
    output logic                   pc_src_o,           // PCSrcE: 1 if branch/jump taken
    output logic [`DATA_WIDTH-1:0] pc_target_addr_o // PCTargetE: target address
);

    logic [`DATA_WIDTH-1:0] alu_operand_a_mux_out;
    logic [`DATA_WIDTH-1:0] alu_operand_a_final;
    logic [`DATA_WIDTH-1:0] alu_operand_b_mux_out;
    logic [`DATA_WIDTH-1:0] alu_operand_b_final;
    logic [`DATA_WIDTH-1:0] write_data_e;

    logic [`DATA_WIDTH-1:0] alu_result_internal;
    logic                   alu_zero_flag_internal;

    // ALU Operand A Source Selection (before forwarding)
    always_comb begin
        case (id_ex_data_i.op_a_sel)
            ALU_A_SRC_RS1:  alu_operand_a_mux_out = id_ex_data_i.rs1_data;
            ALU_A_SRC_PC:   alu_operand_a_mux_out = id_ex_data_i.pc;
            ALU_A_SRC_ZERO: alu_operand_a_mux_out = `DATA_WIDTH'(0);
            default:        alu_operand_a_mux_out = id_ex_data_i.rs1_data; // Should not happen
        endcase
    end

    // ALU Operand A Forwarding
    always_comb begin
        case (forward_a_e_i)
            2'b00:  alu_operand_a_final = alu_operand_a_mux_out;    // No forward
            2'b10:  alu_operand_a_final = forward_data_mem_i;       // Forward from EX/MEM stage (RdM)
            2'b01:  alu_operand_a_final = forward_data_wb_i;        // Forward from MEM/WB stage (RdW)
            default: alu_operand_a_final = alu_operand_a_mux_out;   // Should not happen
        endcase
    end

    // ALU Operand B Source Selection (before forwarding)
    assign alu_operand_b_mux_out = id_ex_data_i.alu_src ? id_ex_data_i.imm_ext : id_ex_data_i.rs2_data;

    // ALU Operand B Forwarding
    always_comb begin
        case (forward_b_e_i)
            2'b00:  write_data_e = alu_operand_b_mux_out;    // No forward
            2'b10:  write_data_e = forward_data_mem_i;       // Forward from EX/MEM stage (RdM)
            2'b01:  write_data_e = forward_data_wb_i;        // Forward from MEM/WB stage (RdW)
            default: write_data_e = alu_operand_b_mux_out;   // Should not happen
        endcase
        if (id_ex_data_i.alu_src) begin // If Operand B is an Immediate, no forwarding
            alu_operand_b_final = id_ex_data_i.imm_ext;
        end else begin
            alu_operand_b_final = write_data_e;
        end
    end

    // ALU Instance
    alu u_alu (
        .operand_a   (alu_operand_a_final),
        .operand_b   (alu_operand_b_final),
        .alu_control (id_ex_data_i.alu_control),
        .result      (alu_result_internal),
        .zero_flag   (alu_zero_flag_internal)
    );

    // PC Target Address Calculation
    logic [`DATA_WIDTH-1:0] target_addr_pc_plus_imm;
    logic [`DATA_WIDTH-1:0] target_addr_alu_jalr_masked;

    assign target_addr_pc_plus_imm = id_ex_data_i.pc + id_ex_data_i.imm_ext;
    // For JALR: target = (ALU result of RS1 + Imm) & ~1.
    // ALU computes (RS1 + Imm) if op_a_sel=RS1, alu_src=Imm, alu_control=ADD.
    // This specific ALU result (alu_result_internal) is used for JALR.
    assign target_addr_alu_jalr_masked = alu_result_internal & ~(`DATA_WIDTH'(1));

    assign pc_target_addr_o = (id_ex_data_i.pc_target_src_sel == PC_TARGET_SRC_ALU_JALR) ?
                               target_addr_alu_jalr_masked : target_addr_pc_plus_imm;

    // Branch Condition Logic
    logic take_branch;
    always_comb begin
        take_branch = 1'b0;
        if (id_ex_data_i.branch) begin
            case (id_ex_data_i.funct3) // Use pipelined funct3
                `FUNCT3_BEQ:  take_branch = alu_zero_flag_internal;
                `FUNCT3_BNE:  take_branch = ~alu_zero_flag_internal;
                `FUNCT3_BLT:  take_branch = alu_result_internal[0];  // SLT result is 1 if taken
                `FUNCT3_BGE:  take_branch = ~alu_result_internal[0]; // SLT result is 0 if taken
                `FUNCT3_BLTU: take_branch = alu_result_internal[0];  // SLTU result is 1 if taken
                `FUNCT3_BGEU: take_branch = ~alu_result_internal[0]; // SLTU result is 0 if taken
                default:      take_branch = 1'b0;
            endcase
        end
    end

    // PCSrc signal: Controls MUX for next PC in Fetch stage
    assign pc_src_o = (id_ex_data_i.jump) || (id_ex_data_i.branch && take_branch);

    // Assign outputs to EX/MEM data structure
    assign ex_mem_data_o.reg_write  = id_ex_data_i.reg_write;
    assign ex_mem_data_o.result_src = id_ex_data_i.result_src;
    assign ex_mem_data_o.mem_write  = id_ex_data_i.mem_write;
    assign ex_mem_data_o.funct3     = id_ex_data_i.funct3;      // Pass funct3 for Memory stage (load/store type)
    assign ex_mem_data_o.alu_result = alu_result_internal;      // Result of ALU operation
    assign ex_mem_data_o.rs2_data   = write_data_e;    // Original RS2 data (e.g., for Store instructions)
    assign ex_mem_data_o.rd_addr    = id_ex_data_i.rd_addr;
    assign ex_mem_data_o.pc_plus_4  = id_ex_data_i.pc_plus_4;   // For JAL/JALR writeback

endmodule