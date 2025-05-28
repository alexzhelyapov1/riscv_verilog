// rtl/core/instruction_memory.sv
`include "common/defines.svh"

module instruction_memory (
    input  logic [`DATA_WIDTH-1:0] address,
    output logic [`INSTR_WIDTH-1:0] instruction
);

    parameter string MEM_INIT_FILE = ""; // Parameter for memory initialization file
    localparam ROM_SIZE = 256; // Number of instructions
    logic [`INSTR_WIDTH-1:0] mem[ROM_SIZE-1:0];

    initial begin
        // Default initialize all memory to NOP
        for (int i = 0; i < ROM_SIZE; i++) begin
            mem[i] = `NOP_INSTRUCTION;
        end

        // if (MEM_INIT_FILE != "") begin
        //     $readmemh(MEM_INIT_FILE, mem);
        // end else begin
            // Hardcoded test instructions for basic pipeline test
            mem[0] = 32'h00100093; // addi x1, x0, 1
            mem[1] = 32'h00200113; // addi x2, x0, 2
            mem[2] = 32'h00300193; // addi x3, x0, 3 (rd=x3)
            mem[3] = 32'h00400213; // addi x4, x0, 4 (rd=x4)
            // $display("Instruction memory initialized with basic addi test program.");
        // end
    end

    assign instruction = (address[`DATA_WIDTH-1:2] < ROM_SIZE) ?
                     mem[address[`DATA_WIDTH-1:2]] :
                     `NOP_INSTRUCTION; // Return NOP for out-of-bounds access

endmodule