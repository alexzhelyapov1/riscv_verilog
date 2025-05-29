`include "common/defines.svh"

module instruction_memory (
    input  logic [`DATA_WIDTH-1:0] address,
    output logic [`INSTR_WIDTH-1:0] instruction
);

    parameter string INSTR_MEM_INIT_FILE_PARAM = ""; // Parameter for memory initialization file
    localparam ROM_SIZE = 2**20; // Number of instructions (1,048,576)
    localparam ROM_ADDR_WIDTH = $clog2(ROM_SIZE); // Width of the index for mem (20 bits)

    logic [`INSTR_WIDTH-1:0] mem[ROM_SIZE-1:0];
    logic [ROM_ADDR_WIDTH-1:0] mem_idx;

    initial begin
        // Default initialize all memory to NOP
        for (int i = 0; i < ROM_SIZE; i++) begin
            mem[i] = `NOP_INSTRUCTION;
        end

        if (INSTR_MEM_INIT_FILE_PARAM != "") begin
            $readmemh(INSTR_MEM_INIT_FILE_PARAM, mem);
        end else begin
            mem[0] = 32'h00100093; // addi x1, x0, 1
            mem[1] = 32'h00200113; // addi x2, x0, 2
            mem[2] = 32'h00308193; // addi x3, x1, 3
            mem[3] = 32'h00110213; // addi x4, x2, 1
        end
    end

    assign mem_idx = address[ROM_ADDR_WIDTH+2-1:2];
    assign instruction = (mem_idx < ROM_SIZE) ?
                         mem[mem_idx] :
                         `NOP_INSTRUCTION;

endmodule