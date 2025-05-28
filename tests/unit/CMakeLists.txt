
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
    ${CMAKE_SOURCE_DIR}/tests/unit/fetch_tb.sv
)

# add_verilator_test(
#     decode_tb
#     ${CMAKE_SOURCE_DIR}/rtl/core/decode.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/control_unit.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/register_file.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/immediate_generator.sv
#     ${CMAKE_SOURCE_DIR}/tests/unit/decode_tb.sv
# )

# add_verilator_test(
#     execute_tb # Top Verilog testbench module and .cpp file name
#     # Source files needed
#     ${CMAKE_SOURCE_DIR}/rtl/core/execute.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/alu.sv         # execute instantiates alu
#     # common defines are included via -I${RTL_INCLUDE_PATH}
#     ${CMAKE_SOURCE_DIR}/tests/unit/execute_tb.sv # The Verilog testbench wrapper
# )

# add_verilator_test(
#     writeback_stage_tb
#     ${CMAKE_SOURCE_DIR}/rtl/core/writeback_stage.sv
#     ${CMAKE_SOURCE_DIR}/tests/unit/writeback_stage_tb.sv
# )

# add_verilator_test(
#     memory_stage_tb
#     ${CMAKE_SOURCE_DIR}/rtl/core/memory_stage.sv
#     ${CMAKE_SOURCE_DIR}/rtl/core/data_memory.sv
#     ${CMAKE_SOURCE_DIR}/tests/unit/memory_stage_tb.sv
# )

#----------------------------------------------------------------------------------------------------------------------
# Pipeline control
#----------------------------------------------------------------------------------------------------------------------

# add_verilator_test(
#     pipeline_control_tb
#     ${CMAKE_SOURCE_DIR}/rtl/core/pipeline_control.sv
#     ${CMAKE_SOURCE_DIR}/tests/unit/pipeline_control_tb.sv
# )

#----------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------

