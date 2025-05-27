`include "common/defines.svh"

module instruction_memory (
    input  logic [`DATA_WIDTH-1:0] address,
    output logic [`INSTR_WIDTH-1:0] instruction
);

    localparam ROM_SIZE = 256; // Number of instructions
    logic [`INSTR_WIDTH-1:0] mem[ROM_SIZE-1:0];

    // In a real scenario, this would be loaded from a file (e.g., $readmemh)
    initial begin
        for (int i = 0; i < ROM_SIZE; i++) begin
            mem[i] = 32'h00000013; // NOP
        end
        // Add a few distinct instructions for testing later
        mem[0] = 32'h00100093; // addi x1, x0, 1
        mem[1] = 32'h00200113; // addi x2, x0, 2
        // mem[2] = 32'h00008067; // jalr x0, x1, 0 (effectively a jump to x1 content)
        //                        // This is a simplification; jalr needs rs1.
        //                        // Let's use simpler instructions for now.
        mem[2] = 32'h00308193; // addi x3, x1, 3
        mem[3] = 32'h00110213; // addi x4, x2, 1
    end

    assign instruction = (address[`DATA_WIDTH-1:2] < ROM_SIZE) ?
                     mem[address[`DATA_WIDTH-1:2]] :
                     `INSTR_WIDTH'('0);

endmodule