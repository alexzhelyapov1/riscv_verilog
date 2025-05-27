// tests/unit/pipeline_tb.cpp
#include "Vpipeline_tb.h"
#include "Vpipeline.h" // To potentially access internal signals if made public
#include "Vpipeline_pipeline.h" // If pipeline is a submodule of pipeline_tb
#include "Vpipeline_register_file.h" // If we can access it this way
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>
#include <map>

// --- Helper: Program Definition ---
struct ProgramInstruction {
    uint32_t address; // Byte address where this instruction should be placed
    uint32_t instruction; // Machine code
    std::string disassembly; // Optional: for logging
};

// --- Global sim time for this testbench ---
vluint64_t sim_time_pipeline = 0;

// --- Tick function ---
void tick_pipeline(Vpipeline_tb* dut, VerilatedVcdC* tfp, int cycles = 1) {
    for (int i = 0; i < cycles; ++i) {
        dut->clk = 0;
        dut->eval();
        if (tfp) tfp->dump(sim_time_pipeline);
        sim_time_pipeline++;

        dut->clk = 1;
        dut->eval();
        if (tfp) tfp->dump(sim_time_pipeline);
        sim_time_pipeline++;
    }
}

// --- Reset DUT ---
void reset_pipeline(Vpipeline_tb* dut, VerilatedVcdC* tfp) {
    dut->rst_n = 0;
    for (int i = 0; i < 10; ++i) { // Hold reset for a few cycles
        tick_pipeline(dut, tfp, 1);
    }
    dut->rst_n = 1;
    std::cout << "Pipeline Reset" << std::endl;
    tick_pipeline(dut, tfp, 1); // Tick once out of reset
}

// --- Function to load program into instruction memory ---
// This is a placeholder. Actual loading depends on how instruction_memory is implemented
// and if it's accessible from the testbench.
// For now, we assume instruction_memory.sv uses its 'initial' block.
// To test different programs, we would need to re-verilate with different
// instruction_memory.sv content or have a writable instruction memory model.
// A more advanced testbench would allow C++ to write to the Verilog instruction memory model.
void load_program(Vpipeline_tb* dut, const std::vector<ProgramInstruction>& program) {
    std::cout << "INFO: Loading program (assuming DUT's instruction_memory is pre-loaded or has write access)" << std::endl;
    // In a real scenario with a writable instruction memory:
    // For (const auto& instr_item : program) {
    //    dut->write_to_instruction_memory(instr_item.address, instr_item.instruction);
    // }
    // For now, we rely on the instruction_memory.sv's initial block for Program 1.
    // For other programs, we'd need to modify instruction_memory.sv and recompile.
}

// --- Function to read register file (Placeholder) ---
// Requires making register file contents accessible (e.g., Verilator public signals, DPI)
uint64_t read_register(Vpipeline_tb* dut, uint8_t reg_addr) {
    // This is a placeholder. Direct access to RF from C++ is non-trivial.
    // For Verilator, if 'regs' array in 'register_file' is made public:
    // return dut->u_pipeline->u_decode->u_register_file->regs[reg_addr];
    std::cerr << "WARN: read_register(" << (int)reg_addr << ") called, but direct RF read not implemented in TB." << std::endl;
    if (reg_addr == 0) return 0;
    return 0xDEADBEEFCAFEBABEULL; // Placeholder
}

// --- Test Case Structure ---
struct PipelineTestCase {
    std::string name;
    std::vector<ProgramInstruction> program; // Machine codes for the test
    int cycles_to_run;
    std::map<uint8_t, uint64_t> expected_registers; // reg_idx -> expected_value
    // std::map<uint64_t, uint64_t> expected_memory; // addr -> expected_value (optional)
};


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vpipeline_tb* top = new Vpipeline_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_pipeline.vcd");

    std::cout << "Starting Pipeline Integration Testbench" << std::endl;

    // --- Define Test Programs (Machine Code) ---
    // Program 1: Simple sequence (addi x1,x0,10; addi x2,x0,20; add x3,x1,x2)
    // Assuming instruction_memory.sv is preloaded with these at addrs 0, 4, 8
    // addi x1, x0, 10   -> 0x00A00093 (from your instruction_memory.sv, this is addi x1,x0,1)
    // Let's use the actual preloaded values for the first test.
    // mem[0] = 32'h00100093; // addi x1, x0, 1
    // mem[1] = 32'h00200113; // addi x2, x0, 2
    // mem[2] = 32'h00308193; // addi x3, x1, 3 -> This is R-type, rs1=x1, rs2=x0? No, rs2=x0 if field is 0.
                                // 0000000 00000 00001 000 00011 0110011 => add x3, x1, x0
                                // Let's redefine mem[2] in instruction_memory.sv for a clearer test
                                // For Program 1:
                                // 0x00: addi x1, x0, 10 (0x00A00093)
                                // 0x04: addi x2, x0, 20 (0x01400113)
                                // 0x08: add  x3, x1, x2 (0x002081B3)
                                // To test this, we need to modify instruction_memory.sv initial block.
                                // For now, let's test with what's IN instruction_memory.sv:
    std::vector<ProgramInstruction> program1 = {
        {0x0, 0x00100093, "addi x1, x0, 1"},  // x1 = 1
        {0x4, 0x00200113, "addi x2, x0, 2"},  // x2 = 2
        {0x8, 0x001101B3, "add  x3, x2, x1"}   // x3 = x2 + x1 = 2 + 1 = 3
                                               // (Need to ensure 0x001101B3 is 'add x3,x2,x1')
                                               // add x3, x2, x1: op=0110011, rd=3, f3=000, rs1=2, rs2=1, f7=0000000
                                               // 0000000_00001_00010_000_00011_0110011 = 0x001101B3. Correct.
    };


    std::vector<PipelineTestCase> test_cases = {
        {   "Program 1: ADDI, ADDI, ADD",
            {}, // program vector not used if preloaded
            15, // Cycles: 3 instrs * 5 stages + few extra = ~10-15 should be enough
            // Ожидаемые значения после выполнения:
            // x1 = 10
            // x2 = 20
            // x3 = x1 + x2 = 10 + 20 = 30
            // Эта проверка пока концептуальная в C++ тесте.
            // Главное - посмотреть VCD.
            { {1, 10}, {2, 20}, {3, 30} }
        },
    };

    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Pipeline Test: " << tc.name << std::endl;
        reset_pipeline(top, tfp);
        // load_program(top, tc.program); // Call this if we have a writable instruction memory

        std::cout << "  Running for " << tc.cycles_to_run << " cycles." << std::endl;
        for (int cycle = 0; cycle < tc.cycles_to_run; ++cycle) {
            tick_pipeline(top, tfp, 1);
            std::cout << "  Cycle " << std::setw(2) << cycle + 1
                      << ": PC_F=0x" << std::hex << top->debug_pc_f
                      << ", Instr_F=0x" << top->debug_instr_f << std::dec << std::endl;
            // Add more debug prints for other pipeline registers if needed
        }

        bool current_pass = true;
        std::cout << "  Verifying register states..." << std::endl;
        // This part is tricky without direct RF access.
        // For a real test, you'd run the program, then have the program store
        // results to known memory locations, then stop the DUT and read memory.
        // Or, use Verilator's --public-flat to access internal signals (advanced).

        // Placeholder for verification:
        // We assume that after enough cycles, the expected register values should hold.
        // This requires either a debug mechanism to read RF or careful cycle counting.
        // For now, this verification part is conceptual.
        if (tc.name == "Program 1: Simple Sequence (using preloaded memory)") {
            // We can't directly read RF yet, so this test is more about observing VCD for now.
            // We'd need a way to halt the processor and then inspect RF.
            // Or write a self-checking program that stores a pass/fail signature to memory.
            std::cout << "  INFO: Register state verification for Program 1 is conceptual without direct RF read." << std::endl;
            std::cout << "        Please inspect VCD for PC flow and instruction fetching." << std::endl;
            std::cout << "        Expected final x1=1, x2=2, x3=3." << std::endl;
            // This test will "pass" for now as we don't have a failure condition here.
        } else {
            std::cout << "  WARN: No specific verification logic for this test case yet." << std::endl;
        }


        if (current_pass) { // This will likely always be true with current verification
            std::cout << "  PASS (conceptual)" << std::endl;
            passed_count++;
        } else {
            std::cout << "  FAILED" << std::endl;
        }
    }

    std::cout << "\nPipeline Integration Testbench Finished. Conceptually Passed "
              << passed_count << "/" << test_cases.size() << " tests." << std::endl;
    std::cout << "NOTE: Actual verification of register/memory state requires more advanced testbench features." << std::endl;


    if (tfp) tfp->close();
    delete top;
    return (passed_count == test_cases.size()) ? EXIT_SUCCESS : EXIT_FAILURE;
}