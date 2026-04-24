// ============================================================
// mac_correct.v
// Hand-corrected reference implementation.
// Fixes issues found in mac_llm_A.v and mac_llm_B.v:
//   - uses always_ff (not plain always)
//   - uses logic (not wire/reg)
//   - explicit intermediate signed [15:0] product avoids any
//     sign-extension ambiguity in the accumulator addition
//   - manual sign-extension via replication: {{16{product[15]}}, product}
//     guarantees the 16-bit product is sign-extended to 32 bits
//     before being added, regardless of tool interpretation
// ============================================================

module mac (
    input  logic              clk,
    input  logic              rst,
    input  logic signed [7:0] a,
    input  logic signed [7:0] b,
    output logic signed [31:0] out
);

    // Explicit 16-bit signed product (8-bit x 8-bit signed = 16-bit signed)
    logic signed [15:0] product;

    always_comb begin
        product = a * b;
    end

    always_ff @(posedge clk) begin
        if (rst)
            out <= '0;
        else
            // Explicit sign extension: replicate MSB of product to fill
            // upper 16 bits before accumulation — no tool ambiguity
            out <= out + {{16{product[15]}}, product};
    end

endmodule
