`include "common/defines.svh"

module pipeline_tb (
    input  logic clk,
    input  logic rst_n,

    // Outputs for C++ test to observe main processor state
    output logic [`DATA_WIDTH-1:0] debug_pc_f,
    output logic [`INSTR_WIDTH-1:0] debug_instr_f,

    // Interface to peek into register file (needs to be exposed or use DPI)
    // For simplicity, we might rely on storing results to memory and checking memory,
    // or add a simplified read port to regfile for debug in simulation ONLY.
    // Or, the C++ test will know the expected final register values and compare
    // after a certain number of cycles by having the DUT run and then stopping it.
    // The register file is written by the pipeline itself.

    // Interface to peek into data memory (similar to register file)
    // For now, we'll execute programs and verify register values through other means
    // or by designing programs that write results to predictable memory locations.
    output logic [`DATA_WIDTH-1:0] debug_rf_read_data [31:0] // Expose RF for debug
);

    pipeline u_pipeline (
        .clk                 (clk),
        .rst_n               (rst_n),
        .current_pc_debug    (debug_pc_f),
        .fetched_instr_debug (debug_instr_f)
    );

    // Expose register file for debug reading by testbench
    // This requires u_pipeline.u_decode.u_register_file to be accessible.
    // This is often done using `bind` or by making internal signals public for Verilator.
    // Or, for a simpler approach, the test program writes values to known memory locations.
    // Let's assume for now we can't directly read RF this way easily without more setup.
    // We will verify by observing program behavior (e.g. results written to data memory).

    // Exposing RF through Verilator's public_flat or similar is an option for C++ access.
    // For now, let's keep the TB simple and rely on program side-effects.
    // To enable direct RF peeking for the test, we'd need to instantiate RF here
    // or use Verilator's features.

    // Simplified debug: just showing PC and Fetched Instruction
    // Verification of program correctness will be by checking specific register/memory
    // values after running the program for N cycles. The C++ test will need to
    // "know" where results are expected.

    // Example of exposing register file values if it were instantiated at this level
    // (This is NOT how it's structured currently, RF is deep inside)
    /*
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : reg_debug_loop
            // This assumes a way to read from u_pipeline.u_decode.u_register_file.regs[i]
            // assign debug_rf_read_data[i] = u_pipeline.u_decode.u_register_file.regs[i]; // Needs direct access
        end
    endgenerate
    */
    // For now, debug_rf_read_data is not driven, C++ test will simulate program and predict register state.

endmodule