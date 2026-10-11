// UART transmitter: 8N1, LSB first
module uart_tx #(
    parameter CLKS_PER_BIT = 434          // clk_freq / baud (50 MHz / 115200)
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,              // 1-cycle pulse: load data and send
    input  wire [7:0] data,
    output reg        tx,
    output wire       busy
);

    localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0]  state;
    reg [15:0] cnt;                       // counts clocks within one bit
    reg [2:0]  bit_idx;
    reg [7:0]  shreg;

    assign busy = (state != IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            tx      <= 1'b1;
            cnt     <= 16'd0;
            bit_idx <= 3'd0;
            shreg   <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    cnt     <= 16'd0;
                    bit_idx <= 3'd0;
                    if (start) begin
                        shreg <= data;
                        tx    <= 1'b0;            // start bit
                        state <= START;
                    end
                end

                START: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt   <= 16'd0;
                        tx    <= shreg[0];        // first data bit
                        state <= DATA;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end

                DATA: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt <= 16'd0;
                        if (bit_idx == 3'd7) begin
                            tx    <= 1'b1;        // stop bit
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                            tx      <= shreg[1];  // next bit
                            shreg   <= {1'b0, shreg[7:1]};
                        end
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end

                STOP: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt   <= 16'd0;
                        state <= IDLE;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end
            endcase
        end
    end

endmodule
