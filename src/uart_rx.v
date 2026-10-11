// UART receiver: 8N1, LSB first, samples in the middle of each bit
module uart_rx #(
    parameter CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid,                  // 1-cycle pulse when a byte is received
    output reg        frame_err               // 1-cycle pulse if stop bit was not 1
);

    localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    // 2-flop synchronizer for the asynchronous rx input
    reg rx_m, rx_s;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_m <= 1'b1;
            rx_s <= 1'b1;
        end else begin
            rx_m <= rx;
            rx_s <= rx_m;
        end
    end

    reg [1:0]  state;
    reg [15:0] cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shreg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            cnt       <= 16'd0;
            bit_idx   <= 3'd0;
            shreg     <= 8'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
            frame_err <= 1'b0;
        end else begin
            valid     <= 1'b0;
            frame_err <= 1'b0;

            case (state)
                IDLE: begin
                    cnt     <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_s == 1'b0) state <= START;   // falling edge
                end

                START: begin                            // wait to the middle of start bit
                    if (cnt == (CLKS_PER_BIT - 1) / 2) begin
                        cnt <= 16'd0;
                        if (rx_s == 1'b0) state <= DATA;
                        else              state <= IDLE; // glitch, not a real start bit
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end

                DATA: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt   <= 16'd0;
                        shreg <= {rx_s, shreg[7:1]};     // LSB arrives first
                        if (bit_idx == 3'd7) state <= STOP;
                        else                 bit_idx <= bit_idx + 3'd1;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end

                STOP: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt   <= 16'd0;
                        state <= IDLE;
                        if (rx_s == 1'b1) begin
                            data  <= shreg;
                            valid <= 1'b1;
                        end else begin
                            frame_err <= 1'b1;
                        end
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end
            endcase
        end
    end

endmodule
