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

// C++ equivalents of enums/defines
// From common/alu_defines.svh
const int ALU_CONTROL_WIDTH_CPP = 4; // Renamed to avoid conflict if alu_defines.svh was accidentally included
const uint8_t ALU_OP_ADD_CPP  = 0b0000;
const uint8_t ALU_OP_SUB_CPP  = 0b0001;
const uint8_t ALU_OP_SLT_CPP  = 0b0011;
const uint8_t ALU_OP_SLTU_CPP = 0b0100;
// ... add other ALU_OPs as needed for tests

// From common/control_signals_defines.svh
enum AluASrcSelCppTb {
    ALU_A_SRC_RS1_TB,
    ALU_A_SRC_PC_TB,
    ALU_A_SRC_ZERO_TB
};

enum PcTargetSrcSelCppTb {
    PC_TARGET_SRC_PC_PLUS_IMM_TB,
    PC_TARGET_SRC_ALU_JALR_TB
};

// From common/riscv_opcodes.svh (funct3 codes)
const uint8_t FUNCT3_BEQ_CPP  = 0b000;
const uint8_t FUNCT3_BNE_CPP  = 0b001;
const uint8_t FUNCT3_BLT_CPP  = 0b100;
const uint8_t FUNCT3_BGE_CPP  = 0b101;
const uint8_t FUNCT3_BLTU_CPP = 0b110;
const uint8_t FUNCT3_BGEU_CPP = 0b111;


vluint64_t sim_time_execute = 0; // Separate sim_time to avoid conflict if linked with other VCDs

void tick_execute(Vexecute_tb* dut, VerilatedVcdC* tfp) {
    dut->clk = 0; // execute stage is combinational, but testbench needs clk for VCD
    dut->eval();
    if (tfp) tfp->dump(sim_time_execute);
    sim_time_execute++;
    dut->clk = 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time_execute);
    sim_time_execute++;
}

struct ExecuteTestCase {
    std::string name;
    // Inputs to Execute Stage
    bool        reg_write_e;
    uint8_t     result_src_e;
    bool        mem_write_e;
    bool        jump_e;
    bool        branch_e;
    bool        alu_src_e; // OpB sel
    uint8_t     alu_control_e;
    uint8_t     funct3_e;
    AluASrcSelCppTb op_a_sel_e;
    PcTargetSrcSelCppTb pc_target_src_sel_e;
    uint64_t    pc_e;
    uint64_t    pc_plus_4_e;
    uint64_t    rs1_data_e;
    uint64_t    rs2_data_e;
    uint64_t    imm_ext_e;
    uint8_t     rd_addr_e;

    // Expected Outputs (to EX/MEM)
    bool        exp_reg_write_m;
    uint8_t     exp_result_src_m;
    bool        exp_mem_write_m;
    uint64_t    exp_alu_result_m;
    uint64_t    exp_rs2_data_m; // Data to store
    uint8_t     exp_rd_addr_m;
    uint64_t    exp_pc_plus_4_m;
    uint8_t     exp_funct3_m;

    // Expected Outputs for PC update
    bool        exp_pc_src_e;
    uint64_t    exp_pc_target_addr_e;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vexecute_tb* top = new Vexecute_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_execute.vcd");

    std::cout << "Starting Execute Stage Testbench" << std::endl;
    top->rst_n = 1; // Execute stage is mostly combinational, reset not critical for logic but good for init

    std::vector<ExecuteTestCase> test_cases = {
        { // ADD R-Type: x3 = x1 (10) + x2 (20)
            "ADD R-Type",
            true, 0b00, false, false, false, false, ALU_OP_ADD_CPP, 0, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB,
            0x100, 0x104, 10, 20, 0, 3, // Inputs
            true, 0b00, false, 30, 20, 3, 0x104, 0, // Expected EX/MEM outputs
            false, 0x100 + 0 // Expected PC update (no branch/jump)
        },
        { // ADDI: x1 = x2 (5) + 15
            "ADDI I-Type",
            true, 0b00, false, false, false, true, ALU_OP_ADD_CPP, FUNCT3_BEQ_CPP /*funct3 for addi*/, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB,
            0x200, 0x204, 5, 100/*rs2_data not used*/, 15, 1,
            true, 0b00, false, 20, 100, 1, 0x204, FUNCT3_BEQ_CPP,
            false, 0x200 + 15
        },
        { // LUI: x5 = 0xABCD0000
            "LUI U-Type",
            true, 0b00, false, false, false, true, ALU_OP_ADD_CPP, 0, ALU_A_SRC_ZERO_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB,
            0x300, 0x304, 0/*rs1_data not used*/, 0/*rs2_data not used*/, 0xFFFFFFFFABCD0000ULL, 5,
            true, 0b00, false, 0xFFFFFFFFABCD0000ULL, 0, 5, 0x304, 0,
            false, 0x300 + 0xFFFFFFFFABCD0000ULL // Default target if not jump/branch
        },
        { // AUIPC: x1 = PC(0x400) + 0x12300000
            "AUIPC U-Type",
            true, 0b00, false, false, false, true, ALU_OP_ADD_CPP, 0, ALU_A_SRC_PC_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB,
            0x400, 0x404, 0/*rs1 not used*/, 0/*rs2 not used*/, 0x12300000ULL, 1,
            true, 0b00, false, 0x400 + 0x12300000ULL, 0, 1, 0x404, 0,
            false, 0x400 + 0x12300000ULL
        },
        { // BEQ taken: pc=0x100, rs1=10, rs2=10, imm=0x20. Target=0x120
            "BEQ Branch Taken",
            false, 0b00, false, false, true, false, ALU_OP_SUB_CPP, FUNCT3_BEQ_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB,
            0x100, 0x104, 10, 10, 0x20, 0/*rd not written*/,
            false, 0b00, false, 0/*ALU res*/, 10/*rs2_data*/, 0, 0x104, FUNCT3_BEQ_CPP,
            true, 0x100 + 0x20
        },
        { // BNE not taken: pc=0x100, rs1=10, rs2=10, imm=0x20. Target=PC+4
            "BNE Branch Not Taken",
            false, 0b00, false, false, true, false, ALU_OP_SUB_CPP, FUNCT3_BNE_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB,
            0x100, 0x104, 10, 10, 0x20, 0,
            false, 0b00, false, 0, 10, 0, 0x104, FUNCT3_BNE_CPP,
            false, 0x100 + 0x20 // pc_target_addr still calculated
        },
        { // JALR: rd=x1, rs1=x2(0x1000), imm=0x80. Target=(0x1000+0x80)&~1 = 0x1080. rd=PC+4
            "JALR Jump",
            true, 0b10/*PC+4*/, false, true, false, true, ALU_OP_ADD_CPP, FUNCT3_BEQ_CPP/*funct3 for jalr*/, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_ALU_JALR_TB,
            0x500, 0x504, 0x1000, 0/*rs2 not used*/, 0x80, 1,
            true, 0b10, false, 0x1080/*ALURes*/, 0, 1, 0x504, FUNCT3_BEQ_CPP,
            true, (0x1000 + 0x80) & ~1ULL
        },
        // Add more cases: LW, SW, other branches, JAL
    };

    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;

        // Apply inputs
        top->i_reg_write_e = tc.reg_write_e;
        top->i_result_src_e = tc.result_src_e;
        top->i_mem_write_e = tc.mem_write_e;
        top->i_jump_e = tc.jump_e;
        top->i_branch_e = tc.branch_e;
        top->i_alu_src_e = tc.alu_src_e;
        top->i_alu_control_e = tc.alu_control_e;
        top->i_funct3_e = tc.funct3_e;
        top->i_op_a_sel_e = static_cast<uint8_t>(tc.op_a_sel_e);
        top->i_pc_target_src_sel_e = static_cast<uint8_t>(tc.pc_target_src_sel_e);
        top->i_pc_e = tc.pc_e;
        top->i_pc_plus_4_e = tc.pc_plus_4_e;
        top->i_rs1_data_e = tc.rs1_data_e;
        top->i_rs2_data_e = tc.rs2_data_e;
        top->i_imm_ext_e = tc.imm_ext_e;
        top->i_rd_addr_e = tc.rd_addr_e;

        tick_execute(top, tfp); // Evaluate combinational logic

        bool current_pass = true;
        // Check EX/MEM outputs
        if(top->o_reg_write_m != tc.exp_reg_write_m) {std::cout << "  FAIL: o_reg_write_m. Exp=" << tc.exp_reg_write_m << " Got=" << (int)top->o_reg_write_m << std::endl; current_pass=false;}
        if(top->o_result_src_m != tc.exp_result_src_m) {std::cout << "  FAIL: o_result_src_m. Exp=" << (int)tc.exp_result_src_m << " Got=" << (int)top->o_result_src_m << std::endl; current_pass=false;}
        if(top->o_mem_write_m != tc.exp_mem_write_m) {std::cout << "  FAIL: o_mem_write_m. Exp=" << tc.exp_mem_write_m << " Got=" << (int)top->o_mem_write_m << std::endl; current_pass=false;}
        if(top->o_alu_result_m != tc.exp_alu_result_m) {std::cout << "  FAIL: o_alu_result_m. Exp=0x" << std::hex << tc.exp_alu_result_m << " Got=0x" << top->o_alu_result_m << std::dec << std::endl; current_pass=false;}
        if(top->o_rs2_data_m != tc.exp_rs2_data_m) {std::cout << "  FAIL: o_rs2_data_m. Exp=0x" << std::hex << tc.exp_rs2_data_m << " Got=0x" << top->o_rs2_data_m << std::dec << std::endl; current_pass=false;}
        if(top->o_rd_addr_m != tc.exp_rd_addr_m) {std::cout << "  FAIL: o_rd_addr_m. Exp=" << (int)tc.exp_rd_addr_m << " Got=" << (int)top->o_rd_addr_m << std::endl; current_pass=false;}
        if(top->o_pc_plus_4_m != tc.exp_pc_plus_4_m) {std::cout << "  FAIL: o_pc_plus_4_m. Exp=0x" << std::hex << tc.exp_pc_plus_4_m << " Got=0x" << top->o_pc_plus_4_m << std::dec << std::endl; current_pass=false;}
        if(top->o_funct3_m != tc.exp_funct3_m) {std::cout << "  FAIL: o_funct3_m. Exp=" << (int)tc.exp_funct3_m << " Got=" << (int)top->o_funct3_m << std::endl; current_pass=false;}

        // Check PC update outputs
        if(top->o_pc_src_e != tc.exp_pc_src_e) {std::cout << "  FAIL: o_pc_src_e. Exp=" << tc.exp_pc_src_e << " Got=" << (int)top->o_pc_src_e << std::endl; current_pass=false;}
        if(top->o_pc_target_addr_e != tc.exp_pc_target_addr_e) {std::cout << "  FAIL: o_pc_target_addr_e. Exp=0x" << std::hex << tc.exp_pc_target_addr_e << " Got=0x" << top->o_pc_target_addr_e << std::dec << std::endl; current_pass=false;}

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