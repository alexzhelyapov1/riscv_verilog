`include "common/defines.svh"
`include "common/immediate_types.svh" // For immediate_type_e

module immediate_generator_tb (
    input  logic [`INSTR_WIDTH-1:0] i_instr,
    input  immediate_type_e         i_imm_type_sel,
    output logic [`DATA_WIDTH-1:0]  o_imm_ext
);

    immediate_generator u_immediate_generator (
        .instr_i        (i_instr),
        .imm_type_sel_i (i_imm_type_sel),
        .imm_ext_o      (o_imm_ext)
    );

endmodule