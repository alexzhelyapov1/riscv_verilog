// tests/unit/pipeline_tb.cpp
#include "Vpipeline_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <iomanip>
#include <vector>

vluint64_t sim_time = 0;

void tick(Vpipeline_tb* dut, VerilatedVcdC* tfp) {
    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;

    dut->clk = 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;
}

void reset_pipeline(Vpipeline_tb* dut, VerilatedVcdC* tfp, int cycles = 5) {
    std::cout << "Resetting pipeline..." << std::endl;
    dut->rst_n = 0;
    for (int i = 0; i < cycles; ++i) {
        tick(dut, tfp);
    }
    dut->rst_n = 1;
    tick(dut, tfp); // First tick out of reset
    std::cout << "Pipeline reset complete." << std::endl;
}

void print_debug_info(Vpipeline_tb* dut, int cycle_num) {
    std::cout << "Cycle " << std::setw(3) << std::dec << cycle_num << ": "
              << "PC_F=0x" << std::hex << std::setw(8) << std::setfill('0') << dut->debug_pc_f_o
              << " Instr_F=0x" << std::setw(8) << std::setfill('0') << dut->debug_instr_f_o;

    if (dut->debug_reg_write_wb_o) {
        std::cout << " | WB: x" << std::dec << std::setw(2) << std::setfill(' ') << (int)dut->debug_rd_addr_wb_o
                  << " <= 0x" << std::hex << std::setw(16) << std::setfill('0') << dut->debug_result_w_o;
    } else {
        std::cout << " | WB: NoWrite";
    }
    std::cout << std::setfill(' ') << std::dec << std::endl;
}

void print_regs(Vpipeline_tb* dut) {
    // Accessing internal signals of the register file.
    // This requires Verilator to make them accessible.
    // If regs is not directly accessible, you might need `/* verilator public */`
    // or use more complex DPI/VPI methods for general access.
    // For this example, we assume Verilator makes them available via hierarchical path
    // or that we have added `debug_rf_xN` outputs to pipeline_tb.sv.
    std::cout << "  Registers: "
              << "x1=0x" << std::hex << dut->debug_rf_x1
              << " x2=0x" << dut->debug_rf_x2
              << " x3=0x" << dut->debug_rf_x3
              << " x4=0x" << dut->debug_rf_x4
              << std::dec << std::endl;
}


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vpipeline_tb* top = new Vpipeline_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("pipeline_tb.vcd");

    std::cout << "Pipeline Testbench Started" << std::endl;

    reset_pipeline(top, tfp);

    // Run for a number of cycles to see instructions propagate
    // Program:
    // 0: addi x1, x0, 1
    // 4: addi x2, x0, 2
    // 8: addi x3, x0, 3
    // C: addi x4, x0, 4

    // Pipeline depth is 5 stages.
    // After 5 cycles, the first instruction should reach WB.
    // After 5+3 = 8 cycles, all 4 instructions should have completed WB.
    // Let's run for ~15 cycles to see everything clear.
    int num_cycles_to_run = 15;

    for (int i = 0; i < num_cycles_to_run; ++i) {
        tick(top, tfp);
        print_debug_info(top, sim_time / 2); // sim_time increments twice per tick
        if (i > 3 && (i % 2 == 0)) { // Print regs periodically after a few instructions might have written back
            print_regs(top);
        }
    }

    std::cout << "\nFinal Register Values after " << num_cycles_to_run << " cycles:" << std::endl;
    print_regs(top);

    // Basic checks (manual verification based on VCD and print_regs for now)
    bool pass = true;
    if (top->debug_rf_x1 != 1) {
        std::cout << "FAIL: x1 expected 1, got 0x" << std::hex << top->debug_rf_x1 << std::dec << std::endl;
        pass = false;
    }
    if (top->debug_rf_x2 != 2) {
        std::cout << "FAIL: x2 expected 2, got 0x" << std::hex << top->debug_rf_x2 << std::dec << std::endl;
        pass = false;
    }
    if (top->debug_rf_x3 != 3) {
        std::cout << "FAIL: x3 expected 3, got 0x" << std::hex << top->debug_rf_x3 << std::dec << std::endl;
        pass = false;
    }
     if (top->debug_rf_x4 != 4) {
        std::cout << "FAIL: x4 expected 4, got 0x" << std::hex << top->debug_rf_x4 << std::dec << std::endl;
        pass = false;
    }


    std::cout << "\nPipeline Testbench Finished." << std::endl;
    if (tfp) tfp->close();
    delete top;

    if (pass) {
        std::cout << "Basic ADDI test sequence: PASS" << std::endl;
        return EXIT_SUCCESS;
    } else {
        std::cout << "Basic ADDI test sequence: FAIL" << std::endl;
        return EXIT_FAILURE;
    }
}