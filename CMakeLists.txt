cmake_minimum_required(VERSION 3.16)
project(Verilog LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)


find_program(PROJECT_VERILATOR_EXECUTABLE
    NAMES verilator verilator_bin
    DOC "Verilator executable"
    REQUIRED
)
message(STATUS "Found system Verilator executable: ${PROJECT_VERILATOR_EXECUTABLE}")

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory(tests)
