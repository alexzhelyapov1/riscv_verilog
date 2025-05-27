// tests/unit/writeback_stage_tb.cpp
#include "Vwriteback_stage_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>
#include <bitset> // Добавил для вывода result_src в бинарном виде

vluint64_t sim_time_wb = 0;

void eval_wb(Vwriteback_stage_tb* dut, VerilatedVcdC* tfp) {
    dut->eval();
    if (tfp) {
        tfp->dump(sim_time_wb);
    }
}

struct WbTestCase {
    std::string name;
    uint8_t     result_src; // 2 bits
    uint64_t    read_data_in;
    uint64_t    alu_result_in;
    uint64_t    pc_plus_4_in;
    uint64_t    expected_result_w;
    bool        expect_defined_output;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vwriteback_stage_tb* top = new Vwriteback_stage_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_writeback_stage.vcd");

    std::cout << "Starting Writeback Stage Testbench (Corrected)" << std::endl;

    // Используем более различимые и валидные значения
    const uint64_t VAL_MEM  = 0xDDDDDDDDDDDDDDDDULL;
    const uint64_t VAL_ALU  = 0xAAAAAAAAAAAAAAAAULL;
    const uint64_t VAL_PC4  = 0x4444444444444444ULL;
    const uint64_t VAL_ZERO = 0x0000000000000000ULL;
    const uint64_t VAL_MAX  = 0xFFFFFFFFFFFFFFFFULL;


    std::vector<WbTestCase> test_cases = {
        {"Select ALU Result",           0b00, VAL_MEM, VAL_ALU, VAL_PC4, VAL_ALU, true},
        {"Select Memory Data",          0b01, VAL_MEM, VAL_ALU, VAL_PC4, VAL_MEM, true},
        {"Select PC+4",                 0b10, VAL_MEM, VAL_ALU, VAL_PC4, VAL_PC4, true},

        {"Select ALU (data is zero)",   0b00, VAL_MEM, VAL_ZERO, VAL_PC4, VAL_ZERO, true},
        {"Select Mem (data is zero)",   0b01, VAL_ZERO, VAL_ALU, VAL_PC4, VAL_ZERO, true},
        {"Select PC+4 (data is zero)",  0b10, VAL_MEM, VAL_ALU, VAL_ZERO, VAL_ZERO, true},

        {"Select ALU (data is max)",    0b00, VAL_MEM, VAL_MAX, VAL_PC4, VAL_MAX, true},
        {"Select Mem (data is max)",    0b01, VAL_MAX, VAL_ALU, VAL_PC4, VAL_MAX, true},
        {"Select PC+4 (data is max)",   0b10, VAL_MEM, VAL_ALU, VAL_MAX, VAL_MAX, true},

        // Test default case of result_src_wb_i (e.g., 2'b11)
        // Verilog `default: result_w_o = `DATA_WIDTH'('x);`
        // Verilator might represent 'x' as 0 if not forced otherwise by flags or specific handling.
        // We check that it's NOT one of the valid inputs if expect_defined_output is false.
        {"Invalid ResultSrc (11)",      0b11, VAL_MEM, VAL_ALU, VAL_PC4, VAL_ZERO /* Placeholder, actual 'x' behavior */, false}
    };

    int passed_count = 0;
    int total_defined_tests = 0;

    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;
        std::cout << "  Inputs: result_src=0b" << std::bitset<2>(tc.result_src)
                  << ", read_data=0x" << std::hex << tc.read_data_in
                  << ", alu_result=0x" << tc.alu_result_in
                  << ", pc_plus_4=0x" << tc.pc_plus_4_in << std::dec << std::endl;

        top->i_result_src_wb = tc.result_src;
        top->i_read_data_wb = tc.read_data_in;
        top->i_alu_result_wb = tc.alu_result_in;
        top->i_pc_plus_4_wb = tc.pc_plus_4_in;

        eval_wb(top, tfp);
        sim_time_wb++;

        bool current_pass = true;
        if (tc.expect_defined_output) {
            total_defined_tests++;
            if (top->o_result_w != tc.expected_result_w) {
                std::cout << "  FAIL: Result_W Mismatch." << std::endl;
                std::cout << "    Expected: 0x" << std::hex << tc.expected_result_w << std::dec << std::endl;
                std::cout << "    Got:      0x" << std::hex << top->o_result_w << std::dec << std::endl;
                current_pass = false;
            }
        } else { // Check for 'x' behavior (not matching any defined input path for this test case)
            if (top->o_result_w == tc.read_data_in && tc.result_src != 0b01) { // Check if it accidentally matched read_data
                std::cout << "  FAIL: Undefined ResultSrc case (0b11) unexpectedly matched ReadData input." << std::endl;
                std::cout << "    Got: 0x" << std::hex << top->o_result_w << std::dec << std::endl;
                current_pass = false;
            } else if (top->o_result_w == tc.alu_result_in && tc.result_src != 0b00) { // Check if it accidentally matched alu_result
                std::cout << "  FAIL: Undefined ResultSrc case (0b11) unexpectedly matched AluResult input." << std::endl;
                std::cout << "    Got: 0x" << std::hex << top->o_result_w << std::dec << std::endl;
                current_pass = false;
            } else if (top->o_result_w == tc.pc_plus_4_in && tc.result_src != 0b10) { // Check if it accidentally matched pc_plus_4
                std::cout << "  FAIL: Undefined ResultSrc case (0b11) unexpectedly matched PC+4 input." << std::endl;
                std::cout << "    Got: 0x" << std::hex << top->o_result_w << std::dec << std::endl;
                current_pass = false;
            } else {
                 std::cout << "  INFO: Undefined ResultSrc (0b11). Got: 0x" << std::hex << top->o_result_w << std::dec
                           << " (Expected 'x'-driven behavior, not matching valid inputs)." << std::endl;
                 // If Verilator consistently drives 'x' to 0, this might pass if inputs are non-zero.
                 // If Verilator drives 'x' to a random-like value, this check is more robust.
                 // A more definitive check for 'x' would require Verilator-specific features or DPI.
            }
        }

        if (tc.expect_defined_output) { // Only count defined behavior tests towards pass/fail strict count
            if (current_pass) {
                std::cout << "  PASS" << std::endl;
                passed_count++;
            } else {
                std::cout << "  FAILED" << std::endl;
            }
        } else if (current_pass) { // For !expect_defined_output, current_pass means it didn't match known inputs
            std::cout << "  PASS (undefined case handled as expected)" << std::endl;
            // Do not increment passed_count here for the main defined test counter
        } else { // !expect_defined_output && !current_pass
            std::cout << "  FAILED (undefined case unexpectedly matched an input)" << std::endl;
        }
    }

    std::cout << "\nWriteback Stage Testbench Finished." << std::endl;
    if (total_defined_tests > 0) {
        std::cout << "Passed " << passed_count << "/" << total_defined_tests << " defined behavior tests." << std::endl;
    } else {
        std::cout << "No defined behavior tests were executed." << std::endl;
    }


    if (tfp) tfp->close();
    delete top;
    // Exit status based on defined behavior tests only
    return (total_defined_tests == 0 || passed_count == total_defined_tests) ? EXIT_SUCCESS : EXIT_FAILURE;
}