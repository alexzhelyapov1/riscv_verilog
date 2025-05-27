// tests/unit/register_file_tb.cpp
#include "Vregister_file_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>

vluint64_t sim_time_regfile = 0;

// Определяем один полный тактовый цикл: negedge -> posedge
// Чтение происходит на negedge, запись на posedge.
void step_clk_regfile(Vregister_file_tb* dut, VerilatedVcdC* tfp) {
    // ---- ФАЗА 1: CLK LOW (negedge) ----
    dut->clk = 0;
    dut->eval(); // Обновляются выходы RF (rs1_data_o, rs2_data_o) на основе адресов, поданных до этого
    if (tfp) tfp->dump(sim_time_regfile);
    sim_time_regfile++;

    // ---- ФАЗА 2: CLK HIGH (posedge) ----
    dut->clk = 1;
    dut->eval(); // Происходит запись в RF, если rd_write_en_wb_i активен
    if (tfp) tfp->dump(sim_time_regfile);
    sim_time_regfile++;
}

void reset_regfile(Vregister_file_tb* dut, VerilatedVcdC* tfp) {
    dut->rst_n = 0;
    // Установить входы в безопасное состояние во время сброса
    dut->i_rs1_addr = 0;
    dut->i_rs2_addr = 0;
    dut->i_rd_write_en_wb = 0;
    dut->i_rd_addr_wb = 0;
    dut->i_rd_data_wb = 0;

    // Пропустить несколько тактов с активным сбросом
    for (int i = 0; i < 3; ++i) {
        step_clk_regfile(dut, tfp);
    }
    dut->rst_n = 1;
    dut->eval(); // Применить rst_n = 1
    step_clk_regfile(dut, tfp); // Один такт после снятия сброса для стабилизации
    std::cout << "DUT Register File Reset" << std::endl;
}

struct RegFileTestCase {
    std::string name;
    // Действия перед проверкой чтения (могут быть множественные записи)
    std::vector<std::tuple<uint8_t, uint64_t, bool>> writes_before_read; // rd_addr, rd_data, write_enable

    // Адреса для чтения
    uint8_t  rs1_addr_check;
    uint8_t  rs2_addr_check;

    // Ожидаемые данные чтения (после всех записей и одного negedge для чтения)
    uint64_t expected_rs1_data;
    uint64_t expected_rs2_data;
};


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vregister_file_tb* top = new Vregister_file_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_register_file.vcd");

    std::cout << "Starting Register File Testbench" << std::endl;

    std::vector<RegFileTestCase> test_cases = {
        {
            "Reset Check (Read x1, x2 after reset)",
            {}, // No writes
            1, 2, 0x0, 0x0 // Expect 0 from x1, x2 after reset
        },
        {
            "Write x1, Read x1",
            {{1, 0xABCD, true}}, // Write 0xABCD to x1
            1, 0, 0xABCD, 0x0 // Read x1, read x0
        },
        {
            "Write x5, x10; Read x5, x10",
            {{5, 0x12345, true}, {10, 0x6789A, true}},
            5, 10, 0x12345, 0x6789A
        },
        {
            "Write x0 (ignored), Read x0, x1",
            {{0, 0xFFFF, true}, {1, 0x1111, true}}, // Attempt write to x0
            0, 1, 0x0, 0x1111 // Expect x0=0, x1=0x1111
        },
        {
            "Write Disabled, Read x3",
            {{3, 0xBAD, false}}, // Write disabled
            3, 0, 0x0, 0x0 // Expect x3 to be 0 (from reset)
        },
        {
            "Sequential Writes to same reg, Read last",
            {{2, 0x100, true}, {2, 0x200, true}},
            2, 0, 0x200, 0x0
        },
        {
            "Read two different written regs",
            {{7, 0x777, true}, {15, 0xFFF, true}},
            7, 15, 0x777, 0xFFF
        },
        // // Тест на "запись в первой половине, чтение во второй" (write x1, read x1 in same conceptual cycle)
        // // В нашем RF: запись по posedge, чтение по negedge.
        // // Если мы выставим write_en, rd_addr, rd_data И rs1_addr (равный rd_addr) одновременно,
        // // то на negedge этого же такта мы прочитаем СТАРОЕ значение,
        // // а новое будет записано на posedge.
        // // Чтобы прочитать НОВОЕ значение, нужен следующий negedge.
        {
            "Write x1 (valA), then setup read x1, check old val, then check new val",
            {{1, 0xAAAA, true}}, // x1 = 0xAAAA after this set of operations + 1st tick
            1, 0, 0xAAAA, 0 // Прочитаем 0xAAAA на negedge после записи
        }
        // // Более сложный тест для read-during-write:
        // // 1. Записать начальное значение в x1 (e.g. 0x1111)
        // // 2. В одном такте: настроить запись нового значения в x1 (e.g. 0x2222) И настроить чтение x1
        // // 3. На negedge этого такта, o_rs1_data должно быть 0x1111 (старое).
        // // 4. На следующем negedge, o_rs1_data должно быть 0x2222 (новое).
    };


    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;
        reset_regfile(top, tfp); // Сбрасываем RF перед каждым набором операций

        // Выполняем предварительные записи
        for (const auto& write_op : tc.writes_before_read) {
            top->i_rd_addr_wb = std::get<0>(write_op);
            top->i_rd_data_wb = std::get<1>(write_op);
            top->i_rd_write_en_wb = std::get<2>(write_op);
            std::cout << "  Setup Write: Addr=" << (int)top->i_rd_addr_wb
                      << ", Data=0x" << std::hex << top->i_rd_data_wb
                      << ", WE=" << (int)top->i_rd_write_en_wb << std::dec << std::endl;
            step_clk_regfile(top, tfp); // Запись происходит на posedge этого такта
        }
        // Сбрасываем сигналы записи после всех операций записи, чтобы они не влияли на чтение
        top->i_rd_write_en_wb = 0;
        top->i_rd_addr_wb = 0; // Можно не сбрасывать, если write_en=0
        top->i_rd_data_wb = 0; // Можно не сбрасывать

        // Устанавливаем адреса для чтения
        top->i_rs1_addr = tc.rs1_addr_check;
        top->i_rs2_addr = tc.rs2_addr_check;
        std::cout << "  Setup Read: rs1_addr=" << (int)top->i_rs1_addr
                  << ", rs2_addr=" << (int)top->i_rs2_addr << std::endl;

        // Данные чтения будут доступны на выходах o_rs1_data, o_rs2_data
        // ПОСЛЕ negedge следующего тактового импульса (или текущего, если адреса уже были установлены).
        // Сделаем один полный такт, чтобы чтение по negedge произошло.
        step_clk_regfile(top, tfp);
        // После этого step_clk_regfile, на выходах o_rs1_data и o_rs2_data должны быть актуальные значения

        bool current_pass = true;
        if (top->o_rs1_data != tc.expected_rs1_data) {
            std::cout << "  FAIL: RS1 Data Mismatch." << std::endl;
            std::cout << "    rs1_addr=" << (int)tc.rs1_addr_check << std::endl;
            std::cout << "    Expected: 0x" << std::hex << tc.expected_rs1_data << std::dec << std::endl;
            std::cout << "    Got:      0x" << std::hex << top->o_rs1_data << std::dec << std::endl;
            current_pass = false;
        }
        if (top->o_rs2_data != tc.expected_rs2_data) {
            std::cout << "  FAIL: RS2 Data Mismatch." << std::endl;
            std::cout << "    rs2_addr=" << (int)tc.rs2_addr_check << std::endl;
            std::cout << "    Expected: 0x" << std::hex << tc.expected_rs2_data << std::dec << std::endl;
            std::cout << "    Got:      0x" << std::hex << top->o_rs2_data << std::dec << std::endl;
            current_pass = false;
        }

        if (current_pass) {
            std::cout << "  PASS" << std::endl;
            passed_count++;
        } else {
            std::cout << "  FAILED" << std::endl;
        }
    }
     // Тест на чтение во время записи (read-during-write)
    std::cout << "\nRunning Test: Read-during-write x1" << std::endl;
    reset_regfile(top, tfp);
    // 1. Записать начальное значение в x1
    top->i_rd_addr_wb = 1; top->i_rd_data_wb = 0x1111; top->i_rd_write_en_wb = 1;
    step_clk_regfile(top, tfp); // x1 = 0x1111
    top->i_rd_write_en_wb = 0; // Снять WE

    // 2. Настроить чтение x1 и одновременно запись нового значения в x1
    top->i_rs1_addr = 1; // Читаем x1
    top->i_rs2_addr = 0; // Читаем x0
    top->i_rd_addr_wb = 1; // Пишем в x1
    top->i_rd_data_wb = 0x2222; // Новое значение
    top->i_rd_write_en_wb = 1;  // Разрешить запись

    // 3. Первый такт после установки:
    // clk=0 (negedge): rs1_data_o читает значение *до* записи 0x2222. Должно быть 0x1111.
    // clk=1 (posedge): 0x2222 записывается в regs[1].
    top->clk = 0; top->eval(); if(tfp) tfp->dump(sim_time_regfile); sim_time_regfile++;
    bool pass_rdw1 = (top->o_rs1_data == 0x1111);
    std::cout << "  Read-during-write (cycle 1 negedge): rs1_addr=1, read_data=0x" << std::hex << top->o_rs1_data << ". Expected 0x1111." << std::dec << std::endl;

    top->clk = 1; top->eval(); if(tfp) tfp->dump(sim_time_regfile); sim_time_regfile++;
    // Запись 0x2222 произошла

    top->i_rd_write_en_wb = 0; // Снять WE для следующего чтения

    // 4. Второй такт:
    // clk=0 (negedge): rs1_data_o читает новое значение 0x2222.
    top->clk = 0; top->eval(); if(tfp) tfp->dump(sim_time_regfile); sim_time_regfile++;
    bool pass_rdw2 = (top->o_rs1_data == 0x2222);
    std::cout << "  Read-during-write (cycle 2 negedge): rs1_addr=1, read_data=0x" << std::hex << top->o_rs1_data << ". Expected 0x2222." << std::dec << std::endl;

    top->clk = 1; top->eval(); if(tfp) tfp->dump(sim_time_regfile); sim_time_regfile++;


    if (pass_rdw1 && pass_rdw2) {
        std::cout << "  Read-during-write: PASS" << std::endl;
        passed_count++;
        test_cases.emplace_back(); // "Фиктивный" успешный тест для общего счетчика
    } else {
        std::cout << "  Read-during-write: FAILED" << std::endl;
        test_cases.emplace_back(); // "Фиктивный" проваленный тест
    }


    std::cout << "\nRegister File Testbench Finished. Passed " << passed_count << "/" << test_cases.size() << " tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    return (passed_count == test_cases.size()) ? EXIT_SUCCESS : EXIT_FAILURE;
}