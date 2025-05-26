#include "Vfetch_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>

// В defines.svh INSTR_WIDTH = 32, DATA_WIDTH = 64
const uint32_t NOP_INSTRUCTION = 0x00000013;

vluint64_t sim_time = 0;

void tick(Vfetch_tb* dut, VerilatedVcdC* tfp) {
    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;

    dut->clk = 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;
}

void reset_dut(Vfetch_tb* dut, VerilatedVcdC* tfp) {
    dut->rst_n = 0;
    // Initialize inputs to known safe values during reset
    dut->i_stall_f = 0;
    dut->i_pc_src_e = 0;
    dut->i_pc_target_e = 0;
    dut->i_stall_d = 0;
    dut->i_flush_d = 0;
    for (int i = 0; i < 5; ++i) { // Hold reset for a few cycles
        tick(dut, tfp);
    }
    dut->rst_n = 1;
    tick(dut, tfp); // One tick out of reset
    std::cout << "DUT Reset" << std::endl;
}


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vfetch_tb* top = new Vfetch_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_fetch.vcd");

    std::cout << "Starting Fetch Stage Testbench" << std::endl;

    reset_dut(top, tfp);

    // Test Case 1: Basic sequential fetch
    std::cout << "Test Case 1: Sequential Fetch" << std::endl;
    top->i_stall_f = 0;
    top->i_pc_src_e = 0;
    top->i_pc_target_e = 0; // Don't care
    top->i_stall_d = 0;
    top->i_flush_d = 0;

    // Cycle 1: PC=0, Fetch instr @0. IF/ID gets this after this cycle.
    tick(top, tfp);
    std::cout << "  PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected after reset and first tick: PC_F=0. IF/ID output still from reset state or previous garbage before first valid data.
    // After PC=0 is fetched, on the NEXT rising edge, IF/ID will latch PC=0 and Instr @0.

    // Cycle 2: PC=0 latched into IF/ID. Fetch stage moves to PC=4.
    tick(top, tfp);
    std::cout << "  PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected: PC_F=4. IF/ID PC=0, Instr = mem[0] (0x00100093)

    // Cycle 3: PC=4 latched into IF/ID. Fetch stage moves to PC=8.
    tick(top, tfp);
    std::cout << "  PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected: PC_F=8. IF/ID PC=4, Instr = mem[1] (0x00200113)


    // Test Case 2: Stall Fetch (StallF)
    std::cout << "\nTest Case 2: Stall Fetch (stall_f)" << std::endl;
    top->i_stall_f = 1; // Stall PC update
    top->i_stall_d = 0; // IF/ID register loads normally
    // PC_F was 8. It should remain 8. Instr_F will be from PC=8.
    // IF/ID will latch current Instr_F and PC_F+4.
    // Previous IF/ID instr was mem[1] (from PC=4).
    tick(top, tfp); // PC=8 (stalled), instr_f = mem[8/4=2]. IF/ID gets (instr @ PC=8, PC=8+4)
    std::cout << "  StallF=1. PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected: PC_F=8. IF/ID PC=8, Instr = mem[2] (0x00308193)

    tick(top, tfp); // PC=8 (still stalled), instr_f = mem[8/4=2]. IF/ID re-latches same values.
    std::cout << "  StallF=1. PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected: PC_F=8. IF/ID PC=8, Instr = mem[2]

    top->i_stall_f = 0; // Release stall_f


    // Test Case 3: Stall Decode (StallD)
    std::cout << "\nTest Case 3: Stall Decode (stall_d)" << std::endl;
    // PC_F was 8. Now stall_f=0, so PC will advance to 12. instr_f = mem[12/4=3].
    // IF/ID was (PC=8, instr=mem[2]). Now stall_d=1, so IF/ID holds its value.
    top->i_stall_d = 1;
    tick(top, tfp);
    std::cout << "  StallD=1. PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected: PC_F=12 (0xC). IF/ID PC=8, Instr = mem[2] (holds previous)

    // PC_F advances to 16. instr_f = mem[16/4=4].
    // IF/ID still holds (PC=8, instr=mem[2]).
    tick(top, tfp);
    std::cout << "  StallD=1. PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected: PC_F=16 (0x10). IF/ID PC=8, Instr = mem[2]

    top->i_stall_d = 0; // Release stall_d


    // Test Case 4: Flush Decode (FlushD)
    std::cout << "\nTest Case 4: Flush Decode (flush_d)" << std::endl;
    // PC_F was 16. Now stall_d=0, PC advances to 20. instr_f = mem[20/4=5].
    // IF/ID was (PC=8, instr=mem[2]). Now flush_d=1. IF/ID should be NOP.
    top->i_flush_d = 1;
    tick(top, tfp);
    std::cout << "  FlushD=1. PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected: PC_F=20 (0x14). IF/ID PC=0, Instr = NOP (0x13)

    top->i_flush_d = 0; // Release flush_d
    tick(top, tfp); // PC_F advances to 24. IF/ID gets (instr @ PC=20, PC=20+4)
    std::cout << "  FlushD=0. PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected: PC_F=24 (0x18). IF/ID PC=20, Instr = mem[5]

    // Test Case 5: Branch Taken (pc_src_e)
    std::cout << "\nTest Case 5: Branch Taken" << std::endl;
    top->i_pc_src_e = 1;
    top->i_pc_target_e = 0x100; // Jump to address 0x100
    // PC_F was 24. Next PC should be 0x100. instr_f will be mem[0x100/4].
    // IF/ID was (PC=20, instr=mem[5]). IF/ID gets (instr @ PC=0x100, PC=0x100+4)
    tick(top, tfp);
    std::cout << "  Branch. PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected: PC_F=0x100. IF/ID PC=0x100, Instr = mem[0x100/4] (which is NOP by default init)

    top->i_pc_src_e = 0; // Next cycle, no branch
    tick(top, tfp); // PC_F advances to 0x104. IF/ID gets (instr @ PC=0x100, PC=0x100+4)
    std::cout << "  After Branch. PC_F: 0x" << std::hex << top->o_current_pc_f
              << " -> IF/ID PC: 0x" << top->o_pc_id
              << " Instr: 0x" << top->o_instr_id << std::dec << std::endl;
    // Expected: PC_F=0x104. IF/ID PC=0x100, Instr = mem[0x100/4]


    std::cout << "\nFetch Stage Testbench Finished." << std::endl;

    if (tfp) tfp->close();
    delete top;
    return 0;
}