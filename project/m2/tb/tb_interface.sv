// ============================================================
// tb_interface.sv — Testbench for interface.sv (SPI Slave)
// Course  : ECE 410/510 HW4AI, Spring 2026
//
// SPI Mode 0 (CPOL=0, CPHA=0):
//   - SCLK idle LOW
//   - Data captured on rising SCLK
//   - Data driven on falling SCLK (or before first rising)
//
// SPI timing in this testbench:
//   System clock  : 10 ns period (100 MHz)
//   SPI bit period: 6 system clocks (60 ns → ~16.7 MHz SPI)
//   SPI signals are driven on negedge of system clk so that
//   the 3-FF synchronizer inside the DUT meets setup time.
//
// Transactions:
//   Write test : send WRITE_WORD = 0xA5C3 on MOSI
//                verify rx_data == 0xA5C3 and rx_valid pulses
//   Read  test : pre-load TX_WORD = 0x7B2E into tx_data
//                perform a 16-clock SPI transaction
//                capture MISO bits and verify == 0x7B2E
// ============================================================
`timescale 1ns/1ps

module tb_interface;

    // ---- DUT signals ----
    logic        clk, rst;
    logic        spi_sclk, spi_cs_n, spi_mosi, spi_miso;
    logic [15:0] rx_data;
    logic        rx_valid;
    logic [15:0] tx_data;

    spi_slave #(.DATA_WIDTH(16)) dut (
        .clk(clk), .rst(rst),
        .spi_sclk(spi_sclk), .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .rx_data(rx_data), .rx_valid(rx_valid),
        .tx_data(tx_data)
    );

    // ---- VCD dump ----
    initial begin
        $dumpfile("interface.vcd");
        $dumpvars(0, tb_interface);
    end

    // ---- Clock ----
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_cnt = 0, fail_cnt = 0;

    task check16;
        input [15:0] got;
        input [15:0] exp;
        input [127:0] name;
        begin
            if (got === exp) begin
                $display("  PASS  %s = 0x%04h", name, got);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  %s = 0x%04h  (expected 0x%04h)", name, got, exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // ---- SPI write task ----
    // Drive 16 bits MSB-first on MOSI; CS_n active during transfer.
    task spi_write_txn;
        input [15:0] data;
        integer i;
        begin
            @(negedge clk);
            spi_cs_n = 1'b0;
            repeat(5) @(negedge clk);   // CS setup + sync latency (3 FF + margin)

            for (i = 15; i >= 0; i = i - 1) begin
                @(negedge clk);
                spi_mosi = data[i];        // set MOSI before rising SCLK
                @(negedge clk);
                spi_sclk = 1'b1;           // SCLK rises
                repeat(3) @(negedge clk);  // hold high: sync chain sees posedge
                spi_sclk = 1'b0;           // SCLK falls
                @(negedge clk);
            end

            repeat(4) @(negedge clk);
            spi_cs_n = 1'b1;             // deassert CS
            repeat(6) @(posedge clk);    // wait for rx_valid to propagate
        end
    endtask

    // ---- SPI read task ----
    // Clock out DATA_WIDTH bits; capture MISO into captured_miso.
    logic [15:0] captured_miso;
    task spi_read_txn;
        integer i;
        begin
            captured_miso = 16'h0;
            @(negedge clk);
            spi_cs_n = 1'b0;
            repeat(5) @(negedge clk);

            for (i = 15; i >= 0; i = i - 1) begin
                @(negedge clk);
                spi_mosi = 1'b0;           // don't care for read
                @(negedge clk);
                spi_sclk = 1'b1;
                repeat(3) @(negedge clk);
                captured_miso[i] = spi_miso;  // capture MISO at mid-high
                spi_sclk = 1'b0;
                @(negedge clk);
            end

            repeat(4) @(negedge clk);
            spi_cs_n = 1'b1;
            repeat(6) @(posedge clk);
        end
    endtask

    // ---- Stimulus ----
    localparam [15:0] WRITE_WORD = 16'hA5C3;
    localparam [15:0] TX_WORD    = 16'h7B2E;

    initial begin
        // Idle state
        rst      = 1; spi_sclk = 0; spi_cs_n = 1; spi_mosi = 0;
        tx_data  = TX_WORD;
        repeat(5) @(posedge clk); #1;
        rst = 0;
        repeat(3) @(posedge clk);

        // =============================================
        // Write transaction: send WRITE_WORD on MOSI
        // =============================================
        $display("--- Write transaction: sending 0x%04h ---", WRITE_WORD);
        spi_write_txn(WRITE_WORD);

        // Check rx_data captured the word
        check16(rx_data, WRITE_WORD, "rx_data");

        repeat(4) @(posedge clk);

        // =============================================
        // Read transaction: capture MISO, expect TX_WORD
        // =============================================
        $display("--- Read transaction: expecting 0x%04h on MISO ---", TX_WORD);
        spi_read_txn();

        check16(captured_miso, TX_WORD, "miso_word");

        // ---- Summary ----
        $display("========================================");
        if (fail_cnt == 0)
            $display("PASS  interface: %0d/%0d checks passed",
                     pass_cnt, pass_cnt + fail_cnt);
        else
            $display("FAIL  interface: %0d failures out of %0d checks",
                     fail_cnt, pass_cnt + fail_cnt);
        $display("========================================");

        $finish;
    end

endmodule
