`include "common/defines.svh"
`include "common/alu_defines.svh"

module alu (
    input  logic [`DATA_WIDTH-1:0] operand_a,
    input  logic [`DATA_WIDTH-1:0] operand_b,
    input  logic [2:0]             alu_op_select,
    input  logic                   alu_modifier,
    output logic [`DATA_WIDTH-1:0] result,
    output logic                   zero_flag
);

    logic [`DATA_WIDTH-1:0] result_comb;
    logic [5:0]             shift_amount; // Для RV64, сдвиг на младшие 6 бит operand_b

    assign shift_amount = operand_b[5:0];

    always_comb begin
        result_comb = {`DATA_WIDTH{1'bx}}; // Значение по умолчанию

        case (alu_op_select)
            `ALU_OP_ADD: result_comb = operand_a + operand_b;
            `ALU_OP_SUB: result_comb = operand_a - operand_b;
            `ALU_OP_AND: result_comb = operand_a & operand_b;
            `ALU_OP_OR:  result_comb = operand_a | operand_b;
            `ALU_OP_XOR: result_comb = operand_a ^ operand_b;
            `ALU_OP_SLT_BASE:
                if (alu_modifier == `ALU_SELECT_SIGNED) begin // SLT (signed)
                    result_comb = ($signed(operand_a) < $signed(operand_b)) ? {{`DATA_WIDTH-1{1'b0}}, 1'b1} : {`DATA_WIDTH{1'b0}};
                end else begin // alu_modifier == `ALU_SELECT_UNSIGNED` -> SLTU (unsigned)
                    result_comb = (operand_a < operand_b) ? {{`DATA_WIDTH-1{1'b0}}, 1'b1} : {`DATA_WIDTH{1'b0}};
                end
            `ALU_OP_SLL: result_comb = operand_a << shift_amount;
            `ALU_OP_SR_BASE:
                if (alu_modifier == `ALU_SELECT_LOGICAL_SR) begin // SRL (logical)
                    result_comb = operand_a >> shift_amount;
                end else begin // alu_modifier == `ALU_SELECT_ARITH_SR` -> SRA (arithmetic)
                    result_comb = $signed(operand_a) >>> shift_amount;
                end
            default: result_comb = {`DATA_WIDTH{1'bx}};
        endcase
    end

    assign result = result_comb;
    assign zero_flag = (result_comb == {`DATA_WIDTH{1'b0}});

endmodule