module uart_top #(
  parameter DATA_WIDTH = 8,
  parameter CLK_FREQ   = 50_000_000,
  parameter BAUD_RATE  = 115_200,
  parameter OVERSAMPLE = 16
) (
  clk,
  rst_n,
  tx_start,
  tx_data,
  tx,
  tx_busy,
  tx_done,
  rx,
  rx_data,
  rx_valid,
  rx_busy,
  framing_error
);
  input clk;
  input rst_n;
  input tx_start;
  input [DATA_WIDTH-1:0] tx_data;
  output tx;
  output tx_busy;
  output tx_done;
  input rx;
  output [DATA_WIDTH-1:0] rx_data;
  output rx_valid;
  output rx_busy;
  output framing_error;

  wire tx_baud_tick;
  wire rx_sample_tick;

  baud_gen #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE),
    .OVERSAMPLE(1)
  ) u_tx_baud_gen (
    .clk(clk),
    .rst_n(rst_n),
    .tick(tx_baud_tick)
  );

  baud_gen #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE),
    .OVERSAMPLE(OVERSAMPLE)
  ) u_rx_baud_gen (
    .clk(clk),
    .rst_n(rst_n),
    .tick(rx_sample_tick)
  );

  uart_tx #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_uart_tx (
    .clk(clk),
    .rst_n(rst_n),
    .baud_tick(tx_baud_tick),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx(tx),
    .tx_busy(tx_busy),
    .tx_done(tx_done)
  );

  uart_rx #(
    .DATA_WIDTH(DATA_WIDTH),
    .OVERSAMPLE(OVERSAMPLE)
  ) u_uart_rx (
    .clk(clk),
    .rst_n(rst_n),
    .sample_tick(rx_sample_tick),
    .rx(rx),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_busy(rx_busy),
    .framing_error(framing_error)
  );
endmodule
