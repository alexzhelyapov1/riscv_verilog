`include "common/defines.svh"

module memory_stage_tb (
    input  logic clk,
    input  logic rst_n,

    // Inputs to memory_stage (simulating outputs of EX/MEM register)
    input  logic       i_reg_write_m,
    input  logic [1:0] i_result_src_m,
    input  logic       i_mem_write_m,
    input  logic [2:0] i_funct3_m,       // For load/store type

    input  logic [`DATA_WIDTH-1:0]     i_alu_result_m, // Address for memory or result from ALU
    input  logic [`DATA_WIDTH-1:0]     i_rs2_data_m,   // Data to store in memory
    input  logic [`REG_ADDR_WIDTH-1:0] i_rd_addr_m,
    input  logic [`DATA_WIDTH-1:0]     i_pc_plus_4_m,

    // Outputs from memory_stage (these would go to MEM/WB register)
    output logic       o_reg_write_w,
    output logic [1:0] o_result_src_w,
    output logic [`DATA_WIDTH-1:0] o_read_data_w,  // Data read from memory
    output logic [`DATA_WIDTH-1:0] o_alu_result_w, // ALU result passed through
    output logic [`REG_ADDR_WIDTH-1:0] o_rd_addr_w,
    output logic [`DATA_WIDTH-1:0] o_pc_plus_4_w
    // o_mem_write_w не существует, т.к. mem_write потребляется в этой стадии
);

    memory_stage u_memory_stage (
        .clk            (clk),
        .rst_n          (rst_n),

        .reg_write_m_i  (i_reg_write_m),
        .result_src_m_i (i_result_src_m),
        .mem_write_m_i  (i_mem_write_m),
        .funct3_m_i     (i_funct3_m),
        .alu_result_m_i (i_alu_result_m),
        .rs2_data_m_i   (i_rs2_data_m),
        .rd_addr_m_i    (i_rd_addr_m),
        .pc_plus_4_m_i  (i_pc_plus_4_m),

        .reg_write_w_o  (o_reg_write_w),
        .result_src_w_o (o_result_src_w),
        .read_data_w_o  (o_read_data_w),
        .alu_result_w_o (o_alu_result_w),
        .rd_addr_w_o    (o_rd_addr_w),
        .pc_plus_4_w_o  (o_pc_plus_4_w)
    );

    // Для доступа к содержимому data_memory из C++ теста, нам нужен способ
    // либо вынести data_memory на верхний уровень тестбенча, либо использовать DPI.
    // Для простоты, пока не будем напрямую читать память из C++ в этом юнит-тесте,
    // а будем полагаться на чтение через Load инструкции.
    // Более полный тест data_memory был бы отдельным.
    // Здесь мы тестируем memory_stage и его взаимодействие с data_memory.

endmodule