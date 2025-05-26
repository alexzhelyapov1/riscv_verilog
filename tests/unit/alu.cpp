// tests/unit/alu.cpp
#include "Valu.h" // Verilator generated header for alu module
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cassert>
#include <cstdint>
#include <string>
#include <vector>
#include <bitset>

// New ALU Control Opcodes (from alu_defines.svh)
const uint8_t ALU_OP_ADD  = 0b0000;
const uint8_t ALU_OP_SUB  = 0b0001;
const uint8_t ALU_OP_SLL  = 0b0010;
const uint8_t ALU_OP_SLT  = 0b0011;
const uint8_t ALU_OP_SLTU = 0b0100;
const uint8_t ALU_OP_XOR  = 0b0101;
const uint8_t ALU_OP_SRL  = 0b0110;
const uint8_t ALU_OP_SRA  = 0b0111;
const uint8_t ALU_OP_OR   = 0b1000;
const uint8_t ALU_OP_AND  = 0b1001;
// const uint8_t ALU_OP_PASS_B = 0b1010; // If added

vluint64_t sim_time = 0;

// Verilator simulation time function (if not using sc_core::sc_time_stamp)
double sc_time_stamp() {
    return sim_time;
}

void eval_alu(Valu* alu_core, VerilatedVcdC* tfp) {
    alu_core->eval();
    if (tfp) tfp->dump(sim_time);
}

struct AluTestCase {
    uint64_t a, b;
    uint8_t alu_control_val; // Changed from alu_op_sel and alu_mod
    uint64_t expected_res;
    bool expected_zero;
    std::string name;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Valu* top = new Valu; // Name of the Verilog module is 'alu', Verilator prepends 'V'

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_alu.vcd");

    std::cout << "Starting Unified ALU Testbench (RV64)" << std::endl;

    AluTestCase tests[] = {
        // ADD tests
        {5, 10, ALU_OP_ADD, 15, false, "ADD 5+10"},
        {0xFFFFFFFFFFFFFFFFULL, 1, ALU_OP_ADD, 0, true, "ADD -1+1 (wrap)"},
        {0x7FFFFFFFFFFFFFFFULL, 1, ALU_OP_ADD, 0x8000000000000000ULL, false, "ADD MAX_POS+1 (signed ovf)"},

        // SUB tests
        {10, 5, ALU_OP_SUB, 5, false, "SUB 10-5"},
        {5, 10, ALU_OP_SUB, (uint64_t)-5, false, "SUB 5-10"},
        {0x8000000000000000ULL, 1, ALU_OP_SUB, 0x7FFFFFFFFFFFFFFFULL, false, "SUB MIN_NEG-1 (signed ovf)"},
        {10, 10, ALU_OP_SUB, 0, true, "SUB 10-10 (zero)"},

        // Logical tests
        {0xF0F0F0F0F0F0F0F0ULL, 0x0F0F0F0F0F0F0F0FULL, ALU_OP_AND, 0x00ULL, true, "AND all zeros"},
        {0xF0F0F0F0F0F0F0F0ULL, 0xFFFFFFFFFFFFFFFFULL, ALU_OP_AND, 0xF0F0F0F0F0F0F0F0ULL, false, "AND with FFs"},
        {0xF0F0F0F0F0F0F0F0ULL, 0x0F0F0F0F0F0F0F0FULL, ALU_OP_OR,  0xFFFFFFFFFFFFFFFFULL, false, "OR"},
        {0xFF00FF00FF00FF00ULL, 0x00FFFF00FFFF00FFULL, ALU_OP_XOR, 0xFFFF000000FFFFFFULL, false, "XOR"},

        // SLT / SLTU tests
        {5, 10, ALU_OP_SLT, 1, false, "SLT 5<10 (signed)"},
        {10, 5, ALU_OP_SLT, 0, true, "SLT 10<5 (signed)"},
        {(uint64_t)-5, 2, ALU_OP_SLT, 1, false, "SLT -5<2 (signed)"},
        {2, (uint64_t)-5, ALU_OP_SLT, 0, true, "SLT 2<-5 (signed)"},
        {(uint64_t)-10, (uint64_t)-5, ALU_OP_SLT, 1, false, "SLT -10<-5 (signed)"},

        {5, 10, ALU_OP_SLTU, 1, false, "SLTU 5<10 (unsigned)"},
        {10, 5, ALU_OP_SLTU, 0, true, "SLTU 10<5 (unsigned)"},
        {(uint64_t)-5, 2, ALU_OP_SLTU, 0, true, "SLTU large_val<2 (unsigned, -5 is large positive)"}, // -5ULL is large positive
        {2, (uint64_t)-5, ALU_OP_SLTU, 1, false, "SLTU 2<large_val (unsigned)"},

        // Shift tests
        {0x1ULL, 3, ALU_OP_SLL, 0x8ULL, false, "SLL 1<<3 (shamt=3)"},
        {0xABCDEF0123456789ULL, 64, ALU_OP_SLL, 0xABCDEF0123456789ULL, false, "SLL by 64 (actual shamt=0)"}, // operand_b[5:0] is 0
        {0xABCDEF0123456789ULL, 0, ALU_OP_SLL, 0xABCDEF0123456789ULL, false, "SLL by 0"},

        {0xF00000000000000FULL, 4, ALU_OP_SRL, 0x0F00000000000000ULL, false, "SRL positive val"},
        {0x8000000000000000ULL, 1, ALU_OP_SRL, 0x4000000000000000ULL, false, "SRL MSB set val"},

        {0x8000000000000000ULL, 1, ALU_OP_SRA, 0xC000000000000000ULL, false, "SRA negative val"},
        {0x4000000000000000ULL, 1, ALU_OP_SRA, 0x2000000000000000ULL, false, "SRA positive val"},
        {0xFFFFFFFFFFFFFFF0ULL, 4, ALU_OP_SRA, 0xFFFFFFFFFFFFFFFFULL, false, "SRA -16 >> 4 = -1"}

        // Test for PASS_B if added
        // {123, 456, ALU_OP_PASS_B, 456, false, "PASS_B"}
    };

    int num_tests = sizeof(tests) / sizeof(AluTestCase);
    int passed_tests = 0;

    for (int i = 0; i < num_tests; ++i) {
        AluTestCase& t = tests[i];

        top->operand_a = t.a;
        top->operand_b = t.b;
        top->alu_control = t.alu_control_val; // Use the new unified control signal

        eval_alu(top, tfp);
        sim_time++; // Increment simulation time for VCD

        bool pass = (top->result == t.expected_res) &&
                    (top->zero_flag == t.expected_zero);

        if (pass) {
            passed_tests++;
        } else {
            std::cout << "FAIL Test: " << t.name << std::endl;
            std::cout << "  Input: A=0x" << std::hex << t.a << ", B=0x" << t.b
                      << ", ALUControl=0b" << std::bitset<4>(t.alu_control_val) << std::dec << std::endl;
            std::cout << "  Got  : Res=0x" << std::hex << top->result << ", Zero=" << (int)top->zero_flag << std::dec << std::endl;
            std::cout << "  Exp  : Res=0x" << std::hex << t.expected_res << ", Zero=" << (int)t.expected_zero << std::dec << std::endl;
        }
        assert(pass); // Stop on first failure for easier debugging
    }

    std::cout << "\nUnified ALU Testbench Finished. Passed " << passed_tests << "/" << num_tests << " tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    exit( (passed_tests == num_tests) ? EXIT_SUCCESS : EXIT_FAILURE );
}