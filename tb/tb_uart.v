`timescale 1ns/1ps

// Loopback testbench: tx_serial is wired straight into rx_serial.
module tb_uart;

    localparam CLKS_PER_BIT = 16;          // small value so simulation is fast

    reg        clk = 0;
    reg        rst_n = 0;
    reg        tx_start = 0;
    reg  [7:0] tx_data = 8'd0;
    wire       tx_busy, tx_serial;
    wire [7:0] rx_data;
    wire       rx_valid, rx_frame_err;

    uart #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
        .clk(clk), .rst_n(rst_n),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx_busy(tx_busy), .tx_serial(tx_serial),
        .rx_serial(tx_serial),             // loopback
        .rx_data(rx_data), .rx_valid(rx_valid), .rx_frame_err(rx_frame_err)
    );

    always #5 clk = ~clk;                  // 100 MHz

    integer errors = 0;
    integer t;

    task send_and_check(input [7:0] b);
        begin
            @(negedge clk);
            while (tx_busy) @(negedge clk);
            tx_data  = b;
            tx_start = 1'b1;
            @(negedge clk);
            tx_start = 1'b0;

            t = 0;
            while (!rx_valid && !rx_frame_err && t < CLKS_PER_BIT * 20) begin
                @(negedge clk);
                t = t + 1;
            end

            if (rx_frame_err) begin
                $display("FAIL: sent 0x%02h, framing error", b);
                errors = errors + 1;
            end else if (!rx_valid) begin
                $display("FAIL: sent 0x%02h, timeout, nothing received", b);
                errors = errors + 1;
            end else if (rx_data !== b) begin
                $display("FAIL: sent 0x%02h, received 0x%02h", b, rx_data);
                errors = errors + 1;
            end else begin
                $display("PASS: sent 0x%02h, received 0x%02h", b, rx_data);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_uart.vcd");
        $dumpvars(0, tb_uart);

        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (4) @(negedge clk);

        send_and_check(8'h55);
        send_and_check(8'hA3);
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'h7E);
        send_and_check(8'h81);

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule
