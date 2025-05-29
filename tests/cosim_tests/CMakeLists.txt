# Файл: tests/cosim_tests/CMakeLists.txt
cmake_minimum_required(VERSION 3.10)

set(COSIM_TEST_BENCH_CPP ${CMAKE_CURRENT_SOURCE_DIR}/pipeline_cosim_tb.cpp)
find_package(Python3 COMPONENTS Interpreter REQUIRED)
set(ELF_TO_MEMH_SCRIPT ${CMAKE_SOURCE_DIR}/scripts/elf_to_memh.py) # Assumed to be in project's scripts/
set(FILTER_SIM_OUTPUT_SCRIPT ${CMAKE_SOURCE_DIR}/scripts/filter_sim_output.py) # User needs to provide this
set(COMPARE_TRACE_FILES_SCRIPT ${CMAKE_SOURCE_DIR}/scripts/compare_trace_files.py) # User needs to provide this

if(NOT EXISTS ${ELF_TO_MEMH_SCRIPT})
    message(FATAL_ERROR "Script elf_to_memh.py not found at ${ELF_TO_MEMH_SCRIPT}")
endif()
# We don't check for filter/compare scripts here, as user needs to add them.
# The build will fail later if they are missing and 'COMMAND' refers to them.

find_program(RISCV_AS NAMES riscv64-unknown-elf-as DOC "RISC-V Assembler")
find_program(RISCV_LD NAMES riscv64-unknown-elf-ld DOC "RISC-V Linker")
find_program(RISCV_OBJCOPY NAMES riscv64-unknown-elf-objcopy DOC "RISC-V Objcopy")
find_program(RISCV_READELF NAMES riscv64-unknown-elf-readelf DOC "RISC-V Readelf")

# User needs to ensure these are correctly set up for their environment
# These are placeholders for the external ISA simulator and its plugin
set(SIMULATOR_TARGET_NAME "Simulator" CACHE STRING "Name of the external ISA simulator target")
set(SIMULATOR_EXECUTABLE "" CACHE FILEPATH "Path to the external ISA simulator executable") # e.g., ${CMAKE_BINARY_DIR}/bin/Simulator
set(COSIM_PLUGIN_TARGET_NAME "cosim_plugin" CACHE STRING "Name of the co-simulation plugin target")
set(COSIM_PLUGIN_SO_FILENAME "lib${COSIM_PLUGIN_TARGET_NAME}.so" CACHE STRING "Filename of the plugin .so") # Or .dll
set(COSIM_PLUGIN_SO_PATH "" CACHE FILEPATH "Path to the co-simulation plugin .so file") # e.g., ${CMAKE_BINARY_DIR}/plugins/libcosim_plugin.so

if(NOT RISCV_AS OR NOT RISCV_LD OR NOT RISCV_OBJCOPY OR NOT RISCV_READELF)
    message(FATAL_ERROR "One or more RISC-V toolchain utilities not found.")
endif()

# List of RTL files for the pipeline, matching your integration tests
set(PIPELINE_RTL_FILES
    ${CMAKE_SOURCE_DIR}/rtl/pipeline.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/fetch.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/decode.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/execute.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/memory_stage.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/writeback_stage.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/hazard_unit.sv # Using hazard_unit.sv as per pipeline.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/alu.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/control_unit.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/data_memory.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/immediate_generator.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/instruction_memory.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/register_file.sv
)
set(RTL_INCLUDE_PATH ${CMAKE_SOURCE_DIR}/rtl) # For common includes like common/defines.svh

# Function to add a co-simulation test case
# data_mem_init_file_rel_path is optional, pass "" if not used
function(add_cosim_test test_case_name asm_file_rel_path num_cycles pc_start_hex_no_prefix data_mem_init_file_rel_path)
    set(VERILOG_MODULE_NAME "pipeline") # Top Verilog module for Verilation
    set(TEST_CASE_INPUT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
    set(OBJ_DIR ${CMAKE_CURRENT_BINARY_DIR}/obj_dir_cosim_${test_case_name})

    set(ASM_INPUT_FILE_FULL_PATH "${TEST_CASE_INPUT_PATH}/${asm_file_rel_path}")
    set(ASM_OBJECT_FILE_IN_OBJDIR "${OBJ_DIR}/${test_case_name}.o")
    set(LINKED_ELF_FILE_IN_OBJDIR "${OBJ_DIR}/${test_case_name}.elf")
    set(VERILOG_HEX_MEM_FILENAME_FOR_PARAM "${test_case_name}_instr_mem.hex") # Relative to OBJ_DIR
    set(GENERATED_HEX_MEM_FILE_FULL_PATH_IN_OBJDIR "${OBJ_DIR}/${VERILOG_HEX_MEM_FILENAME_FOR_PARAM}")

    set(VERILOG_SIDE_OUTPUT_FILE_REL_TO_OBJDIR "${test_case_name}_verilog_trace.txt")
    set(VERILOG_SIDE_OUTPUT_FILE_FULL_PATH "${OBJ_DIR}/${VERILOG_SIDE_OUTPUT_FILE_REL_TO_OBJDIR}")
    
    set(SIMULATOR_SIDE_RAW_OUTPUT_FILE "${OBJ_DIR}/${test_case_name}_simulator_raw_stdout.txt")
    # This is the file the cosim_plugin.cpp will write to, path needs to be absolute or resolvable by plugin
    set(SIMULATOR_PLUGIN_OUTPUT_FILE_FULL_PATH "${OBJ_DIR}/${test_case_name}_simulator_plugin_trace.txt") 
    # Assuming filter_sim_output.py will process SIMULATOR_PLUGIN_OUTPUT_FILE_FULL_PATH
    set(SIMULATOR_SIDE_FILTERED_OUTPUT_FILE "${OBJ_DIR}/${test_case_name}_simulator_filtered_trace.txt")


    set(VERILOG_PARAM_PC_START_ADDR "64'h${pc_start_hex_no_prefix}")
    
    set(VERILOG_PARAM_DATA_MEM_INIT_FILE "")
    set(DATA_MEM_INIT_FILE_FULL_PATH_IN_OBJDIR "")
    if(data_mem_init_file_rel_path AND NOT "${data_mem_init_file_rel_path}" STREQUAL "")
        # Assume data_mem_init_file_rel_path is like "my_data.hex", needs to be copied or found in OBJ_DIR
        # For simplicity, assume it's copied to OBJ_DIR if needed, or Verilator finds it relative to OBJ_DIR
        set(VERILOG_PARAM_DATA_MEM_INIT_FILE "${data_mem_init_file_rel_path}") # Name relative to OBJ_DIR
        # If the source is elsewhere, you'd add a copy command:
        # COMMAND ${CMAKE_COMMAND} -E copy ${TEST_CASE_INPUT_PATH}/${data_mem_init_file_rel_path} ${OBJ_DIR}/${data_mem_init_file_rel_path}
        # For now, we pass the name and assume it's available in OBJ_DIR or an absolute path is given.
        # If it's just a filename, Verilator looks in Mdir.
        set(DATA_MEM_INIT_FILE_FULL_PATH_IN_OBJDIR "${OBJ_DIR}/${data_mem_init_file_rel_path}") # For dependency tracking
    endif()


    set(ASSEMBLE_CMD ${RISCV_AS} -march=rv64i -mabi=lp64 -o ${ASM_OBJECT_FILE_IN_OBJDIR} ${ASM_INPUT_FILE_FULL_PATH})
    set(LINK_CMD ${RISCV_LD} --no-relax -Ttext=0x${pc_start_hex_no_prefix} -o ${LINKED_ELF_FILE_IN_OBJDIR} ${ASM_OBJECT_FILE_IN_OBJDIR})
    set(ELF_TO_HEX_CMD
        ${Python3_EXECUTABLE} "${ELF_TO_MEMH_SCRIPT}"
        "${LINKED_ELF_FILE_IN_OBJDIR}"
        "${GENERATED_HEX_MEM_FILE_FULL_PATH_IN_OBJDIR}"
        --objcopy "${RISCV_OBJCOPY}" --readelf "${RISCV_READELF}" --section ".text" --wordsize 4)

    set(VERILATOR_EXE_TARGET_NAME V${VERILOG_MODULE_NAME}_${test_case_name}) # Unique target name for the exe
    set(VERILATOR_GENERATED_EXE ${OBJ_DIR}/V${VERILOG_MODULE_NAME}) # Path to exe

    # Custom command to build Verilator executable and dependent files
    add_custom_command(
        OUTPUT ${VERILATOR_GENERATED_EXE} # Verilator build produces this executable
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OBJ_DIR}
        COMMAND ${ASSEMBLE_CMD}
        COMMAND ${LINK_CMD}
        COMMAND ${ELF_TO_HEX_CMD}
        # If data_mem_init_file_rel_path is provided and needs copying:
        # COMMAND ${CMAKE_COMMAND} -E copy ${TEST_CASE_INPUT_PATH}/${data_mem_init_file_rel_path} ${OBJ_DIR}/${data_mem_init_file_rel_path}
        COMMAND ${PROJECT_VERILATOR_EXECUTABLE}
                -Wall --Wno-fatal --cc --exe --build --trace
                --top-module ${VERILOG_MODULE_NAME}
                -I${RTL_INCLUDE_PATH} # To find common/*.svh
                "-GINSTR_MEM_INIT_FILE=\"${VERILOG_HEX_MEM_FILENAME_FOR_PARAM}\"" # Name relative to OBJ_DIR
                "-GPC_START_ADDR=${VERILOG_PARAM_PC_START_ADDR}"
                "-GDATA_MEM_INIT_FILE=\"${VERILOG_PARAM_DATA_MEM_INIT_FILE}\"" # Pass data mem init file
                ${PIPELINE_RTL_FILES} # All Verilog source files
                "${COSIM_TEST_BENCH_CPP}" # The C++ testbench file for Verilog side
                --Mdir "${OBJ_DIR}" # Output directory for Verilator artifacts
                -CFLAGS "-std=c++17 -Wall \
                    -DPIPELINE_COSIM_TEST_CASE_NAME_STR_RAW=${test_case_name} \
                    -DNUM_CYCLES_TO_RUN=${num_cycles} \
                    -DVERILOG_OUTPUT_FILE_PATH_STR_RAW=${VERILOG_SIDE_OUTPUT_FILE_FULL_PATH}"
        DEPENDS "${COSIM_TEST_BENCH_CPP}" "${ASM_INPUT_FILE_FULL_PATH}"
                "${ELF_TO_MEMH_SCRIPT}" ${PIPELINE_RTL_FILES}
                ${DATA_MEM_INIT_FILE_FULL_PATH_IN_OBJDIR} # Add dependency if file is used
        COMMENT "Building Verilog side for co-sim test: ${test_case_name}" VERBATIM
    )
    
    # Target to ensure Verilator executable is built
    add_custom_target(${VERILATOR_EXE_TARGET_NAME} DEPENDS ${VERILATOR_GENERATED_EXE})

    # Target to run the full co-simulation test and compare results
    set(RUN_AND_COMPARE_TARGET run_cosim_${test_case_name})
    add_custom_target(${RUN_AND_COMPARE_TARGET}
        # Step 1: Run Verilog simulation (generates ${VERILOG_SIDE_OUTPUT_FILE_FULL_PATH})
        COMMAND "${VERILATOR_GENERATED_EXE}"
        
        # Step 2: Run ISA simulator with plugin
        # The plugin will write to ${SIMULATOR_PLUGIN_OUTPUT_FILE_FULL_PATH}
        # The ISA simulator's stdout/stderr might go to ${SIMULATOR_SIDE_RAW_OUTPUT_FILE}
        COMMAND ${CMAKE_COMMAND} -E env COSIM_PLUGIN_OUTPUT_FILE=${SIMULATOR_PLUGIN_OUTPUT_FILE_FULL_PATH}
                "${SIMULATOR_EXECUTABLE}" "${LINKED_ELF_FILE_IN_OBJDIR}" "${COSIM_PLUGIN_SO_PATH}"
                #> ${SIMULATOR_SIDE_RAW_OUTPUT_FILE} 2>&1 
                # Stderr/stdout redirection might be useful for ISA sim debugging, but not for trace itself if plugin writes directly
        
        # Step 3: Filter the ISA simulator's plugin output (if necessary)
        # Assuming filter_sim_output.py takes raw plugin output and produces a clean trace
        COMMAND ${Python3_EXECUTABLE} "${FILTER_SIM_OUTPUT_SCRIPT}"
                "${SIMULATOR_PLUGIN_OUTPUT_FILE_FULL_PATH}" # Input: raw trace from plugin
                "${SIMULATOR_SIDE_FILTERED_OUTPUT_FILE}"    # Output: filtered trace
                # Add other params for filter_sim_output.py if needed (e.g. --skip_header)

        # Step 4: Compare the Verilog trace with the filtered ISA simulator trace
        COMMAND ${Python3_EXECUTABLE} "${COMPARE_TRACE_FILES_SCRIPT}"
                "${VERILOG_SIDE_OUTPUT_FILE_FULL_PATH}"
                "${SIMULATOR_SIDE_FILTERED_OUTPUT_FILE}"

        DEPENDS ${VERILATOR_EXE_TARGET_NAME} # Depends on the Verilator exe being built
                # SIMULATOR_TARGET_NAME COSIM_PLUGIN_TARGET_NAME # User must ensure these are built
                "${FILTER_SIM_OUTPUT_SCRIPT}" "${COMPARE_TRACE_FILES_SCRIPT}" # Scripts must exist
                # Add dependency on SIMULATOR_EXECUTABLE and COSIM_PLUGIN_SO_PATH if they are CMake targets/outputs
                # For now, assume they exist or are handled by user.
        WORKING_DIRECTORY ${OBJ_DIR} # Important for relative paths (e.g., for Verilator finding .hex)
        COMMENT "Running co-simulation and comparing for: ${test_case_name}"
        VERBATIM
    )

    # Logic to add this test to a global 'run_all_cosim_tests' target
    if(NOT TARGET run_all_cosim_tests)
        add_custom_target(run_all_cosim_tests COMMENT "Running all co-simulation tests")
    endif()
    add_dependencies(run_all_cosim_tests ${RUN_AND_COMPARE_TARGET})

    # If you have a top-level 'tests_full' or similar target
    if(TARGET tests_full)
         add_dependencies(tests_full run_all_cosim_tests)
    endif()

    message(STATUS "Configured CO-SIMULATION test case: ${test_case_name}")
    message(STATUS "  ASM file: ${ASM_INPUT_FILE_FULL_PATH}")
    message(STATUS "  Verilog trace will be at: ${VERILOG_SIDE_OUTPUT_FILE_FULL_PATH}")
    message(STATUS "  Simulator plugin trace will be at: ${SIMULATOR_PLUGIN_OUTPUT_FILE_FULL_PATH}")
    if(VERILOG_PARAM_DATA_MEM_INIT_FILE AND NOT "${VERILOG_PARAM_DATA_MEM_INIT_FILE}" STREQUAL "")
        message(STATUS "  Data memory init file: ${VERILOG_PARAM_DATA_MEM_INIT_FILE}")
    endif()
endfunction()

# Example calls to the function:
# add_cosim_test(test_case_name asm_file num_cycles pc_start_hex data_mem_init_file_name_or_empty)
add_cosim_test(addi_basic_cosim "addi_basic_instr.s" 20 "10000" "")
add_cosim_test(mem_basic_cosim "mem.s" 15 "10000" "") # Assuming mem.s might use data memory, pass "" if no specific init file
add_cosim_test(complex_cosim "complex.s" 60 "10000" "")
add_cosim_test(complex_cosim_1 "complex_1.s" 35 "10000" "")

# You might need to adjust NUM_CYCLES_TO_RUN for each test based on its length and pipeline depth.
# The original CMakeLists had different cycle counts.
# addi_basic_instr.s in cosim_tests has an sret, which might take more cycles to fully retire or if the
# ISA simulator runs until sret. The integration test version doesn't have sret.
# Adjust cycles as needed.