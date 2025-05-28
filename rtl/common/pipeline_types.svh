// common/pipeline_types.svh
`ifndef PIPELINE_TYPES_SVH
`define PIPELINE_TYPES_SVH

`include "common/defines.svh"
`include "common/alu_defines.svh"
`include "common/control_signals_defines.svh"
`include "common/immediate_types.svh"

// Data from Fetch to Decode
typedef struct packed {
    logic [`INSTR_WIDTH-1:0]    instr;
    logic [`DATA_WIDTH-1:0]     pc;
    logic [`DATA_WIDTH-1:0]     pc_plus_4;
} if_id_data_t;

// Data from Decode to Execute
typedef struct packed {
    // Control Signals
    logic                       reg_write;
    logic [1:0]                 result_src; // 00:ALU, 01:MemRead, 10:PC+4
    logic                       mem_write;
    logic                       jump;
    logic                       branch;
    logic                       alu_src;    // Selects ALU OpB (0: Reg_Rs2, 1: Imm)
    logic [`ALU_CONTROL_WIDTH-1:0] alu_control;
    alu_a_src_sel_e             op_a_sel;
    pc_target_src_sel_e         pc_target_src_sel;
    logic [2:0]                 funct3;     // Pipelined funct3

    // Data
    logic [`DATA_WIDTH-1:0]     pc;
    logic [`DATA_WIDTH-1:0]     pc_plus_4;
    logic [`DATA_WIDTH-1:0]     rs1_data;
    logic [`DATA_WIDTH-1:0]     rs2_data;
    logic [`DATA_WIDTH-1:0]     imm_ext;

    // Register Addresses
    logic [`REG_ADDR_WIDTH-1:0] rs1_addr;
    logic [`REG_ADDR_WIDTH-1:0] rs2_addr;
    logic [`REG_ADDR_WIDTH-1:0] rd_addr;
} id_ex_data_t;

// Data from Execute to Memory
typedef struct packed {
    // Control Signals
    logic                       reg_write;
    logic [1:0]                 result_src;
    logic                       mem_write;
    logic [2:0]                 funct3;     // For memory access type

    // Data
    logic [`DATA_WIDTH-1:0]     alu_result; // Effective address or ALU result
    logic [`DATA_WIDTH-1:0]     rs2_data;   // Data to be stored
    logic [`DATA_WIDTH-1:0]     pc_plus_4;  // For JAL/JALR writeback

    // Register Address
    logic [`REG_ADDR_WIDTH-1:0] rd_addr;
} ex_mem_data_t;

// Data from Memory to Writeback
typedef struct packed {
    // Control Signals
    logic                       reg_write;
    logic [1:0]                 result_src;

    // Data
    logic [`DATA_WIDTH-1:0]     read_data_mem; // Data read from memory
    logic [`DATA_WIDTH-1:0]     alu_result;    // ALU result from EX
    logic [`DATA_WIDTH-1:0]     pc_plus_4;     // PC+4 from EX

    // Register Address
    logic [`REG_ADDR_WIDTH-1:0] rd_addr;
} mem_wb_data_t;

// Data for actual writeback to Register File (subset of mem_wb_data_t + selected result)
typedef struct packed {
    logic                       reg_write_en;
    logic [`REG_ADDR_WIDTH-1:0] rd_addr;
    logic [`DATA_WIDTH-1:0]     result_to_rf;
} rf_write_data_t;


// Control signals from Hazard Unit
typedef struct packed {
    logic       stall_f;
    logic       stall_d; // Stalls IF/ID latching new data
    logic       flush_d; // Clears IF/ID outputs (inserts NOP)
    logic       flush_e; // Clears ID/EX outputs (inserts NOP)
    logic [1:0] forward_a_e;
    logic [1:0] forward_b_e;
} hazard_control_t;


// NOP default values for pipeline data structures
// Used for reset and flushing stages

localparam if_id_data_t NOP_IF_ID_DATA = '{
    instr:      `NOP_INSTRUCTION,
    pc:         `PC_RESET_VALUE, // Or other defined "safe" PC
    pc_plus_4:  `PC_RESET_VALUE + 4 // Or other defined "safe" PC+4
};

localparam id_ex_data_t NOP_ID_EX_DATA = '{
    reg_write:          1'b0,
    result_src:         2'b00, // ALU Result
    mem_write:          1'b0,
    jump:               1'b0,
    branch:             1'b0,
    alu_src:            1'b0,  // Operand B from Reg
    alu_control:        `ALU_OP_ADD, // Default ADD
    op_a_sel:           ALU_A_SRC_RS1,
    pc_target_src_sel:  PC_TARGET_SRC_PC_PLUS_IMM,
    funct3:             3'b000,
    pc:                 `DATA_WIDTH'(0),
    pc_plus_4:          `DATA_WIDTH'(0),
    rs1_data:           `DATA_WIDTH'(0),
    rs2_data:           `DATA_WIDTH'(0),
    imm_ext:            `DATA_WIDTH'(0),
    rs1_addr:           `REG_ADDR_WIDTH'(0),
    rs2_addr:           `REG_ADDR_WIDTH'(0),
    rd_addr:            `REG_ADDR_WIDTH'(0)
};

localparam ex_mem_data_t NOP_EX_MEM_DATA = '{
    reg_write:          1'b0,
    result_src:         2'b00,
    mem_write:          1'b0,
    funct3:             3'b000,
    alu_result:         `DATA_WIDTH'(0),
    rs2_data:           `DATA_WIDTH'(0),
    pc_plus_4:          `DATA_WIDTH'(0),
    rd_addr:            `REG_ADDR_WIDTH'(0)
};

localparam mem_wb_data_t NOP_MEM_WB_DATA = '{
    reg_write:          1'b0,
    result_src:         2'b00,
    read_data_mem:      `DATA_WIDTH'(0),
    alu_result:         `DATA_WIDTH'(0),
    pc_plus_4:          `DATA_WIDTH'(0),
    rd_addr:            `REG_ADDR_WIDTH'(0)
};

`endif // PIPELINE_TYPES_SVH