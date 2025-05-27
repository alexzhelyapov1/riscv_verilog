// tests/unit/control_unit_tb.cpp
#include "Vcontrol_unit_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>
#include <map> // Not strictly needed here, but useful for complex setups
#include <bitset>

// --- C++ Constants Mirroring Verilog Defines ---
// From common/alu_defines.svh
const int ALU_CONTROL_WIDTH_CPP_CU = 4; // Suffix to avoid clash if alu.cpp linked
const uint8_t ALU_OP_ADD_CU  = 0b0000;
const uint8_t ALU_OP_SUB_CU  = 0b0001;
const uint8_t ALU_OP_SLL_CU  = 0b0010;
const uint8_t ALU_OP_SLT_CU  = 0b0011;
const uint8_t ALU_OP_SLTU_CU = 0b0100;
const uint8_t ALU_OP_XOR_CU  = 0b0101;
const uint8_t ALU_OP_SRL_CU  = 0b0110;
const uint8_t ALU_OP_SRA_CU  = 0b0111;
const uint8_t ALU_OP_OR_CU   = 0b1000;
const uint8_t ALU_OP_AND_CU  = 0b1001;

// From common/immediate_types.svh
enum ImmediateTypeCppCU {
    IMM_TYPE_NONE_CU, IMM_TYPE_I_CU, IMM_TYPE_S_CU, IMM_TYPE_B_CU,
    IMM_TYPE_U_CU, IMM_TYPE_J_CU, IMM_TYPE_ISHIFT_CU
};

// From common/control_signals_defines.svh
enum AluASrcSelCppCU { ALU_A_SRC_RS1_CU, ALU_A_SRC_PC_CU, ALU_A_SRC_ZERO_CU };
enum PcTargetSrcSelCppCU { PC_TARGET_SRC_PC_PLUS_IMM_CU, PC_TARGET_SRC_ALU_JALR_CU };

// From common/riscv_opcodes.svh
// Opcodes
const uint8_t OPCODE_LUI_CU        = 0b0110111;
const uint8_t OPCODE_AUIPC_CU      = 0b0010111;
const uint8_t OPCODE_JAL_CU        = 0b1101111;
const uint8_t OPCODE_JALR_CU       = 0b1100111;
const uint8_t OPCODE_BRANCH_CU     = 0b1100011;
const uint8_t OPCODE_LOAD_CU       = 0b0000011;
const uint8_t OPCODE_STORE_CU      = 0b0100011;
const uint8_t OPCODE_OP_IMM_CU   = 0b0010011;
const uint8_t OPCODE_OP_CU         = 0b0110011;
// Funct3 (examples, add more as needed for specific tests)
const uint8_t FUNCT3_ADDI_CU       = 0b000;
const uint8_t FUNCT3_SLLI_CU       = 0b001;
const uint8_t FUNCT3_SLTI_CU       = 0b010;
const uint8_t FUNCT3_SRLI_SRAI_CU  = 0b101;
const uint8_t FUNCT3_ADD_SUB_CU    = 0b000;
const uint8_t FUNCT3_BEQ_CU        = 0b000;
const uint8_t FUNCT3_BNE_CU        = 0b001;
const uint8_t FUNCT3_BLT_CU        = 0b100;
const uint8_t FUNCT3_BGE_CU        = 0b101;
const uint8_t FUNCT3_BLTU_CU       = 0b110;
const uint8_t FUNCT3_BGEU_CU       = 0b111;
// Funct7_5
const uint8_t FUNCT7_5_SRA_ALT_CU  = 1; // For SRA/SRAI/SUB
const uint8_t FUNCT7_5_ADD_MAIN_CU = 0; // For SRL/SRLI/ADD


vluint64_t sim_time_cu = 0;

void eval_cu(Vcontrol_unit_tb* dut, VerilatedVcdC* tfp) {
    dut->eval();
    if (tfp) tfp->dump(sim_time_cu);
    // sim_time_cu++; // For combinational, advance time per test case
}

struct ControlUnitTestCase {
    std::string name;
    uint8_t     op;
    uint8_t     funct3;
    uint8_t     funct7_5; // Only 1 bit

    // Expected outputs
    bool        exp_reg_write;
    uint8_t     exp_result_src; // 2 bits
    bool        exp_mem_write;
    bool        exp_jump;
    bool        exp_branch;
    bool        exp_alu_src_b;   // Operand B: 0 for Reg, 1 for Imm
    uint8_t     exp_alu_control;
    ImmediateTypeCppCU exp_imm_type;
    // exp_funct3_d is implicitly tc.funct3
    AluASrcSelCppCU exp_op_a_sel;
    PcTargetSrcSelCppCU exp_pc_target_sel;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vcontrol_unit_tb* top = new Vcontrol_unit_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_control_unit.vcd");

    std::cout << "Starting Control Unit Testbench" << std::endl;

    std::vector<ControlUnitTestCase> test_cases = {
        // LUI
        {"LUI", OPCODE_LUI_CU, 0, 0, true, 0b00, false, false, false, true, ALU_OP_ADD_CU, IMM_TYPE_U_CU, ALU_A_SRC_ZERO_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        // AUIPC
        {"AUIPC", OPCODE_AUIPC_CU, 0, 0, true, 0b00, false, false, false, true, ALU_OP_ADD_CU, IMM_TYPE_U_CU, ALU_A_SRC_PC_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        // JAL
        {"JAL", OPCODE_JAL_CU, 0, 0, true, 0b10, false, true, false, true, ALU_OP_ADD_CU, IMM_TYPE_J_CU, ALU_A_SRC_PC_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        // JALR
        {"JALR", OPCODE_JALR_CU, FUNCT3_ADDI_CU, 0, true, 0b10, false, true, false, true, ALU_OP_ADD_CU, IMM_TYPE_I_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_ALU_JALR_CU},
        // Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU)
        {"BEQ", OPCODE_BRANCH_CU, FUNCT3_BEQ_CU, 0, false,0b00,false,false,true, false,ALU_OP_SUB_CU, IMM_TYPE_B_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        {"BNE", OPCODE_BRANCH_CU, FUNCT3_BNE_CU, 0, false,0b00,false,false,true, false,ALU_OP_SUB_CU, IMM_TYPE_B_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        {"BLT", OPCODE_BRANCH_CU, FUNCT3_BLT_CU, 0, false,0b00,false,false,true, false,ALU_OP_SLT_CU, IMM_TYPE_B_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        {"BGE", OPCODE_BRANCH_CU, FUNCT3_BGE_CU, 0, false,0b00,false,false,true, false,ALU_OP_SLT_CU, IMM_TYPE_B_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        {"BLTU",OPCODE_BRANCH_CU, FUNCT3_BLTU_CU,0, false,0b00,false,false,true, false,ALU_OP_SLTU_CU,IMM_TYPE_B_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        {"BGEU",OPCODE_BRANCH_CU, FUNCT3_BGEU_CU,0, false,0b00,false,false,true, false,ALU_OP_SLTU_CU,IMM_TYPE_B_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        // Load (e.g. LW, funct3=010)
        {"LOAD (LW)", OPCODE_LOAD_CU, 0b010, 0, true, 0b01, false, false, false, true, ALU_OP_ADD_CU, IMM_TYPE_I_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        // Store (e.g. SW, funct3=010)
        {"STORE (SW)", OPCODE_STORE_CU, 0b010, 0, false,0b00,true, false, false, true, ALU_OP_ADD_CU, IMM_TYPE_S_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        // OP_IMM (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
        {"ADDI", OPCODE_OP_IMM_CU, FUNCT3_ADDI_CU, 0,                true,0b00,false,false,false, true, ALU_OP_ADD_CU, IMM_TYPE_I_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        {"SLLI", OPCODE_OP_IMM_CU, FUNCT3_SLLI_CU, FUNCT7_5_ADD_MAIN_CU, true,0b00,false,false,false, true, ALU_OP_SLL_CU, IMM_TYPE_ISHIFT_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        {"SRLI", OPCODE_OP_IMM_CU, FUNCT3_SRLI_SRAI_CU, FUNCT7_5_ADD_MAIN_CU,true,0b00,false,false,false, true, ALU_OP_SRL_CU, IMM_TYPE_ISHIFT_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        {"SRAI", OPCODE_OP_IMM_CU, FUNCT3_SRLI_SRAI_CU, FUNCT7_5_SRA_ALT_CU, true,0b00,false,false,false, true, ALU_OP_SRA_CU, IMM_TYPE_ISHIFT_CU, ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        // OP (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND)
        {"ADD", OPCODE_OP_CU, FUNCT3_ADD_SUB_CU, FUNCT7_5_ADD_MAIN_CU, true,0b00,false,false,false, false,ALU_OP_ADD_CU, IMM_TYPE_NONE_CU,ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        {"SUB", OPCODE_OP_CU, FUNCT3_ADD_SUB_CU, FUNCT7_5_SRA_ALT_CU,  true,0b00,false,false,false, false,ALU_OP_SUB_CU, IMM_TYPE_NONE_CU,ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        {"SRA", OPCODE_OP_CU, FUNCT3_SRLI_SRAI_CU, FUNCT7_5_SRA_ALT_CU,true,0b00,false,false,false, false,ALU_OP_SRA_CU, IMM_TYPE_NONE_CU,ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU},
        // Unknown Opcode
        {"Unknown Opcode", 0x7F, 0, 0, false,0b00,false,false,false,false,ALU_OP_ADD_CU, IMM_TYPE_NONE_CU,ALU_A_SRC_RS1_CU, PC_TARGET_SRC_PC_PLUS_IMM_CU}
    };

    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name
                  << " (op=0x" << std::hex << (int)tc.op
                  << ", f3=0x" << (int)tc.funct3
                  << ", f7_5=" << (int)tc.funct7_5 << std::dec << ")" << std::endl;

        top->i_op = tc.op;
        top->i_funct3 = tc.funct3;
        top->i_funct7_5 = tc.funct7_5;

        eval_cu(top, tfp);
        sim_time_cu++;

        bool current_pass = true;
        if(top->o_reg_write_d != tc.exp_reg_write) {std::cout << "  FAIL: RegWrite. Exp=" << tc.exp_reg_write << " Got=" << (int)top->o_reg_write_d << std::endl; current_pass=false;}
        if(top->o_result_src_d != tc.exp_result_src) {std::cout << "  FAIL: ResultSrc. Exp=" << (int)tc.exp_result_src << " Got=" << (int)top->o_result_src_d << std::endl; current_pass=false;}
        if(top->o_mem_write_d != tc.exp_mem_write) {std::cout << "  FAIL: MemWrite. Exp=" << tc.exp_mem_write << " Got=" << (int)top->o_mem_write_d << std::endl; current_pass=false;}
        if(top->o_jump_d != tc.exp_jump) {std::cout << "  FAIL: Jump. Exp=" << tc.exp_jump << " Got=" << (int)top->o_jump_d << std::endl; current_pass=false;}
        if(top->o_branch_d != tc.exp_branch) {std::cout << "  FAIL: Branch. Exp=" << tc.exp_branch << " Got=" << (int)top->o_branch_d << std::endl; current_pass=false;}
        if(top->o_alu_src_d != tc.exp_alu_src_b) {std::cout << "  FAIL: AluSrcB. Exp=" << tc.exp_alu_src_b << " Got=" << (int)top->o_alu_src_d << std::endl; current_pass=false;}
        if(top->o_alu_control_d != tc.exp_alu_control) {std::cout << "  FAIL: AluControl. Exp=0b" << std::bitset<ALU_CONTROL_WIDTH_CPP_CU>(tc.exp_alu_control) << " Got=0b" << std::bitset<ALU_CONTROL_WIDTH_CPP_CU>(top->o_alu_control_d) << std::endl; current_pass=false;}
        if(top->o_imm_type_d != static_cast<uint8_t>(tc.exp_imm_type)) {std::cout << "  FAIL: ImmType. Exp=" << (int)tc.exp_imm_type << " Got=" << (int)top->o_imm_type_d << std::endl; current_pass=false;}
        if(top->o_funct3_d != tc.funct3) {std::cout << "  FAIL: Funct3Out. Exp=0b" << std::bitset<3>(tc.funct3) << " Got=0b" << std::bitset<3>(top->o_funct3_d) << std::endl; current_pass=false;} // Funct3 should pass through
        if(top->o_op_a_sel_d != static_cast<uint8_t>(tc.exp_op_a_sel)) {std::cout << "  FAIL: OpASel. Exp=" << (int)tc.exp_op_a_sel << " Got=" << (int)top->o_op_a_sel_d << std::endl; current_pass=false;}
        if(top->o_pc_target_src_sel_d != static_cast<uint8_t>(tc.exp_pc_target_sel)) {std::cout << "  FAIL: PcTargetSel. Exp=" << (int)tc.exp_pc_target_sel << " Got=" << (int)top->o_pc_target_src_sel_d << std::endl; current_pass=false;}

        if (current_pass) {
            std::cout << "  PASS" << std::endl;
            passed_count++;
        } else {
            std::cout << "  FAILED" << std::endl;
        }
    }

    std::cout << "\nControl Unit Testbench Finished. Passed " << passed_count << "/" << test_cases.size() << " tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    return (passed_count == test_cases.size()) ? EXIT_SUCCESS : EXIT_FAILURE;
}