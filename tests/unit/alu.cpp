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

// ALU Control Opcodes (из alu_defines.svh)
const int ALU_CONTROL_WIDTH_CPP = 4;
const uint8_t ALU_OP_ADD_CPP  = 0b0000;
const uint8_t ALU_OP_SUB_CPP  = 0b0001;
const uint8_t ALU_OP_SLL_CPP  = 0b0010;
const uint8_t ALU_OP_SLT_CPP  = 0b0011;
const uint8_t ALU_OP_SLTU_CPP = 0b0100;
const uint8_t ALU_OP_XOR_CPP  = 0b0101;
const uint8_t ALU_OP_SRL_CPP  = 0b0110;
const uint8_t ALU_OP_SRA_CPP  = 0b0111;
const uint8_t ALU_OP_OR_CPP   = 0b1000;
const uint8_t ALU_OP_AND_CPP  = 0b1001;

vluint64_t sim_time = 0; // Глобальное время симуляции для VCD

double sc_time_stamp() {
    return sim_time;
}

// Измененная функция eval_alu: clk не нужен для комбинационного ALU
void eval_alu(Valu* alu_core, VerilatedVcdC* tfp) {
    alu_core->eval(); // Просто вызываем eval
    if (tfp) {
        tfp->dump(sim_time); // Дампим на текущее время симуляции
    }
}

struct AluTestCase {
    std::string name;
    uint64_t a, b;
    uint8_t alu_control_val;
    uint64_t expected_res;
    bool expected_zero;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Valu* top = new Valu;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_alu.vcd");

    std::cout << "Starting Enhanced ALU Testbench (RV64)" << std::endl;

    AluTestCase tests[] = {
        // === ADD Tests ===
        {"ADD 5+10", 5, 10, ALU_OP_ADD_CPP, 15, false},
        {"ADD 0+0", 0, 0, ALU_OP_ADD_CPP, 0, true},
        {"ADD -1+1", 0xFFFFFFFFFFFFFFFFULL, 1, ALU_OP_ADD_CPP, 0, true},
        {"ADD MAX_UINT64+1", 0xFFFFFFFFFFFFFFFFULL, 1, ALU_OP_ADD_CPP, 0, true},
        {"ADD MAX_INT64+1", 0x7FFFFFFFFFFFFFFFULL, 1, ALU_OP_ADD_CPP, 0x8000000000000000ULL, false},
        {"ADD MIN_INT64-1", 0x8000000000000000ULL, 0xFFFFFFFFFFFFFFFFULL, ALU_OP_ADD_CPP, 0x7FFFFFFFFFFFFFFFULL, false},
        {"ADD large positives", 0x7000000000000000ULL, 0x0FFFFFFFFFFFFFFFULL, ALU_OP_ADD_CPP, 0x7FFFFFFFFFFFFFFFULL, false},

        // === SUB Tests ===
        {"SUB 10-5", 10, 5, ALU_OP_SUB_CPP, 5, false},
        {"SUB 5-10", 5, 10, ALU_OP_SUB_CPP, (uint64_t)-5, false},
        {"SUB 0-0", 0, 0, ALU_OP_SUB_CPP, 0, true},
        {"SUB 0-1", 0, 1, ALU_OP_SUB_CPP, (uint64_t)-1, false},
        {"SUB MIN_INT64-1", 0x8000000000000000ULL, 1, ALU_OP_SUB_CPP, 0x7FFFFFFFFFFFFFFFULL, false},
        {"SUB MAX_INT64 - MIN_INT64", 0x7FFFFFFFFFFFFFFFULL, 0x8000000000000000ULL, ALU_OP_SUB_CPP, 0xFFFFFFFFFFFFFFFFULL, false},

        // === SLL Tests ===
        {"SLL 1<<3", 0x1ULL, 3, ALU_OP_SLL_CPP, 0x8ULL, false},
        {"SLL 1<<0", 0x1ULL, 0, ALU_OP_SLL_CPP, 0x1ULL, false},
        {"SLL 1<<63", 0x1ULL, 63, ALU_OP_SLL_CPP, 0x8000000000000000ULL, false},
        {"SLL 1<<64 (shamt=0)", 0x1ULL, 64, ALU_OP_SLL_CPP, 0x1ULL, false}, // operand_b[5:0] -> shamt=0
        {"SLL 0xFF<<8", 0xFFULL, 8, ALU_OP_SLL_CPP, 0xFF00ULL, false},
        {"SLL anything by 0", 0xABCDEF1234567890ULL, 0, ALU_OP_SLL_CPP, 0xABCDEF1234567890ULL, false},

        // === SLT Tests ===
        {"SLT 5<10", 5, 10, ALU_OP_SLT_CPP, 1, false},
        {"SLT 10<5", 10, 5, ALU_OP_SLT_CPP, 0, true},
        {"SLT 5<5", 5, 5, ALU_OP_SLT_CPP, 0, true},
        {"SLT -5<2", (uint64_t)-5, 2, ALU_OP_SLT_CPP, 1, false},
        {"SLT 2<-5", 2, (uint64_t)-5, ALU_OP_SLT_CPP, 0, true},
        {"SLT -2<-5", (uint64_t)-2, (uint64_t)-5, ALU_OP_SLT_CPP, 0, true},
        {"SLT -5<-2", (uint64_t)-5, (uint64_t)-2, ALU_OP_SLT_CPP, 1, false},
        {"SLT MAX_INT64 vs MIN_INT64", 0x7FFFFFFFFFFFFFFFULL, 0x8000000000000000ULL, ALU_OP_SLT_CPP, 0, true},
        {"SLT MIN_INT64 vs MAX_INT64", 0x8000000000000000ULL, 0x7FFFFFFFFFFFFFFFULL, ALU_OP_SLT_CPP, 1, false},

        // === SLTU Tests ===
        {"SLTU 5<10", 5, 10, ALU_OP_SLTU_CPP, 1, false},
        {"SLTU 10<5", 10, 5, ALU_OP_SLTU_CPP, 0, true},
        {"SLTU 5<5", 5, 5, ALU_OP_SLTU_CPP, 0, true},
        {"SLTU (uint)-5 < 2", (uint64_t)-5, 2, ALU_OP_SLTU_CPP, 0, true}, 
        {"SLTU 2 < (uint)-5", 2, (uint64_t)-5, ALU_OP_SLTU_CPP, 1, false},
        {"SLTU MAX_UINT64 vs 0", 0xFFFFFFFFFFFFFFFFULL, 0, ALU_OP_SLTU_CPP, 0, true},
        {"SLTU 0 vs MAX_UINT64", 0, 0xFFFFFFFFFFFFFFFFULL, ALU_OP_SLTU_CPP, 1, false},

        // === XOR Tests ===
        {"XOR F0F0^0F0F", 0xF0F0F0F0F0F0F0F0ULL, 0x0F0F0F0F0F0F0F0FULL, ALU_OP_XOR_CPP, 0xFFFFFFFFFFFFFFFFULL, false},
        {"XOR A^A=0", 0x123456789ABCDEF0ULL, 0x123456789ABCDEF0ULL, ALU_OP_XOR_CPP, 0, true},
        {"XOR A^0=A", 0x123456789ABCDEF0ULL, 0, ALU_OP_XOR_CPP, 0x123456789ABCDEF0ULL, false},

        // === SRL Tests ===
        {"SRL 0x8000...>>1", 0x8000000000000000ULL, 1, ALU_OP_SRL_CPP, 0x4000000000000000ULL, false},
        {"SRL 0x0F...>>4", 0x0F00000000000000ULL, 4, ALU_OP_SRL_CPP, 0x00F0000000000000ULL, false},
        {"SRL val by 0", 0xABCDEF1234567890ULL, 0, ALU_OP_SRL_CPP, 0xABCDEF1234567890ULL, false},
        {"SRL val by 64 (shamt=0)", 0xABCDEF1234567890ULL, 64, ALU_OP_SRL_CPP, 0xABCDEF1234567890ULL, false},
        {"SRL val by 63", 0x8000000000000000ULL, 63, ALU_OP_SRL_CPP, 1, false},

        // === SRA Tests ===
        {"SRA 0x8000...>>1 (neg)", 0x8000000000000000ULL, 1, ALU_OP_SRA_CPP, 0xC000000000000000ULL, false},
        {"SRA 0x4000...>>1 (pos)", 0x4000000000000000ULL, 1, ALU_OP_SRA_CPP, 0x2000000000000000ULL, false},
        {"SRA -16>>4", 0xFFFFFFFFFFFFFFF0ULL, 4, ALU_OP_SRA_CPP, 0xFFFFFFFFFFFFFFFFULL, false}, 
        {"SRA val by 0", 0x8BCDEF1234567890ULL, 0, ALU_OP_SRA_CPP, 0x8BCDEF1234567890ULL, false},
        {"SRA val by 64 (shamt=0)", 0x8BCDEF1234567890ULL, 64, ALU_OP_SRA_CPP, 0x8BCDEF1234567890ULL, false},
        {"SRA -2 by 1", (uint64_t)-2, 1, ALU_OP_SRA_CPP, (uint64_t)-1, false}, 
        {"SRA MIN_INT64 by 63", 0x8000000000000000ULL, 63, ALU_OP_SRA_CPP, 0xFFFFFFFFFFFFFFFFULL, false},

        // === OR Tests ===
        {"OR F0F0|0F0F", 0xF0F0F0F0F0F0F0F0ULL, 0x0F0F0F0F0F0F0F0FULL, ALU_OP_OR_CPP, 0xFFFFFFFFFFFFFFFFULL, false},
        {"OR A|0=A", 0x123456789ABCDEF0ULL, 0, ALU_OP_OR_CPP, 0x123456789ABCDEF0ULL, false},
        {"OR A|A=A", 0x123456789ABCDEF0ULL, 0x123456789ABCDEF0ULL, ALU_OP_OR_CPP, 0x123456789ABCDEF0ULL, false},
        {"OR A|~A = FFs", 0x5555555555555555ULL, 0xAAAAAAAAAAAAAAAAULL, ALU_OP_OR_CPP, 0xFFFFFFFFFFFFFFFFULL, false},

        // === AND Tests ===
        {"AND F0F0&0F0F", 0xF0F0F0F0F0F0F0F0ULL, 0x0F0F0F0F0F0F0F0FULL, ALU_OP_AND_CPP, 0, true},
        {"AND A&0=0", 0x123456789ABCDEF0ULL, 0, ALU_OP_AND_CPP, 0, true},
        {"AND A&A=A", 0x123456789ABCDEF0ULL, 0x123456789ABCDEF0ULL, ALU_OP_AND_CPP, 0x123456789ABCDEF0ULL, false},
        {"AND A&~A = 0", 0x5555555555555555ULL, 0xAAAAAAAAAAAAAAAAULL, ALU_OP_AND_CPP, 0, true},
    };

    int num_tests = sizeof(tests) / sizeof(AluTestCase);
    int passed_tests = 0;

    for (int i = 0; i < num_tests; ++i) {
        AluTestCase& t = tests[i];

        top->operand_a = t.a;
        top->operand_b = t.b;
        top->alu_control = t.alu_control_val;

        eval_alu(top, tfp); // Вызываем eval один раз, т.к. модуль комбинационный
        // Для VCD инкрементируем время после каждого набора входов/выходов
        sim_time++;

        bool pass = (top->result == t.expected_res) &&
                    (top->zero_flag == t.expected_zero);

        if (pass) {
            passed_tests++;
        } else {
            std::cout << "FAIL Test: " << t.name << std::endl;
            std::cout << "  Input: A=0x" << std::hex << t.a << ", B=0x" << t.b
                      << ", ALUControl=0b" << std::bitset<ALU_CONTROL_WIDTH_CPP>(t.alu_control_val) << std::dec << std::endl;
            std::cout << "  Got  : Res=0x" << std::hex << top->result << ", Zero=" << (int)top->zero_flag << std::dec << std::endl;
            std::cout << "  Exp  : Res=0x" << std::hex << t.expected_res << ", Zero=" << (int)t.expected_zero << std::dec << std::endl;
        }
        assert(pass);
    }

    std::cout << "\nEnhanced ALU Testbench Finished. Passed " << passed_tests << "/" << num_tests << " tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    return (passed_tests == num_tests) ? EXIT_SUCCESS : EXIT_FAILURE;
}