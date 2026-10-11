// Top level: UART transmitter + receiver
module uart #(
    parameter CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rst_n,

    // transmit side
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx_busy,
    output wire       tx_serial,

    // receive side
    input  wire       rx_serial,
    output wire [7:0] rx_data,
    output wire       rx_valid,
    output wire       rx_frame_err
);

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk   (clk),
        .rst_n (rst_n),
        .start (tx_start),
        .data  (tx_data),
        .tx    (tx_serial),
        .busy  (tx_busy)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .clk       (clk),
        .rst_n     (rst_n),
        .rx        (rx_serial),
        .data      (rx_data),
        .valid     (rx_valid),
        .frame_err (rx_frame_err)
    );

endmodule
