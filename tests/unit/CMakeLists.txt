set(RTL_INCLUDE_PATH ${CMAKE_SOURCE_DIR}/rtl)

function(add_verilator_test module_name)
    set(OBJ_DIR ${CMAKE_CURRENT_BINARY_DIR}/obj_dir_${module_name})
    set(CPP_TESTBENCH_FILE ${CMAKE_CURRENT_SOURCE_DIR}/${module_name}.cpp)

    set(RTL_SOURCES "")
    foreach(rtl_file ${ARGN})
        list(APPEND RTL_SOURCES "${rtl_file}")
    endforeach()

    add_custom_target(build-unit-test-${module_name} ALL
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OBJ_DIR}
        COMMAND ${PROJECT_VERILATOR_EXECUTABLE}
                -Wall --Wno-fatal --cc --exe --build --trace
                --top-module ${module_name}
                -I${RTL_INCLUDE_PATH}
                ${RTL_SOURCES}
                ${CPP_TESTBENCH_FILE}
                --Mdir "${OBJ_DIR}"
                -CFLAGS "-std=c++17 -Wall"
        DEPENDS ${RTL_SOURCES} ${CPP_TESTBENCH_FILE}
        COMMENT "Verilating and Building executable for ${module_name}"
        VERBATIM
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )

    add_custom_target(run-unit-test-${module_name}
        COMMAND "${OBJ_DIR}/V${module_name}"
        DEPENDS "build-unit-test-${module_name}"
        WORKING_DIRECTORY ${OBJ_DIR}
        COMMENT "Running Verilated test for ${module_name}"
        VERBATIM
    )

    if(TARGET tests_full)
        add_dependencies(tests_full run-unit-test-${module_name})
    endif()
endfunction()


#----------------------------------------------------------------------------------------------------------------------
# Base components
#----------------------------------------------------------------------------------------------------------------------

add_verilator_test(
    alu
    ${CMAKE_SOURCE_DIR}/rtl/core/alu.sv
)

add_verilator_test(
    instruction_memory_tb
    ${CMAKE_SOURCE_DIR}/rtl/core/instruction_memory.sv
    ${CMAKE_SOURCE_DIR}/tests/unit/instruction_memory_tb.sv
)

add_verilator_test(
    data_memory_tb
    ${CMAKE_SOURCE_DIR}/rtl/core/data_memory.sv
    ${CMAKE_SOURCE_DIR}/tests/unit/data_memory_tb.sv
)

add_verilator_test(
    register_file_tb
    ${CMAKE_SOURCE_DIR}/rtl/core/register_file.sv
    ${CMAKE_SOURCE_DIR}/tests/unit/register_file_tb.sv
)

add_verilator_test(
    immediate_generator_tb
    ${CMAKE_SOURCE_DIR}/rtl/core/immediate_generator.sv
    ${CMAKE_SOURCE_DIR}/tests/unit/immediate_generator_tb.sv
)


#----------------------------------------------------------------------------------------------------------------------
# Pipeline stages
#----------------------------------------------------------------------------------------------------------------------

add_verilator_test(
    control_unit_tb
    ${CMAKE_SOURCE_DIR}/rtl/core/control_unit.sv
    ${CMAKE_SOURCE_DIR}/tests/unit/control_unit_tb.sv
)

add_verilator_test(
    fetch_tb
    ${CMAKE_SOURCE_DIR}/rtl/core/fetch.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/instruction_memory.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/if_id_register.sv
    ${CMAKE_SOURCE_DIR}/tests/unit/fetch_tb.sv
)

add_verilator_test(
    decode_tb
    ${CMAKE_SOURCE_DIR}/rtl/core/decode.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/control_unit.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/register_file.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/immediate_generator.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/if_id_register.sv
    ${CMAKE_SOURCE_DIR}/tests/unit/decode_tb.sv
)

add_verilator_test(
    execute_tb # Top Verilog testbench module and .cpp file name
    # Source files needed
    ${CMAKE_SOURCE_DIR}/rtl/core/execute.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/alu.sv         # execute instantiates alu
    # common defines are included via -I${RTL_INCLUDE_PATH}
    ${CMAKE_SOURCE_DIR}/tests/unit/execute_tb.sv # The Verilog testbench wrapper
)

add_verilator_test(
    writeback_stage_tb
    ${CMAKE_SOURCE_DIR}/rtl/core/writeback_stage.sv
    ${CMAKE_SOURCE_DIR}/tests/unit/writeback_stage_tb.sv
)

add_verilator_test(
    memory_stage_tb
    ${CMAKE_SOURCE_DIR}/rtl/core/memory_stage.sv
    ${CMAKE_SOURCE_DIR}/rtl/core/data_memory.sv
    ${CMAKE_SOURCE_DIR}/tests/unit/memory_stage_tb.sv
)

#----------------------------------------------------------------------------------------------------------------------
# Pipeline control
#----------------------------------------------------------------------------------------------------------------------

add_verilator_test(
    pipeline_control_tb
    ${CMAKE_SOURCE_DIR}/rtl/core/pipeline_control.sv
    ${CMAKE_SOURCE_DIR}/tests/unit/pipeline_control_tb.sv
)

#----------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------

# add_verilator_test(
#     pipeline_tb
#     # All RTL core files are needed as they are instantiated within pipeline.sv
#     # or its submodules. The -I path handles includes.
#     ${CMAKE_SOURCE_DIR}/rtl/pipeline.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/fetch.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/if_id_register.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/decode.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/control_unit.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/register_file.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/immediate_generator.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/id_ex_register.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/execute.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/alu.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/ex_mem_register
#     ${CMAKE_SOURCE_DIR}/rtl/core/memory_stage.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/data_memory.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/mem_wb_register.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/writeback_stage.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/pipeline_control.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/instruction_memory.sv # Included by fetch
#     ${CMAKE_SOURCE_DIR}/tests/unit/pipeline_tb.sv
# )
