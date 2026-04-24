// ============================================================
// mac_tb.v — Testbench for mac module (CF04 CLLM)
// Tests mac_correct.v (compile together)
//
// Sequence:
//   1. Assert rst for 1 cycle
//   2. a=3, b=4 for 3 cycles  → expect out = 12, 24, 36
//   3. Assert rst for 1 cycle → expect out = 0
//   4. a=-5, b=2 for 2 cycles → expect out = -10, -20
// ============================================================
`timescale 1ns/1ps

module mac_tb;

    // DUT signals
    logic              clk;
    logic              rst;
    logic signed [7:0] a;
    logic signed [7:0] b;
    logic signed [31:0] out;

    // Instantiate DUT
    mac dut (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .out(out)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Pass/fail counter
    integer pass_count = 0;
    integer fail_count = 0;

    task check;
        input signed [31:0] expected;
        input [127:0] label;
        begin
            if (out === expected) begin
                $display("PASS  %s: out = %0d", label, out);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL  %s: out = %0d (expected %0d)", label, out, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // ---- Reset ----
        rst = 1; a = 0; b = 0;
        @(posedge clk); #1;          // cycle 0: reset active

        rst = 0;
        // ---- Phase 1: a=3, b=4 for 3 cycles ----
        a = 8'sd3; b = 8'sd4;

        @(posedge clk); #1;          // cycle 1: out = 0 + 12 = 12
        check(32'sd12,  "cycle1 [a=3,b=4]");

        @(posedge clk); #1;          // cycle 2: out = 12 + 12 = 24
        check(32'sd24,  "cycle2 [a=3,b=4]");

        @(posedge clk); #1;          // cycle 3: out = 24 + 12 = 36
        check(32'sd36,  "cycle3 [a=3,b=4]");

        // ---- Reset ----
        rst = 1;
        @(posedge clk); #1;          // cycle 4: reset
        check(32'sd0,   "rst    [out=0] ");

        // ---- Phase 2: a=-5, b=2 for 2 cycles ----
        rst = 0;
        a = -8'sd5; b = 8'sd2;

        @(posedge clk); #1;          // cycle 5: out = 0 + (-10) = -10
        check(-32'sd10, "cycle5 [a=-5,b=2]");

        @(posedge clk); #1;          // cycle 6: out = -10 + (-10) = -20
        check(-32'sd20, "cycle6 [a=-5,b=2]");

        // ---- Summary ----
        $display("-------------------------------");
        $display("Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("-------------------------------");

        $finish;
    end

endmodule
