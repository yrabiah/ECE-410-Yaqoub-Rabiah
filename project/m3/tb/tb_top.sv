// ============================================================
// tb_top.sv — End-to-End Co-Simulation Testbench
// Project : 256-pt FFT Vibration Anomaly Detection Accelerator
// Course  : ECE 410/510 HW4AI, Spring 2026
// Author  : Yaqoub Rabiah
//
// Description:
//   Exercises top.sv end-to-end through the SPI interface only.
//   No compute_core or spi_slave ports are accessed directly.
//   The testbench acts as an SPI master (Mode 0: CPOL=0, CPHA=0).
//
// Test vector (dominant kernel from M1: 256-pt FFT butterfly):
//   Input:   A = 100+0j, B = 100+0j, W = 0.5+0j (Q1.15: 0x4000)
//   Expected (hand-calculated):
//     W·B  = (0.5)(100)+0j = 50+0j
//     A'   = A + W·B = 150+0j  → ar_out=0x0096, ai_out=0x0000
//     B'   = A - W·B =  50+0j  → br_out=0x0032, bi_out=0x0000
//
// SPI timing:
//   System clock : 100 MHz (10 ns period)
//   SPI half-period: 8 system clock cycles (SCLK = ~6.25 MHz)
//   All SPI signals change on negedge clk; sampled by DUT at posedge.
//
// Commands:
//   WRITE_CMD = 0x0001  — begins 6-word operand receive sequence
//   READ_CMD  = 0x0002  — begins 4-word output readback sequence
// ============================================================

`timescale 1ns/1ps

module tb_top;

    // ------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------
    logic clk, rst;
    logic spi_sclk, spi_cs_n, spi_mosi, spi_miso;

    // ------------------------------------------------------------------
    // DUT instantiation — access ONLY through SPI pins
    // ------------------------------------------------------------------
    top dut (
        .clk      (clk),
        .rst      (rst),
        .spi_sclk (spi_sclk),
        .spi_cs_n (spi_cs_n),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso)
    );

    // ------------------------------------------------------------------
    // 100 MHz system clock
    // ------------------------------------------------------------------
    initial clk = 0;
    always  #5 clk = ~clk;

    // ------------------------------------------------------------------
    // SPI master task — Mode 0 (CPOL=0, CPHA=0)
    //
    // Protocol per bit:
    //   MOSI set on negedge (stable before rising SCLK)
    //   Rising SCLK: DUT captures MOSI[i] via 3-FF sync (2 cycles + 1 FF)
    //   Falling SCLK: DUT shifts MISO to next bit (2 cycles + 1 FF)
    //   MISO sampled after HALF cycles following falling SCLK
    //
    // cs_n fall pre-drives MISO[15]; sampled before first rising SCLK.
    // ------------------------------------------------------------------
    localparam HALF = 8;   // system clocks per SPI half period

    task spi_txn;
        input  [15:0] tx;
        output [15:0] rx;
        integer i;
        begin
            rx = 16'h0000;

            // Assert CS_n and set first MOSI bit (MSB)
            @(negedge clk); spi_cs_n = 0; spi_mosi = tx[15];

            // Wait for cs_n_fall detection (2 sync cycles + 1 FF) + margin
            repeat(HALF) @(posedge clk);
            rx[15] = spi_miso;   // capture MSB pre-driven by slave

            // Clock out all 16 bits
            for (i = 15; i >= 0; i = i - 1) begin
                // Rising SCLK: DUT captures MOSI[i]
                @(negedge clk); spi_sclk = 1;
                repeat(HALF) @(posedge clk);

                // Falling SCLK: DUT shifts MISO; update MOSI for next bit
                @(negedge clk);
                spi_sclk = 0;
                if (i > 0) spi_mosi = tx[i-1];

                // Wait for DUT to update MISO via 3-FF (2 sync + 1 FF)
                repeat(HALF) @(posedge clk);

                // Capture next MISO bit (valid after falling SCLK + sync)
                if (i > 0) rx[i-1] = spi_miso;
            end

            // Deassert CS_n; inter-transaction gap
            @(negedge clk); spi_cs_n = 1;
            repeat(HALF * 3) @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------------
    // Test variables
    // ------------------------------------------------------------------
    integer pass_cnt, fail_cnt;
    logic [15:0] rx_word, dummy;

    // ------------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------------
    initial begin
        // Initialise
        pass_cnt = 0; fail_cnt = 0;
        spi_sclk = 0; spi_cs_n = 1; spi_mosi = 0;
        rst = 1;
        repeat(5) @(posedge clk); #1;
        rst = 0;
        repeat(5) @(posedge clk);

        $display("=== M3 Co-Simulation: 256-pt FFT butterfly via SPI ===");
        $display("Input : A=100+0j  B=100+0j  W=0.5+0j (0x4000)");
        $display("Expect: A'=150+0j (0x0096,0x0000)  B'=50+0j (0x0032,0x0000)");
        $display("--------------------------------------------------------");

        // ------------------------------------------------------------------
        // WRITE PHASE: WRITE_CMD + 6 operand words
        // ------------------------------------------------------------------
        spi_txn(16'h0001, dummy);   // WRITE_CMD
        spi_txn(16'h0064, dummy);   // ar_in = 100
        spi_txn(16'h0000, dummy);   // ai_in =   0
        spi_txn(16'h0064, dummy);   // br_in = 100
        spi_txn(16'h0000, dummy);   // bi_in =   0
        spi_txn(16'h4000, dummy);   // wr_in = 0x4000 (+0.5 Q1.15)
        spi_txn(16'h0000, dummy);   // wi_in =   0  → fires compute_core

        // Wait well beyond the 3-cycle pipeline latency before reading
        repeat(40) @(posedge clk);

        // ------------------------------------------------------------------
        // READ PHASE: READ_CMD + 3 NOPs; DUT returns results on MISO
        // ------------------------------------------------------------------
        spi_txn(16'h0002, rx_word);   // READ_CMD → MISO = ar_out
        if (rx_word === 16'h0096) begin
            $display("PASS [ar_out] : got 0x%04X (150)", rx_word);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL [ar_out] : got 0x%04X, expected 0x0096 (150)", rx_word);
            fail_cnt = fail_cnt + 1;
        end

        spi_txn(16'h0000, rx_word);   // NOP → MISO = ai_out
        if (rx_word === 16'h0000) begin
            $display("PASS [ai_out] : got 0x%04X (0)", rx_word);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL [ai_out] : got 0x%04X, expected 0x0000 (0)", rx_word);
            fail_cnt = fail_cnt + 1;
        end

        spi_txn(16'h0000, rx_word);   // NOP → MISO = br_out
        if (rx_word === 16'h0032) begin
            $display("PASS [br_out] : got 0x%04X (50)", rx_word);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL [br_out] : got 0x%04X, expected 0x0032 (50)", rx_word);
            fail_cnt = fail_cnt + 1;
        end

        spi_txn(16'h0000, rx_word);   // NOP → MISO = bi_out
        if (rx_word === 16'h0000) begin
            $display("PASS [bi_out] : got 0x%04X (0)", rx_word);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL [bi_out] : got 0x%04X, expected 0x0000 (0)", rx_word);
            fail_cnt = fail_cnt + 1;
        end

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("--------------------------------------------------------");
        $display("%0d/4 checks PASS", pass_cnt);
        if (fail_cnt == 0)
            $display("PASS — end-to-end co-simulation PASSED");
        else
            $display("FAIL — %0d check(s) failed", fail_cnt);

        $finish;
    end

    // Watchdog
    initial begin
        #5000000;
        $display("TIMEOUT — simulation did not complete");
        $finish;
    end

endmodule
