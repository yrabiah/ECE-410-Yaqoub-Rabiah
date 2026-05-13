// ============================================================
// compute_core.sv — Radix-2 DIF FFT Butterfly Processing Element
// Project : 256-pt FFT Vibration Anomaly Detection Accelerator
// Course  : ECE 410/510 HW4AI, Spring 2026
// Author  : Yaqoub Rabiah
//
// Description:
//   This module is the core compute kernel of the 256-point FFT
//   accelerator.  It implements one radix-2 decimation-in-frequency
//   (DIF) butterfly:
//
//       A' = A + W·B
//       B' = A − W·B
//
//   where W is the complex twiddle factor, A and B are complex
//   input samples, and A', B' are complex outputs.
//
//   Data format : INT16 / Q1.15 signed fixed-point throughout.
//   Products     : 32-bit (2×16), rescaled by arithmetic right-shift
//                  of 15 to return to Q1.15.
//   Pipeline     : 3 clock cycles latency, 1 sample/cycle throughput.
//
// Port list:
//   clk       in   1    system clock (single domain)
//   rst       in   1    synchronous active-high reset
//   valid_in  in   1    input sample valid
//   ar_in     in  16    A real  (Q1.15 signed)
//   ai_in     in  16    A imag  (Q1.15 signed)
//   br_in     in  16    B real  (Q1.15 signed)
//   bi_in     in  16    B imag  (Q1.15 signed)
//   wr_in     in  16    twiddle W real  (Q1.15 signed)
//   wi_in     in  16    twiddle W imag  (Q1.15 signed)
//   valid_out out  1    output valid (asserted 3 cycles after valid_in)
//   ar_out    out 16    A' real (Q1.15 signed)
//   ai_out    out 16    A' imag (Q1.15 signed)
//   br_out    out 16    B' real (Q1.15 signed)
//   bi_out    out 16    B' imag (Q1.15 signed)
//
// Clock domain : single clock (clk)
// Reset        : synchronous, active-high (rst)
// ============================================================

module compute_core #(
    parameter DATA_WIDTH = 16
) (
    input  logic                         clk,
    input  logic                         rst,
    // control
    input  logic                         valid_in,
    // A operand
    input  logic signed [DATA_WIDTH-1:0] ar_in,
    input  logic signed [DATA_WIDTH-1:0] ai_in,
    // B operand
    input  logic signed [DATA_WIDTH-1:0] br_in,
    input  logic signed [DATA_WIDTH-1:0] bi_in,
    // twiddle W
    input  logic signed [DATA_WIDTH-1:0] wr_in,
    input  logic signed [DATA_WIDTH-1:0] wi_in,
    // outputs
    output logic                         valid_out,
    output logic signed [DATA_WIDTH-1:0] ar_out,
    output logic signed [DATA_WIDTH-1:0] ai_out,
    output logic signed [DATA_WIDTH-1:0] br_out,
    output logic signed [DATA_WIDTH-1:0] bi_out
);

    // ------------------------------------------------------------------
    // Stage 1 — four parallel signed 16×16 multiplies
    //   W·B = (wr·br − wi·bi) + j(wr·bi + wi·br)
    // Products are 32-bit signed (Q2.30); A is pipelined alongside.
    // ------------------------------------------------------------------
    logic signed [2*DATA_WIDTH-1:0] s1_wr_br, s1_wi_bi;
    logic signed [2*DATA_WIDTH-1:0] s1_wr_bi, s1_wi_br;
    logic signed [DATA_WIDTH-1:0]   s1_ar,    s1_ai;
    logic                           s1_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            s1_wr_br <= '0;  s1_wi_bi <= '0;
            s1_wr_bi <= '0;  s1_wi_br <= '0;
            s1_ar    <= '0;  s1_ai    <= '0;
            s1_valid <= 1'b0;
        end else begin
            s1_wr_br <= wr_in * br_in;
            s1_wi_bi <= wi_in * bi_in;
            s1_wr_bi <= wr_in * bi_in;
            s1_wi_br <= wi_in * br_in;
            s1_ar    <= ar_in;
            s1_ai    <= ai_in;
            s1_valid <= valid_in;
        end
    end

    // ------------------------------------------------------------------
    // Stage 2 — combine and rescale back to Q1.15
    //   Arithmetic right-shift by (DATA_WIDTH−1 = 15) rounds Q2.30 → Q1.15
    //   Truncation to DATA_WIDTH bits takes bits [DATA_WIDTH-1:0] of result.
    //   A is pipelined again.
    // ------------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] s2_wb_r, s2_wb_i;
    logic signed [DATA_WIDTH-1:0] s2_ar,   s2_ai;
    logic                         s2_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            s2_wb_r  <= '0;  s2_wb_i  <= '0;
            s2_ar    <= '0;  s2_ai    <= '0;
            s2_valid <= 1'b0;
        end else begin
            s2_wb_r  <= (s1_wr_br - s1_wi_bi) >>> (DATA_WIDTH - 1);
            s2_wb_i  <= (s1_wr_bi + s1_wi_br) >>> (DATA_WIDTH - 1);
            s2_ar    <= s1_ar;
            s2_ai    <= s1_ai;
            s2_valid <= s1_valid;
        end
    end

    // ------------------------------------------------------------------
    // Stage 3 — butterfly add / subtract
    //   A' = A + W·B
    //   B' = A − W·B
    // ------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            ar_out    <= '0;  ai_out    <= '0;
            br_out    <= '0;  bi_out    <= '0;
            valid_out <= 1'b0;
        end else begin
            ar_out    <= s2_ar + s2_wb_r;
            ai_out    <= s2_ai + s2_wb_i;
            br_out    <= s2_ar - s2_wb_r;
            bi_out    <= s2_ai - s2_wb_i;
            valid_out <= s2_valid;
        end
    end

endmodule
