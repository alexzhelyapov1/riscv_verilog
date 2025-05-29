
`include "common/defines.svh"
`include "common/riscv_opcodes.svh"

module data_memory #(
    parameter string DATA_MEM_INIT_FILE = ""
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [`DATA_WIDTH-1:0]     addr_i,
    input  logic [`DATA_WIDTH-1:0]     write_data_i,
    input  logic                       mem_write_en_i,
    input  logic [2:0]                 funct3_i,

    output logic [`DATA_WIDTH-1:0]     read_data_o
);

    localparam MEM_ADDR_BITS = 10;
    localparam MEM_SIZE_BYTES = 1 << MEM_ADDR_BITS;
    localparam MEM_ADDR_WIDTH = $clog2(MEM_SIZE_BYTES);

    logic [7:0] mem [MEM_SIZE_BYTES-1:0];
    logic [`DATA_WIDTH-1:0] aligned_word_read_comb;
    logic [`DATA_WIDTH-1:0] temp_read_data_comb;

    always_comb begin
        temp_read_data_comb = `DATA_WIDTH'('x);
        aligned_word_read_comb = `DATA_WIDTH'('0);

        if (addr_i < MEM_SIZE_BYTES) begin
            logic [2:0] byte_offset_in_word = addr_i[2:0];
            logic [`DATA_WIDTH-1:0] current_aligned_word;

            for (int i = 0; i < (`DATA_WIDTH/8); i++) begin
                if (((addr_i & ~((`DATA_WIDTH/8) - 1)) + `DATA_WIDTH'(i)) < MEM_SIZE_BYTES) begin
                    current_aligned_word[(i*8) +: 8] = mem[(addr_i & ~((`DATA_WIDTH/8) - 1)) + `DATA_WIDTH'(i)];
                end else begin
                    current_aligned_word[(i*8) +: 8] = 8'h00;
                end
            end
            aligned_word_read_comb = current_aligned_word;

            case (funct3_i)
                `FUNCT3_LB: begin
                    temp_read_data_comb = {{(`DATA_WIDTH-8){aligned_word_read_comb[byte_offset_in_word*8 + 7]}}, aligned_word_read_comb[byte_offset_in_word*8 +: 8]};
                end
                `FUNCT3_LH: begin
                    temp_read_data_comb = {{(`DATA_WIDTH-16){aligned_word_read_comb[byte_offset_in_word*8 + 15]}}, aligned_word_read_comb[byte_offset_in_word*8 +: 16]};
                end
                `FUNCT3_LW: begin
                    temp_read_data_comb = {{(`DATA_WIDTH-32){aligned_word_read_comb[byte_offset_in_word*8 + 31]}}, aligned_word_read_comb[byte_offset_in_word*8 +: 32]};
                end
                `FUNCT3_LD: begin
                    temp_read_data_comb = aligned_word_read_comb;
                end
                `FUNCT3_LBU: begin
                    temp_read_data_comb = {{(`DATA_WIDTH-8){1'b0}}, aligned_word_read_comb[byte_offset_in_word*8 +: 8]};
                end
                `FUNCT3_LHU: begin
                    temp_read_data_comb = {{(`DATA_WIDTH-16){1'b0}}, aligned_word_read_comb[byte_offset_in_word*8 +: 16]};
                end
                `FUNCT3_LWU: begin
                    temp_read_data_comb = {{(`DATA_WIDTH-32){1'b0}}, aligned_word_read_comb[byte_offset_in_word*8 +: 32]};
                end
                default: temp_read_data_comb = `DATA_WIDTH'('x);
            endcase
        end else begin
             temp_read_data_comb = `DATA_WIDTH'('x);
        end
    end
    assign read_data_o = temp_read_data_comb;

    always_ff @(posedge clk) begin
        if (mem_write_en_i) begin

            case (funct3_i)
                `FUNCT3_SB: begin
                    if (addr_i < MEM_SIZE_BYTES) mem[addr_i] = write_data_i[7:0];
                end
                `FUNCT3_SH: begin
                    if (addr_i < MEM_SIZE_BYTES - 1) begin
                        mem[addr_i]   <= write_data_i[7:0];
                        mem[addr_i+1] <= write_data_i[15:8];
                    end
                end
                `FUNCT3_SW: begin
                    if (addr_i < MEM_SIZE_BYTES - 3) begin
                        for (int i = 0; i < 4; i++) begin
                            mem[addr_i+i] <= write_data_i[i*8 +: 8];
                        end
                    end
                end
                `FUNCT3_SD: begin
                     if (addr_i < MEM_SIZE_BYTES - 7) begin
                        for (int i = 0; i < (`DATA_WIDTH/8); i++) begin
                            mem[addr_i + `DATA_WIDTH'(i)] <= write_data_i[i*8 +: 8];
                        end
                    end
                end
                default: ;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < MEM_SIZE_BYTES; i++) begin
                mem[i] = 8'h00;
            end
        end
    end

    initial begin
        if (DATA_MEM_INIT_FILE != "") begin
            $readmemh(DATA_MEM_INIT_FILE, mem);
        end
    end

endmodule