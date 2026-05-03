// ============================================================
// tb_compute_core.sv — Testbench for compute_core.sv
// Course  : ECE 410/510 HW4AI, Spring 2026
//
// Reference values computed independently in Python:
//   import numpy as np
//   def q15(x): return int(round(x * 32768)) & 0xFFFF  # Q1.15 encode
//   def iq15(x): return x if x < 32768 else x - 65536   # Q1.15 decode
//
// Test vector 1  (W = 0.5 + 0j):
//   A = 100 + 0j, B = 100 + 0j, W = 0x4000 + 0j
//   W*B_r = 0x4000 * 100 >> 15 = 50
//   W*B_i = 0
//   A' = 150 + 0j   B' = 50 + 0j
//
// Test vector 2  (W = 0 + 0.5j):
//   A = 0 + 100j, B = 100 + 0j, W = 0 + 0x4000j
//   W*B_r = 0*100 - 0x4000*0   >> 15 = 0
//   W*B_i = 0*0   + 0x4000*100 >> 15 = 50
//   A' = 0 + 150j  B' = 0 + 50j
//
// Pipeline latency: 3 clock cycles.
// ============================================================
`timescale 1ns/1ps

module tb_compute_core;

    // ---- DUT signals ----
    logic        clk, rst;
    logic        valid_in, valid_out;
    logic signed [15:0] ar_in,  ai_in,  br_in,  bi_in;
    logic signed [15:0] wr_in,  wi_in;
    logic signed [15:0] ar_out, ai_out, br_out, bi_out;

    compute_core #(.DATA_WIDTH(16)) dut (
        .clk(clk), .rst(rst),
        .valid_in(valid_in),
        .ar_in(ar_in), .ai_in(ai_in),
        .br_in(br_in), .bi_in(bi_in),
        .wr_in(wr_in), .wi_in(wi_in),
        .valid_out(valid_out),
        .ar_out(ar_out), .ai_out(ai_out),
        .br_out(br_out), .bi_out(bi_out)
    );

    // ---- VCD dump for waveform viewer ----
    initial begin
        $dumpfile("compute_core.vcd");
        $dumpvars(0, tb_compute_core);
    end

    // ---- Clock: 10 ns period ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Pass/fail tracking ----
    integer pass_cnt = 0, fail_cnt = 0;

    task check16;
        input signed [15:0] got;
        input signed [15:0] exp;
        input [127:0]        name;
        begin
            if (got === exp) begin
                $display("  PASS  %s = %0d", name, got);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %s = %0d  (expected %0d)", name, got, exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // ---- Stimulus ----
    initial begin
        // Reset
        rst = 1; valid_in = 0;
        ar_in = 0; ai_in = 0; br_in = 0; bi_in = 0;
        wr_in = 0; wi_in = 0;
        repeat(3) @(posedge clk); #1;
        rst = 0;

        // ---- Vector 1: W = 0.5+0j, A = 100+0j, B = 100+0j ----
        // Expected: A' = 150+0j, B' = 50+0j
        @(posedge clk); #1;
        valid_in = 1;
        ar_in = 16'sd100;   ai_in = 16'sd0;
        br_in = 16'sd100;   bi_in = 16'sd0;
        wr_in = 16'h4000;   wi_in = 16'sd0;   // 0x4000 = 0.5 in Q1.15

        @(posedge clk); #1;
        valid_in = 0;

        // Pipeline latency = 3 cycles; valid_in was applied 1 cycle ago,
        // so wait 2 more rising edges to land exactly on the output cycle.
        repeat(2) @(posedge clk); #1;

        $display("--- Vector 1: W=0.5+0j, A=100+0j, B=100+0j ---");
        $display("    valid_out = %0b  (expected 1)", valid_out);
        check16(ar_out, 16'sd150, "ar_out");
        check16(ai_out, 16'sd0,   "ai_out");
        check16(br_out, 16'sd50,  "br_out");
        check16(bi_out, 16'sd0,   "bi_out");

        // ---- Vector 2: W = 0+0.5j, A = 0+100j, B = 100+0j ----
        // Expected: A' = 0+150j, B' = 0+50j
        @(posedge clk); #1;
        valid_in = 1;
        ar_in = 16'sd0;    ai_in = 16'sd100;
        br_in = 16'sd100;  bi_in = 16'sd0;
        wr_in = 16'sd0;    wi_in = 16'h4000;   // 0x4000 = 0.5 in Q1.15

        @(posedge clk); #1;
        valid_in = 0;

        repeat(2) @(posedge clk); #1;

        $display("--- Vector 2: W=0+0.5j, A=0+100j, B=100+0j ---");
        $display("    valid_out = %0b  (expected 1)", valid_out);
        check16(ar_out, 16'sd0,   "ar_out");
        check16(ai_out, 16'sd150, "ai_out");
        check16(br_out, 16'sd0,   "br_out");
        check16(bi_out, 16'sd50,  "bi_out");

        // ---- Summary ----
        $display("========================================");
        if (fail_cnt == 0)
            $display("PASS  compute_core: %0d/%0d checks passed",
                     pass_cnt, pass_cnt + fail_cnt);
        else
            $display("FAIL  compute_core: %0d failures out of %0d checks",
                     fail_cnt, pass_cnt + fail_cnt);
        $display("========================================");

        $finish;
    end

endmodule
