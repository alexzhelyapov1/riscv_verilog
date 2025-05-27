// tests/unit/instruction_memory_tb.cpp
#include "Vinstruction_memory_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h" // Optional: if we want VCD for this simple test

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>

// Ожидаемые значения из instruction_memory.sv initial block
const uint32_t DEFAULT_NOP_INSTR = 0x00000013;
const uint32_t INSTR_MEM_0 = 0x00100093; // addi x1, x0, 1
const uint32_t INSTR_MEM_1 = 0x00200113; // addi x2, x0, 2
const uint32_t INSTR_MEM_2 = 0x00308193; // addi x3, x1, 3
const uint32_t INSTR_MEM_3 = 0x00110213; // addi x4, x2, 1

const int ROM_SIZE_INSTR = 256; // Должно соответствовать ROM_SIZE в instruction_memory.sv

vluint64_t sim_time_imem = 0; // Отдельное время для этого теста

void eval_imem(Vinstruction_memory_tb* dut, VerilatedVcdC* tfp) {
    dut->eval();
    if (tfp) {
        tfp->dump(sim_time_imem);
    }
    // sim_time_imem++; // Для комбинационного теста время можно не инкрементировать на каждом eval
}

struct ImemTestCase {
    std::string name;
    uint64_t    address;
    uint32_t    expected_instruction;
    bool        expect_defined_behavior; // true if address is within ROM and behavior is defined
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vinstruction_memory_tb* top = new Vinstruction_memory_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_instruction_memory.vcd");

    std::cout << "Starting Instruction Memory Testbench" << std::endl;

    std::vector<ImemTestCase> test_cases = {
        {"Read Addr 0 (Instr 0)",       0x00, INSTR_MEM_0, true},
        {"Read Addr 4 (Instr 1)",       0x04, INSTR_MEM_1, true},
        {"Read Addr 8 (Instr 2)",       0x08, INSTR_MEM_2, true},
        {"Read Addr 12 (Instr 3)",      0x0C, INSTR_MEM_3, true},
        {"Read Addr 16 (Uninit, NOP)",  0x10, DEFAULT_NOP_INSTR, true},
        {"Read Addr last valid (NOP)",  (uint64_t)((ROM_SIZE_INSTR - 1) * 4), DEFAULT_NOP_INSTR, true},
        // Тесты для адресов немного за пределами инициализированных, но внутри ROM_SIZE
        {"Read Addr 20 (Uninit, NOP)",  0x14, DEFAULT_NOP_INSTR, true},
        {"Read Addr 0x3F8 (last in ROM)",0x3F8, DEFAULT_NOP_INSTR, true}, // (255*4)
        {"Read Addr 0x3FC (last in ROM)",0x3FC, DEFAULT_NOP_INSTR, true}, // (255*4) -> (256-1)*4

        // Тесты на граничные условия (за пределами ROM)
        // Поведение здесь зависит от Verilator/SystemVerilog для out-of-bounds array access.
        // Verilator может выдать предупреждение или ошибку, или вернуть 'x.
        // Мы ожидаем, что это не приведет к падению симуляции, но значение может быть неопределенным.
        // Для `logic` неинициализированные биты обычно 'x'.
        // Если instruction_memory.sv не обрабатывает out-of-bounds, то это undefined behavior.
        // Мы пометим expect_defined_behavior = false для таких случаев.
        {"Read Addr Out of Bounds High", (uint64_t)(ROM_SIZE_INSTR * 4), 0x0, false}, // Адрес сразу за памятью
        {"Read Addr Very High",          0xFFFFFFFFFFFFFFFCULL,          0x0, false}  // Очень большой адрес
    };

    int passed_count = 0;
    int total_defined_tests = 0;

    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;
        std::cout << "  Address: 0x" << std::hex << tc.address << std::dec << std::endl;

        top->i_address = tc.address;
        eval_imem(top, tfp);
        sim_time_imem++; // Инкрементируем время для каждого тестового случая в VCD

        bool current_pass = true;
        if (tc.expect_defined_behavior) {
            total_defined_tests++;
            if (top->o_instruction != tc.expected_instruction) {
                std::cout << "  FAIL: Instruction Mismatch." << std::endl;
                std::cout << "    Expected: 0x" << std::hex << tc.expected_instruction << std::dec << std::endl;
                std::cout << "    Got:      0x" << std::hex << top->o_instruction << std::dec << std::endl;
                current_pass = false;
            }
        } else {
            // Для неопределенного поведения мы не делаем строгую проверку значения,
            // но убеждаемся, что симуляция не упала (это делается самим фактом выполнения).
            // Можно проверить, что значение содержит 'x', если Verilator так делает.
            // Verilator часто инициализирует 'x' как 0 при преобразовании в uint32_t, если нет явной обработки.
            // Для простоты, просто логируем, что это тест на "неопределенное поведение".
            std::cout << "  INFO: Testing out-of-bounds read. Got: 0x" << std::hex << top->o_instruction << std::dec << ". Behavior might be undefined by DUT." << std::endl;
            // Если бы мы хотели проверить на 'x', это было бы сложнее без DPI или анализа сигнала как строки.
        }

        if (current_pass && tc.expect_defined_behavior) {
            std::cout << "  PASS" << std::endl;
            passed_count++;
        } else if (!tc.expect_defined_behavior) {
            // Считаем тесты на неопределенное поведение "пройденными", если симуляция не упала.
            // Это больше для проверки устойчивости, чем для проверки корректности значения.
             std::cout << "  INFO: Out-of-bounds test case executed." << std::endl;
        } else {
             std::cout << "  FAILED" << std::endl;
        }
    }

    std::cout << "\nInstruction Memory Testbench Finished." << std::endl;
    std::cout << "Passed " << passed_count << "/" << total_defined_tests << " defined behavior tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    // Успех, если все тесты с ожидаемым поведением прошли
    return (passed_count == total_defined_tests) ? EXIT_SUCCESS : EXIT_FAILURE;
}