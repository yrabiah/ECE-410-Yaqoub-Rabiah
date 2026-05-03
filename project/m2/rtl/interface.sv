// ============================================================
// interface.sv — SPI Slave Interface Module
// Project : 256-pt FFT Vibration Anomaly Detection Accelerator
// Course  : ECE 410/510 HW4AI, Spring 2026
// Author  : Yaqoub Rabiah
//
// Description:
//   SPI slave compliant with Mode 0 (CPOL=0, CPHA=0).
//   Transfers one DATA_WIDTH-bit word per transaction:
//     - Write (host→chip): CS_n falls, host clocks DATA_WIDTH bits
//       MSB-first on MOSI; rx_data and rx_valid asserted after the
//       final rising SCLK edge.
//     - Read (chip→host): tx_data must be stable before CS_n falls;
//       it is loaded into the TX shift register on CS_n falling edge
//       and shifted out MSB-first, changing on each falling SCLK edge.
//
//   SPI signals are asynchronous to clk; a 3-flop synchronizer chain
//   is used for SCLK, CS_n, and MOSI before edge detection.
//
// Transaction format (16-bit word):
//   Bits [15:8] — high byte of sample (INT16 MSB)
//   Bits  [7:0] — low byte of sample  (INT16 LSB)
//   Clock polarity : CPOL = 0 (SCLK idle LOW)
//   Clock phase    : CPHA = 0 (data captured on rising SCLK)
//
// Register / address map:
//   This module implements a single 16-bit data register.
//   Each CS transaction is one atomic read or write of that register.
//   No explicit address phase; direction determined by initiator.
//
// Port list:
//   clk       in   1    system clock (single domain, ≥10× SPI rate)
//   rst       in   1    synchronous active-high reset
//   spi_sclk  in   1    SPI serial clock from master (async)
//   spi_cs_n  in   1    SPI chip-select, active-low (async)
//   spi_mosi  in   1    master→slave data (async)
//   spi_miso  out  1    slave→master data
//   rx_data   out 16    last received word (stable after rx_valid)
//   rx_valid  out  1    pulses high 1 cycle when rx_data is new
//   tx_data   in  16    word to shift out on next read transaction
//
// Clock domain : single (clk); SPI signals synchronized via 3-FF chain
// Reset        : synchronous, active-high (rst)
// ============================================================

module spi_slave #(
    parameter DATA_WIDTH = 16
) (
    input  logic                          clk,
    input  logic                          rst,
    // SPI port (Mode 0 — CPOL=0, CPHA=0)
    input  logic                          spi_sclk,
    input  logic                          spi_cs_n,
    input  logic                          spi_mosi,
    output logic                          spi_miso,
    // Core-side data interface
    output logic [DATA_WIDTH-1:0]         rx_data,
    output logic                          rx_valid,
    input  logic [DATA_WIDTH-1:0]         tx_data
);

    // ------------------------------------------------------------------
    // 3-flop synchronizers for asynchronous SPI inputs
    // sclk_r[0] = newest capture, sclk_r[2] = oldest
    // ------------------------------------------------------------------
    logic [2:0] sclk_r, cs_r;
    logic [1:0] mosi_r;

    always_ff @(posedge clk) begin
        if (rst) begin
            sclk_r <= 3'b000;
            cs_r   <= 3'b111;   // CS_n idle high
            mosi_r <= 2'b00;
        end else begin
            sclk_r <= {sclk_r[1:0], spi_sclk};
            cs_r   <= {cs_r[1:0],   spi_cs_n};
            mosi_r <= {mosi_r[0],   spi_mosi};
        end
    end

    // ------------------------------------------------------------------
    // Edge and level detection on synchronized signals
    // ------------------------------------------------------------------
    wire sclk_posedge_det = (sclk_r[2:1] == 2'b01);
    wire sclk_negedge_det = (sclk_r[2:1] == 2'b10);
    wire cs_n_fall        = (cs_r[2:1]   == 2'b10);
    wire cs_n_active      = ~cs_r[2];          // CS_n is asserted (low)
    wire mosi_stable      = mosi_r[1];

    // ------------------------------------------------------------------
    // Shift registers and bit counter
    // ------------------------------------------------------------------
    logic [DATA_WIDTH-1:0]        rx_shift;
    logic [DATA_WIDTH-1:0]        tx_shift;
    logic [$clog2(DATA_WIDTH):0]  bit_cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            rx_shift <= '0;
            tx_shift <= '0;
            rx_data  <= '0;
            rx_valid <= 1'b0;
            bit_cnt  <= '0;
            spi_miso <= 1'b0;
        end else begin
            rx_valid <= 1'b0;               // default: deassert each cycle

            if (cs_n_fall) begin
                // Load TX register and pre-drive MSB onto MISO
                tx_shift <= tx_data;
                spi_miso <= tx_data[DATA_WIDTH-1];
                bit_cnt  <= '0;
            end else if (cs_n_active) begin
                if (sclk_posedge_det) begin
                    // Capture MOSI on rising SCLK
                    rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi_stable};
                    bit_cnt  <= bit_cnt + 1;
                    if (bit_cnt == (DATA_WIDTH - 1)) begin
                        rx_data  <= {rx_shift[DATA_WIDTH-2:0], mosi_stable};
                        rx_valid <= 1'b1;
                    end
                end
                if (sclk_negedge_det) begin
                    // Shift TX register and drive next bit on MISO
                    tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                    spi_miso <= tx_shift[DATA_WIDTH-2];
                end
            end
        end
    end

endmodule
