# RISC-V 5-Stage Pipelined Processor (RV64I Subset)

An educational 64-bit RISC-V processor implementation written in SystemVerilog. This project features a classic 5-stage pipeline with comprehensive hazard handling, designed to demonstrate the fundamentals of computer architecture and the RISC-V ISA.

## Tech Stack
- **Hardware Description Language:** SystemVerilog
- **Simulation & Verification:** [Verilator](https://www.veripool.org/verilator/)
- **Build System:** CMake
- **Testbench Language:** C++17

## Key Features & Learning Objectives
- **5-Stage Pipeline:** Implements Fetch (IF), Decode (ID), Execute (EX), Memory (MEM), and Writeback (WB) stages.
- **Hazard Unit:** Handles data hazards via forwarding and stalls (Load-Use), and control hazards via flushes on branches and jumps.
- **RV64I Subset Support:** Implements a significant portion of the 64-bit RISC-V base integer instruction set.
- **Modular Design:** Each pipeline stage and core component (ALU, Register File, Control Unit) is implemented as a standalone module for clarity.
- **Automated Unit Testing:** Includes a robust testing suite using Verilator to compile RTL into C++ models for high-performance simulation.

## Pipeline Architecture
1.  **Fetch (IF):** Accesses instruction memory and manages the Program Counter (PC).
2.  **Decode (ID):** Decodes 32-bit instructions, reads from the 32-entry register file, and generates immediate values.
3.  **Execute (EX):** Performs arithmetic and logic operations via the ALU and calculates branch/jump targets.
4.  **Memory (MEM):** Interacts with byte-addressable data memory for load and store operations.
5.  **Writeback (WB):** Commits results (ALU output, Memory data, or PC+4) back to the register file.

## Supported Instruction Set (RV64I Subset)
- **Arithmetic & Logic:** `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` (both R-type and I-type).
- **Load & Store:** `LB`, `LH`, `LW`, `LD`, `LBU`, `LHU`, `LWU`, `SB`, `SH`, `SW`, `SD`.
- **Control Flow:** `JAL`, `JALR`, `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`.
- **Upper Immediates:** `LUI`, `AUIPC`.

## Project Structure
- `rtl/`: Core SystemVerilog implementation.
  - `core/`: Pipeline stages, ALU, Control Unit, and Hazard Unit.
  - `common/`: Global definitions and opcode constants.
- `tests/`: Verification environment.
  - `unit/`: C++ testbenches and SystemVerilog test wrappers for individual components.
- `scripts/`: Environment setup and utility scripts.

## Installation

### Prerequisites
- **OS:** Linux (Ubuntu recommended)
- **Verilator:** (Installed via provided script)
- **CMake:** >= 3.16
- **Compiler:** GCC or Clang with C++17 support

### Setup & Build
1.  **Install Dependencies:**
    ```bash
    sudo ./scripts/setup.sh
    ```
2.  **Configure and Build:**
    ```bash
    mkdir build && cd build
    cmake ..
    make -j$(nproc)
    ```

## Usage
The project is structured around unit tests for each component. To run a specific test, use the following `make` targets from the `build` directory:

```bash
# Run ALU unit test
make run-unit-test-alu

# Run Control Unit test
make run-unit-test-control_unit_tb

# Run Pipeline Control (Hazard Unit) test
make run-unit-test-pipeline_control_tb
```

### Available Test Targets
- `alu`
- `instruction_memory_tb`
- `data_memory_tb`
- `register_file_tb`
- `immediate_generator_tb`
- `control_unit_tb`
- `fetch_tb`
- `decode_tb`
- `execute_tb`
- `writeback_stage_tb`
- `memory_stage_tb`
- `pipeline_control_tb`
