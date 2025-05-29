
#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#include "hart.h"

std::ofstream cosim_plugin_output_file;
bool cosim_plugin_file_opened = false;

void initialize_plugin_output(const std::string& filename) {
    if (!cosim_plugin_file_opened) {
        const char* out_file_env = std::getenv("COSIM_PLUGIN_OUTPUT_FILE");
        std::string actual_filename = filename;

        if (out_file_env) {
            actual_filename = std::string(out_file_env);
        } else {
            std::cerr << "PLUGIN WARNING: COSIM_PLUGIN_OUTPUT_FILE env var not set. Using default: " << actual_filename << std::endl;
        }

        cosim_plugin_output_file.open(actual_filename, std::ios::out | std::ios::trunc);
        if (cosim_plugin_output_file.is_open()) {
            cosim_plugin_file_opened = true;
            std::cout << "PLUGIN: Output file opened: " << actual_filename << std::endl;
        } else {
            std::cerr << "PLUGIN ERROR: Could not open output file: " << actual_filename << std::endl;
        }
    }
}


extern "C" {
    void setReg(Machine::Hart *hart, Machine::RegId *reg_id_ptr, Machine::Instr *instr) {
        if (!cosim_plugin_file_opened) {
             const char* out_file_env = std::getenv("COSIM_PLUGIN_OUTPUT_FILE");
             if (out_file_env) {
                cosim_plugin_output_file.open(out_file_env, std::ios::out | std::ios::app);
                if (cosim_plugin_output_file.is_open()) {
                    cosim_plugin_file_opened = true;
                } else {
                    std::cerr << "PLUGIN ERROR: Could not open output file: " << out_file_env << std::endl;
                }
             } else {
                 std::cerr << "PLUGIN ERROR: COSIM_PLUGIN_OUTPUT_FILE env var not set in setReg." << std::endl;
                 return;
             }
        }
        if (cosim_plugin_file_opened && reg_id_ptr != nullptr) {
            Machine::RegId reg = *reg_id_ptr;
            if (reg != 0) {
                Machine::RegValue val = hart->getReg(reg);
                cosim_plugin_output_file << std::hex << std::setw(16) << std::setfill('0') << val << std::endl;
            }
        }
    }
}