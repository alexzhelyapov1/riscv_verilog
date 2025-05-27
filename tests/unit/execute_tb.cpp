// tests/unit/execute_tb.cpp
#include "Vexecute_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>
#include <map>
#include <bitset>

// C++ Constants (mirroring .svh files for testbench use)

// From common/alu_defines.svh
const int ALU_CONTROL_WIDTH_EX_TB = 4; // Suffix to avoid clash if alu.cpp linked
const uint8_t ALU_OP_ADD_EX_TB  = 0b0000;
const uint8_t ALU_OP_SUB_EX_TB  = 0b0001;
const uint8_t ALU_OP_SLL_EX_TB  = 0b0010;
const uint8_t ALU_OP_SLT_EX_TB  = 0b0011;
const uint8_t ALU_OP_SLTU_EX_TB = 0b0100;
const uint8_t ALU_OP_XOR_EX_TB  = 0b0101;
const uint8_t ALU_OP_SRL_EX_TB  = 0b0110;
const uint8_t ALU_OP_SRA_EX_TB  = 0b0111;
const uint8_t ALU_OP_OR_EX_TB   = 0b1000;
const uint8_t ALU_OP_AND_EX_TB  = 0b1001;

// From common/control_signals_defines.svh
enum AluASrcSelCppExTb {
    ALU_A_SRC_RS1_EX_TB,
    ALU_A_SRC_PC_EX_TB,
    ALU_A_SRC_ZERO_EX_TB
};

enum PcTargetSrcSelCppExTb {
    PC_TARGET_SRC_PC_PLUS_IMM_EX_TB,
    PC_TARGET_SRC_ALU_JALR_EX_TB
};

// From common/riscv_opcodes.svh (funct3 codes)
// For R-Type (funct3 can vary, but for ADD/SUB it's 000)
const uint8_t FUNCT3_ADD_SUB_EX_TB = 0b000;
// For I-Type
const uint8_t FUNCT3_ADDI_EX_TB    = 0b000;
// For U-Type (LUI/AUIPC - funct3 not critical for EX logic itself, but passed)
const uint8_t FUNCT3_LUI_AUIPC_EX_TB = 0b000; // Example, often not specifically checked in EX
// For Branches
const uint8_t FUNCT3_BEQ_EX_TB  = 0b000;
const uint8_t FUNCT3_BNE_EX_TB  = 0b001;
const uint8_t FUNCT3_BLT_EX_TB  = 0b100;
const uint8_t FUNCT3_BGE_EX_TB  = 0b101;
const uint8_t FUNCT3_BLTU_EX_TB = 0b110;
const uint8_t FUNCT3_BGEU_EX_TB = 0b111;
// For JALR
const uint8_t FUNCT3_JALR_EX_TB    = 0b000;
// For Store (e.g. SW)
const uint8_t FUNCT3_SW_EX_TB      = 0b010;
// Add other specific funct3 codes if needed for detailed tests


// Forwarding MUX select codes
const uint8_t FWD_NONE_EX_TB   = 0b00;
const uint8_t FWD_MEM_WB_EX_TB = 0b01; // From MEM/WB (RdW) -> EX
const uint8_t FWD_EX_MEM_EX_TB = 0b10; // From EX/MEM (RdM) -> EX

vluint64_t sim_time_execute_tb = 0;

void eval_execute(Vexecute_tb* dut, VerilatedVcdC* tfp) {
    dut->eval();
    if (tfp) tfp->dump(sim_time_execute_tb);
}

// Test case structure
struct ExecuteTestCase {
    std::string name;
    // --- Inputs to Execute Stage (simulating outputs of ID/EX register) ---
    bool     reg_write_e_i;
    uint8_t  result_src_e_i; // 00:ALU, 01:Mem, 10:PC+4
    bool     mem_write_e_i;
    bool     jump_e_i;
    bool     branch_e_i;
    bool     alu_src_e_i;     // For ALU OpB: 0=Reg_Rs2, 1=Imm
    uint8_t  alu_control_e_i; // 4-bit ALU operation
    uint8_t  funct3_e_i;      // 3-bit funct3 (from instruction, used for branches, memory ops)
    AluASrcSelCppExTb op_a_sel_e_i;    // Selects original source for ALU OpA
    PcTargetSrcSelCppExTb pc_target_src_sel_e_i; // Selects how PC_Target is calculated

    uint64_t pc_e_i;
    uint64_t pc_plus_4_e_i;
    uint64_t rs1_data_e_i;    // Data from RF/forwarding for Rs1
    uint64_t rs2_data_e_i;    // Data from RF/forwarding for Rs2
    uint64_t imm_ext_e_i;     // Sign-extended immediate
    uint8_t  rd_addr_e_i;     // Destination register address

    // Forwarding inputs
    uint64_t forward_data_mem_i; // Data from MEM stage (EX/MEM reg output) for forwarding
    uint64_t forward_data_wb_i;  // Data from WB stage (MEM/WB reg output) for forwarding
    uint8_t  forward_a_e_i;      // Control for OpA forwarding MUX
    uint8_t  forward_b_e_i;      // Control for OpB forwarding MUX

    // --- Expected Outputs from Execute Stage ---
    // To EX/MEM Register
    bool     exp_reg_write_m;
    uint8_t  exp_result_src_m;
    bool     exp_mem_write_m;
    uint64_t exp_alu_result_m;
    uint64_t exp_rs2_data_m;   // Original rs2_data_e_i value passed through
    uint8_t  exp_rd_addr_m;
    uint64_t exp_pc_plus_4_m;
    uint8_t  exp_funct3_m;     // Pipelined funct3

    // To PC Update Logic
    bool     exp_pc_src_e;       // PCSrcE: 1 if branch/jump taken
    uint64_t exp_pc_target_addr_e; // PCTargetE: target address
};


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vexecute_tb* top = new Vexecute_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_execute.vcd");

    std::cout << "Starting Execute Stage Testbench (Corrected)" << std::endl;
    top->rst_n = 1; // For combinational DUT, rst_n is not strictly for logic, but good for sim init
    top->clk = 0;   // Provide a clock for VCD tracing, though execute stage is combinational

    std::vector<ExecuteTestCase> test_cases = {
        // --- Test Case 1: R-Type ADD (no forwarding) ---
        {   "R-Type ADD, no fwd",
            true, 0b00, false, false, false, false, ALU_OP_ADD_EX_TB, FUNCT3_ADD_SUB_EX_TB, ALU_A_SRC_RS1_EX_TB, PC_TARGET_SRC_PC_PLUS_IMM_EX_TB,
            0x100, 0x104, 10, 20, 0xBADBEEF, 3,
            0, 0, FWD_NONE_EX_TB, FWD_NONE_EX_TB,
            true, 0b00, false, 30, 20, 3, 0x104, FUNCT3_ADD_SUB_EX_TB,
            false, 0x100 + 0xBADBEEF // pc_target_addr is pc_e_i + imm_ext_e_i by default for non-JALR target_sel
        },
        // --- Test Case 2: I-Type ADDI (no forwarding) ---
        {   "I-Type ADDI, no fwd",
            true, 0b00, false, false, false, true, ALU_OP_ADD_EX_TB, FUNCT3_ADDI_EX_TB, ALU_A_SRC_RS1_EX_TB, PC_TARGET_SRC_PC_PLUS_IMM_EX_TB,
            0x200, 0x204, 50, 0xCCC, 15, 6,
            0, 0, FWD_NONE_EX_TB, FWD_NONE_EX_TB,
            true, 0b00, false, 65, 0xCCC, 6, 0x204, FUNCT3_ADDI_EX_TB,
            false, 0x200 + 15
        },
        // --- Test Case 3: LUI (OpA=Zero, OpB=Imm) ---
        {   "LUI U-Type",
            true, 0b00, false, false, false, true, ALU_OP_ADD_EX_TB, FUNCT3_LUI_AUIPC_EX_TB, ALU_A_SRC_ZERO_EX_TB, PC_TARGET_SRC_PC_PLUS_IMM_EX_TB,
            0x300, 0x304, 0xAAA, 0xBBB, 0xFFFFFFFFABCD0000ULL, 5,
            0,0,FWD_NONE_EX_TB,FWD_NONE_EX_TB,
            true,0b00,false,0xFFFFFFFFABCD0000ULL,0xBBB,5,0x304,FUNCT3_LUI_AUIPC_EX_TB,
            false, 0x300 + 0xFFFFFFFFABCD0000ULL
        },
        // --- Test Case 4: AUIPC (OpA=PC, OpB=Imm) ---
        {   "AUIPC U-Type",
            true, 0b00, false, false, false, true, ALU_OP_ADD_EX_TB, FUNCT3_LUI_AUIPC_EX_TB, ALU_A_SRC_PC_EX_TB, PC_TARGET_SRC_PC_PLUS_IMM_EX_TB,
            0x400, 0x404, 0xAAA, 0xBBB, 0x12300000ULL, 1,
            0,0,FWD_NONE_EX_TB,FWD_NONE_EX_TB,
            true,0b00,false, 0x400 + 0x12300000ULL,0xBBB,1,0x404,FUNCT3_LUI_AUIPC_EX_TB,
            false, 0x400 + 0x12300000ULL
        },
        // --- Test Case 5: Forwarding EX/MEM -> OpA for ADD ---
        {   "R-Type ADD, FwdA from EX/MEM",
            true, 0b00, false, false, false, false, ALU_OP_ADD_EX_TB, FUNCT3_ADD_SUB_EX_TB, ALU_A_SRC_RS1_EX_TB, PC_TARGET_SRC_PC_PLUS_IMM_EX_TB,
            0x100, 0x104, 10/*old rs1_data_e_i, will be overridden by fwd*/, 20, 0, 5,
            0x55/*fwd_mem_data*/, 0x66/*fwd_wb_data, not used*/, FWD_EX_MEM_EX_TB, FWD_NONE_EX_TB,
            true, 0b00, false, 0x55 + 20, 20, 5, 0x104, FUNCT3_ADD_SUB_EX_TB,
            false, 0x100 + 0
        },
        // --- Test Case 6: Forwarding MEM/WB -> OpB for ADD (OpB is reg, not imm) ---
        {   "R-Type ADD, FwdB from MEM/WB",
            true, 0b00, false, false, false, false, ALU_OP_ADD_EX_TB, FUNCT3_ADD_SUB_EX_TB, ALU_A_SRC_RS1_EX_TB, PC_TARGET_SRC_PC_PLUS_IMM_EX_TB,
            0x100, 0x104, 10, 20/*old rs2_data_e_i, will be overridden*/, 0, 5,
            0x88/*fwd_mem_data, not used*/, 0x77/*fwd_wb_data*/, FWD_NONE_EX_TB, FWD_MEM_WB_EX_TB,
            true, 0b00, false, 10 + 0x77, 20, 5, 0x104, FUNCT3_ADD_SUB_EX_TB,
            false, 0x100 + 0
        },
        // --- Test Case 7: BEQ Taken (ALU SUB, Zero=1) ---
        {   "BEQ Branch Taken",
            false,0b00,false,false,true,false,ALU_OP_SUB_EX_TB,FUNCT3_BEQ_EX_TB,ALU_A_SRC_RS1_EX_TB,PC_TARGET_SRC_PC_PLUS_IMM_EX_TB,
            0x800,0x804,100,100,0x40/*offset*/,0,
            0,0,FWD_NONE_EX_TB,FWD_NONE_EX_TB,
            false,0b00,false,0/*ALU result 100-100=0*/,100,0,0x804,FUNCT3_BEQ_EX_TB,
            true, 0x800 + 0x40
        },
        // --- Test Case 8: BLT Not Taken (ALU SLT, Res=0) ---
        {   "BLT Not Taken",
            false,0b00,false,false,true,false,ALU_OP_SLT_EX_TB,FUNCT3_BLT_EX_TB,ALU_A_SRC_RS1_EX_TB,PC_TARGET_SRC_PC_PLUS_IMM_EX_TB,
            0x800,0x804,200,100,0x40,0, // rs1(200) not < rs2(100), so SLT res=0
            0,0,FWD_NONE_EX_TB,FWD_NONE_EX_TB,
            false,0b00,false,0/*ALU result*/,100,0,0x804,FUNCT3_BLT_EX_TB,
            false, 0x800 + 0x40
        },
        // --- Test Case 9: JALR ---
        {   "JALR Jump",
            true,0b10/*ResultSrc=PC+4*/,false,true,false,true,ALU_OP_ADD_EX_TB,FUNCT3_JALR_EX_TB,ALU_A_SRC_RS1_EX_TB,PC_TARGET_SRC_ALU_JALR_EX_TB,
            0x500,0x504,0x1000/*rs1_data*/,0xCCC/*rs2_data not used*/,0x80/*imm*/,1,
            0,0,FWD_NONE_EX_TB,FWD_NONE_EX_TB,
            true,0b10,false,0x1000+0x80,0xCCC,1,0x504,FUNCT3_JALR_EX_TB,
            true, (0x1000+0x80) & ~1ULL
        },
        // --- Test Case 10: Store instruction (SW) ---
        {   "SW (Store Word)",
            false, 0b00, true, false, false, true, ALU_OP_ADD_EX_TB, FUNCT3_SW_EX_TB, ALU_A_SRC_RS1_EX_TB, PC_TARGET_SRC_PC_PLUS_IMM_EX_TB,
            0xA00, 0xA04, 0x100/*base_addr_rs1*/, 0xDEADBEEF/*data_to_store_rs2*/, 0x8/*offset_imm*/, 0/*rd not written for SW*/,
            0, 0, FWD_NONE_EX_TB, FWD_NONE_EX_TB,
            false, 0b00, true, 0x100 + 0x8/*eff_addr*/, 0xDEADBEEF/*data_to_store*/, 0, 0xA04, FUNCT3_SW_EX_TB,
            false, 0xA00 + 0x8
        },
    };

    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;

        // Apply inputs from test case
        top->i_reg_write_e = tc.reg_write_e_i;
        top->i_result_src_e = tc.result_src_e_i;
        top->i_mem_write_e = tc.mem_write_e_i;
        top->i_jump_e = tc.jump_e_i;
        top->i_branch_e = tc.branch_e_i;
        top->i_alu_src_e = tc.alu_src_e_i;
        top->i_alu_control_e = tc.alu_control_e_i;
        top->i_funct3_e = tc.funct3_e_i;
        top->i_op_a_sel_e = static_cast<uint8_t>(tc.op_a_sel_e_i);
        top->i_pc_target_src_sel_e = static_cast<uint8_t>(tc.pc_target_src_sel_e_i);
        top->i_pc_e = tc.pc_e_i;
        top->i_pc_plus_4_e = tc.pc_plus_4_e_i;
        top->i_rs1_data_e = tc.rs1_data_e_i;
        top->i_rs2_data_e = tc.rs2_data_e_i;
        top->i_imm_ext_e = tc.imm_ext_e_i;
        top->i_rd_addr_e = tc.rd_addr_e_i;
        top->i_forward_data_mem = tc.forward_data_mem_i;
        top->i_forward_data_wb = tc.forward_data_wb_i;
        top->i_forward_a_e = tc.forward_a_e_i;
        top->i_forward_b_e = tc.forward_b_e_i;

        eval_execute(top, tfp); // Evaluate combinational logic
        sim_time_execute_tb++;    // Increment VCD time for each test case

        bool current_pass = true;
        // Check all outputs
        if(top->o_reg_write_m != tc.exp_reg_write_m) { std::cout << "  FAIL o_reg_write_m Exp=" << tc.exp_reg_write_m << " Got=" << (int)top->o_reg_write_m << std::endl; current_pass = false; }
        if(top->o_result_src_m != tc.exp_result_src_m) { std::cout << "  FAIL o_result_src_m Exp=" << (int)tc.exp_result_src_m << " Got=" << (int)top->o_result_src_m << std::endl; current_pass = false; }
        if(top->o_mem_write_m != tc.exp_mem_write_m) { std::cout << "  FAIL o_mem_write_m Exp=" << tc.exp_mem_write_m << " Got=" << (int)top->o_mem_write_m << std::endl; current_pass = false; }
        if(top->o_alu_result_m != tc.exp_alu_result_m) { std::cout << "  FAIL o_alu_result_m Exp=0x" << std::hex << tc.exp_alu_result_m << " Got=0x" << top->o_alu_result_m << std::dec << std::endl; current_pass = false; }
        if(top->o_rs2_data_m != tc.exp_rs2_data_m) { std::cout << "  FAIL o_rs2_data_m Exp=0x" << std::hex << tc.exp_rs2_data_m << " Got=0x" << top->o_rs2_data_m << std::dec << std::endl; current_pass = false; }
        if(top->o_rd_addr_m != tc.exp_rd_addr_m) { std::cout << "  FAIL o_rd_addr_m Exp=" << (int)tc.exp_rd_addr_m << " Got=" << (int)top->o_rd_addr_m << std::endl; current_pass = false; }
        if(top->o_pc_plus_4_m != tc.exp_pc_plus_4_m) { std::cout << "  FAIL o_pc_plus_4_m Exp=0x" << std::hex << tc.exp_pc_plus_4_m << " Got=0x" << top->o_pc_plus_4_m << std::dec << std::endl; current_pass = false; }
        if(top->o_funct3_m != tc.exp_funct3_m) { std::cout << "  FAIL o_funct3_m Exp=" << (int)tc.exp_funct3_m << " Got=" << (int)top->o_funct3_m << std::endl; current_pass = false; }
        if(top->o_pc_src_e != tc.exp_pc_src_e) { std::cout << "  FAIL o_pc_src_e Exp=" << tc.exp_pc_src_e << " Got=" << (int)top->o_pc_src_e << std::endl; current_pass = false; }
        if(top->o_pc_target_addr_e != tc.exp_pc_target_addr_e) { std::cout << "  FAIL o_pc_target_addr_e Exp=0x" << std::hex << tc.exp_pc_target_addr_e << " Got=0x" << top->o_pc_target_addr_e << std::dec << std::endl; current_pass = false; }

        if (current_pass) {
            std::cout << "  PASS" << std::endl;
            passed_count++;
        } else {
            std::cout << "  FAILED" << std::endl;
        }
    }

    std::cout << "\nExecute Stage Testbench Finished. Passed " << passed_count << "/" << test_cases.size() << " tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    return (passed_count == test_cases.size()) ? EXIT_SUCCESS : EXIT_FAILURE;
}