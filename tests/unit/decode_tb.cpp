// tests/unit/decode_tb.cpp
#include "Vdecode_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>
#include <map>
#include <bitset> // For printing ALU control in binary
#include <optional> // For optional expected values

// MANUALLY DEFINED CONSTANTS (mirroring .svh files for testbench use)
const int ALU_CONTROL_WIDTH = 4;
const uint8_t ALU_OP_ADD  = 0b0000;
const uint8_t ALU_OP_SUB  = 0b0001;
// ... (остальные ALU_OP_* как были)
const uint8_t ALU_OP_SLL  = 0b0010;
const uint8_t ALU_OP_SLT  = 0b0011;
const uint8_t ALU_OP_SLTU = 0b0100;
const uint8_t ALU_OP_XOR  = 0b0101;
const uint8_t ALU_OP_SRL  = 0b0110;
const uint8_t ALU_OP_SRA  = 0b0111;
const uint8_t ALU_OP_OR   = 0b1000;
const uint8_t ALU_OP_AND  = 0b1001;


const uint32_t NOP_INSTRUCTION = 0x00000013; // addi x0, x0, 0

// RISC-V Opcodes for instruction type determination in C++
const uint8_t OPCODE_LUI        = 0b0110111;
const uint8_t OPCODE_AUIPC      = 0b0010111;
const uint8_t OPCODE_JAL        = 0b1101111;
const uint8_t OPCODE_JALR       = 0b1100111;
const uint8_t OPCODE_BRANCH     = 0b1100011;
const uint8_t OPCODE_LOAD       = 0b0000011;
const uint8_t OPCODE_STORE      = 0b0100011;
const uint8_t OPCODE_OP_IMM   = 0b0010011;
const uint8_t OPCODE_OP         = 0b0110011;
// const uint8_t OPCODE_MISC_MEM = 0b0001111;
// const uint8_t OPCODE_SYSTEM =   0b1110011;


vluint64_t sim_time = 0;

void tick(Vdecode_tb* dut, VerilatedVcdC* tfp) {
    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;
    dut->clk = 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;
}

void reset_dut(Vdecode_tb* dut, VerilatedVcdC* tfp) {
    dut->rst_n = 0;
    dut->i_if_id_stall_d = 0;
    dut->i_if_id_flush_d = 0;
    dut->i_instr_f = NOP_INSTRUCTION;
    dut->i_pc_f = 0;
    dut->i_pc_plus_4_f = 4;
    dut->i_wb_write_en = 0;
    dut->i_wb_rd_addr = 0;
    dut->i_wb_rd_data = 0;
    for (int i = 0; i < 5; ++i) tick(dut, tfp);
    dut->rst_n = 1;
    tick(dut, tfp);
    std::cout << "DUT Reset" << std::endl;
}

void set_reg(Vdecode_tb* dut, VerilatedVcdC* tfp, uint8_t reg_addr, uint64_t data) {
    if (reg_addr == 0) return;
    dut->i_wb_write_en = 1;
    dut->i_wb_rd_addr = reg_addr;
    dut->i_wb_rd_data = data;
    tick(dut, tfp); // Write happens on posedge
    dut->i_wb_write_en = 0;
    // tick(dut, tfp); // Allow outputs to settle - removed, one tick in set_reg should be enough before next op
}

// Helper to extract fields from instruction
uint8_t get_opcode_cpp(uint32_t instr) { return instr & 0x7F; }
uint8_t get_rd_cpp(uint32_t instr) { return (instr >> 7) & 0x1F; }
uint8_t get_rs1_cpp(uint32_t instr) { return (instr >> 15) & 0x1F; }
uint8_t get_rs2_cpp(uint32_t instr) { return (instr >> 20) & 0x1F; }

struct ExpectedControls {
    bool        reg_write;
    uint8_t     result_src;
    bool        mem_write;
    bool        jump;
    bool        branch;
    bool        alu_src;
    uint8_t     alu_control;
};

struct DecodeTestCase {
    std::string name;
    uint32_t    instruction;
    uint64_t    pc_val;
    std::map<uint8_t, uint64_t> initial_regs;

    // Expected control signals
    ExpectedControls controls;

    // Expected data values (use std::optional for values that might not be relevant)
    std::optional<uint64_t> expected_rs1_data;
    std::optional<uint64_t> expected_rs2_data;
    std::optional<uint64_t> expected_imm_ext;

    // Expected register addresses (these are always extracted by decode stage)
    // They will be compared against instruction fields directly.
};


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vdecode_tb* top = new Vdecode_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_decode.vcd");

    std::cout << "Starting Decode Stage Testbench (Intelligent Checks)" << std::endl;
    reset_dut(top, tfp);

    std::vector<DecodeTestCase> test_cases = {
        // === R-Type Instructions ===
        {
            "ADD x3, x1, x2", 0x002081B3, 0x100, // x1=0x10, x2=0x20 => x3=0x30
            {{1, 0x10}, {2, 0x20}},
            {true, 0b00, false, false, false, false, ALU_OP_ADD},
            0x10, 0x20, std::nullopt
        },
        {
            "SUB x4, x1, x2", 0x40208233, 0x104, // x1=0x20, x2=0x10 => x4=0x10
            {{1, 0x20}, {2, 0x10}},
            {true, 0b00, false, false, false, false, ALU_OP_SUB},
            0x20, 0x10, std::nullopt
        },
        {
            "SLL x5, x1, x2", 0x002092B3, 0x108, // x1=0x1, x2=0x5 (shamt) => x5=0x20
            {{1, 0x1}, {2, 0x5}},
            {true, 0b00, false, false, false, false, ALU_OP_SLL},
            0x1, 0x5, std::nullopt
        },
        {
            "SLT x6, x1, x2", 0x0020A333, 0x10C, // x1=5, x2=10 => x6=1
            {{1, 5}, {2, 10}},
            {true, 0b00, false, false, false, false, ALU_OP_SLT},
            5, 10, std::nullopt
        },
        {
            "SLT x6, x1, x2 (neg)", 0x0020A333, 0x110, // x1=-5, x2=-2 => x6=1
            {{1, uint64_t(-5)}, {2, uint64_t(-2)}},
            {true, 0b00, false, false, false, false, ALU_OP_SLT},
            uint64_t(-5), uint64_t(-2), std::nullopt
        },
        {
            "SLTU x7, x1, x2", 0x0020B3B3, 0x114, // x1=5, x2=10 => x7=1
            {{1, 5}, {2, 10}},
            {true, 0b00, false, false, false, false, ALU_OP_SLTU},
            5, 10, std::nullopt
        },
        {
            "SLTU x7, x1, x2 (large)", 0x0020B3B3, 0x118, // x1=-5 (large unsigned), x2=10 => x7=0
            {{1, uint64_t(-5)}, {2, 10}},
            {true, 0b00, false, false, false, false, ALU_OP_SLTU},
            uint64_t(-5), 10, std::nullopt
        },
        {
            "XOR x8, x1, x2", 0x0020C433, 0x11C, // x1=0xF0, x2=0x0F => x8=0xFF
            {{1, 0xF0}, {2, 0x0F}},
            {true, 0b00, false, false, false, false, ALU_OP_XOR},
            0xF0, 0x0F, std::nullopt
        },
        {
            "SRL x9, x1, x2", 0x0020D4B3, 0x120, // x1=0x80, x2=0x1 (shamt) => x9=0x40
            {{1, 0x80}, {2, 0x1}},
            {true, 0b00, false, false, false, false, ALU_OP_SRL},
            0x80, 0x1, std::nullopt
        },
        {
            "SRA x10, x1, x2", 0x4020D533, 0x124, // x1=0xFFFFFFFFFFFFFF80 (-128), x2=0x1 => x10=0xFFFFFFFFFFFFFFC0 (-64)
            {{1, 0xFFFFFFFFFFFFFF80ULL}, {2, 0x1}},
            {true, 0b00, false, false, false, false, ALU_OP_SRA},
            0xFFFFFFFFFFFFFF80ULL, 0x1, std::nullopt
        },
        {
            "OR x11, x1, x2", 0x0020E5B3, 0x128, // x1=0xF0, x2=0x0F => x11=0xFF
            {{1, 0xF0}, {2, 0x0F}},
            {true, 0b00, false, false, false, false, ALU_OP_OR},
            0xF0, 0x0F, std::nullopt
        },
        {
            "AND x12, x1, x2", 0x0020F633, 0x12C, // x1=0xF0, x2=0x0F => x12=0x00
            {{1, 0xF0}, {2, 0x0F}},
            {true, 0b00, false, false, false, false, ALU_OP_AND},
            0xF0, 0x0F, std::nullopt
        },

        // === I-Type Instructions (Arithmetic/Logic) ===
        {
            "ADDI x1, x2, 10", 0x00A10093, 0x200, // x2=0x200 => x1=0x20A
            {{2, 0x200}},
            {true, 0b00, false, false, false, true, ALU_OP_ADD},
            0x200, std::nullopt, 0xA
        },
        {
            "ADDI x1, x2, -10", 0xFF610093, 0x204, // x2=0x200 => x1=0x1F6. imm = -10 (0xFF6)
            {{2, 0x200}},
            {true, 0b00, false, false, false, true, ALU_OP_ADD},
            0x200, std::nullopt, 0xFFFFFFFFFFFFFFF6ULL // Sign-extended -10
        },
        {
            "SLTI x3, x1, 10", 0x00A0A193, 0x208, // x1=5 => x3=1
            {{1, 5}},
            {true, 0b00, false, false, false, true, ALU_OP_SLT},
            5, std::nullopt, 0xA
        },
        {
            "SLTIU x4, x1, 10", 0x00A0B213, 0x20C, // x1=5 => x4=1
            {{1, 5}},
            {true, 0b00, false, false, false, true, ALU_OP_SLTU},
            5, std::nullopt, 0xA
        },
        {
            "SLTIU x4, x1, -1 (large unsigned)", 0xFFF0B213, 0x210, // x1=5, imm=-1 (0xFFF) => x4=1 (5 < large_val)
            {{1, 5}},
            {true, 0b00, false, false, false, true, ALU_OP_SLTU},
            5, std::nullopt, 0xFFFFFFFFFFFFFFFFULL // Sign-extended -1
        },
        {
            "XORI x5, x1, 0x0F", 0x00F0C293, 0x214, // x1=0xF0 => x5=0xFF
            {{1, 0xF0}},
            {true, 0b00, false, false, false, true, ALU_OP_XOR},
            0xF0, std::nullopt, 0x0F
        },
        {
            "ORI x6, x1, 0x0F", 0x00F0E313, 0x218, // x1=0xF0 => x6=0xFF
            {{1, 0xF0}},
            {true, 0b00, false, false, false, true, ALU_OP_OR},
            0xF0, std::nullopt, 0x0F
        },
        {
            "ANDI x7, x1, 0x0F", 0x00F0F393, 0x21C, // x1=0xF0 => x7=0x00
            {{1, 0xF0}},
            {true, 0b00, false, false, false, true, ALU_OP_AND},
            0xF0, std::nullopt, 0x0F
        },
        {
            "SLLI x8, x1, 5", 0x00509413, 0x220, // x1=0x1 => x8=0x20
            {{1, 0x1}},
            {true, 0b00, false, false, false, true, ALU_OP_SLL},
            0x1, std::nullopt, 0x5 // shamt is in imm[4:0] part of I-imm
        },
        {
            "SRLI x9, x1, 1", 0x0010D493, 0x224, // x1=0x80 => x9=0x40
            {{1, 0x80}},
            {true, 0b00, false, false, false, true, ALU_OP_SRL},
            0x80, std::nullopt, 0x1
        },
        {
            "SRAI x10, x1, 1", 0x4010D513, 0x228, // x1=0xFFFFFFFFFFFFFF80 (-128) => x10=0xFFFFFFFFFFFFFFC0 (-64)
            {{1, 0xFFFFFFFFFFFFFF80ULL}},
            {true, 0b00, false, false, false, true, ALU_OP_SRA},
            0xFFFFFFFFFFFFFF80ULL, std::nullopt, 0x1
        },
        {
            "ADDI using x0 as source", 0x00A00093, 0x22C, // addi x1, x0, 10 => x1=10
            {},
            {true, 0b00, false, false, false, true, ALU_OP_ADD},
            0, std::nullopt, 0xA
        },

        // === Load/Store Instructions ===
        // LUI/LW/SW/JAL already covered in basic set. Adding LD for RV64.
        {
            "LD x12, 24(x13)", 0x0186B603, 0x300, // LD x12, 24(x13) (funct3=011 for LD)
            {{13, 0x1000}}, // x13 = 0x1000
            {true, 0b01, false, false, false, true, ALU_OP_ADD}, // result_src=Mem
            0x1000, std::nullopt, 0x18
        },

        // === Jump Instructions ===
        {
            "JALR x1, x2, 0x7FF", 0x7FF100E7, 0x400, // JALR x1, x2, 2047 (max positive I-imm)
            {{2, 0x1000}}, // x2 = 0x1000
            {true, 0b10, false, true, false, true, ALU_OP_ADD}, // result_src=PC+4, jump=true
            0x1000, std::nullopt, 0x7FF
        },
        {
            "JALR x0, x1, 0 (Jump to x1)", 0x00008067, 0x404, // JALR x0, x1, 0
            {{1, 0x2000}}, // x1 = 0x2000
            {true, 0b10, false, true, false, true, ALU_OP_ADD}, // RegWrite to x0 is suppressed by RF
            0x2000, std::nullopt, 0x0
        },

        // === Branch Instructions ===
        {
            "BNE x1, x2, +0x20 (taken)", 0x02209063, 0x500, // BNE x1,x2,+0x20. Instr for +0x20 offset and BNE (funct3=001)
            {{1, 100}, {2, 200}}, // x1 != x2
            {false, 0b00, false, false, true, false, ALU_OP_SUB},
            100, 200, 0x20
        },
        {
            "BNE x1, x2, +0x20 (not taken)", 0x02209063, 0x504, // Same instruction
            {{1, 100}, {2, 100}}, // x1 == x2
            {false, 0b00, false, false, true, false, ALU_OP_SUB},
            100, 100, 0x20
        },
        {
            "BLT x1, x2, +0x20 (taken)", 0x0220C063, 0x508, // BLT (funct3=100)
            {{1, -5}, {2, 5}},
            {false, 0b00, false, false, true, false, ALU_OP_SLT},
            uint64_t(-5), 5, 0x20
        },
        {
            "BGE x1, x2, +0x20 (taken)", 0x0220D063, 0x50C, // BGE (funct3=101)
            {{1, 5}, {2, -5}},
            {false, 0b00, false, false, true, false, ALU_OP_SLT}, // Condition is !(rs1 < rs2)
            5, uint64_t(-5), 0x20
        },
        {
            "BLTU x1, x2, +0x20 (taken)", 0x0220E063, 0x510, // BLTU (funct3=110)
            {{1, 5}, {2, 10}},
            {false, 0b00, false, false, true, false, ALU_OP_SLTU},
            5, 10, 0x20
        },
        {
            "BGEU x1, x2, +0x20 (taken)", 0x0220F063, 0x514, // BGEU (funct3=111)
            {{1, 10}, {2, 5}},
            {false, 0b00, false, false, true, false, ALU_OP_SLTU}, // Condition is !(rs1 < rs2)unsigned
            10, 5, 0x20
        },
        {
            "NOP", NOP_INSTRUCTION, 0x600,
            {},
            {true, 0b00, false, false, false, true, ALU_OP_ADD},
            0, std::nullopt, 0
        }
    };

    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;
        std::cout << "  Instruction: 0x" << std::hex << tc.instruction << std::dec << std::endl;

        reset_dut(top, tfp); // Reset before each test case application
        for(const auto& reg_pair : tc.initial_regs) {
            set_reg(top, tfp, reg_pair.first, reg_pair.second);
        }
        // One tick for register values to settle before IF/ID latches instruction
        if (!tc.initial_regs.empty()) {
             tick(top, tfp);
        }

        top->i_instr_f = tc.instruction;
        top->i_pc_f = tc.pc_val;
        top->i_pc_plus_4_f = tc.pc_val + 4;
        top->i_if_id_stall_d = 0;
        top->i_if_id_flush_d = 0;

        tick(top, tfp); // Let IF/ID latch the instruction
        tick(top, tfp); // Let Decode stage process the latched instruction

        bool current_pass = true;
        uint8_t opcode = get_opcode_cpp(tc.instruction);
        uint8_t rd  = get_rd_cpp(tc.instruction);
        uint8_t rs1 = get_rs1_cpp(tc.instruction);
        uint8_t rs2 = get_rs2_cpp(tc.instruction);

        // Check Control Signals (always relevant)
        if (top->o_reg_write_d != tc.controls.reg_write) { std::cout << "  FAIL: RegWrite_D. Exp: " << tc.controls.reg_write << ", Got: " << (int)top->o_reg_write_d << std::endl; current_pass = false; }
        if (top->o_result_src_d != tc.controls.result_src) { std::cout << "  FAIL: ResultSrc_D. Exp: " << (int)tc.controls.result_src << ", Got: " << (int)top->o_result_src_d << std::endl; current_pass = false; }
        if (top->o_mem_write_d != tc.controls.mem_write) { std::cout << "  FAIL: MemWrite_D. Exp: " << tc.controls.mem_write << ", Got: " << (int)top->o_mem_write_d << std::endl; current_pass = false; }
        if (top->o_jump_d != tc.controls.jump) { std::cout << "  FAIL: Jump_D. Exp: " << tc.controls.jump << ", Got: " << (int)top->o_jump_d << std::endl; current_pass = false; }
        if (top->o_branch_d != tc.controls.branch) { std::cout << "  FAIL: Branch_D. Exp: " << tc.controls.branch << ", Got: " << (int)top->o_branch_d << std::endl; current_pass = false; }
        if (top->o_alu_src_d != tc.controls.alu_src) { std::cout << "  FAIL: AluSrc_D. Exp: " << tc.controls.alu_src << ", Got: " << (int)top->o_alu_src_d << std::endl; current_pass = false; }
        if (top->o_alu_control_d != tc.controls.alu_control) { std::cout << "  FAIL: AluControl_D. Exp: 0b" << std::bitset<ALU_CONTROL_WIDTH>(tc.controls.alu_control) << ", Got: 0b" << std::bitset<ALU_CONTROL_WIDTH>(top->o_alu_control_d) << std::endl; current_pass = false; }

        // Check PC values (always relevant)
        if (top->o_pc_d != tc.pc_val) { std::cout << "  FAIL: PC_D. Exp: 0x" << std::hex << tc.pc_val << ", Got: 0x" << top->o_pc_d << std::dec << std::endl; current_pass = false; }
        if (top->o_pc_plus_4_d != (tc.pc_val + 4)) { std::cout << "  FAIL: PCPlus4_D. Exp: 0x" << std::hex << (tc.pc_val + 4) << ", Got: 0x" << top->o_pc_plus_4_d << std::dec << std::endl; current_pass = false; }

        // Check Register Addresses (always extracted by decode.sv)
        if (top->o_rd_addr_d != rd) { std::cout << "  FAIL: RdAddr_D. Exp: " << (int)rd << ", Got: " << (int)top->o_rd_addr_d << std::endl; current_pass = false; }
        if (top->o_rs1_addr_d != rs1) { std::cout << "  FAIL: Rs1Addr_D. Exp: " << (int)rs1 << ", Got: " << (int)top->o_rs1_addr_d << std::endl; current_pass = false; }
        if (top->o_rs2_addr_d != rs2) { std::cout << "  FAIL: Rs2Addr_D. Exp: " << (int)rs2 << ", Got: " << (int)top->o_rs2_addr_d << std::endl; current_pass = false; }


        // Check rs1_data if expected
        if (tc.expected_rs1_data.has_value()) {
            uint64_t expected_val = (rs1 == 0) ? 0 : tc.expected_rs1_data.value();
            if (top->o_rs1_data_d != expected_val) {
                std::cout << "  FAIL: Rs1Data_D. Exp: 0x" << std::hex << expected_val << ", Got: 0x" << top->o_rs1_data_d << std::dec << std::endl;
                current_pass = false;
            }
        }

        // Check rs2_data if expected
        if (tc.expected_rs2_data.has_value()) {
            uint64_t expected_val = (rs2 == 0 && opcode != OPCODE_STORE) ? 0 : tc.expected_rs2_data.value();
             // For Store, rs2 field is rs2_addr, so rs2_data is always from regfile[rs2_addr]
            if (opcode == OPCODE_STORE) { // For store, rs2_data is the value from register rs2.
                expected_val = tc.expected_rs2_data.value();
            }

            if (top->o_rs2_data_d != expected_val) {
                std::cout << "  FAIL: Rs2Data_D. Exp: 0x" << std::hex << expected_val << ", Got: 0x" << top->o_rs2_data_d << std::dec << std::endl;
                current_pass = false;
            }
        }

        // Check imm_ext if expected
        if (tc.expected_imm_ext.has_value()) {
            if (top->o_imm_ext_d != tc.expected_imm_ext.value()) {
                std::cout << "  FAIL: ImmExt_D. Exp: 0x" << std::hex << tc.expected_imm_ext.value() << ", Got: 0x" << top->o_imm_ext_d << std::dec << std::endl;
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

    std::cout << "\nDecode Stage Testbench Finished. Passed " << passed_count << "/" << test_cases.size() << " detailed test cases." << std::endl;

    if (tfp) tfp->close();
    delete top;
    return (passed_count == test_cases.size()) ? EXIT_SUCCESS : EXIT_FAILURE;
}