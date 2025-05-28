cmake_minimum_required(VERSION 3.16)
project(Verilog LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra")


find_program(PROJECT_VERILATOR_EXECUTABLE
    NAMES verilator verilator_bin
    DOC "Verilator executable"
    REQUIRED
)
message(STATUS "Found system Verilator executable: ${PROJECT_VERILATOR_EXECUTABLE}")

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

find_package(Python3 COMPONENTS Interpreter QUIET)
if(NOT Python3_FOUND)
    message(WARNING "Python3 interpreter not found, elf_to_memh.py script might not work.")
else()
    message(STATUS "Found Python3 interpreter: ${Python3_EXECUTABLE}")
endif()

# Поиск утилит RISC-V (если они не найдены, pipeline_tests не соберутся)
find_program(RISCV_AS NAMES riscv64-unknown-elf-as DOC "RISC-V Assembler")
find_program(RISCV_LD NAMES riscv64-unknown-elf-ld DOC "RISC-V Linker")
find_program(RISCV_OBJCOPY NAMES riscv64-unknown-elf-objcopy DOC "RISC-V Objcopy")
find_program(RISCV_READELF NAMES riscv64-unknown-elf-readelf DOC "RISC-V Readelf")

add_subdirectory(tests)