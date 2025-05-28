// tests/unit/pipeline_control_tb.cpp
#include "Vpipeline_control_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "common_pipeline_types_tb.h" // Вспомогательный файл с C++ структурами

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <vector>
#include <string>
#include <bitset>


// Define Forwarding codes for clarity (matching pipeline_control hazard unit logic)
const uint8_t FORWARD_NONE_CPP   = 0b00;
const uint8_t FORWARD_MEM_WB_CPP = 0b01; // From MEM/WB (RdW) -> EX
const uint8_t FORWARD_EX_MEM_CPP = 0b10; // From EX/MEM (RdM) -> EX


vluint64_t sim_time_pc_tb = 0; // Renamed to avoid conflict

void eval_pipeline_control(Vpipeline_control_tb* dut, VerilatedVcdC* tfp) {
    dut->eval();
    if (tfp) {
        tfp->dump(sim_time_pc_tb);
    }
    // sim_time_pc_tb++; // For combinational, advance time per test case
}

// Test Case Structure (Revised)
struct PCTestCase {
    std::string name;

    // Inputs (representing pipeline register contents)
    IfIdDataTb      if_id_data; // from common_pipeline_types_tb.h
    IdExDataTb      id_ex_data;
    ExMemDataTb     ex_mem_data;
    MemWbDataTb     mem_wb_data;
    bool            pc_src_from_ex;

    // Expected Outputs
    HazardControlTb exp_hazard_ctrl;
};

// Helper to initialize structures to NOP-like values
void init_test_data(IfIdDataTb& if_id, IdExDataTb& id_ex, ExMemDataTb& ex_mem, MemWbDataTb& mem_wb) {
    // Initialize to something that represents a NOP or non-interfering state
    // This should mirror NOP_IF_ID_DATA etc. from pipeline_types.svh
    // For simplicity in C++, we'll zero them out and set specific fields.

    if_id = {}; // Zero initialize
    if_id.instr = NOP_INSTRUCTION_TB; // Defined in common_pipeline_types_tb.h
    if_id.pc = 0;
    if_id.pc_plus_4 = 4;

    id_ex = {};
    id_ex.reg_write = false;
    id_ex.rd_addr = 0;
    // ... other fields for NOP_ID_EX_DATA_TB

    ex_mem = {};
    ex_mem.reg_write = false;
    ex_mem.rd_addr = 0;
    // ... other fields for NOP_EX_MEM_DATA_TB

    mem_wb = {};
    mem_wb.reg_write = false;
    mem_wb.rd_addr = 0;
    // ... other fields for NOP_MEM_WB_DATA_TB
}


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vpipeline_control_tb* top = new Vpipeline_control_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_pipeline_control.vcd");

    std::cout << "Starting Pipeline Control (Hazard Unit) Testbench (Revised)" << std::endl;

    std::vector<PCTestCase> test_cases;

    // --- Test Case 1: No Hazard ---
    {
        PCTestCase tc;
        tc.name = "No Hazard";
        init_test_data(tc.if_id_data, tc.id_ex_data, tc.ex_mem_data, tc.mem_wb_data);
        // IF/ID: some instruction, e.g., add x10, x1, x2 (rs1=1, rs2=2)
        tc.if_id_data.instr = 0x00208533; // add x10, x1, x2
        // ID/EX: some non-load instruction, e.g., add x5, x3, x4 (rd=5, rs1=3, rs2=4)
        tc.id_ex_data.rd_addr = 5; tc.id_ex_data.reg_write = true; tc.id_ex_data.result_src = RESULT_SRC_ALU_TB;
        tc.id_ex_data.rs1_addr = 3; tc.id_ex_data.rs2_addr = 4;
        // EX/MEM: add x6, ... (rd=6)
        tc.ex_mem_data.rd_addr = 6; tc.ex_mem_data.reg_write = true;
        // MEM/WB: add x7, ... (rd=7)
        tc.mem_wb_data.rd_addr = 7; tc.mem_wb_data.reg_write = true;
        tc.pc_src_from_ex = false;

        tc.exp_hazard_ctrl = {false, false, false, false, FORWARD_NONE_CPP, FORWARD_NONE_CPP};
        test_cases.push_back(tc);
    }

    // --- Test Case 2: Load-Use Hazard (rs1D depends on RdE from Load) ---
    {
        PCTestCase tc;
        tc.name = "Load-Use rs1D == RdE (LW x3; ADD xN,x3,xY)";
        init_test_data(tc.if_id_data, tc.id_ex_data, tc.ex_mem_data, tc.mem_wb_data);
        // IF/ID: instruction uses x3 as rs1. e.g. add x10, x3, x2
        tc.if_id_data.instr = (3 << 15) | (2 << 20) | (10 << 7) | 0x33; // rs1=3, rs2=2, rd=10, opcode OP
        // ID/EX: LW x3, offset(xZ)
        tc.id_ex_data.rd_addr = 3; tc.id_ex_data.reg_write = true;
        tc.id_ex_data.result_src = RESULT_SRC_MEM_TB; // Indicates Load
        tc.id_ex_data.rs1_addr = 15; // Base for LW, doesn't matter for hazard with rs1_ID
        tc.pc_src_from_ex = false;

        tc.exp_hazard_ctrl = {true, true, false, true, FORWARD_NONE_CPP, FORWARD_NONE_CPP}; // StallF, StallD, FlushE
        test_cases.push_back(tc);
    }

    // --- Test Case 3: Forwarding EX/MEM -> Rs1E ---
    // Instr in EX: add x10, x3, x4 (rs1E=3, rs2E=4)
    // Instr in MEM: add x3, ... (RdM=3)
    {
        PCTestCase tc;
        tc.name = "EX/MEM Fwd A (RdM==Rs1E)";
        init_test_data(tc.if_id_data, tc.id_ex_data, tc.ex_mem_data, tc.mem_wb_data);
        // ID/EX: add x10, x3, x4
        tc.id_ex_data.rs1_addr = 3; tc.id_ex_data.rs2_addr = 4;
        tc.id_ex_data.rd_addr = 10; tc.id_ex_data.reg_write = true; tc.id_ex_data.result_src = RESULT_SRC_ALU_TB;
        // EX/MEM: instruction writes to x3
        tc.ex_mem_data.rd_addr = 3; tc.ex_mem_data.reg_write = true;
        tc.pc_src_from_ex = false;

        tc.exp_hazard_ctrl = {false, false, false, false, FORWARD_EX_MEM_CPP, FORWARD_NONE_CPP};
        test_cases.push_back(tc);
    }

    // --- Test Case 4: Forwarding MEM/WB -> Rs1E ---
    // Instr in EX: add x10, x3, x4 (rs1E=3, rs2E=4)
    // Instr in MEM: add xY, ... (RdM != 3)
    // Instr in WB: add x3, ... (RdW = 3)
    {
        PCTestCase tc;
        tc.name = "MEM/WB Fwd A (RdW==Rs1E, no EX/MEM conflict)";
        init_test_data(tc.if_id_data, tc.id_ex_data, tc.ex_mem_data, tc.mem_wb_data);
        // ID/EX: add x10, x3, x4
        tc.id_ex_data.rs1_addr = 3; tc.id_ex_data.rs2_addr = 4;
        tc.id_ex_data.rd_addr = 10; tc.id_ex_data.reg_write = true; tc.id_ex_data.result_src = RESULT_SRC_ALU_TB;
        // EX/MEM: no conflict
        tc.ex_mem_data.rd_addr = 15; tc.ex_mem_data.reg_write = true;
        // MEM/WB: instr writes to x3
        tc.mem_wb_data.rd_addr = 3; tc.mem_wb_data.reg_write = true;
        tc.pc_src_from_ex = false;

        tc.exp_hazard_ctrl = {false, false, false, false, FORWARD_MEM_WB_CPP, FORWARD_NONE_CPP};
        test_cases.push_back(tc);
    }


    // --- Test Case 5: Branch Taken ---
    {
        PCTestCase tc;
        tc.name = "Branch Taken";
        init_test_data(tc.if_id_data, tc.id_ex_data, tc.ex_mem_data, tc.mem_wb_data);
        tc.pc_src_from_ex = true;

        tc.exp_hazard_ctrl = {false, false, true, true, FORWARD_NONE_CPP, FORWARD_NONE_CPP}; // FlushD, FlushE
        test_cases.push_back(tc);
    }

    // Add more test cases for other scenarios:
    // - Load-use for rs2D
    // - Forwarding for rs2E from EX/MEM and MEM/WB
    // - Priority of EX/MEM forwarding over MEM/WB
    // - Combinations of stall and branch

    int passed_count = 0;
    for (const auto& tc : test_cases) {
        std::cout << "\nRunning Test: " << tc.name << std::endl;

        // Set inputs using the C++ structures
        top->i_if_id_data.instr     = tc.if_id_data.instr;
        top->i_if_id_data.pc        = tc.if_id_data.pc;
        top->i_if_id_data.pc_plus_4 = tc.if_id_data.pc_plus_4;

        top->i_id_ex_data.reg_write = tc.id_ex_data.reg_write;
        top->i_id_ex_data.result_src = tc.id_ex_data.result_src;
        // ... (set all fields of i_id_ex_data from tc.id_ex_data) ...
        top->i_id_ex_data.mem_write = tc.id_ex_data.mem_write;
        top->i_id_ex_data.jump = tc.id_ex_data.jump;
        top->i_id_ex_data.branch = tc.id_ex_data.branch;
        top->i_id_ex_data.alu_src = tc.id_ex_data.alu_src;
        top->i_id_ex_data.alu_control = tc.id_ex_data.alu_control;
        top->i_id_ex_data.op_a_sel = tc.id_ex_data.op_a_sel;
        top->i_id_ex_data.pc_target_src_sel = tc.id_ex_data.pc_target_src_sel;
        top->i_id_ex_data.funct3 = tc.id_ex_data.funct3;
        top->i_id_ex_data.pc = tc.id_ex_data.pc;
        top->i_id_ex_data.pc_plus_4 = tc.id_ex_data.pc_plus_4;
        top->i_id_ex_data.rs1_data = tc.id_ex_data.rs1_data;
        top->i_id_ex_data.rs2_data = tc.id_ex_data.rs2_data;
        top->i_id_ex_data.imm_ext = tc.id_ex_data.imm_ext;
        top->i_id_ex_data.rs1_addr = tc.id_ex_data.rs1_addr;
        top->i_id_ex_data.rs2_addr = tc.id_ex_data.rs2_addr;
        top->i_id_ex_data.rd_addr = tc.id_ex_data.rd_addr;


        top->i_ex_mem_data.reg_write = tc.ex_mem_data.reg_write;
        // ... (set all fields of i_ex_mem_data from tc.ex_mem_data) ...
        top->i_ex_mem_data.result_src = tc.ex_mem_data.result_src;
        top->i_ex_mem_data.mem_write = tc.ex_mem_data.mem_write;
        top->i_ex_mem_data.funct3 = tc.ex_mem_data.funct3;
        top->i_ex_mem_data.alu_result = tc.ex_mem_data.alu_result;
        top->i_ex_mem_data.rs2_data = tc.ex_mem_data.rs2_data;
        top->i_ex_mem_data.pc_plus_4 = tc.ex_mem_data.pc_plus_4;
        top->i_ex_mem_data.rd_addr = tc.ex_mem_data.rd_addr;

        top->i_mem_wb_data.reg_write = tc.mem_wb_data.reg_write;
        // ... (set all fields of i_mem_wb_data from tc.mem_wb_data) ...
        top->i_mem_wb_data.result_src = tc.mem_wb_data.result_src;
        top->i_mem_wb_data.read_data_mem = tc.mem_wb_data.read_data_mem;
        top->i_mem_wb_data.alu_result = tc.mem_wb_data.alu_result;
        top->i_mem_wb_data.pc_plus_4 = tc.mem_wb_data.pc_plus_4;
        top->i_mem_wb_data.rd_addr = tc.mem_wb_data.rd_addr;

        top->i_pc_src_from_ex = tc.pc_src_from_ex;

        eval_pipeline_control(top, tfp);
        sim_time_pc_tb++;

        bool current_pass = true;
        // Check outputs from the o_hazard_ctrl structure
        if(top->o_hazard_ctrl.stall_f != tc.exp_hazard_ctrl.stall_f) {std::cout << "  FAIL: StallF. Exp=" << tc.exp_hazard_ctrl.stall_f << " Got=" << (int)top->o_hazard_ctrl.stall_f << std::endl; current_pass=false;}
        if(top->o_hazard_ctrl.stall_d != tc.exp_hazard_ctrl.stall_d) {std::cout << "  FAIL: StallD. Exp=" << tc.exp_hazard_ctrl.stall_d << " Got=" << (int)top->o_hazard_ctrl.stall_d << std::endl; current_pass=false;}
        if(top->o_hazard_ctrl.flush_d != tc.exp_hazard_ctrl.flush_d) {std::cout << "  FAIL: FlushD. Exp=" << tc.exp_hazard_ctrl.flush_d << " Got=" << (int)top->o_hazard_ctrl.flush_d << std::endl; current_pass=false;}
        if(top->o_hazard_ctrl.flush_e != tc.exp_hazard_ctrl.flush_e) {std::cout << "  FAIL: FlushE. Exp=" << tc.exp_hazard_ctrl.flush_e << " Got=" << (int)top->o_hazard_ctrl.flush_e << std::endl; current_pass=false;}
        if(top->o_hazard_ctrl.forward_a_e != tc.exp_hazard_ctrl.forward_a_e) {std::cout << "  FAIL: ForwardAE. Exp=0b" << std::bitset<2>(tc.exp_hazard_ctrl.forward_a_e) << " Got=0b" << std::bitset<2>(top->o_hazard_ctrl.forward_a_e) << std::endl; current_pass=false;}
        if(top->o_hazard_ctrl.forward_b_e != tc.exp_hazard_ctrl.forward_b_e) {std::cout << "  FAIL: ForwardBE. Exp=0b" << std::bitset<2>(tc.exp_hazard_ctrl.forward_b_e) << " Got=0b" << std::bitset<2>(top->o_hazard_ctrl.forward_b_e) << std::endl; current_pass=false;}

        if (current_pass) {
            std::cout << "  PASS" << std::endl;
            passed_count++;
        } else {
            std::cout << "  FAILED" << std::endl;
        }
    }

    std::cout << "\nPipeline Control Testbench Finished. Passed " << passed_count << "/" << test_cases.size() << " tests." << std::endl;

    if (tfp) tfp->close();
    delete top;
    return (passed_count == test_cases.size()) ? EXIT_SUCCESS : EXIT_FAILURE;
}