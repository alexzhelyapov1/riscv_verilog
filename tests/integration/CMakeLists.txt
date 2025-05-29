cmake_minimum_required(VERSION 3.10)

set(PIPELINE_TEST_BENCH_CPP ${CMAKE_CURRENT_SOURCE_DIR}/pipeline_tb.cpp)
find_package(Python3 COMPONENTS Interpreter REQUIRED)
set(ELF_TO_MEMH_SCRIPT ${CMAKE_SOURCE_DIR}/scripts/elf_to_memh.py)
if(NOT EXISTS ${ELF_TO_MEMH_SCRIPT})
    message(FATAL_ERROR "Script elf_to_memh.py not found at ${ELF_TO_MEMH_SCRIPT}")
endif()

find_program(RISCV_AS NAMES riscv64-unknown-elf-as DOC "RISC-V Assembler")
find_program(RISCV_LD NAMES riscv64-unknown-elf-ld DOC "RISC-V Linker")
find_program(RISCV_OBJCOPY NAMES riscv64-unknown-elf-objcopy DOC "RISC-V Objcopy")
find_program(RISCV_READELF NAMES riscv64-unknown-elf-readelf DOC "RISC-V Readelf")

if(NOT RISCV_AS OR NOT RISCV_LD OR NOT RISCV_OBJCOPY OR NOT RISCV_READELF)
    message(FATAL_ERROR "One or more RISC-V toolchain utilities not found.")
endif()

function(add_pipeline_test test_case_name asm_file_rel_path expected_wd3_file_rel_path num_cycles pc_start_hex_no_prefix)
    set(VERILOG_MODULE_NAME "pipeline")
    set(PIPELINE_RTL_FILES
        ${CMAKE_SOURCE_DIR}/rtl/pipeline.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/fetch.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/decode.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/execute.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/memory_stage.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/writeback_stage.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/hazard_unit.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/alu.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/control_unit.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/data_memory.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/immediate_generator.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/instruction_memory.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/register_file.sv

    )
    set(RTL_INCLUDE_PATH ${CMAKE_SOURCE_DIR}/rtl)
    set(TEST_CASE_INPUT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
    set(OBJ_DIR ${CMAKE_CURRENT_BINARY_DIR}/obj_dir_pipeline_${test_case_name})
    set(VERILATOR_GENERATED_EXE ${OBJ_DIR}/V${VERILOG_MODULE_NAME})
    set(ASM_INPUT_FILE_FULL_PATH "${TEST_CASE_INPUT_PATH}/${asm_file_rel_path}")
    set(ASM_OBJECT_FILE_IN_OBJDIR "${OBJ_DIR}/${test_case_name}.o")
    set(LINKED_ELF_FILE_IN_OBJDIR "${OBJ_DIR}/${test_case_name}.elf")
    set(VERILOG_HEX_MEM_FILENAME_FOR_PARAM "${test_case_name}_instr_mem.hex")
    set(GENERATED_HEX_MEM_FILE_FULL_PATH_IN_OBJDIR "${OBJ_DIR}/${VERILOG_HEX_MEM_FILENAME_FOR_PARAM}")
    set(VERILOG_PARAM_PC_START_ADDR "64'h${pc_start_hex_no_prefix}")
    set(EXPECTED_WD3_FILE_FULL_PATH "${TEST_CASE_INPUT_PATH}/${expected_wd3_file_rel_path}")
    set(VERILOG_PARAM_DATA_MEM_INIT_FILE "")
    set(BUILD_TARGET_NAME ${test_case_name}_build_verilated_pipeline)
    add_custom_target(${BUILD_TARGET_NAME} ALL
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OBJ_DIR}
        COMMAND ${RISCV_AS} -march=rv64i -mabi=lp64 -o ${ASM_OBJECT_FILE_IN_OBJDIR} ${ASM_INPUT_FILE_FULL_PATH}
        COMMAND ${RISCV_LD} --no-relax -Ttext=0x${pc_start_hex_no_prefix} -o ${LINKED_ELF_FILE_IN_OBJDIR} ${ASM_OBJECT_FILE_IN_OBJDIR}
        COMMAND ${Python3_EXECUTABLE} "${ELF_TO_MEMH_SCRIPT}"
                "${LINKED_ELF_FILE_IN_OBJDIR}"
                "${GENERATED_HEX_MEM_FILE_FULL_PATH_IN_OBJDIR}"
                --objcopy "${RISCV_OBJCOPY}" --readelf "${RISCV_READELF}" --section ".text" --wordsize 4
        COMMAND ${PROJECT_VERILATOR_EXECUTABLE}
                -Wall --Wno-fatal --cc --exe --build --trace
                --top-module ${VERILOG_MODULE_NAME}
                -I${RTL_INCLUDE_PATH}
                "-GINSTR_MEM_INIT_FILE=\"${VERILOG_HEX_MEM_FILENAME_FOR_PARAM}\""
                "-GPC_START_ADDR=${VERILOG_PARAM_PC_START_ADDR}"
                "-GDATA_MEM_INIT_FILE=\"${VERILOG_PARAM_DATA_MEM_INIT_FILE}\""
                ${PIPELINE_RTL_FILES}
                "${PIPELINE_TEST_BENCH_CPP}"
                --Mdir "${OBJ_DIR}"
                -CFLAGS "-std=c++17 -Wall \
                    -DPIPELINE_TEST_CASE_NAME_STR_RAW=${test_case_name} \
                    -DEXPECTED_WD3_FILE_PATH_STR_RAW=${EXPECTED_WD3_FILE_FULL_PATH} \
                    -DNUM_CYCLES_TO_RUN=${num_cycles}"
        DEPENDS "${PIPELINE_TEST_BENCH_CPP}" "${ASM_INPUT_FILE_FULL_PATH}"
                "${EXPECTED_WD3_FILE_FULL_PATH}" "${ELF_TO_MEMH_SCRIPT}"
                ${PIPELINE_RTL_FILES}
        COMMENT "Building pipeline for test case: ${test_case_name}"
        VERBATIM
    )

    set(RUN_TARGET_NAME run_${test_case_name}_pipeline_test)
    add_custom_target(${RUN_TARGET_NAME}
        COMMAND "${VERILATOR_GENERATED_EXE}"
        DEPENDS ${BUILD_TARGET_NAME}
        WORKING_DIRECTORY ${OBJ_DIR}
        COMMENT "Running pipeline test case: ${test_case_name}"
        VERBATIM
    )

    if(NOT TARGET run_all_pipeline_tests)
        add_custom_target(run_all_pipeline_tests COMMENT "Running all pipeline integration tests")
    endif()
    add_dependencies(run_all_pipeline_tests ${RUN_TARGET_NAME})

    if(TARGET tests_full)
         add_dependencies(tests_full run_all_pipeline_tests)
    endif()

    message(STATUS "Configured pipeline test case: ${test_case_name}")
    message(STATUS "  ASM file: ${ASM_INPUT_FILE_FULL_PATH}")
    message(STATUS "  Expected output file: ${EXPECTED_WD3_FILE_FULL_PATH}")
    message(STATUS "  Generated instruction hex file will be at: ${GENERATED_HEX_MEM_FILE_FULL_PATH_IN_OBJDIR}")
endfunction()


add_pipeline_test(addi_basic_asm "addi_basic_instr.s" "addi_basic_expected.txt" 12 "10000")
add_pipeline_test(jump_basic_asm "jump.s" "jump_expected.txt" 17 "10000")
add_pipeline_test(beq_basic_asm "beq.s" "beq_expected.txt" 22 "10000")
add_pipeline_test(mem_basic_asm "mem.s" "mem_expected.txt" 12 "10000")
add_pipeline_test(complex_asm "complex.s" "complex_expected.txt" 55 "10000")
