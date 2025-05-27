// tests/unit/immediate_generator_tb.cpp
#include "Vimmediate_generator_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h" // Optional for VCD

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>

// C++ enum equivalent for immediate_type_e
enum ImmediateTypeCpp {
    IMM_TYPE_NONE_CPP,
    IMM_TYPE_I_CPP,
    IMM_TYPE_S_CPP,
    IMM_TYPE_B_CPP,
    IMM_TYPE_U_CPP,
    IMM_TYPE_J_CPP,
    IMM_TYPE_ISHIFT_CPP
};

vluint64_t sim_time_immgen = 0;

void eval_immgen(Vimmediate_generator_tb* dut, VerilatedVcdC* tfp) {
    dut->eval();
    if (tfp) {
        tfp->dump(sim_time_immgen);
    }
    // sim_time_immgen++; // For combinational, time can be advanced per test case
}

// Helper function to construct instruction bits for testing immediates
// This is crucial for precisely setting immediate fields.
// Fields: opcode(6:0), rd(11:7), funct3(14:12), rs1(19:15), rs2(24:20), imm_generic(31:20 or other)
// For simplicity, we'll focus on setting the immediate bits directly within a pseudo-instruction.
// More complex: functions to generate full valid instructions for each type.

// For I-type: imm[11:0] is in instr[31:20]
uint32_t instr_i_type(uint16_t imm12) {
    return (uint32_t(imm12 & 0xFFF) << 20);
}

// For S-type: imm[11:5] in instr[31:25], imm[4:0] in instr[11:7]
uint32_t instr_s_type(uint16_t imm12) {
    return ((uint32_t(imm12 >> 5) & 0x7F) << 25) | ((uint32_t(imm12 & 0x1F)) << 7);
}

// For B-type: imm[12|10:5|4:1|11] (13-bit, LSB is implicit 0)
// imm_val is the actual signed offset (e.g., +20, -8).
// The immediate encoded in instruction is imm_val >> 1.
uint32_t instr_b_type(int16_t signed_offset_val) {
    uint16_t imm13_shifted = uint16_t(signed_offset_val >> 1); // Value to encode
    uint32_t instr = 0;
    instr |= ((uint32_t(imm13_shifted >> 11) & 0x1) << 31); // imm[12]
    instr |= ((uint32_t(imm13_shifted >> 4) & 0x3F) << 25); // imm[10:5]
    instr |= ((uint32_t(imm13_shifted >> 0) & 0xF) << 8);   // imm[4:1]
    instr |= ((uint32_t(imm13_shifted >> 10) & 0x1) << 7);  // imm[11]
    return instr;
}

// For U-type: imm[31:12] in instr[31:12]
uint32_t instr_u_type(uint32_t imm20) { // imm20 is the raw 20-bit value for bits 31:12
    return (uint32_t(imm20 & 0xFFFFF) << 12);
}

// For J-type: imm[20|10:1|11|19:12] (21-bit, LSB is implicit 0)
// imm_val is the actual signed offset.
uint32_t instr_j_type(int32_t signed_offset_val) {
    uint32_t imm21_shifted = uint32_t(signed_offset_val >> 1); // Value to encode
    uint32_t instr = 0;
    instr |= ((uint32_t(imm21_shifted >> 19) & 0x1) << 31);  // imm[20]
    instr |= ((uint32_t(imm21_shifted >> 0) & 0x3FF) << 21); // imm[10:1]
    instr |= ((uint32_t(imm21_shifted >> 10) & 0x1) << 20);  // imm[11]
    instr |= ((uint32_t(imm21_shifted >> 11) & 0xFF) << 12); // imm[19:12]
    return instr;
}

// For ISHIFT-type (RV64): shamt[5:0] in instr[25:20]
// Other bits (e.g. instr[31:26] for SRAI) are part of opcode/funct7
uint32_t instr_ishift_type(uint8_t shamt6, uint8_t fixed_upper_bits = 0) {
    // fixed_upper_bits would be 0b010000 for SRAI's instr[31:26]
    // For SLLI/SRLI it's 0b000000
    return (uint32_t(fixed_upper_bits & 0x3F) << 26) | (uint32_t(shamt6 & 0x3F) << 20);
}


struct ImmGenTestCase {
    std::string name;
    uint32_t    instruction_bits; // The full instruction word
    ImmediateTypeCpp imm_type;
    uint64_t    expected_imm_ext;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vimmediate_generator_tb* top = new Vimmediate_generator_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_immediate_generator.vcd");

    std::cout << "Starting Immediate Generator Testbench" << std::endl;

    std::vector<ImmGenTestCase> test_cases = {
        // I-Type
        {"I-Type positive", instr_i_type(100), IMM_TYPE_I_CPP, 100},
        {"I-Type negative", instr_i_type(0xFFF), IMM_TYPE_I_CPP, 0xFFFFFFFFFFFFFFFFULL}, // -1 (12-bit 0xFFF)
        {"I-Type max pos", instr_i_type(0x7FF), IMM_TYPE_I_CPP, 0x7FF}, // 2047
        {"I-Type min neg", instr_i_type(0x800), IMM_TYPE_I_CPP, 0xFFFFFFFFFFFFF800ULL}, // -2048
        {"I-Type zero", instr_i_type(0), IMM_TYPE_I_CPP, 0},

        // S-Type
        {"S-Type positive", instr_s_type(200), IMM_TYPE_S_CPP, 200},
        {"S-Type negative", instr_s_type(0xF00), IMM_TYPE_S_CPP, 0xFFFFFFFFFFFFFF00ULL}, // -256 (0xF00 is 1111 0000 0000, sign bit is instr[31])
        {"S-Type max pos", instr_s_type(0x7FF), IMM_TYPE_S_CPP, 0x7FF},
        {"S-Type min neg", instr_s_type(0x800), IMM_TYPE_S_CPP, 0xFFFFFFFFFFFFF800ULL},

        // B-Type
        {"B-Type positive offset +20", instr_b_type(20), IMM_TYPE_B_CPP, 20},
        {"B-Type negative offset -20", instr_b_type(-20), IMM_TYPE_B_CPP, (uint64_t)-20},
        {"B-Type max pos offset (4094)", instr_b_type(4094), IMM_TYPE_B_CPP, 4094}, // 2^12 - 2
        {"B-Type min neg offset (-4096)", instr_b_type(-4096), IMM_TYPE_B_CPP, (uint64_t)-4096},

        // U-Type (imm is shifted left by 12 bits internally by LUI/AUIPC, generator outputs imm_val for bits 31:12, zero-extended lower)
        // The generator itself outputs {instr[31:12], 12'h0}, sign-extended from bit 31 of this 32-bit value.
        {"U-Type 0xABCD0", instr_u_type(0xABCD0), IMM_TYPE_U_CPP, 0xFFFFFFFFABCD0000ULL}, // A=1010, so MSB is 1
        {"U-Type 0x12345", instr_u_type(0x12345), IMM_TYPE_U_CPP, 0x0000000012345000ULL}, // MSB is 0
        {"U-Type 0x0", instr_u_type(0x0), IMM_TYPE_U_CPP, 0x0},
        {"U-Type max (0xFFFFF)", instr_u_type(0xFFFFF), IMM_TYPE_U_CPP, 0xFFFFFFFFFFFFF000ULL},

        // J-Type
        {"J-Type positive offset +2046", instr_j_type(2046), IMM_TYPE_J_CPP, 2046}, // Max positive for 11 bit field for example (2^11-2)
                                                                                   // J-imm is 21 bits, so 2^20 max offset
        {"J-Type negative offset -2048", instr_j_type(-2048), IMM_TYPE_J_CPP, (uint64_t)-2048},
        {"J-Type max pos offset (2^19-2)", instr_j_type((1<<19)-2), IMM_TYPE_J_CPP, (1ULL<<19)-2},
        {"J-Type min neg offset (-2^19)", instr_j_type(-(1<<19)), IMM_TYPE_J_CPP, (uint64_t)(-(1LL<<19))},

        // ISHIFT-Type (RV64 shamt is 6 bits, instr[25:20])
        {"ISHIFT shamt=1", instr_ishift_type(1), IMM_TYPE_ISHIFT_CPP, 1},
        {"ISHIFT shamt=31", instr_ishift_type(31), IMM_TYPE_ISHIFT_CPP, 31},
        {"ISHIFT shamt=63", instr_ishift_type(63), IMM_TYPE_ISHIFT_CPP, 63},
        {"ISHIFT shamt=0", instr_ishift_type(0), IMM_TYPE_ISHIFT_CPP, 0},
        {"ISHIFT (SRAI fixed bits)", instr_ishift_type(5, 0b010000), IMM_TYPE_ISHIFT_CPP, 5}, // Check shamt extraction part

        // IMM_TYPE_NONE
        {"None Type", 0, IMM_TYPE_NONE_CPP, 0},
    };

    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;
        std::cout << "  Instruction Bits: 0x" << std::hex << tc.instruction_bits
                  << ", Type: " << (int)tc.imm_type << std::dec << std::endl;

        top->i_instr = tc.instruction_bits;
        top->i_imm_type_sel = static_cast<uint8_t>(tc.imm_type); // Cast enum to uint8_t for Verilator port

        eval_immgen(top, tfp);
        sim_time_immgen++; // Increment time for VCD for each test case

        bool current_pass = true;
        if (top->o_imm_ext != tc.expected_imm_ext) {
            std::cout << "  FAIL: Immediate Mismatch." << std::endl;
            std::cout << "    Expected: 0x" << std::hex << tc.expected_imm_ext << std::dec << std::endl;
            std::cout << "    Got:      0x" << std::hex << top->o_imm_ext << std::dec << std::endl;
            current_pass = false;
        }

        if (current_pass) {
            std::cout << "  PASS" << std::endl;
            passed_count++;
        } else {
            std::cout << "  FAILED" << std::endl;
        }
    }

    std::cout << "\nImmediate Generator Testbench Finished. Passed " << passed_count << "/" << test_cases.size() << " tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    return (passed_count == test_cases.size()) ? EXIT_SUCCESS : EXIT_FAILURE;
}