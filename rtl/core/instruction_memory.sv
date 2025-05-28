// rtl/core/instruction_memory.sv
`include "common/defines.svh"

module instruction_memory (
    input  logic [`DATA_WIDTH-1:0] address,
    output logic [`INSTR_WIDTH-1:0] instruction
);

    parameter string INSTR_MEM_INIT_FILE_PARAM = ""; // Parameter for memory initialization file
    localparam ROM_SIZE = 256; // Number of instructions
    logic [`INSTR_WIDTH-1:0] mem[ROM_SIZE-1:0];

    initial begin
        // Default initialize all memory to NOP
        for (int i = 0; i < ROM_SIZE; i++) begin
            mem[i] = `NOP_INSTRUCTION;
        end

        if (INSTR_MEM_INIT_FILE_PARAM != "") begin
            // If a file is specified, load it. This will override NOPs.
            $readmemh(INSTR_MEM_INIT_FILE_PARAM, mem);
            // $display("Instruction memory initialized from %s", INSTR_MEM_INIT_FILE_PARAM);
        end else begin
            // Fallback to hardcoded test instructions if no file is provided
            // These will override the NOPs at specific locations.
            mem[0] = 32'h00100093; // addi x1, x0, 1
            mem[1] = 32'h00200113; // addi x2, x0, 2
            mem[2] = 32'h00308193; // addi x3, x1, 3
            mem[3] = 32'h00110213; // addi x4, x2, 1
            // $display("Instruction memory initialized with default test program.");
        end
    end

    assign instruction = (address[`DATA_WIDTH-1:2] < ROM_SIZE) ?
                     mem[address[`DATA_WIDTH-1:2]] :
                     `NOP_INSTRUCTION; // Return NOP for out-of-bounds access

endmodule