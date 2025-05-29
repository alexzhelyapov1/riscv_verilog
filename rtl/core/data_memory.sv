// rtl/core/data_memory.sv
`include "common/defines.svh"
`include "common/riscv_opcodes.svh" // For FUNCT3 defines (LB, LH, LW, etc.)

module data_memory #(
    parameter string DATA_MEM_INIT_FILE = "" // This parameter must exist
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [`DATA_WIDTH-1:0]     addr_i,        // Address from ALU result
    input  logic [`DATA_WIDTH-1:0]     write_data_i,  // Data from RS2 (for stores)
    input  logic                       mem_write_en_i,  // From MemWriteM control signal
    input  logic [2:0]                 funct3_i,      // To determine load/store type (size and sign)

    output logic [`DATA_WIDTH-1:0]     read_data_o    // Data read from memory (for loads)
);

    // Parameter for memory size (e.g., 2^10 = 1024 words of 64-bit)
    // Addresses are byte addresses.
    localparam MEM_ADDR_BITS = 10; // For 1KB of byte-addressable memory (2^10 bytes)
    localparam MEM_SIZE_BYTES = 1 << MEM_ADDR_BITS;
    localparam MEM_ADDR_WIDTH = $clog2(MEM_SIZE_BYTES);

    // Byte-addressable memory array. Each element is a byte.
    logic [7:0] mem [MEM_SIZE_BYTES-1:0];
    logic [`DATA_WIDTH-1:0] aligned_word_read_comb; // Changed name to avoid potential conflict
    logic [`DATA_WIDTH-1:0] temp_read_data_comb;    // Changed name

    // Read logic (combinational read based on address)
    always_comb begin
        temp_read_data_comb = `DATA_WIDTH'('x); // Default to 'x'
        aligned_word_read_comb = `DATA_WIDTH'('0); // Default to 0

        if (addr_i < MEM_SIZE_BYTES) begin
            logic [2:0] byte_offset_in_word = addr_i[2:0];
            logic [`DATA_WIDTH-1:0] current_aligned_word;

            // Construct the 64-bit aligned word from individual bytes
            for (int i = 0; i < (`DATA_WIDTH/8); i++) begin
                if (((addr_i & ~((`DATA_WIDTH/8) - 1)) + `DATA_WIDTH'(i)) < MEM_SIZE_BYTES) begin
                    current_aligned_word[(i*8) +: 8] = mem[(addr_i & ~((`DATA_WIDTH/8) - 1)) + `DATA_WIDTH'(i)];
                end else begin
                    current_aligned_word[(i*8) +: 8] = 8'h00; // Out of bounds byte read as 0
                end
            end
            aligned_word_read_comb = current_aligned_word;


            case (funct3_i)
                `FUNCT3_LB: begin // Load Byte (signed)
                    temp_read_data_comb = {{(`DATA_WIDTH-8){aligned_word_read_comb[byte_offset_in_word*8 + 7]}}, aligned_word_read_comb[byte_offset_in_word*8 +: 8]};
                end
                `FUNCT3_LH: begin // Load Half-word (signed)
                    temp_read_data_comb = {{(`DATA_WIDTH-16){aligned_word_read_comb[byte_offset_in_word*8 + 15]}}, aligned_word_read_comb[byte_offset_in_word*8 +: 16]};
                end
                `FUNCT3_LW: begin // Load Word (signed, 32-bit)
                    temp_read_data_comb = {{(`DATA_WIDTH-32){aligned_word_read_comb[byte_offset_in_word*8 + 31]}}, aligned_word_read_comb[byte_offset_in_word*8 +: 32]};
                end
                `FUNCT3_LD: begin // Load Double-word (64-bit)
                    temp_read_data_comb = aligned_word_read_comb;
                end
                `FUNCT3_LBU: begin // Load Byte (unsigned)
                    temp_read_data_comb = {{(`DATA_WIDTH-8){1'b0}}, aligned_word_read_comb[byte_offset_in_word*8 +: 8]};
                end
                `FUNCT3_LHU: begin // Load Half-word (unsigned)
                    temp_read_data_comb = {{(`DATA_WIDTH-16){1'b0}}, aligned_word_read_comb[byte_offset_in_word*8 +: 16]};
                end
                `FUNCT3_LWU: begin // Load Word (unsigned, 32-bit into 64-bit)
                    temp_read_data_comb = {{(`DATA_WIDTH-32){1'b0}}, aligned_word_read_comb[byte_offset_in_word*8 +: 32]};
                end
                default: temp_read_data_comb = `DATA_WIDTH'('x);
            endcase
        end else begin
             temp_read_data_comb = `DATA_WIDTH'('x); // Address out of bounds
        end
    end
    assign read_data_o = temp_read_data_comb;

    // Write logic (synchronous write on positive clock edge)
    always_ff @(posedge clk) begin
        if (mem_write_en_i) begin // Check enable first
            // Ensure address is within bounds for each byte written
            case (funct3_i)
                `FUNCT3_SB: begin // Store Byte
                    if (addr_i < MEM_SIZE_BYTES) mem[addr_i] = write_data_i[7:0];
                end
                `FUNCT3_SH: begin // Store Half-word
                    if (addr_i < MEM_SIZE_BYTES - 1) begin // Check bounds for 2 bytes
                        mem[addr_i]   <= write_data_i[7:0];
                        mem[addr_i+1] <= write_data_i[15:8];
                    end
                end
                `FUNCT3_SW: begin // Store Word (32-bit)
                    if (addr_i < MEM_SIZE_BYTES - 3) begin // Check bounds for 4 bytes
                        for (int i = 0; i < 4; i++) begin
                            mem[addr_i+i] <= write_data_i[i*8 +: 8];
                        end
                    end
                end
                `FUNCT3_SD: begin // Store Double-word (64-bit)
                     if (addr_i < MEM_SIZE_BYTES - 7) begin // Check bounds for 8 bytes
                        for (int i = 0; i < (`DATA_WIDTH/8); i++) begin
                            mem[addr_i + `DATA_WIDTH'(i)] <= write_data_i[i*8 +: 8];
                        end
                    end
                end
                default: ; // No action for other funct3 values during store
            endcase
        end
    end

    // Initialize memory on reset (for simulation)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < MEM_SIZE_BYTES; i++) begin
                mem[i] = 8'h00;
            end
        end
    end
    // Added initial block for Verilator to load memory init file
    initial begin
        if (DATA_MEM_INIT_FILE != "") begin
            $readmemh(DATA_MEM_INIT_FILE, mem);
        end
    end

endmodule