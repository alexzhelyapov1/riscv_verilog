# tests/integration/CMakeLists.txt
cmake_minimum_required(VERSION 3.16)

# Файл C++ тестбенча для конвейера (будет один для всех интеграционных тестов конвейера)
set(PIPELINE_TB_CPP_FILE ${CMAKE_CURRENT_SOURCE_DIR}/pipeline_tb.cpp)

# Проверка наличия скрипта конвертации
set(ELF_TO_MEMH_SCRIPT ${CMAKE_SOURCE_DIR}/scripts/elf_to_memh.py)
if(NOT EXISTS ${ELF_TO_MEMH_SCRIPT})
    message(FATAL_ERROR "Script elf_to_memh.py not found at ${ELF_TO_MEMH_SCRIPT}")
endif()

message(STATUS ${RISCV_AS})
message(STATUS ${RISCV_LD})
message(STATUS ${RISCV_OBJCOPY})
message(STATUS ${RISCV_READELF})

# Проверка наличия утилит тулчейна (уже должны быть найдены в корневом CMakeLists.txt)
if(NOT RISCV_AS OR NOT RISCV_LD OR NOT RISCV_OBJCOPY OR NOT RISCV_READELF)
    message(FATAL_ERROR "RISC-V toolchain utilities (AS, LD, OBJCOPY, READELF) not found by root CMake. Ensure they are in PATH or configure them.")
endif()

# --- Функция для добавления интеграционного теста конвейера ---
function(add_pipeline_integration_test test_name asm_file_rel expected_rf_file_rel num_cycles pc_start_hex)
    set(VERILOG_TOP_MODULE "pipeline") # Наш основной модуль конвейера

    # Исходные RTL файлы для всего конвейера
    set(PIPELINE_RTL_FILES
        ${CMAKE_SOURCE_DIR}/rtl/pipeline.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/fetch.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/decode.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/execute.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/memory_stage.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/writeback_stage.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/pipeline_control.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/alu.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/control_unit.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/data_memory.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/immediate_generator.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/instruction_memory.sv
        ${CMAKE_SOURCE_DIR}/rtl/core/register_file.sv
    )
    set(RTL_INCLUDE_PATH ${CMAKE_SOURCE_DIR}/rtl) # Для `include "common/..."

    # Пути и имена файлов для конкретного теста
    set(TEST_CASE_DIR ${CMAKE_CURRENT_SOURCE_DIR}) # Где лежат .s и .txt файлы
    set(OBJ_DIR ${CMAKE_CURRENT_BINARY_DIR}/obj_dir_pipeline_${test_name})
    set(VERILATOR_EXECUTABLE ${OBJ_DIR}/V${VERILOG_TOP_MODULE})

    set(ASM_FILE_FULL_PATH "${TEST_CASE_DIR}/${asm_file_rel}")
    set(ASM_OBJECT_FILE "${OBJ_DIR}/${test_name}.o")
    set(LINKED_ELF_FILE "${OBJ_DIR}/${test_name}.elf")
    set(HEX_MEM_FILENAME_PARAM_VALUE "${test_name}_instr.hex") # Это будет передано в Verilog
    set(GENERATED_HEX_MEM_FILE_FULL_PATH "${OBJ_DIR}/${HEX_MEM_FILENAME_PARAM_VALUE}")
    set(EXPECTED_RF_FILE_FULL_PATH "${TEST_CASE_DIR}/${expected_rf_file_rel}")

    # Verilog параметры (значения для -G...)
    set(VERILOG_PARAM_INSTR_MEM_FILE_DEF "-GINSTR_MEM_INIT_FILE=\"${HEX_MEM_FILENAME_PARAM_VALUE}\"") # Важно: кавычки для строки!
    set(VERILOG_PARAM_PC_START_ADDR_DEF "-GPC_START_ADDR=64'h${pc_start_hex}")
    # DATA_MEM_INIT_FILE пока не используем для простых тестов, но можно добавить
    # set(VERILOG_PARAM_DATA_MEM_FILE_DEF "-GDATA_MEM_INIT_FILE=\"some_data.hex\"")


    # C++ defines (для -D...)
    set(FINAL_CXX_FLAGS "${CMAKE_CXX_FLAGS}") # Начальные флаги из CMake
    list(APPEND FINAL_CXX_FLAGS "-DPIPELINE_TEST_NAME_STR_RAW=${test_name}")
    list(APPEND FINAL_CXX_FLAGS "-DEXPECTED_RF_FILE_PATH_STR_RAW=${EXPECTED_RF_FILE_FULL_PATH}")
    list(APPEND FINAL_CXX_FLAGS "-DNUM_CYCLES_TO_RUN=${num_cycles}")
    string(REPLACE ";" " " FINAL_CXX_FLAGS_STR "${FINAL_CXX_FLAGS}") # Преобразовать список в строку

    set(BUILD_TARGET_NAME build_pipeline_test_${test_name})
    add_custom_target(${BUILD_TARGET_NAME} ALL
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OBJ_DIR}
        COMMAND ${RISCV_AS} -march=rv64i -mabi=lp64 -o ${ASM_OBJECT_FILE} ${ASM_FILE_FULL_PATH}
            COMMENT "Assembling ${asm_file_rel}"
        COMMAND ${RISCV_LD} --no-relax -Ttext=0x${pc_start_hex} -o ${LINKED_ELF_FILE} ${ASM_OBJECT_FILE}
            COMMENT "Linking ${test_name}.o to ${test_name}.elf"
        COMMAND ${Python3_EXECUTABLE} "${ELF_TO_MEMH_SCRIPT}"
                "${LINKED_ELF_FILE}"
                "${GENERATED_HEX_MEM_FILE_FULL_PATH}"
                --objcopy "${RISCV_OBJCOPY}" --readelf "${RISCV_READELF}" --section ".text" --wordsize 4
            COMMENT "Converting ${test_name}.elf to ${HEX_MEM_FILENAME_PARAM_VALUE}"
        COMMAND ${PROJECT_VERILATOR_EXECUTABLE}
                -Wall --Wno-fatal --cc --exe --build --trace
                --top-module ${VERILOG_TOP_MODULE}
                -I${RTL_INCLUDE_PATH}
                ${VERILOG_PARAM_INSTR_MEM_FILE_DEF}
                ${VERILOG_PARAM_PC_START_ADDR_DEF}
                ${PIPELINE_RTL_FILES}
                "${PIPELINE_TB_CPP_FILE}"
                --Mdir "${OBJ_DIR}"
                -CFLAGS "${FINAL_CXX_FLAGS_STR}" # Передаем объединенную строку флагов
        DEPENDS ${PIPELINE_TB_CPP_FILE} ${ASM_FILE_FULL_PATH} ${EXPECTED_RF_FILE_FULL_PATH} ${ELF_TO_MEMH_SCRIPT} ${PIPELINE_RTL_FILES}
        COMMENT "Verilating and Building pipeline for test: ${test_name}"
        VERBATIM
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )

    # Цель для запуска теста
    set(RUN_TARGET_NAME run_pipeline_test_${test_name})
    add_test(NAME ${test_name}_pipeline_integration COMMAND "${VERILATOR_EXECUTABLE}")
    set_tests_properties(${test_name}_pipeline_integration PROPERTIES
        WORKING_DIRECTORY ${OBJ_DIR} 
        DEPENDS ${BUILD_TARGET_NAME}
    )
    add_custom_target(${RUN_TARGET_NAME}
        COMMAND "${VERILATOR_EXECUTABLE}"
        DEPENDS ${BUILD_TARGET_NAME}
        WORKING_DIRECTORY ${OBJ_DIR}
        COMMENT "Running pipeline test: ${test_name}"
        VERBATIM
    )

    if(TARGET run_all_integration_tests)
        add_dependencies(run_all_integration_tests ${RUN_TARGET_NAME})
    endif()

    message(STATUS "Configured pipeline integration test: ${test_name}")
endfunction()

# Общая цель для запуска всех интеграционных тестов (можно будет добавить в CTest)
add_custom_target(run_all_integration_tests)
add_dependencies(tests_full run_all_integration_tests)

# --- Определение конкретных тестов ---
# add_pipeline_integration_test(<test_name> <asm_file> <expected_file> <num_cycles> <pc_start_hex_no_0x>)
add_pipeline_integration_test(simple_addi "simple_addi.s" "simple_addi_expected_rf.txt" 15 "0")
# Добавьте другие тесты здесь...
# add_pipeline_integration_test(data_hazard_test "data_hazard.s" "data_hazard_expected.txt" 20 "100")