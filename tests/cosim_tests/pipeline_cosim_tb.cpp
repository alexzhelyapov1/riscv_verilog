// Файл: tests/cosim_tests/pipeline_cosim_tb.cpp
#include "Vpipeline.h"
#include "verilated_vcd_c.h"
#include "verilated.h"

#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#include <vector>
#include <sstream>
#include <cstdlib> // Для std::getenv

// Макросы, определяемые CMake
#ifndef PIPELINE_COSIM_TEST_CASE_NAME_STR_RAW
#error "PIPELINE_COSIM_TEST_CASE_NAME_STR_RAW not defined!"
#endif

#ifndef NUM_CYCLES_TO_RUN
#error "NUM_CYCLES_TO_RUN not defined!"
#endif

#ifndef VERILOG_OUTPUT_FILE_PATH_STR_RAW // Имя файла, куда будет писать Verilog тестбенч
#error "VERILOG_OUTPUT_FILE_PATH_STR_RAW not defined!"
#endif


// Вспомогательные макросы для превращения в строку
#define STRINGIFY_HELPER(x) #x
#define STRINGIFY(x) STRINGIFY_HELPER(x)

// Глобальные переменные из макросов
const std::string G_PIPELINE_COSIM_TEST_CASE_NAME = STRINGIFY(PIPELINE_COSIM_TEST_CASE_NAME_STR_RAW);
const int G_NUM_CYCLES_TO_RUN = NUM_CYCLES_TO_RUN;
const std::string G_VERILOG_OUTPUT_FILE_PATH = STRINGIFY(VERILOG_OUTPUT_FILE_PATH_STR_RAW);

vluint64_t sim_time = 0;

double sc_time_stamp() {
    return sim_time;
}

void tick(Vpipeline* top, VerilatedVcdC* tfp, std::ofstream& outFile) {
    top->clk = 0; // Changed from clk_i
    top->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;

    top->clk = 1; // Changed from clk_i
    top->eval();
    if (tfp) tfp->dump(sim_time);
    // After posedge clk, when all signals WB stage are stable
    if (top->debug_reg_write_wb) { // Changed from we3_d_o, using existing debug signal
        if (outFile.is_open()) {
            // Changed from wd3_d_o, using existing debug signal
            outFile << std::hex << std::setw(16) << std::setfill('0') << top->debug_result_w << std::endl;
        }
    }
    sim_time++;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vpipeline* top = new Vpipeline;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    std::string vcd_file_name = G_PIPELINE_COSIM_TEST_CASE_NAME + "_cosim_verilog_tb.vcd";
    tfp->open(vcd_file_name.c_str());

    std::cout << "VERILOG SIM: Starting Co-simulation Test Case: " << G_PIPELINE_COSIM_TEST_CASE_NAME << std::endl;
    std::cout << "VERILOG SIM: Number of cycles to run: " << G_NUM_CYCLES_TO_RUN << std::endl;
    std::cout << "VERILOG SIM: Output file: " << G_VERILOG_OUTPUT_FILE_PATH << std::endl;

    std::ofstream verilog_output_file(G_VERILOG_OUTPUT_FILE_PATH, std::ios::out | std::ios::trunc);
    if (!verilog_output_file.is_open()) {
        std::cerr << "VERILOG SIM ERROR: Could not open output file: " << G_VERILOG_OUTPUT_FILE_PATH << std::endl;
        if (tfp) tfp->close();
        delete top;
        return 1;
    }

    top->rst_n = 0; // Assert reset (active low), changed from rst_i = 1
    for(int i=0; i<2; ++i) {
        // During reset, do not write to output file
        top->clk = 0; top->eval(); if (tfp) tfp->dump(sim_time); sim_time++;
        top->clk = 1; top->eval(); if (tfp) tfp->dump(sim_time); sim_time++;
    }
    top->rst_n = 1; // De-assert reset, changed from rst_i = 0
    // One more tick for reset to propagate if needed, or start main loop
    top->clk = 0; top->eval(); if (tfp) tfp->dump(sim_time); sim_time++;
    top->clk = 1; top->eval(); if (tfp) tfp->dump(sim_time); sim_time++;

    std::cout << "VERILOG SIM: Reset complete." << std::endl;

    for (int cycle = 0; cycle < G_NUM_CYCLES_TO_RUN; ++cycle) {
        tick(top, tfp, verilog_output_file);
    }

    std::cout << "VERILOG SIM: Simulation finished after " << G_NUM_CYCLES_TO_RUN << " cycles." << std::endl;

    if (verilog_output_file.is_open()) {
        verilog_output_file.close();
    }
    if (tfp) {
        tfp->close();
    }
    delete top;
    return 0; // Success for Verilog part
}