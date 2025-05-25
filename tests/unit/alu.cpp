#include "Valu.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cassert>
#include <cstdint>
#include <string>
#include <vector>
#include <bitset>

const uint8_t ALU_OP_ADD      = 0b000;
const uint8_t ALU_OP_SUB      = 0b001;
const uint8_t ALU_OP_AND      = 0b010;
const uint8_t ALU_OP_OR       = 0b011;
const uint8_t ALU_OP_XOR      = 0b100;
const uint8_t ALU_OP_SLT_BASE = 0b101;
const uint8_t ALU_OP_SLL      = 0b110;
const uint8_t ALU_OP_SR_BASE  = 0b111;

const uint8_t ALU_SELECT_SIGNED     = 0;
const uint8_t ALU_SELECT_UNSIGNED   = 1;
const uint8_t ALU_SELECT_LOGICAL_SR = 0;
const uint8_t ALU_SELECT_ARITH_SR   = 1;

vluint64_t sim_time = 0;

double sc_time_stamp() {
    return sim_time;
}

void eval_alu(Valu* alu, VerilatedVcdC* tfp) {
    alu->eval();
    if (tfp) tfp->dump(sim_time);
}

struct AluTestCase {
    uint64_t a, b;
    uint8_t alu_op_sel;
    uint8_t alu_mod;
    uint64_t expected_res;
    bool expected_zero;
    // Убраны expected_cout и expected_ovf
    std::string name;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Valu* top = new Valu;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_alu.vcd");

    std::cout << "Starting Simplified ALU Testbench (RV64)" << std::endl;

    AluTestCase tests[] = {
        {5, 10, ALU_OP_ADD, 0, 15, false, "ADD 5+10"},
        {0xFFFFFFFFFFFFFFFFULL, 1, ALU_OP_ADD, 0, 0, true, "ADD -1+1"},
        {0x7FFFFFFFFFFFFFFFULL, 1, ALU_OP_ADD, 0, 0x8000000000000000ULL, false, "ADD signed ovf (MAX_POS+1)"}, // Результат все равно вычисляется

        {10, 5, ALU_OP_SUB, 0, 5, false, "SUB 10-5"},
        {5, 10, ALU_OP_SUB, 0, (uint64_t)-5, false, "SUB 5-10"},
        {0x8000000000000000ULL, 1, ALU_OP_SUB, 0, 0x7FFFFFFFFFFFFFFFULL, false, "SUB signed ovf (MIN_NEG-1)"},
        {10, 10, ALU_OP_SUB, 0, 0, true, "SUB 10-10 (zero)"},

        {0xF0F0F0F0F0F0F0F0ULL, 0x0F0F0F0F0F0F0F0FULL, ALU_OP_AND, 0, 0x00ULL, true, "AND"},
        {0xF0F0F0F0F0F0F0F0ULL, 0x0F0F0F0F0F0F0F0FULL, ALU_OP_OR,  0, 0xFFFFFFFFFFFFFFFFULL, false, "OR"},
        {0xFF00FF00FF00FF00ULL, 0x00FFFF00FFFF00FFULL, ALU_OP_XOR, 0, 0xFFFF000000FFFFFFULL, false, "XOR"},

        {5, 10, ALU_OP_SLT_BASE, ALU_SELECT_SIGNED, 1, false, "SLT 5<10"},
        {10, 5, ALU_OP_SLT_BASE, ALU_SELECT_SIGNED, 0, true, "SLT 10<5"},
        {(uint64_t)-5, 2, ALU_OP_SLT_BASE, ALU_SELECT_SIGNED, 1, false, "SLT -5<2 (signed)"},

        {5, 10, ALU_OP_SLT_BASE, ALU_SELECT_UNSIGNED, 1, false, "SLTU 5<10"},
        {10, 5, ALU_OP_SLT_BASE, ALU_SELECT_UNSIGNED, 0, true, "SLTU 10<5"},
        {(uint64_t)-5, 2, ALU_OP_SLT_BASE, ALU_SELECT_UNSIGNED, 0, true, "SLTU large_val<2 (unsigned)"},

        {0x1ULL, 3, ALU_OP_SLL, 0, 0x8ULL, false, "SLL 1<<3 (val=3)"},
        {0xABCDEF0123456789ULL, 64, ALU_OP_SLL, 0, 0xABCDEF0123456789ULL, false, "SLL by 64 (shamt=0)"},

        {0x800000000000000FULL, 4, ALU_OP_SR_BASE, ALU_SELECT_LOGICAL_SR, 0x0800000000000000ULL, false, "SRL"},
        {0x8000000000000000ULL, 1, ALU_OP_SR_BASE, ALU_SELECT_ARITH_SR,   0xC000000000000000ULL, false, "SRA neg"},
        {0x4000000000000000ULL, 1, ALU_OP_SR_BASE, ALU_SELECT_ARITH_SR,   0x2000000000000000ULL, false, "SRA pos"}
    };

    int num_tests = sizeof(tests) / sizeof(AluTestCase);
    int passed_tests = 0;

    for (int i = 0; i < num_tests; ++i) {
        AluTestCase& t = tests[i];

        top->operand_a = t.a;
        top->operand_b = t.b;
        top->alu_op_select = t.alu_op_sel;
        top->alu_modifier = t.alu_mod;

        eval_alu(top, tfp);
        sim_time++;

        bool pass = (top->result == t.expected_res) &&
                    (top->zero_flag == t.expected_zero);

        if (pass) {
            passed_tests++;
        } else {
            std::cout << "FAIL Test: " << t.name << std::endl;
            std::cout << "  Input: A=0x" << std::hex << t.a << ", B=0x" << t.b
                      << ", OpSel=" << std::bitset<3>(t.alu_op_sel) << ", Mod=" << (int)t.alu_mod << std::dec << std::endl;
            std::cout << "  Got  : Res=0x" << std::hex << top->result << ", Zero=" << (int)top->zero_flag << std::dec << std::endl;
            std::cout << "  Exp  : Res=0x" << std::hex << t.expected_res << ", Zero=" << (int)t.expected_zero << std::dec << std::endl;
        }
        assert(pass);
    }

    std::cout << "\nSimplified ALU Testbench Finished. Passed " << passed_tests << "/" << num_tests << " tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    exit( (passed_tests == num_tests) ? EXIT_SUCCESS : EXIT_FAILURE );
}
