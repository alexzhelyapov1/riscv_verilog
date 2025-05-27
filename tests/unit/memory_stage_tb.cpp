// tests/unit/memory_stage_tb.cpp
#include "Vmemory_stage_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>
#include <bitset> // For printing funct3

// Funct3 codes for LOAD/STORE (mirroring common/riscv_opcodes.svh)
const uint8_t FUNCT3_LB_MSTB  = 0b000;
const uint8_t FUNCT3_LH_MSTB  = 0b001;
const uint8_t FUNCT3_LW_MSTB  = 0b010;
const uint8_t FUNCT3_LD_MSTB  = 0b011;
const uint8_t FUNCT3_LBU_MSTB = 0b100;
const uint8_t FUNCT3_LHU_MSTB = 0b101;
const uint8_t FUNCT3_LWU_MSTB = 0b110;

const uint8_t FUNCT3_SB_MSTB  = 0b000;
const uint8_t FUNCT3_SH_MSTB  = 0b001;
const uint8_t FUNCT3_SW_MSTB  = 0b010;
const uint8_t FUNCT3_SD_MSTB  = 0b011;

// ResultSrc codes (mirroring control_unit logic)
const uint8_t RESULT_SRC_ALU_MSTB = 0b00;
const uint8_t RESULT_SRC_MEM_MSTB = 0b01;
const uint8_t RESULT_SRC_PC4_MSTB = 0b10;

vluint64_t sim_time_mem_stage = 0;

void tick_mem_stage(Vmemory_stage_tb* dut, VerilatedVcdC* tfp) {
    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time_mem_stage);
    sim_time_mem_stage++;

    dut->clk = 1;
    dut->eval(); // Write to data_memory happens on posedge
    if (tfp) tfp->dump(sim_time_mem_stage);
    sim_time_mem_stage++;
}

void reset_mem_stage(Vmemory_stage_tb* dut, VerilatedVcdC* tfp) {
    dut->rst_n = 0;
    dut->i_reg_write_m = 0;
    dut->i_result_src_m = 0;
    dut->i_mem_write_m = 0;
    dut->i_funct3_m = 0;
    dut->i_alu_result_m = 0;
    dut->i_rs2_data_m = 0;
    dut->i_rd_addr_m = 0;
    dut->i_pc_plus_4_m = 0;
    for (int i = 0; i < 3; ++i) { // Hold reset for a few cycles
        tick_mem_stage(dut, tfp);
    }
    dut->rst_n = 1;
    tick_mem_stage(dut, tfp); // One tick after reset
    std::cout << "DUT Memory Stage Reset" << std::endl;
}

struct MemStageTestCase {
    std::string name;
    // Inputs to memory_stage (from EX/MEM)
    bool     reg_write_m_i;
    uint8_t  result_src_m_i;
    bool     mem_write_m_i;
    uint8_t  funct3_m_i;
    uint64_t alu_result_m_i; // Address for mem or ALU result
    uint64_t rs2_data_m_i;   // Data to store
    uint8_t  rd_addr_m_i;
    uint64_t pc_plus_4_m_i;

    // Expected outputs from memory_stage (to MEM/WB)
    bool     exp_reg_write_w;
    uint8_t  exp_result_src_w;
    uint64_t exp_read_data_w;
    bool     check_read_data; // True if we expect a valid read_data_w
    uint64_t exp_alu_result_w;
    uint8_t  exp_rd_addr_w;
    uint64_t exp_pc_plus_4_w;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vmemory_stage_tb* top = new Vmemory_stage_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_memory_stage.vcd");

    std::cout << "Starting Memory Stage Testbench" << std::endl;

    std::vector<MemStageTestCase> test_cases;

    // --- Test Sequence: Write then Read ---
    // 1. Store Byte 0xAA at address 0x10
    test_cases.push_back({ "Write SB 0xAA @0x10",
        false, RESULT_SRC_ALU_MSTB, true, FUNCT3_SB_MSTB, 0x10, 0xAA, 0, 0,
        false, RESULT_SRC_ALU_MSTB, 0, false, 0x10, 0, 0});
    // 2. Load Byte from 0x10 (expect 0xAA, sign-extended to 0xFF...FFAA)
    test_cases.push_back({ "Read LB from 0x10",
        true, RESULT_SRC_MEM_MSTB, false, FUNCT3_LB_MSTB, 0x10, 0, 1, 0x104,
        true, RESULT_SRC_MEM_MSTB, 0xFFFFFFFFFFFFFFAAULL, true, 0x10, 1, 0x104});
    // 3. Load Byte Unsigned from 0x10 (expect 0xAA)
    test_cases.push_back({ "Read LBU from 0x10",
        true, RESULT_SRC_MEM_MSTB, false, FUNCT3_LBU_MSTB, 0x10, 0, 2, 0x108,
        true, RESULT_SRC_MEM_MSTB, 0xAA, true, 0x10, 2, 0x108});

    // 4. Store Word 0x12345678 at address 0x20
    test_cases.push_back({ "Write SW 0x12345678 @0x20",
        false, RESULT_SRC_ALU_MSTB, true, FUNCT3_SW_MSTB, 0x20, 0x12345678, 0, 0,
        false, RESULT_SRC_ALU_MSTB, 0, false, 0x20, 0, 0});
    // 5. Load Word from 0x20 (expect 0x12345678, sign-extended)
    test_cases.push_back({ "Read LW from 0x20",
        true, RESULT_SRC_MEM_MSTB, false, FUNCT3_LW_MSTB, 0x20, 0, 3, 0,
        true, RESULT_SRC_MEM_MSTB, 0x12345678, true, 0x20, 3, 0}); // 0x12345678 is positive, so sign ext doesn't change value if top bits are 0

    // 6. Store Double 0xAABBCCDD11223344 at address 0x30
    test_cases.push_back({ "Write SD @0x30",
        false, RESULT_SRC_ALU_MSTB, true, FUNCT3_SD_MSTB, 0x30, 0xAABBCCDD11223344ULL, 0, 0,
        false, RESULT_SRC_ALU_MSTB, 0, false, 0x30, 0, 0});
    // 7. Load Double from 0x30
    test_cases.push_back({ "Read LD from 0x30",
        true, RESULT_SRC_MEM_MSTB, false, FUNCT3_LD_MSTB, 0x30, 0, 4, 0,
        true, RESULT_SRC_MEM_MSTB, 0xAABBCCDD11223344ULL, true, 0x30, 4, 0});


    // // --- Test Case: R-Type (ALU result pass-through) --- <--- CTE, need to fix
    // test_cases.push_back({ "R-Type (ALU pass)",
    //     true, RESULT_SRC_ALU_MSTB, false, FUNCT3_ADD_SUB_EX_TB, /*funct3 arbitrary non-mem*/
    //     0xABCDEF0123456789ULL /*ALU res*/, 0 /*rs2 data*/, 10 /*rd*/, 0x1008 /*pc+4*/,
    //     true, RESULT_SRC_ALU_MSTB, 0 /*read_data undefined*/, false, 0xABCDEF0123456789ULL, 10, 0x1008
    // });

    // --- Test Case: JAL/JALR (PC+4 pass-through as result) ---
    test_cases.push_back({ "JAL/JALR (PC+4 pass)",
        true, RESULT_SRC_PC4_MSTB, false, 0, /*funct3 arbitrary non-mem*/
        0xBADADD /*ALU res (target addr)*/, 0, 11 /*rd*/, 0x2010 /*pc+4*/,
        true, RESULT_SRC_PC4_MSTB, 0, false, 0xBADADD, 11, 0x2010
    });

    int passed_count = 0;
    // Reset memory once at the beginning for all test sequences
    reset_mem_stage(top, tfp);

    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;
        // Set inputs
        top->i_reg_write_m = tc.reg_write_m_i;
        top->i_result_src_m = tc.result_src_m_i;
        top->i_mem_write_m = tc.mem_write_m_i;
        top->i_funct3_m = tc.funct3_m_i;
        top->i_alu_result_m = tc.alu_result_m_i;
        top->i_rs2_data_m = tc.rs2_data_m_i;
        top->i_rd_addr_m = tc.rd_addr_m_i;
        top->i_pc_plus_4_m = tc.pc_plus_4_m_i;

        // Clock the DUT
        // For writes, the change happens on posedge.
        // For reads, data_memory is combinational, so output is available after eval.
        // memory_stage itself is combinational.
        // tick_mem_stage will handle one full clock cycle.
        tick_mem_stage(top, tfp);

        // Perform checks
        bool current_pass = true;
        if(top->o_reg_write_w != tc.exp_reg_write_w) {std::cout << "  FAIL: o_reg_write_w. Exp=" << tc.exp_reg_write_w << " Got=" << (int)top->o_reg_write_w << std::endl; current_pass=false;}
        if(top->o_result_src_w != tc.exp_result_src_w) {std::cout << "  FAIL: o_result_src_w. Exp=" << (int)tc.exp_result_src_w << " Got=" << (int)top->o_result_src_w << std::endl; current_pass=false;}
        if(tc.check_read_data && (top->o_read_data_w != tc.exp_read_data_w)) {
            std::cout << "  FAIL: o_read_data_w. Exp=0x" << std::hex << tc.exp_read_data_w << " Got=0x" << top->o_read_data_w << std::dec << std::endl; current_pass=false;
        }
        if(top->o_alu_result_w != tc.exp_alu_result_w) {std::cout << "  FAIL: o_alu_result_w. Exp=0x" << std::hex << tc.exp_alu_result_w << " Got=0x" << top->o_alu_result_w << std::dec << std::endl; current_pass=false;}
        if(top->o_rd_addr_w != tc.exp_rd_addr_w) {std::cout << "  FAIL: o_rd_addr_w. Exp=" << (int)tc.exp_rd_addr_w << " Got=" << (int)top->o_rd_addr_w << std::endl; current_pass=false;}
        if(top->o_pc_plus_4_w != tc.exp_pc_plus_4_w) {std::cout << "  FAIL: o_pc_plus_4_w. Exp=0x" << std::hex << tc.exp_pc_plus_4_w << " Got=0x" << top->o_pc_plus_4_w << std::dec << std::endl; current_pass=false;}

        if (current_pass) {
            std::cout << "  PASS" << std::endl;
            passed_count++;
        } else {
            std::cout << "  FAILED" << std::endl;
        }
    }

    std::cout << "\nMemory Stage Testbench Finished. Passed " << passed_count << "/" << test_cases.size() << " tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    return (passed_count == test_cases.size()) ? EXIT_SUCCESS : EXIT_FAILURE;
}