`include "common/defines.svh"
`include "common/alu_defines.svh"

module alu (
    input  logic [`DATA_WIDTH-1:0]     operand_a,
    input  logic [`DATA_WIDTH-1:0]     operand_b,
    input  logic [`ALU_CONTROL_WIDTH-1:0] alu_control,
    output logic [`DATA_WIDTH-1:0]     result,
    output logic                       zero_flag
);

    logic [`DATA_WIDTH-1:0] result_comb;
    logic [5:0]             shift_amount;

    assign shift_amount = operand_b[5:0];

    always_comb begin
        result_comb = {`DATA_WIDTH{1'bx}};

        case (alu_control)
            `ALU_OP_ADD:  result_comb = operand_a + operand_b;
            `ALU_OP_SUB:  result_comb = operand_a - operand_b;
            `ALU_OP_SLL:  result_comb = operand_a << shift_amount;
            `ALU_OP_SLT:  result_comb = ($signed(operand_a) < $signed(operand_b)) ? {{`DATA_WIDTH-1{1'b0}}, 1'b1} : {`DATA_WIDTH{1'b0}};
            `ALU_OP_SLTU: result_comb = (operand_a < operand_b) ? {{`DATA_WIDTH-1{1'b0}}, 1'b1} : {`DATA_WIDTH{1'b0}};
            `ALU_OP_XOR:  result_comb = operand_a ^ operand_b;
            `ALU_OP_SRL:  result_comb = operand_a >> shift_amount;
            `ALU_OP_SRA:  result_comb = $signed(operand_a) >>> shift_amount;
            `ALU_OP_OR:   result_comb = operand_a | operand_b;
            `ALU_OP_AND:  result_comb = operand_a & operand_b;
            default:      result_comb = {`DATA_WIDTH{1'bx}};
        endcase
    end

    assign result = result_comb;
    assign zero_flag = (result_comb == {`DATA_WIDTH{1'b0}});

endmodule