// rtl/core/id_ex_register.sv
`include "common/defines.svh"
`include "common/alu_defines.svh" // For ALU_CONTROL_WIDTH and default ALU_OP_ADD

module id_ex_register (
    input  logic clk,
    input  logic rst_n,

    // Control signals from Hazard Unit
    input  logic stall_e, // Stall: keeps current values
    input  logic flush_e, // Flush: clears register (outputs NOP-like control)

    // Inputs from Decode Stage
    // Control Signals
    input  logic       reg_write_d_i,
    input  logic [1:0] result_src_d_i,
    input  logic       mem_write_d_i,
    input  logic       jump_d_i,
    input  logic       branch_d_i,
    input  logic       alu_src_d_i,
    input  logic [`ALU_CONTROL_WIDTH-1:0] alu_control_d_i, // Unified ALU control

    // Data
    input  logic [`DATA_WIDTH-1:0]  pc_d_i,
    input  logic [`DATA_WIDTH-1:0]  pc_plus_4_d_i,
    input  logic [`DATA_WIDTH-1:0]  rs1_data_d_i,
    input  logic [`DATA_WIDTH-1:0]  rs2_data_d_i,
    input  logic [`DATA_WIDTH-1:0]  imm_ext_d_i,

    // Register addresses
    input  logic [`REG_ADDR_WIDTH-1:0] rs1_addr_d_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rs2_addr_d_i,
    input  logic [`REG_ADDR_WIDTH-1:0] rd_addr_d_i,


    // Outputs to Execute Stage
    // Control Signals
    output logic       reg_write_e_o,
    output logic [1:0] result_src_e_o,
    output logic       mem_write_e_o,
    output logic       jump_e_o,
    output logic       branch_e_o,
    output logic       alu_src_e_o,
    output logic [`ALU_CONTROL_WIDTH-1:0] alu_control_e_o, // Unified ALU control

    // Data
    output logic [`DATA_WIDTH-1:0]  pc_e_o,
    output logic [`DATA_WIDTH-1:0]  pc_plus_4_e_o,
    output logic [`DATA_WIDTH-1:0]  rs1_data_e_o,
    output logic [`DATA_WIDTH-1:0]  rs2_data_e_o,
    output logic [`DATA_WIDTH-1:0]  imm_ext_e_o,

    // Register addresses
    output logic [`REG_ADDR_WIDTH-1:0] rs1_addr_e_o,
    output logic [`REG_ADDR_WIDTH-1:0] rs2_addr_e_o,
    output logic [`REG_ADDR_WIDTH-1:0] rd_addr_e_o
);

    // Default NOP-like control values for flush/reset
    localparam CTL_NOP_REG_WRITE  = 1'b0;
    localparam CTL_NOP_MEM_WRITE  = 1'b0;
    localparam CTL_NOP_JUMP       = 1'b0;
    localparam CTL_NOP_BRANCH     = 1'b0;
    localparam CTL_NOP_ALU_SRC    = 1'b0;
    localparam CTL_NOP_ALU_CTRL   = `ALU_OP_ADD; // NOP ALU op

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_write_e_o    <= CTL_NOP_REG_WRITE;
            result_src_e_o   <= 2'b00;
            mem_write_e_o    <= CTL_NOP_MEM_WRITE;
            jump_e_o         <= CTL_NOP_JUMP;
            branch_e_o       <= CTL_NOP_BRANCH;
            alu_src_e_o      <= CTL_NOP_ALU_SRC;
            alu_control_e_o  <= CTL_NOP_ALU_CTRL;

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
            // Data fields can be zeroed
            pc_e_o           <= {`DATA_WIDTH{1'b0}};
            pc_plus_4_e_o    <= {`DATA_WIDTH{1'b0}};
            rs1_data_e_o     <= {`DATA_WIDTH{1'b0}};
            rs2_data_e_o     <= {`DATA_WIDTH{1'b0}};
            imm_ext_e_o      <= {`DATA_WIDTH{1'b0}};
            rs1_addr_e_o     <= {`REG_ADDR_WIDTH{1'b0}};
            rs2_addr_e_o     <= {`REG_ADDR_WIDTH{1'b0}};
            rd_addr_e_o      <= {`REG_ADDR_WIDTH{1'b0}}; // Rd for NOP should be x0 if RegWrite is active

        end else if (!stall_e) begin
            reg_write_e_o    <= reg_write_d_i;
            result_src_e_o   <= result_src_d_i;
            mem_write_e_o    <= mem_write_d_i;
            jump_e_o         <= jump_d_i;
            branch_e_o       <= branch_d_i;
            alu_src_e_o      <= alu_src_d_i;
            alu_control_e_o  <= alu_control_d_i;

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