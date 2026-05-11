// tb_crossbar_mac.sv
// Testbench for the 4×4 binary-weight crossbar MAC unit
//
// Weight matrix loaded:
//   Row 0 (input 0): [+1, -1, +1, -1]  →  w_row[0] = 4'b0101
//   Row 1 (input 1): [-1, +1, -1, +1]  →  w_row[1] = 4'b1010
//   Row 2 (input 2): [+1, +1, -1, -1]  →  w_row[2] = 4'b0011
//   Row 3 (input 3): [-1, -1, +1, +1]  →  w_row[3] = 4'b1100
//   (bit j of w_row[i] = weight[i][j]: 1→+1, 0→−1)
//
// Hand-calculated expected outputs  [out = Σ_i weight[i][j] * in[i]]:
//
//   TV1: in=[  1, -1,  1, -1]  → out=[ 4,  0,  0, -4]
//        out[0] = (+1)(1)+(-1)(-1)+(+1)(1)+(-1)(-1) = 1+1+1+1 =  4
//        out[1] = (-1)(1)+(+1)(-1)+(+1)(1)+(-1)(-1) = -1-1+1+1 = 0
//        out[2] = (+1)(1)+(-1)(-1)+(-1)(1)+(+1)(-1) = 1+1-1-1 =  0
//        out[3] = (-1)(1)+(+1)(-1)+(-1)(1)+(+1)(-1) = -1-1-1-1 = -4
//
//   TV2: in=[  2,  3, -1,  2]  → out=[-4, -2,  2,  4]
//        out[0] = (+1)(2)+(-1)(3)+(+1)(-1)+(-1)(2) = 2-3-1-2 = -4
//        out[1] = (-1)(2)+(+1)(3)+(+1)(-1)+(-1)(2) = -2+3-1-2 = -2
//        out[2] = (+1)(2)+(-1)(3)+(-1)(-1)+(+1)(2) = 2-3+1+2 =  2
//        out[3] = (-1)(2)+(+1)(3)+(-1)(-1)+(+1)(2) = -2+3+1+2 = 4
//
//   TV3: in=[  0,  0,  0,  0]  → out=[ 0,  0,  0,  0]
//        (trivially zero for any weight matrix)

`timescale 1ns/1ps

module tb_crossbar_mac;

    // -------------------------------------------------------------------
    // DUT signals
    // Note: data_out uses packed [3:0][9:0] — access element j as data_out[j]
    // -------------------------------------------------------------------
    logic        clk, rst_n, load_w, valid_in, valid_out;
    logic [3:0]  w_row    [3:0];
    logic signed [7:0]  data_in [3:0];
    logic [3:0][9:0]    data_out;       // packed; use $signed(data_out[j])

    // -------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------
    crossbar_mac dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .load_w   (load_w),
        .w_row    (w_row),
        .valid_in (valid_in),
        .data_in  (data_in),
        .valid_out(valid_out),
        .data_out (data_out)
    );

    // -------------------------------------------------------------------
    // 100 MHz clock
    // -------------------------------------------------------------------
    initial clk = 0;
    always  #5 clk = ~clk;   // 10 ns period

    // -------------------------------------------------------------------
    // Bookkeeping
    // -------------------------------------------------------------------
    integer pass_cnt, fail_cnt;
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
    end

    // -------------------------------------------------------------------
    // Main stimulus
    // -------------------------------------------------------------------
    initial begin
        // Initialise all signals
        rst_n    = 0;
        load_w   = 0;
        valid_in = 0;
        w_row[0] = 4'h0; w_row[1] = 4'h0;
        w_row[2] = 4'h0; w_row[3] = 4'h0;
        data_in[0] = 8'sd0; data_in[1] = 8'sd0;
        data_in[2] = 8'sd0; data_in[3] = 8'sd0;

        // ---------------------------------------------------------------
        // Reset for 2 cycles (synchronous, active-low)
        // ---------------------------------------------------------------
        repeat(2) @(posedge clk);
        #1; rst_n = 1;

        // ---------------------------------------------------------------
        // Load weight matrix (drive on negedge, captured on next posedge)
        //   w_row[i][j] encoding: bit j = 1 → +1, bit j = 0 → −1
        //   Row 0: [+1,-1,+1,-1] → j0=1,j1=0,j2=1,j3=0 → 4'b0101
        //   Row 1: [-1,+1,-1,+1] → j0=0,j1=1,j2=0,j3=1 → 4'b1010
        //   Row 2: [+1,+1,-1,-1] → j0=1,j1=1,j2=0,j3=0 → 4'b0011
        //   Row 3: [-1,-1,+1,+1] → j0=0,j1=0,j2=1,j3=1 → 4'b1100
        // ---------------------------------------------------------------
        @(negedge clk);
        load_w   = 1;
        w_row[0] = 4'b0101;
        w_row[1] = 4'b1010;
        w_row[2] = 4'b0011;
        w_row[3] = 4'b1100;

        @(posedge clk); #1;   // weights captured into registers
        load_w   = 0;
        valid_in = 1;

        // ---------------------------------------------------------------
        // TV1: in=[1, -1, 1, -1]   expected out=[4, 0, 0, -4]
        // ---------------------------------------------------------------
        @(negedge clk);
        data_in[0] =  8'sd1;
        data_in[1] = -8'sd1;
        data_in[2] =  8'sd1;
        data_in[3] = -8'sd1;

        @(posedge clk); #1;
        if (valid_out !== 1'b1 ||
            $signed(data_out[0]) !== 10'sd4  ||
            $signed(data_out[1]) !== 10'sd0  ||
            $signed(data_out[2]) !== 10'sd0  ||
            $signed(data_out[3]) !== -10'sd4) begin
            $display("FAIL [TV1 in=[1,-1,1,-1]]: got [%0d,%0d,%0d,%0d] exp [4,0,0,-4]",
                $signed(data_out[0]), $signed(data_out[1]),
                $signed(data_out[2]), $signed(data_out[3]));
            fail_cnt = fail_cnt + 1;
        end else begin
            $display("PASS [TV1 in=[1,-1,1,-1]]: out=[%0d,%0d,%0d,%0d]",
                $signed(data_out[0]), $signed(data_out[1]),
                $signed(data_out[2]), $signed(data_out[3]));
            pass_cnt = pass_cnt + 1;
        end

        // ---------------------------------------------------------------
        // TV2: in=[2, 3, -1, 2]   expected out=[-4, -2, 2, 4]
        // ---------------------------------------------------------------
        @(negedge clk);
        data_in[0] =  8'sd2;
        data_in[1] =  8'sd3;
        data_in[2] = -8'sd1;
        data_in[3] =  8'sd2;

        @(posedge clk); #1;
        if (valid_out !== 1'b1 ||
            $signed(data_out[0]) !== -10'sd4 ||
            $signed(data_out[1]) !== -10'sd2 ||
            $signed(data_out[2]) !== 10'sd2  ||
            $signed(data_out[3]) !== 10'sd4) begin
            $display("FAIL [TV2 in=[2,3,-1,2]]: got [%0d,%0d,%0d,%0d] exp [-4,-2,2,4]",
                $signed(data_out[0]), $signed(data_out[1]),
                $signed(data_out[2]), $signed(data_out[3]));
            fail_cnt = fail_cnt + 1;
        end else begin
            $display("PASS [TV2 in=[2,3,-1,2]]: out=[%0d,%0d,%0d,%0d]",
                $signed(data_out[0]), $signed(data_out[1]),
                $signed(data_out[2]), $signed(data_out[3]));
            pass_cnt = pass_cnt + 1;
        end

        // ---------------------------------------------------------------
        // TV3: in=[0, 0, 0, 0]   expected out=[0, 0, 0, 0]
        // ---------------------------------------------------------------
        @(negedge clk);
        data_in[0] = 8'sd0;
        data_in[1] = 8'sd0;
        data_in[2] = 8'sd0;
        data_in[3] = 8'sd0;

        @(posedge clk); #1;
        if (valid_out !== 1'b1 ||
            $signed(data_out[0]) !== 10'sd0 ||
            $signed(data_out[1]) !== 10'sd0 ||
            $signed(data_out[2]) !== 10'sd0 ||
            $signed(data_out[3]) !== 10'sd0) begin
            $display("FAIL [TV3 in=[0,0,0,0]]: got [%0d,%0d,%0d,%0d] exp [0,0,0,0]",
                $signed(data_out[0]), $signed(data_out[1]),
                $signed(data_out[2]), $signed(data_out[3]));
            fail_cnt = fail_cnt + 1;
        end else begin
            $display("PASS [TV3 in=[0,0,0,0]]: out=[%0d,%0d,%0d,%0d]",
                $signed(data_out[0]), $signed(data_out[1]),
                $signed(data_out[2]), $signed(data_out[3]));
            pass_cnt = pass_cnt + 1;
        end

        // ---------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------
        valid_in = 0;
        @(posedge clk); #1;
        $display("\n%0d/%0d tests PASS", pass_cnt, pass_cnt + fail_cnt);
        $finish;
    end

    // Watchdog
    initial begin
        #5000;
        $display("TIMEOUT — simulation did not complete");
        $finish;
    end

endmodule
