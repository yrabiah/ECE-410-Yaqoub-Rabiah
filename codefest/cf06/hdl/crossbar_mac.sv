// crossbar_mac.sv  — LLM-generated (Claude Sonnet 4.6)
//
// 4×4 binary-weight crossbar MAC unit
//
// Weight encoding:  weight[i][j] = 1 → multiplier +1
//                   weight[i][j] = 0 → multiplier −1
//                   Stored as a 4-bit vector per input row:
//                     w_row[i][j] = bit j of w_row[i]
//
// Computation (each clock cycle, when valid_in=1):
//   out[j] = Σ_{i=0}^{3}  (weight[i][j] ? +data_in[i] : −data_in[i])
//
// Latency:  1 clock cycle — inputs sampled, outputs registered on same posedge
// Width:    data_in  8-bit signed  (range −128 … +127)
//           data_out 10-bit signed (max |sum| = 4 × 127 = 508 < 512 = 2^9)
//
// Port note:  data_out is a packed 2D array [3:0][9:0] to work around an
//             iverilog limitation where always_ff cannot drive unpacked array
//             output logic ports.  Access element j as data_out[j] (10 bits).
//
// Interface:
//   load_w   — hold high for one cycle with w_row valid to load weight registers
//   valid_in — assert to present new input vector; valid_out pulses one cycle later

`timescale 1ns/1ps

module crossbar_mac (
    input  logic        clk,
    input  logic        rst_n,        // active-low synchronous reset

    // Weight loading
    input  logic        load_w,
    input  logic [3:0]  w_row [3:0],  // w_row[i][j]: 1=+1 weight, 0=−1 weight

    // Streaming data
    input  logic        valid_in,
    input  logic signed [7:0] data_in [3:0],  // 8-bit signed inputs

    // Outputs (packed [3:0][9:0]: element j = data_out[j], 10-bit signed value)
    output logic        valid_out,
    output logic [3:0][9:0] data_out  // 10-bit signed results, packed for iverilog compat
);

    // -----------------------------------------------------------------------
    // Weight register file  (weight[i] stores row i; bit j = weight[i][j])
    // -----------------------------------------------------------------------
    logic [3:0] weight [3:0];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            weight[0] <= 4'h0;  weight[1] <= 4'h0;
            weight[2] <= 4'h0;  weight[3] <= 4'h0;
        end else if (load_w) begin
            weight[0] <= w_row[0];  weight[1] <= w_row[1];
            weight[2] <= w_row[2];  weight[3] <= w_row[3];
        end
    end

    // -----------------------------------------------------------------------
    // Sign-extend 8-bit inputs to 10 bits (combinational)
    // -----------------------------------------------------------------------
    logic signed [9:0] e0, e1, e2, e3;
    assign e0 = {{2{data_in[0][7]}}, data_in[0]};
    assign e1 = {{2{data_in[1][7]}}, data_in[1]};
    assign e2 = {{2{data_in[2][7]}}, data_in[2]};
    assign e3 = {{2{data_in[3][7]}}, data_in[3]};

    // -----------------------------------------------------------------------
    // Internal scalar output registers (iverilog requires scalars in always_ff;
    // then drive the packed output port via continuous assign)
    // -----------------------------------------------------------------------
    logic        vo_r;
    logic signed [9:0] do0_r, do1_r, do2_r, do3_r;

    // Registered MAC:  data_out[j] = Σ_i ±e{i}  according to weight[i][j]
    // The crossbar routes each input to every output column; the binary weight
    // at each intersection determines the sign (+1 or −1) before accumulation.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            vo_r  <= 1'b0;
            do0_r <= 10'sb0;  do1_r <= 10'sb0;
            do2_r <= 10'sb0;  do3_r <= 10'sb0;
        end else begin
            vo_r <= valid_in;
            if (valid_in) begin
                // Column 0: out[0] = Σ_i weight[i][0]*in[i]
                do0_r <= (weight[0][0] ? e0 : -e0)
                       + (weight[1][0] ? e1 : -e1)
                       + (weight[2][0] ? e2 : -e2)
                       + (weight[3][0] ? e3 : -e3);
                // Column 1: out[1] = Σ_i weight[i][1]*in[i]
                do1_r <= (weight[0][1] ? e0 : -e0)
                       + (weight[1][1] ? e1 : -e1)
                       + (weight[2][1] ? e2 : -e2)
                       + (weight[3][1] ? e3 : -e3);
                // Column 2: out[2] = Σ_i weight[i][2]*in[i]
                do2_r <= (weight[0][2] ? e0 : -e0)
                       + (weight[1][2] ? e1 : -e1)
                       + (weight[2][2] ? e2 : -e2)
                       + (weight[3][2] ? e3 : -e3);
                // Column 3: out[3] = Σ_i weight[i][3]*in[i]
                do3_r <= (weight[0][3] ? e0 : -e0)
                       + (weight[1][3] ? e1 : -e1)
                       + (weight[2][3] ? e2 : -e2)
                       + (weight[3][3] ? e3 : -e3);
            end
        end
    end

    // Drive packed output port from internal scalar registers
    assign valid_out   = vo_r;
    assign data_out[0] = do0_r;
    assign data_out[1] = do1_r;
    assign data_out[2] = do2_r;
    assign data_out[3] = do3_r;

endmodule
