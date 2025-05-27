// rtl/core/data_memory.sv
`include "common/defines.svh"
`include "common/riscv_opcodes.svh" // For FUNCT3 defines (LB, LH, LW, etc.)

module data_memory (
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
    localparam MEM_SIZE_WORDS = MEM_SIZE_BYTES / (`DATA_WIDTH/8);

    // Byte-addressable memory array. Each element is a byte.
    logic [7:0] mem [MEM_SIZE_BYTES-1:0];
    logic [`DATA_WIDTH-1:0] aligned_word_read;
    logic [`DATA_WIDTH-1:0] temp_read_data;

    // For faster simulation, Verilator might prefer word-oriented memory if operations are word-aligned
    // but byte-addressable is more general for LB/SB etc.

    // Read logic (combinational read based on address)
    // Handles different load types based on funct3
    logic [`DATA_WIDTH-1:0] read_data_aligned;
    always_comb begin
        // Default to 'x' or 0 if address is out of bounds (not explicitly handled here for simplicity)
        read_data_aligned = `DATA_WIDTH'('0);
        if (addr_i < MEM_SIZE_BYTES) begin
            // Read a full 64-bit word aligned to 8 bytes for simplicity first
            // This assumes addr_i is mostly aligned for LW/LD. Unaligned access is complex.
            // For byte/half access, we need to pick correct bytes from the word.
            // Let's read the 8 bytes starting at the (potentially unaligned) address.
            // This is a simplification; real unaligned access is more involved.
            // We'll handle alignment and byte picking for loads.
            // For simplicity, assume addr_i is aligned for word/double-word access.
            // For byte/half, addr_i can be unaligned within the word.

            // Construct the 64-bit value from individual bytes
            // This handles potential unaligned reads across word boundaries if MEM_SIZE_BYTES is large enough
            // and if addr_i + 7 does not exceed MEM_SIZE_BYTES-1.
            // For simplicity, let's assume we read an aligned 64-bit word first, then extract.
            logic [`DATA_WIDTH-1:0] fetched_word;
            logic [2:0] byte_offset_in_word = addr_i[2:0]; // Lower 3 bits for byte offset within a 64-bit word
            logic [MEM_ADDR_BITS-1:3] word_addr_idx;

            // Read the 8 bytes that form the 64-bit chunk containing addr_i
            // This is still a simplification, proper unaligned access over physical memory is hard
            for (int i = 0; i < (`DATA_WIDTH/8); i++) begin
                if ((addr_i + i) < MEM_SIZE_BYTES) begin
                    fetched_word[i*8 +: 8] = mem[addr_i + i];
                end else begin
                    fetched_word[i*8 +: 8] = 8'h00; // Out of bounds byte
                end
            end
            // The above loop is not quite right for constructing the word based on addr_i alignment
            // Let's re-think: fetch the aligned word, then select based on offset and funct3.
            temp_read_data = `DATA_WIDTH'('x);
            word_addr_idx = addr_i[MEM_ADDR_BITS-1:3]; // Index for 64-bit words if mem was word array

            // More correct byte-wise construction for an aligned read:
            for (int i = 0; i < (`DATA_WIDTH/8); i++) begin
                 // addr_i & ~7 ensures we start at an 8-byte boundary for the read
                if (( (addr_i & ~(`DATA_WIDTH/8 - 1)) + i) < MEM_SIZE_BYTES) begin
                    aligned_word_read[(i*8) +: 8] = mem[(addr_i & ~(`DATA_WIDTH/8 - 1)) + i];
                end else begin
                    aligned_word_read[(i*8) +: 8] = 8'h00;
                end
            end


            case (funct3_i)
                `FUNCT3_LB: begin // Load Byte (signed)
                    temp_read_data = {{(`DATA_WIDTH-8){aligned_word_read[byte_offset_in_word*8 + 7]}}, aligned_word_read[byte_offset_in_word*8 +: 8]};
                end
                `FUNCT3_LH: begin // Load Half-word (signed)
                    temp_read_data = {{(`DATA_WIDTH-16){aligned_word_read[byte_offset_in_word*8 + 15]}}, aligned_word_read[byte_offset_in_word*8 +: 16]};
                end
                `FUNCT3_LW: begin // Load Word (signed, 32-bit)
                    temp_read_data = {{(`DATA_WIDTH-32){aligned_word_read[byte_offset_in_word*8 + 31]}}, aligned_word_read[byte_offset_in_word*8 +: 32]};
                end
                `FUNCT3_LD: begin // Load Double-word (64-bit)
                    temp_read_data = aligned_word_read; // Assumes addr_i is 8-byte aligned for LD
                end
                `FUNCT3_LBU: begin // Load Byte (unsigned)
                    temp_read_data = {{(`DATA_WIDTH-8){1'b0}}, aligned_word_read[byte_offset_in_word*8 +: 8]};
                end
                `FUNCT3_LHU: begin // Load Half-word (unsigned)
                    temp_read_data = {{(`DATA_WIDTH-16){1'b0}}, aligned_word_read[byte_offset_in_word*8 +: 16]};
                end
                `FUNCT3_LWU: begin // Load Word (unsigned, 32-bit into 64-bit)
                    temp_read_data = {{(`DATA_WIDTH-32){1'b0}}, aligned_word_read[byte_offset_in_word*8 +: 32]};
                end
                default: temp_read_data = `DATA_WIDTH'('x); // Should not happen for load opcodes
            endcase
            read_data_aligned = temp_read_data;
        end
    end
    assign read_data_o = read_data_aligned;

    // Write logic (synchronous write on positive clock edge)
    always_ff @(posedge clk) begin
        if (mem_write_en_i && addr_i < MEM_SIZE_BYTES) begin
            case (funct3_i)
                `FUNCT3_SB: begin // Store Byte
                    if (addr_i < MEM_SIZE_BYTES) mem[addr_i] = write_data_i[7:0];
                end
                `FUNCT3_SH: begin // Store Half-word
                    if ((addr_i + 1) < MEM_SIZE_BYTES) begin // Check bounds for 2 bytes
                        mem[addr_i]   = write_data_i[7:0];
                        mem[addr_i+1] = write_data_i[15:8];
                    end
                end
                `FUNCT3_SW: begin // Store Word (32-bit)
                    if ((addr_i + 3) < MEM_SIZE_BYTES) begin // Check bounds for 4 bytes
                        for (int i = 0; i < 4; i++) begin
                            mem[addr_i+i] = write_data_i[i*8 +: 8];
                        end
                    end
                end
                `FUNCT3_SD: begin // Store Double-word (64-bit)
                    if ((addr_i + 7) < MEM_SIZE_BYTES) begin // Check bounds for 8 bytes
                        for (int i = 0; i < (`DATA_WIDTH/8); i++) begin
                            mem[addr_i+i] = write_data_i[i*8 +: 8];
                        end
                    end
                end
                default: ; // No action for other funct3 values during store
            endcase
        end
    end

    // Optional: Initialize memory on reset (for simulation)
    initial begin
        if (rst_n) begin // Wait for reset to de-assert if this initial block runs at time 0
            for (int i = 0; i < MEM_SIZE_BYTES; i++) begin
                mem[i] = 8'h00;
            end
        end
    end
    // Better reset handling:
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < MEM_SIZE_BYTES; i++) begin
                mem[i] = 8'h00;
            end
        end
    end

endmodule