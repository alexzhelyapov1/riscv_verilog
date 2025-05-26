// rtl/core/id_ex_register.sv
`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/control_signals_defines.svh" // New include

module id_ex_register (
    input  logic clk,
    input  logic rst_n,

    input  logic stall_e,
    input  logic flush_e,

    // Inputs from Decode Stage
    input  logic       reg_write_d_i,
    input  logic [1:0] result_src_d_i,
    input  logic       mem_write_d_i,
    input  logic       jump_d_i,
    input  logic       branch_d_i,
    input  logic       alu_src_d_i,
    input  logic [`ALU_CONTROL_WIDTH-1:0] alu_control_d_i,
    input  logic [2:0] funct3_d_i,
    input  alu_a_src_sel_e op_a_sel_d_i,
    input  pc_target_src_sel_e pc_target_src_sel_d_i,

    input  logic [`DATA_WIDTH-1:0]  pc_d_i,
    input  logic [`DATA_WIDTH-1:0]  pc_plus_4_d_i,
    input  logic [`DATA_WIDTH-1:0]  rs1_data_d_i,
    input  logic [`DATA_WIDTH-1:0]  rs2_data_d_i,
    input  logic [`DATA_WIDTH-1:0]  imm_ext_d_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rs1_addr_d_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rs2_addr_d_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_d_i,

    // Outputs to Execute Stage
    output logic       reg_write_e_o,
    output logic [1:0] result_src_e_o,
    output logic       mem_write_e_o,
    output logic       jump_e_o,
    output logic       branch_e_o,
    output logic       alu_src_e_o,
    output logic [`ALU_CONTROL_WIDTH-1:0] alu_control_e_o,
    output logic [2:0] funct3_e_o,
    output alu_a_src_sel_e op_a_sel_e_o,
    output pc_target_src_sel_e pc_target_src_sel_e_o,

    output logic [`DATA_WIDTH-1:0]  pc_e_o,
    output logic [`DATA_WIDTH-1:0]  pc_plus_4_e_o,
    output logic [`DATA_WIDTH-1:0]  rs1_data_e_o,
    output logic [`DATA_WIDTH-1:0]  rs2_data_e_o,
    output logic [`DATA_WIDTH-1:0]  imm_ext_e_o,
    output logic [`REG_ADDR_WIDTH-1:0] rs1_addr_e_o,
    output logic [`REG_ADDR_WIDTH-1:0] rs2_addr_e_o,
    output logic [`REG_ADDR_WIDTH-1:0] rd_addr_e_o
);

    localparam CTL_NOP_REG_WRITE  = 1'b0;
    localparam CTL_NOP_MEM_WRITE  = 1'b0;
    localparam CTL_NOP_JUMP       = 1'b0;
    localparam CTL_NOP_BRANCH     = 1'b0;
    localparam CTL_NOP_ALU_SRC    = 1'b0;
    localparam CTL_NOP_ALU_CTRL   = `ALU_OP_ADD;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_write_e_o    <= CTL_NOP_REG_WRITE;
            result_src_e_o   <= 2'b00;
            mem_write_e_o    <= CTL_NOP_MEM_WRITE;
            jump_e_o         <= CTL_NOP_JUMP;
            branch_e_o       <= CTL_NOP_BRANCH;
            alu_src_e_o      <= CTL_NOP_ALU_SRC;
            alu_control_e_o  <= CTL_NOP_ALU_CTRL;
            funct3_e_o       <= 3'b000;
            op_a_sel_e_o     <= ALU_A_SRC_RS1;
            pc_target_src_sel_e_o <= PC_TARGET_SRC_PC_PLUS_IMM;

            pc_e_o           <= {`DATA_WIDTH{1'b0}};
            pc_plus_4_e_o    <= {`DATA_WIDTH{1'b0}};
            rs1_data_e_o     <= {`DATA_WIDTH{1'b0}};
            rs2_data_e_o     <= {`DATA_WIDTH{1'b0}};
            imm_ext_e_o      <= {`DATA_WIDTH{1'b0}};
            rs1_addr_e_o     <= {`REG_ADDR_WIDTH{1'b0}};
            rs2_addr_e_o     <= {`REG_ADDR_WIDTH{1'b0}};
            rd_addr_e_o      <= {`REG_ADDR_WIDTH{1'b0}};
        end else if (flush_e) begin
            reg_write_e_o    <= CTL_NOP_REG_WRITE;
            result_src_e_o   <= 2'b00;
            mem_write_e_o    <= CTL_NOP_MEM_WRITE;
            jump_e_o         <= CTL_NOP_JUMP;
            branch_e_o       <= CTL_NOP_BRANCH;
            alu_src_e_o      <= CTL_NOP_ALU_SRC;
            alu_control_e_o  <= CTL_NOP_ALU_CTRL;
            funct3_e_o       <= 3'b000;
            op_a_sel_e_o     <= ALU_A_SRC_RS1;
            pc_target_src_sel_e_o <= PC_TARGET_SRC_PC_PLUS_IMM;

            // Data fields are also NOP'd or zeroed
            pc_e_o           <= {`DATA_WIDTH{1'b0}};
            pc_plus_4_e_o    <= {`DATA_WIDTH{1'b0}};
            rs1_data_e_o     <= {`DATA_WIDTH{1'b0}};
            rs2_data_e_o     <= {`DATA_WIDTH{1'b0}};
            imm_ext_e_o      <= {`DATA_WIDTH{1'b0}};
            rs1_addr_e_o     <= {`REG_ADDR_WIDTH{1'b0}};
            rs2_addr_e_o     <= {`REG_ADDR_WIDTH{1'b0}};
            rd_addr_e_o      <= {`REG_ADDR_WIDTH{1'b0}};
        end else if (!stall_e) begin
            reg_write_e_o    <= reg_write_d_i;
            result_src_e_o   <= result_src_d_i;
            mem_write_e_o    <= mem_write_d_i;
            jump_e_o         <= jump_d_i;
            branch_e_o       <= branch_d_i;
            alu_src_e_o      <= alu_src_d_i;
            alu_control_e_o  <= alu_control_d_i;
            funct3_e_o       <= funct3_d_i;
            op_a_sel_e_o     <= op_a_sel_d_i;
            pc_target_src_sel_e_o <= pc_target_src_sel_d_i;

            pc_e_o           <= pc_d_i;
            pc_plus_4_e_o    <= pc_plus_4_d_i;
            rs1_data_e_o     <= rs1_data_d_i;
            rs2_data_e_o     <= rs2_data_d_i;
            imm_ext_e_o      <= imm_ext_d_i;
            rs1_addr_e_o     <= rs1_addr_d_i;
            rs2_addr_e_o     <= rs2_addr_d_i;
            rd_addr_e_o      <= rd_addr_d_i;
        end
        // If stalled (stall_e = 1) and not flushed, register holds its value
    end
endmodule