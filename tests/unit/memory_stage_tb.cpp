// tests/unit/memory_stage_tb.cpp
#include "Vmemory_stage_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>

// Funct3 codes for LOAD/STORE (из common/riscv_opcodes.svh)
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

// ResultSrc codes
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
    dut->eval(); // Запись в data_memory происходит на posedge
    if (tfp) tfp->dump(sim_time_mem_stage);
    sim_time_mem_stage++;
}

void reset_mem_stage(Vmemory_stage_tb* dut, VerilatedVcdC* tfp) {
    dut->rst_n = 0;
    // Init inputs to known state during reset
    dut->i_reg_write_m = 0;
    dut->i_result_src_m = 0;
    dut->i_mem_write_m = 0;
    dut->i_funct3_m = 0;
    dut->i_alu_result_m = 0;
    dut->i_rs2_data_m = 0;
    dut->i_rd_addr_m = 0;
    dut->i_pc_plus_4_m = 0;

    for (int i = 0; i < 5; ++i) { // Hold reset
        tick_mem_stage(dut, tfp);
    }
    dut->rst_n = 1;
    tick_mem_stage(dut, tfp); // One tick after reset
    std::cout << "DUT Memory Stage Reset" << std::endl;
}

struct MemStageTestCase {
    std::string name;
    // Inputs to memory_stage
    bool     reg_write_m_i;
    uint8_t  result_src_m_i;
    bool     mem_write_m_i;
    uint8_t  funct3_m_i;
    uint64_t alu_result_m_i; // Address or ALU data
    uint64_t rs2_data_m_i;   // Data to store
    uint8_t  rd_addr_m_i;
    uint64_t pc_plus_4_m_i;

    // Expected outputs from memory_stage
    bool     exp_reg_write_w;
    uint8_t  exp_result_src_w;
    uint64_t exp_read_data_w;    // Only checked if it's a load
    bool     check_read_data;    // Flag to indicate if exp_read_data_w is valid
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

    // --- Test Case Group 1: Store Operations ---
    // Write byte, then try to read it back in a subsequent (conceptual) cycle via a Load test
    test_cases.push_back({
        "Store Byte (SB)",
        false, RESULT_SRC_ALU_MSTB, true, FUNCT3_SB_MSTB, // reg_write=0, mem_write=1
        0x10, 0x123456789ABCDEF0ULL, 0, 0,               // addr=0x10, data_to_store (only LSB used)
        false, RESULT_SRC_ALU_MSTB, 0, false, 0x10, 0, 0 // Outputs (read_data not checked)
    });
    // Read back the byte (as LB)
    test_cases.push_back({
        "Load Byte (LB) after SB",
        true, RESULT_SRC_MEM_MSTB, false, FUNCT3_LB_MSTB,
        0x10, 0, 1, 0, // addr=0x10, rd=1
        true, RESULT_SRC_MEM_MSTB, 0xF0, true, 0x10, 1, 0 // Expected: sign-extended 0xF0
    });

    // Write half-word, then read back
    test_cases.push_back({
        "Store Half (SH)",
        false, RESULT_SRC_ALU_MSTB, true, FUNCT3_SH_MSTB,
        0x20, 0xABCD1234ULL, 0, 0,
        false, RESULT_SRC_ALU_MSTB, 0, false, 0x20, 0, 0
    });
    test_cases.push_back({
        "Load Half Unsigned (LHU) after SH",
        true, RESULT_SRC_MEM_MSTB, false, FUNCT3_LHU_MSTB,
        0x20, 0, 2, 0,
        true, RESULT_SRC_MEM_MSTB, 0x1234, true, 0x20, 2, 0
    });
     test_cases.push_back({
        "Load Half Signed (LH) after SH", // Assuming 0xABCD1234 was written, 0x1234 is positive
        true, RESULT_SRC_MEM_MSTB, false, FUNCT3_LH_MSTB,
        0x20, 0, 3, 0,
        true, RESULT_SRC_MEM_MSTB, 0x1234, true, 0x20, 3, 0
    });


    // Write word, then read back
    test_cases.push_back({
        "Store Word (SW)",
        false, RESULT_SRC_ALU_MSTB, true, FUNCT3_SW_MSTB,
        0x30, 0x89ABCDEF, 0, 0,
        false, RESULT_SRC_ALU_MSTB, 0, false, 0x30, 0, 0
    });
    test_cases.push_back({
        "Load Word (LW) after SW",
        true, RESULT_SRC_MEM_MSTB, false, FUNCT3_LW_MSTB,
        0x30, 0, 4, 0,
        true, RESULT_SRC_MEM_MSTB, 0xFFFFFFFF89ABCDEFULL, true, 0x30, 4, 0
    });

    // Write double-word, then read back
    test_cases.push_back({
        "Store Double (SD)",
        false, RESULT_SRC_ALU_MSTB, true, FUNCT3_SD_MSTB,
        0x40, 0x11223344AABBCCDDULL, 0, 0,
        false, RESULT_SRC_ALU_MSTB, 0, false, 0x40, 0, 0
    });
    test_cases.push_back({
        "Load Double (LD) after SD",
        true, RESULT_SRC_MEM_MSTB, false, FUNCT3_LD_MSTB,
        0x40, 0, 5, 0,
        true, RESULT_SRC_MEM_MSTB, 0x11223344AABBCCDDULL, true, 0x40, 5, 0
    });

    // --- Test Case Group 2: Non-Memory Operations (pass-through) ---
    test_cases.push_back({
        "R-Type Pass Through (ADD result)",
        true, RESULT_SRC_ALU_MSTB, false, FUNCT3_ADD_SUB_EX_TB, // mem_write=0
        0x7777, 0, 6, 0x1004, // alu_result=0x7777, rd=6, pc+4
        true, RESULT_SRC_ALU_MSTB, 0 /*read_data don't care*/, false, 0x7777, 6, 0x1004
    });
    test_cases.push_back({
        "JAL/JALR Pass Through (PC+4 result)",
        true, RESULT_SRC_PC4_MSTB, false, 0, // result_src=PC+4
        0, 0, 7, 0x2008, // alu_result (target_addr) don't care for WB, pc+4 is result
        true, RESULT_SRC_PC4_MSTB, 0, false, 0, 7, 0x2008
    });


    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;
        // Для каждого нового теста сбрасываем память, чтобы тесты были независимы
        if (tc.action == "WRITE" || test_cases[0].name == tc.name) { // Reset before first test or any write
             reset_mem_stage(top, tfp);
        }


        top->i_reg_write_m = tc.reg_write_m_i;
        top->i_result_src_m = tc.result_src_m_i;
        top->i_mem_write_m = tc.mem_write_m_i;
        top->i_funct3_m = tc.funct3_m_i;
        top->i_alu_result_m = tc.alu_result_m_i;
        top->i_rs2_data_m = tc.rs2_data_m_i;
        top->i_rd_addr_m = tc.rd_addr_m_i;
        top->i_pc_plus_4_m = tc.pc_plus_4_m_i;

        // Операции записи в память происходят по posedge clk.
        // Операции чтения из памяти комбинационные (в data_memory.sv).
        // memory_stage в основном пробрасывает сигналы.
        tick_mem_stage(top, tfp); // Этот такт нужен для записи, если mem_write_en_i=1
                                  // и для того, чтобы read_data_o на выходе data_memory обновилось.

        bool current_pass = true;
        // Проверка проброса управляющих сигналов
        if(top->o_reg_write_w != tc.exp_reg_write_w) {std::cout << "  FAIL: o_reg_write_w. Exp=" << tc.exp_reg_write_w << " Got=" << (int)top->o_reg_write_w << std::endl; current_pass=false;}
        if(top->o_result_src_w != tc.exp_result_src_w) {std::cout << "  FAIL: o_result_src_w. Exp=" << (int)tc.exp_result_src_w << " Got=" << (int)top->o_result_src_w << std::endl; current_pass=false;}
        // Проверка проброса данных
        if(top->o_alu_result_w != tc.exp_alu_result_w) {std::cout << "  FAIL: o_alu_result_w. Exp=0x" << std::hex << tc.exp_alu_result_w << " Got=0x" << top->o_alu_result_w << std::dec << std::endl; current_pass=false;}
        if(top->o_rd_addr_w != tc.exp_rd_addr_w) {std::cout << "  FAIL: o_rd_addr_w. Exp=" << (int)tc.exp_rd_addr_w << " Got=" << (int)top->o_rd_addr_w << std::endl; current_pass=false;}
        if(top->o_pc_plus_4_w != tc.exp_pc_plus_4_w) {std::cout << "  FAIL: o_pc_plus_4_w. Exp=0x" << std::hex << tc.exp_pc_plus_4_w << " Got=0x" << top->o_pc_plus_4_w << std::dec << std::endl; current_pass=false;}

        if (tc.check_read_data) {
            if (top->o_read_data_w != tc.exp_read_data_w) {
                std::cout << "  FAIL: o_read_data_w. Exp=0x" << std::hex << tc.exp_read_data_w << " Got=0x" << top->o_read_data_w << std::dec << std::endl;
                current_pass = false;
            }
        }

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