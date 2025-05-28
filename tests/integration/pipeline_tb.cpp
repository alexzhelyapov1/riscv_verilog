// Файл: tests/integration/pipeline_tb.cpp
#include "Vpipeline.h"
#include "verilated_vcd_c.h"
#include "verilated.h"

#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#include <vector>
#include <sstream>
#include <cassert>

// Макросы, определяемые CMake
#ifndef PIPELINE_TEST_CASE_NAME_STR_RAW
#error "PIPELINE_TEST_CASE_NAME_STR_RAW not defined! Pass it via CFLAGS from CMake."
#endif

#ifndef EXPECTED_WD3_FILE_PATH_STR_RAW
#error "EXPECTED_WD3_FILE_PATH_STR_RAW not defined! Pass it via CFLAGS from CMake."
#endif

#ifndef NUM_CYCLES_TO_RUN
#error "NUM_CYCLES_TO_RUN not defined! Pass it via CFLAGS from CMake."
#endif

// Вспомогательные макросы для превращения в строку
#define STRINGIFY_HELPER(x) #x
#define STRINGIFY(x) STRINGIFY_HELPER(x)

// Глобальные переменные из макросов
const std::string G_PIPELINE_TEST_CASE_NAME = STRINGIFY(PIPELINE_TEST_CASE_NAME_STR_RAW);
const std::string G_EXPECTED_WD3_FILE_PATH = STRINGIFY(EXPECTED_WD3_FILE_PATH_STR_RAW);
const int G_NUM_CYCLES_TO_RUN = NUM_CYCLES_TO_RUN;
const uint64_t X_DEF = 0xFFFFFFFFFFFFFFFFUL;


vluint64_t sim_time = 0;

double sc_time_stamp() {
    return sim_time;
}

// In C++, the top module instance is named 'top' by Verilator default
// The Verilog module is 'pipeline'. So Vpipeline.h and Vpipeline class.
// The input ports in Verilog `clk, rst_n` become `top->clk, top->rst_n`
// The output ports in Verilog `debug_pc_f, ...` become `top->debug_pc_f, ...`
void tick(Vpipeline* top, VerilatedVcdC* tfp) {
    top->clk = 0; // Verilog `clk` input
    top->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;

    top->clk = 1; // Verilog `clk` input
    top->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;
}

bool load_expected_wd3_values(const std::string& filepath, std::vector<uint64_t>& values, int expected_num_cycles) {
    std::ifstream file(filepath);
    if (!file.is_open()) {
        std::cerr << "ERROR: Could not open expected output file: " << filepath << std::endl;
        return false;
    }
    std::string line;
    int line_count = 0;
    while (std::getline(file, line)) {
        if (line.empty() || line[0] == '#') {
            continue;
        }
        try {
            if (line == "X" || line == "x") {
                values.push_back(X_DEF);
            } else {
                values.push_back(std::stoull(line, nullptr, 16));
            }
            line_count++;
        } catch (const std::exception& e) {
            std::cerr << "Error parsing hex value '" << line << "' at line " << (line_count + 1) << ": " << e.what() << std::endl;
            return false;
        }
    }
    file.close();
    if (line_count < expected_num_cycles) {
        std::cerr << "ERROR: Number of expected values (" << line_count
                  << ") is less than NUM_CYCLES_TO_RUN (" << expected_num_cycles << ")." << std::endl;
        std::cerr << "Please provide an expected value (or 'X' if no write) for each cycle." << std::endl;
        return false;
    }
    if (line_count > expected_num_cycles) {
         std::cerr << "Warning: Number of expected values (" << line_count
                  << ") is greater than NUM_CYCLES_TO_RUN (" << expected_num_cycles << ")." << std::endl;
    }
    return true;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vpipeline* top = new Vpipeline; // Instantiating the Verilog module 'pipeline'

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    std::string vcd_file_name = G_PIPELINE_TEST_CASE_NAME + "_pipeline_tb.vcd";
    tfp->open(vcd_file_name.c_str());

    std::cout << "Starting Pipeline Test Case: " << G_PIPELINE_TEST_CASE_NAME << std::endl;
    std::cout << "Expected output file: " << G_EXPECTED_WD3_FILE_PATH << std::endl;
    std::cout << "Number of cycles to run: " << G_NUM_CYCLES_TO_RUN << std::endl;

    std::vector<uint64_t> expected_results_per_cycle;
    if (!load_expected_wd3_values(G_EXPECTED_WD3_FILE_PATH, expected_results_per_cycle, G_NUM_CYCLES_TO_RUN)) {
        if (tfp) tfp->close();
        delete top;
        return 1;
    }

    top->rst_n = 0; // Assert reset (active low)
    for(int i=0; i<2; ++i) { // Hold reset for 2 cycles
        tick(top, tfp);
    }
    top->rst_n = 1; // De-assert reset
    tick(top, tfp); // One cycle for reset to propagate
    std::cout << "Reset complete." << std::endl;

    bool test_passed = true;

    std::cout << "\nCycle | PC_F     | Instr_F  | RegWr_WB | RdAddr_WB | Result_W (Got) | Result_W (Exp) | Status" << std::endl;
    std::cout << "------|----------|----------|----------|-----------|----------------|----------------|-------" << std::endl;

    for (int cycle = 0; cycle < G_NUM_CYCLES_TO_RUN; ++cycle) {
        tick(top, tfp);

        // Read debug outputs from pipeline.sv
        uint64_t current_pc_f = top->debug_pc_f;
        uint32_t current_instr_f = top->debug_instr_f;
        bool current_reg_write_wb = top->debug_reg_write_wb;
        uint8_t current_rd_addr_wb = top->debug_rd_addr_wb;
        uint64_t current_result_w = top->debug_result_w;

        uint64_t expected_result = expected_results_per_cycle[cycle];
        bool expect_write_this_cycle = (expected_result != X_DEF);

        std::cout << std::setw(5) << std::dec << cycle + 1 << " | " // cycle is 0-indexed
                  << "0x" << std::setw(8) << std::setfill('0') << std::hex << current_pc_f << " | "
                  << "0x" << std::setw(8) << std::setfill('0') << std::hex << current_instr_f << " | "
                  << std::setw(8) << std::dec << (current_reg_write_wb ? "1" : "0") << " | "
                  << std::setw(9) << std::dec << (current_reg_write_wb ? (int)current_rd_addr_wb : 0 )<< " | " // Display RdAddr if write
                  << "0x" << std::setw(14) << std::setfill('0') << std::hex << (current_reg_write_wb ? current_result_w : 0) << " | "
                  << (expect_write_this_cycle ? ("0x" + [&]{std::stringstream ss; ss << std::setw(14) << std::setfill('0') << std::hex << expected_result; return ss.str(); }()) : " X (no write)  ");

        bool cycle_pass = true;
        if (expect_write_this_cycle) {
            if (!current_reg_write_wb) {
                cycle_pass = false;
                std::cout << " | FAIL (Exp Write, Got No Write)";
            } else if (current_result_w != expected_result) {
                cycle_pass = false;
                std::cout << " | FAIL (Value Mismatch)";
            } else {
                std::cout << " | PASS";
            }
        } else { // Expect no write (X_DEF)
            if (current_reg_write_wb) {
                cycle_pass = false;
                std::cout << " | FAIL (Exp No Write, Got Write to x" << std::dec << (int)current_rd_addr_wb << "=0x" << std::hex << current_result_w << ")";
            } else {
                std::cout << " | PASS (No Write)";
            }
        }
        std::cout << std::endl;

        if (!cycle_pass) {
            test_passed = false;
        }
        std::cout << std::setfill(' '); // Reset fill character
    }

    if (tfp) {
        tfp->close();
    }
    delete top;

    if (test_passed) {
        std::cout << "\nPipeline Test Case: " << G_PIPELINE_TEST_CASE_NAME << " - PASSED" << std::endl;
        return 0;
    } else {
        std::cout << "\nPipeline Test Case: " << G_PIPELINE_TEST_CASE_NAME << " - FAILED" << std::endl;
        return 1;
    }
}