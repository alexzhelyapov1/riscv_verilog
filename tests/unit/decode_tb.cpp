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
#include <bitset>
#include <optional>

// MANUALLY DEFINED C++ CONSTANTS (mirroring .svh files)

// From common/alu_defines.svh
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

// From common/control_signals_defines.svh
enum AluASrcSelCppTb { // Renamed to avoid potential conflicts if enums are also in Verilator headers
    ALU_A_SRC_RS1_TB,
    ALU_A_SRC_PC_TB,
    ALU_A_SRC_ZERO_TB
};

enum PcTargetSrcSelCppTb {
    PC_TARGET_SRC_PC_PLUS_IMM_TB,
    PC_TARGET_SRC_ALU_JALR_TB
};

// From common/riscv_opcodes.svh
// Opcodes
const uint8_t OPCODE_LUI_CPP        = 0b0110111;
const uint8_t OPCODE_AUIPC_CPP      = 0b0010111;
const uint8_t OPCODE_JAL_CPP        = 0b1101111;
const uint8_t OPCODE_JALR_CPP       = 0b1100111;
const uint8_t OPCODE_BRANCH_CPP     = 0b1100011;
const uint8_t OPCODE_LOAD_CPP       = 0b0000011;
const uint8_t OPCODE_STORE_CPP      = 0b0100011;
const uint8_t OPCODE_OP_IMM_CPP   = 0b0010011;
const uint8_t OPCODE_OP_CPP         = 0b0110011;

// Funct3 for OP_IMM & OP (examples)
const uint8_t FUNCT3_ADDI_CPP       = 0b000;
const uint8_t FUNCT3_SLLI_CPP       = 0b001;
const uint8_t FUNCT3_SLTI_CPP       = 0b010;
const uint8_t FUNCT3_SLTIU_CPP      = 0b011;
const uint8_t FUNCT3_XORI_CPP       = 0b100;
const uint8_t FUNCT3_SRLI_SRAI_CPP  = 0b101;
const uint8_t FUNCT3_ORI_CPP        = 0b110;
const uint8_t FUNCT3_ANDI_CPP       = 0b111;
// Funct3 for BRANCH (examples)
const uint8_t FUNCT3_BEQ_CPP        = 0b000;


const uint32_t NOP_INSTRUCTION = 0x00000013; // addi x0, x0, 0

vluint64_t sim_time = 0; // Changed from sim_time_decode to avoid conflicts if other TBs use sim_time

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
    for (int i = 0; i < 5; ++i) tick(dut, tfp); // Hold reset for a few cycles
    dut->rst_n = 1;
    tick(dut, tfp); // One tick out of reset
}

void set_reg(Vdecode_tb* dut, VerilatedVcdC* tfp, uint8_t reg_addr, uint64_t data) {
    if (reg_addr == 0) return; // Cannot write to x0
    dut->i_wb_write_en = 1;
    dut->i_wb_rd_addr = reg_addr;
    dut->i_wb_rd_data = data;
    // Write occurs on posedge clk within this tick
    tick(dut, tfp);
    dut->i_wb_write_en = 0;
    // It's good practice to let signals propagate after write_en goes low,
    // though for this specific RF design, the next tick in the main loop will handle negedge read.
}

uint8_t get_opcode_cpp(uint32_t instr) { return instr & 0x7F; }
uint8_t get_rd_cpp(uint32_t instr) { return (instr >> 7) & 0x1F; }
uint8_t get_funct3_cpp(uint32_t instr) { return (instr >> 12) & 0x07; }
uint8_t get_rs1_cpp(uint32_t instr) { return (instr >> 15) & 0x1F; }
uint8_t get_rs2_cpp(uint32_t instr) { return (instr >> 20) & 0x1F; }

struct ExpectedControls {
    bool        reg_write;
    uint8_t     result_src;
    bool        mem_write;
    bool        jump;
    bool        branch;
    bool        alu_src_b; // For Operand B
    uint8_t     alu_control;
    AluASrcSelCppTb op_a_sel;
    PcTargetSrcSelCppTb pc_target_sel;
};

struct DecodeTestCase {
    std::string name;
    uint32_t    instruction;
    uint64_t    pc_val;
    std::map<uint8_t, uint64_t> initial_regs;
    ExpectedControls controls;
    std::optional<uint64_t> expected_rs1_data;
    std::optional<uint64_t> expected_rs2_data;
    std::optional<uint64_t> expected_imm_ext;
};


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vdecode_tb* top = new Vdecode_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99); // Trace 99 levels of hierarchy
    tfp->open("tb_decode.vcd");

    std::cout << "Starting Decode Stage Testbench (Comprehensive)" << std::endl;

    std::vector<DecodeTestCase> test_cases = {
        // NOP
        {
            "NOP (addi x0,x0,0)", NOP_INSTRUCTION, 0x0, {},
            {true, 0b00, false, false, false, true, ALU_OP_ADD_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            0, std::nullopt, 0 // rs1 is x0, so data is 0. rs2 not used by ADDI. imm is 0.
        },
        // R-Type
        {
            "ADD x3,x1,x2", 0x002081B3, 0x100, {{1,10},{2,20}}, // x1=10, x2=20 => x3=30
            {true, 0b00, false, false, false, false, ALU_OP_ADD_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            10, 20, std::nullopt // rs1=10, rs2=20. No imm.
        },
        {
            "SUB x4,x1,x0", 0x40008233, 0x104, {{1,50}},      // x1=50, x0=0 => x4=50
            {true, 0b00, false, false, false, false, ALU_OP_SUB_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            50, 0, std::nullopt // rs1=50, rs2 (x0) = 0. No imm.
        },
         {
            "SLL x5,x1,x2 (shamt=5)", 0x002092B3, 0x108, {{1,0x1},{2,0x5}},
            {true, 0b00, false, false, false, false, ALU_OP_SLL_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            0x1, 0x5, std::nullopt // rs1=1, rs2=5 (shamt). No imm.
        },
        // I-Type Arithmetic
        {
            "ADDI x1,x2,-10", 0xFF610093, 0x200, {{2,100}},   // x2=100, imm=-10 => x1=90
            {true, 0b00, false, false, false, true, ALU_OP_ADD_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            100, std::nullopt, 0xFFFFFFFFFFFFFFF6ULL // rs1=100. rs2 not used. imm = -10.
        },
        {
            "SLLI x8,x1,5", 0x00509413, 0x220, {{1,0x2}},    // x1=2, shamt=5 => x8=64 (0x40)
            {true, 0b00, false, false, false, true, ALU_OP_SLL_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            0x2, std::nullopt, 0x5 // rs1=2. rs2 not used for SLLI. imm_ext is shamt=5.
        },
        {
            "SRAI x10,x1,2", 0x4020D513, 0x228, {{1,0xFFFFFFFFFFFFFFFCULL}}, // x1=-4, shamt=2 => x10=-1
            {true, 0b00, false, false, false, true, ALU_OP_SRA_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            0xFFFFFFFFFFFFFFFCULL, std::nullopt, 0x2 // rs1=-4. rs2 not used for SRAI. imm_ext is shamt=2.
        },
        // U-Type
        {
            "LUI x5,0xABCD0", 0xABCD02B7, 0x300, {}, // imm=0xABCD0 => x5=0xABCD0000 (sign ext if MSB of imm is 1)
            {true, 0b00, false, false, false, true, ALU_OP_ADD_CPP, ALU_A_SRC_ZERO_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            std::nullopt, std::nullopt, 0xFFFFFFFFABCD0000ULL // rs1 not used (OpA is ZERO). rs2 not used. imm is U-type.
        },
        {
            "AUIPC x6,0x1", 0x00001317, 0x304, {},   // pc=0x304, imm=0x1 => x6=0x304 + 0x1000 = 0x1304
            {true, 0b00, false, false, false, true, ALU_OP_ADD_CPP, ALU_A_SRC_PC_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            std::nullopt, std::nullopt, 0x1000ULL // rs1 not used (OpA is PC). rs2 not used. imm is U-type.
        },
        // Load
        {
            "LW x7,12(x1)", 0x00C0A383, 0x400, {{1,0x1000}}, // x1=0x1000, offset=12. rd=x7
            {true, 0b01, false, false, false, true, ALU_OP_ADD_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            0x1000, std::nullopt, 0xC // rs1=0x1000 (base addr). rs2 not used. imm=offset.
        },
        // Store - Corrected test case as per previous discussion
        {
            "SW x7,16(x5)", 0x0110A823, 0x404, {{5,0x2000},{7,0xDEADBEEF}}, // rs1=x5 (base), rs2=x7 (data)
            {false,0b00, true, false, false, true, ALU_OP_ADD_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            0x2000, 0xDEADBEEF, 0x10 // rs1_data_d is from x5 (base), rs2_data_d is from x7 (data to store). imm=offset.
        },
        // Branch
        {
            "BEQ x1,x0,+8 (taken)", 0x00008463, 0x500, {{1,0}}, // x1=0, x0=0. offset=8. Target=0x508
            {false,0b00, false, false, true, false, ALU_OP_SUB_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            0, 0, 0x8 // rs1 (x1)=0, rs2 (x0)=0. imm=offset.
        },
        // Jumps
        {
            "JAL x1,+16", 0x010000EF, 0x600, {}, // rd=x1 (PC+4). Target=PC+16=0x610
            {true, 0b10, false, true, false, true, ALU_OP_ADD_CPP, ALU_A_SRC_PC_TB, PC_TARGET_SRC_PC_PLUS_IMM_TB},
            std::nullopt, std::nullopt, 0x10 // rs1 not used (OpA is PC). rs2 not used. imm=J-offset.
        },
        {
            "JALR x1,x2,32", 0x020100E7, 0x604, {{2,0x1000}}, // rd=x1 (PC+4). Target=(x2+32)&~1 = (0x1000+0x20)&~1 = 0x1020
            {true, 0b10, false, true, false, true, ALU_OP_ADD_CPP, ALU_A_SRC_RS1_TB, PC_TARGET_SRC_ALU_JALR_TB},
            0x1000, std::nullopt, 0x20 // rs1 (x2)=0x1000. rs2 not used. imm=I-offset.
        }
    };

    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;
        std::cout << "  Instruction: 0x" << std::hex << tc.instruction << ", PC: 0x" << tc.pc_val << std::dec << std::endl;

        reset_dut(top, tfp);

        // Initialize registers based on the test case
        for(const auto& reg_pair : tc.initial_regs) {
            set_reg(top, tfp, reg_pair.first, reg_pair.second);
        }

        // Set up inputs for the IF/ID register
        top->i_instr_f = tc.instruction;
        top->i_pc_f = tc.pc_val;
        top->i_pc_plus_4_f = tc.pc_val + 4;
        top->i_if_id_stall_d = 0;
        top->i_if_id_flush_d = 0;

        // --- Clock Cycle 1 ---
        // Posedge: IF/ID register latches i_instr_f, i_pc_f, i_pc_plus_4_f.
        //          Outputs of IF/ID (instr_id_val, pc_id_val, pc_plus_4_id_val) update.
        //          These values propagate to the Decode stage.
        //          In decode.sv, rs1_addr_instr and rs2_addr_instr update based on new instr_id_val.
        // Negedge (conceptually at the end of clk=0 period of this tick):
        //          Register file rs1_data_o/rs2_data_o are NOT yet updated with data for *this* instruction,
        //          as their read addresses (rs1_addr_i, rs2_addr_i) only just got updated.
        //          They would reflect data for addresses present *before* this instruction was latched.
        tick(top, tfp);
        // For debugging:
        // std::cout << "  After Tick 1 (IF/ID latch): " << std::endl;
        // std::cout << "    o_instr_id: 0x" << std::hex << top->o_instr_id << std::dec << std::endl;
        // std::cout << "    o_rs1_addr_d: " << (int)top->o_rs1_addr_d << ", o_rs2_addr_d: " << (int)top->o_rs2_addr_d << std::endl;

        // --- Clock Cycle 2 ---
        // Negedge (at the start of clk=0 period of this tick):
        //          Register file now performs read using rs1_addr_i and rs2_addr_i that were set
        //          by the current instruction (latched in IF/ID in the previous cycle).
        //          rs1_data_o and rs2_data_o outputs of register_file update with correct data.
        // Posedge: Decode stage's combinational logic (control_unit, immediate_generator)
        //          processes the now-stable rs1_data_o, rs2_data_o, and other inputs.
        //          All outputs of the Decode stage (o_rs1_data_d, o_control_signals, etc.) become stable.
        tick(top, tfp);
        // For debugging:
        // std::cout << "  After Tick 2 (Decode process): " << std::endl;
        // std::cout << "    o_rs1_data_d: 0x" << std::hex << top->o_rs1_data_d << std::dec << std::endl;
        // std::cout << "    o_rs2_data_d: 0x" << std::hex << top->o_rs2_data_d << std::dec << std::endl;


        // Now perform checks on the stable outputs of the Decode stage
        bool current_pass = true;
        uint8_t instr_opcode = get_opcode_cpp(tc.instruction);
        uint8_t instr_rd  = get_rd_cpp(tc.instruction);
        uint8_t instr_rs1 = get_rs1_cpp(tc.instruction);
        uint8_t instr_rs2 = get_rs2_cpp(tc.instruction);
        uint8_t instr_funct3 = get_funct3_cpp(tc.instruction);

        // Check Control Signals
        if(top->o_reg_write_d != tc.controls.reg_write) {std::cout << "  FAIL: RegWrite_D. Exp=" << tc.controls.reg_write << " Got=" << (int)top->o_reg_write_d << std::endl; current_pass=false;}
        if(top->o_result_src_d != tc.controls.result_src) {std::cout << "  FAIL: ResultSrc_D. Exp=" << (int)tc.controls.result_src << " Got=" << (int)top->o_result_src_d << std::endl; current_pass=false;}
        if(top->o_mem_write_d != tc.controls.mem_write) {std::cout << "  FAIL: MemWrite_D. Exp=" << tc.controls.mem_write << " Got=" << (int)top->o_mem_write_d << std::endl; current_pass=false;}
        if(top->o_jump_d != tc.controls.jump) {std::cout << "  FAIL: Jump_D. Exp=" << tc.controls.jump << " Got=" << (int)top->o_jump_d << std::endl; current_pass=false;}
        if(top->o_branch_d != tc.controls.branch) {std::cout << "  FAIL: Branch_D. Exp=" << tc.controls.branch << " Got=" << (int)top->o_branch_d << std::endl; current_pass=false;}
        if(top->o_alu_src_d != tc.controls.alu_src_b) {std::cout << "  FAIL: AluSrc_B_D (alu_src_d). Exp=" << tc.controls.alu_src_b << " Got=" << (int)top->o_alu_src_d << std::endl; current_pass=false;}
        if(top->o_alu_control_d != tc.controls.alu_control) {std::cout << "  FAIL: AluControl_D. Exp=0b" << std::bitset<ALU_CONTROL_WIDTH_CPP>(tc.controls.alu_control) << " Got=0b" << std::bitset<ALU_CONTROL_WIDTH_CPP>(top->o_alu_control_d) << std::endl; current_pass=false;}
        if(top->o_op_a_sel_d != static_cast<uint8_t>(tc.controls.op_a_sel)) {std::cout << "  FAIL: OpASel_D. Exp=" << (int)tc.controls.op_a_sel << " Got=" << (int)top->o_op_a_sel_d << std::endl; current_pass=false;}
        if(top->o_pc_target_src_sel_d != static_cast<uint8_t>(tc.controls.pc_target_sel)) {std::cout << "  FAIL: PcTargetSel_D. Exp=" << (int)tc.controls.pc_target_sel << " Got=" << (int)top->o_pc_target_src_sel_d << std::endl; current_pass=false;}
        if(top->o_funct3_d != instr_funct3) {std::cout << "  FAIL: Funct3_D. Exp=0b" << std::bitset<3>(instr_funct3) << " Got=0b" << std::bitset<3>(top->o_funct3_d) << std::endl; current_pass=false;}

        // Check PC values (latched from IF/ID)
        if(top->o_pc_d != tc.pc_val) {std::cout << "  FAIL: PC_D. Exp=0x" << std::hex << tc.pc_val << " Got=0x" << top->o_pc_d << std::dec << std::endl; current_pass=false;}
        if(top->o_pc_plus_4_d != (tc.pc_val + 4)) {std::cout << "  FAIL: PCPlus4_D. Exp=0x" << std::hex << (tc.pc_val + 4) << " Got=0x" << top->o_pc_plus_4_d << std::dec << std::endl; current_pass=false;}

        // Check Register Addresses (extracted from instruction)
        if(top->o_rd_addr_d != instr_rd) {std::cout << "  FAIL: RdAddr_D. Exp=" << (int)instr_rd << " Got=" << (int)top->o_rd_addr_d << std::endl; current_pass=false;}
        if(top->o_rs1_addr_d != instr_rs1) {std::cout << "  FAIL: Rs1Addr_D. Exp=" << (int)instr_rs1 << " Got=" << (int)top->o_rs1_addr_d << std::endl; current_pass=false;}
        if(top->o_rs2_addr_d != instr_rs2) {std::cout << "  FAIL: Rs2Addr_D. Exp=" << (int)instr_rs2 << " Got=" << (int)top->o_rs2_addr_d << std::endl; current_pass=false;}

        // Check rs1_data_d
        if (tc.expected_rs1_data.has_value()) {
            uint64_t expected_val_rs1 = (instr_rs1 == 0) ? 0 : tc.expected_rs1_data.value();
            if (top->o_rs1_data_d != expected_val_rs1) {
                std::cout << "  FAIL: Rs1Data_D. Exp=0x" << std::hex << expected_val_rs1 << " Got=0x" << top->o_rs1_data_d << std::dec << std::endl;
                current_pass = false;
            }
        }
        // Check rs2_data_d
        if (tc.expected_rs2_data.has_value()) {
            uint64_t expected_val_rs2 = (instr_rs2 == 0 && instr_opcode != OPCODE_STORE_CPP) ? 0 : tc.expected_rs2_data.value();
             // For STORE, rs2_data_d is the data to be stored, read from register rs2.
             // It should be tc.expected_rs2_data.value() even if rs2 is x0 (though storing x0 is unusual).
             // For non-STORE instructions, if rs2 is x0, data should be 0.
            if (instr_opcode == OPCODE_STORE_CPP) { // Ensure store takes the direct expected value
                expected_val_rs2 = tc.expected_rs2_data.value();
            }


            if (top->o_rs2_data_d != expected_val_rs2) {
                std::cout << "  FAIL: Rs2Data_D. Exp=0x" << std::hex << expected_val_rs2 << " Got=0x" << top->o_rs2_data_d << " (Instr rs2: " << (int)instr_rs2 << ")" << std::dec << std::endl;
                current_pass = false;
            }
        }
        // Check imm_ext_d
        if (tc.expected_imm_ext.has_value()) {
            if (top->o_imm_ext_d != tc.expected_imm_ext.value()) {
                std::cout << "  FAIL: ImmExt_D. Exp=0x" << std::hex << tc.expected_imm_ext.value() << " Got=0x" << top->o_imm_ext_d << std::dec << std::endl;
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

    std::cout << "\nDecode Stage Testbench Finished. Passed " << passed_count << "/" << test_cases.size() << " test cases." << std::endl;
    if (tfp) tfp->close();
    delete top;
    return (passed_count == test_cases.size()) ? EXIT_SUCCESS : EXIT_FAILURE;
}