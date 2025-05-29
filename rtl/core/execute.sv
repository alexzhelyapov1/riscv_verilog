`include "common/pipeline_types.svh"
`include "common/riscv_opcodes.svh"

module execute (
    input  id_ex_data_t            id_ex_data_i,
    input  logic [`DATA_WIDTH-1:0] forward_data_mem_i,
    input  logic [`DATA_WIDTH-1:0] forward_data_wb_i,
    input  logic [1:0]             forward_a_e_i,
    input  logic [1:0]             forward_b_e_i,

    output ex_mem_data_t           ex_mem_data_o,
    output logic                   pc_src_o,
    output logic [`DATA_WIDTH-1:0] pc_target_addr_o
);

    logic [`DATA_WIDTH-1:0] alu_operand_a_mux_out;
    logic [`DATA_WIDTH-1:0] alu_operand_a_final;
    logic [`DATA_WIDTH-1:0] alu_operand_b_mux_out;
    logic [`DATA_WIDTH-1:0] alu_operand_b_final;
    logic [`DATA_WIDTH-1:0] write_data_e;
    logic [`DATA_WIDTH-1:0] alu_result_internal;
    logic                   alu_zero_flag_internal;

    always_comb begin
        case (id_ex_data_i.op_a_sel)
            ALU_A_SRC_RS1:  alu_operand_a_mux_out = id_ex_data_i.rs1_data;
            ALU_A_SRC_PC:   alu_operand_a_mux_out = id_ex_data_i.pc;
            ALU_A_SRC_ZERO: alu_operand_a_mux_out = `DATA_WIDTH'(0);
            default:        alu_operand_a_mux_out = id_ex_data_i.rs1_data;
        endcase
    end

    always_comb begin
        case (forward_a_e_i)
            2'b00:  alu_operand_a_final = alu_operand_a_mux_out;
            2'b10:  alu_operand_a_final = forward_data_mem_i;
            2'b01:  alu_operand_a_final = forward_data_wb_i;
            default: alu_operand_a_final = alu_operand_a_mux_out;
        endcase
    end

    assign alu_operand_b_mux_out = id_ex_data_i.alu_src ? id_ex_data_i.imm_ext : id_ex_data_i.rs2_data;

    always_comb begin
        case (forward_b_e_i)
            2'b00:  write_data_e = alu_operand_b_mux_out;
            2'b10:  write_data_e = forward_data_mem_i;
            2'b01:  write_data_e = forward_data_wb_i;
            default: write_data_e = alu_operand_b_mux_out;
        endcase
        if (id_ex_data_i.alu_src) begin
            alu_operand_b_final = id_ex_data_i.imm_ext;
        end else begin
            alu_operand_b_final = write_data_e;
        end
    end

    alu u_alu (
        .operand_a   (alu_operand_a_final),
        .operand_b   (alu_operand_b_final),
        .alu_control (id_ex_data_i.alu_control),
        .result      (alu_result_internal),
        .zero_flag   (alu_zero_flag_internal)
    );

    logic [`DATA_WIDTH-1:0] target_addr_pc_plus_imm;
    logic [`DATA_WIDTH-1:0] target_addr_alu_jalr_masked;

    assign target_addr_pc_plus_imm = id_ex_data_i.pc + id_ex_data_i.imm_ext;
    assign target_addr_alu_jalr_masked = alu_result_internal & ~(`DATA_WIDTH'(1));
    assign pc_target_addr_o = (id_ex_data_i.pc_target_src_sel == PC_TARGET_SRC_ALU_JALR) ?
                               target_addr_alu_jalr_masked : target_addr_pc_plus_imm;

    logic take_branch;
    always_comb begin
        take_branch = 1'b0;
        if (id_ex_data_i.branch) begin
            case (id_ex_data_i.funct3)
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

    assign pc_src_o = (id_ex_data_i.jump) || (id_ex_data_i.branch && take_branch);
    assign ex_mem_data_o.reg_write  = id_ex_data_i.reg_write;
    assign ex_mem_data_o.result_src = id_ex_data_i.result_src;
    assign ex_mem_data_o.mem_write  = id_ex_data_i.mem_write;
    assign ex_mem_data_o.funct3     = id_ex_data_i.funct3;
    assign ex_mem_data_o.alu_result = alu_result_internal;
    assign ex_mem_data_o.rs2_data   = write_data_e;
    assign ex_mem_data_o.rd_addr    = id_ex_data_i.rd_addr;
    assign ex_mem_data_o.pc_plus_4  = id_ex_data_i.pc_plus_4;

endmodule