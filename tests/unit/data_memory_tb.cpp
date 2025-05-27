// tests/unit/data_memory_tb.cpp
#include "Vdata_memory_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <bitset>
#include <cstdint>
#include <vector>
#include <string>

// Funct3 codes for LOAD/STORE (из common/riscv_opcodes.svh)
const uint8_t FUNCT3_LB_CPP  = 0b000;
const uint8_t FUNCT3_LH_CPP  = 0b001;
const uint8_t FUNCT3_LW_CPP  = 0b010;
const uint8_t FUNCT3_LD_CPP  = 0b011;
const uint8_t FUNCT3_LBU_CPP = 0b100;
const uint8_t FUNCT3_LHU_CPP = 0b101;
const uint8_t FUNCT3_LWU_CPP = 0b110;

const uint8_t FUNCT3_SB_CPP  = 0b000;
const uint8_t FUNCT3_SH_CPP  = 0b001;
const uint8_t FUNCT3_SW_CPP  = 0b010;
const uint8_t FUNCT3_SD_CPP  = 0b011;


vluint64_t sim_time_dmem = 0;

void tick_dmem(Vdata_memory_tb* dut, VerilatedVcdC* tfp) {
    // Память синхронная по записи, комбинационная по чтению (но зависит от clk для записи)
    // Поэтому тактируем
    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time_dmem);
    sim_time_dmem++;

    dut->clk = 1;
    dut->eval(); // Запись происходит на posedge clk
    if (tfp) tfp->dump(sim_time_dmem);
    sim_time_dmem++;
}


void reset_dmem(Vdata_memory_tb* dut, VerilatedVcdC* tfp) {
    dut->rst_n = 0;
    dut->i_addr = 0;
    dut->i_write_data = 0;
    dut->i_mem_write_en = 0;
    dut->i_funct3 = 0;
    // Держим ресет несколько тактов
    for(int i=0; i<5; ++i) {
        tick_dmem(dut, tfp);
    }
    dut->rst_n = 1;
    tick_dmem(dut, tfp); // Один такт после снятия ресета
    std::cout << "DUT Data Memory Reset" << std::endl;
}

struct DmemTestCase {
    std::string name;
    // Действия: "WRITE" или "READ"
    std::string action;
    uint64_t    address;
    uint8_t     funct3;
    uint64_t    write_data; // Используется для WRITE
    bool        mem_write_en;

    // Ожидания (только для READ)
    uint64_t    expected_read_data;
    bool        check_read_data; // true, если нужно проверять прочитанные данные
};


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vdata_memory_tb* top = new Vdata_memory_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_data_memory.vcd");

    std::cout << "Starting Data Memory Testbench" << std::endl;

    reset_dmem(top, tfp);

    std::vector<DmemTestCase> test_cases = {
        // Test SB (Store Byte) then LB (Load Byte Signed)
        {"Write Byte 0xAA to 0x00", "WRITE", 0x00, FUNCT3_SB_CPP, 0xAA, true, 0, false},
        {"Read Byte from 0x00 (signed AA)", "READ", 0x00, FUNCT3_LB_CPP, 0, false, 0xFFFFFFFFFFFFFFAAULL, true},
        {"Write Byte 0x55 to 0x01", "WRITE", 0x01, FUNCT3_SB_CPP, 0x55, true, 0, false},
        {"Read Byte from 0x01 (signed 55)", "READ", 0x01, FUNCT3_LB_CPP, 0, false, 0x55, true},

        // Test SH (Store Half) then LH (Load Half Signed) / LHU (Load Half Unsigned)
        {"Write Half 0xCCBB to 0x04", "WRITE", 0x04, FUNCT3_SH_CPP, 0xCCBB, true, 0, false},
        {"Read Half from 0x04 (signed CCBB)", "READ", 0x04, FUNCT3_LH_CPP, 0, false, 0xFFFFFFFFFFFFCCBBULL, true},
        {"Read Half from 0x04 (unsigned CCBB)", "READ", 0x04, FUNCT3_LHU_CPP, 0, false, 0xCCBB, true},
        {"Write Half 0x3344 to 0x0A", "WRITE", 0x0A, FUNCT3_SH_CPP, 0x3344, true, 0, false},
        {"Read Half from 0x0A (signed 3344)", "READ", 0x0A, FUNCT3_LH_CPP, 0, false, 0x3344, true},

        // Test SW (Store Word) then LW (Load Word Signed) / LWU (Load Word Unsigned)
        {"Write Word 0x87654321 to 0x10", "WRITE", 0x10, FUNCT3_SW_CPP, 0x87654321, true, 0, false},
        {"Read Word from 0x10 (signed)", "READ", 0x10, FUNCT3_LW_CPP, 0, false, 0xFFFFFFFF87654321ULL, true},
        {"Read Word from 0x10 (unsigned)", "READ", 0x10, FUNCT3_LWU_CPP, 0, false, 0x87654321, true},

        // Test SD (Store Double) then LD (Load Double)
        {"Write Double 0x1122334455667788 to 0x20", "WRITE", 0x20, FUNCT3_SD_CPP, 0x1122334455667788ULL, true, 0, false},
        {"Read Double from 0x20", "READ", 0x20, FUNCT3_LD_CPP, 0, false, 0x1122334455667788ULL, true},

        // Test LBU (Load Byte Unsigned)
        {"Write Byte 0xDD to 0x02", "WRITE", 0x02, FUNCT3_SB_CPP, 0xDD, true, 0, false},
        {"Read Byte from 0x02 (unsigned DD)", "READ", 0x02, FUNCT3_LBU_CPP, 0, false, 0xDD, true},

        // Test read from unwritten location (should be 0 after reset)
        {"Read from unwritten (0x100)", "READ", 0x100, FUNCT3_LD_CPP, 0, false, 0x00, true},

        // Test write disabled
        {"Attempt Write Byte 0xFF to 0x30 (Write Disabled)", "WRITE", 0x30, FUNCT3_SB_CPP, 0xFF, false, 0, false}, // mem_write_en = false
        {"Read Byte from 0x30 (should be 0)", "READ", 0x30, FUNCT3_LB_CPP, 0, false, 0x00, true}, // Expect 0 (or prev value if not reset)

        // Testfunct3 mismatch on write (should still write based on size)
        // The funct3 is mainly for size on store, and size+sign on load.
        {"Write Byte 0xEE to 0x40 (funct3=SD, but SB behavior)", "WRITE", 0x40, FUNCT3_SD_CPP /* Mismatched funct3, but size is SB */, 0xEE, true, 0, false}, // This test is tricky. Store ops only use funct3 for size.
                                                                                                                                                   // Let's make a specific SD then read it as byte
        {"Write Double 0x12345678ABCDEF01 to 0x50", "WRITE", 0x50, FUNCT3_SD_CPP, 0x12345678ABCDEF01ULL, true, 0, false},
        {"Read Byte from 0x50 (LSB of double)", "READ", 0x50, FUNCT3_LB_CPP, 0, false, 0x01, true} // Assuming Little Endian for byte order
    };

    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;
        std::cout << "  Action: " << tc.action
                  << ", Address: 0x" << std::hex << tc.address
                  << ", Funct3: 0b" << std::bitset<3>(tc.funct3) << std::dec;
        if (tc.action == "WRITE") {
            std::cout << ", WriteData: 0x" << std::hex << tc.write_data << std::dec;
        }
        std::cout << ", MemWriteEn: " << tc.mem_write_en << std::endl;

        top->i_addr = tc.address;
        top->i_funct3 = tc.funct3;
        top->i_mem_write_en = tc.mem_write_en;
        if (tc.action == "WRITE") {
            top->i_write_data = tc.write_data;
        } else {
            top->i_write_data = 0; // Don't care for read
        }

        // For WRITE, data is written on posedge. For READ, output is combinational.
        // We tick once to ensure any synchronous write happens.
        // Then, for READs, the output o_read_data should be valid after eval.
        if (tc.action == "WRITE") {
            tick_dmem(top, tfp); // This will apply write on posedge clk
        } else { // READ
            // For read, the output is combinational. One eval after setting address should be enough.
            // But to keep VCD clean and have a "moment" of read:
            top->clk = 0; top->eval(); if(tfp) tfp->dump(sim_time_dmem); // Set address
            sim_time_dmem++;
            top->clk = 1; top->eval(); if(tfp) tfp->dump(sim_time_dmem); // Read output is stable
            sim_time_dmem++;
        }


        bool current_pass = true;
        if (tc.action == "READ" && tc.check_read_data) {
            if (top->o_read_data != tc.expected_read_data) {
                std::cout << "  FAIL: Read Data Mismatch." << std::endl;
                std::cout << "    Expected: 0x" << std::hex << tc.expected_read_data << std::dec << std::endl;
                std::cout << "    Got:      0x" << std::hex << top->o_read_data << std::dec << std::endl;
                current_pass = false;
            }
        }

        if (current_pass) {
            std::cout << "  PASS" << std::endl;
            passed_count++;
        } else {
            std::cout << "  FAILED" << std::endl;
        }
    }

    std::cout << "\nData Memory Testbench Finished. Passed " << passed_count << "/" << test_cases.size() << " tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    return (passed_count == test_cases.size()) ? EXIT_SUCCESS : EXIT_FAILURE;
}