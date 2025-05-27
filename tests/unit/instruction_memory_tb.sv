// tests/unit/instruction_memory_tb.sv

`include "common/defines.svh"

module instruction_memory_tb (
    // Testbench is combinational for instruction_memory inputs/outputs
    // clk/rst_n are not strictly needed by instruction_memory.sv itself for read path,
    // but Verilator testbenches often have them. We can omit for this simple module.

    input  logic [`DATA_WIDTH-1:0]     i_address,
    output logic [`INSTR_WIDTH-1:0]    o_instruction
);

    instruction_memory u_instr_mem (
        .address     (i_address),
        .instruction (o_instruction)
    );

endmodule