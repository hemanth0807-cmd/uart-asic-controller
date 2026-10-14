`timescale 1ns/1ps

import uart_pkg::*;

module tb_uart_top;
  localparam int unsigned CLK_FREQ_HZ = 10_000_000;
  localparam int unsigned BAUD_RATE   = 1_000_000;
  localparam int unsigned DATA_WIDTH  = 8;
  localparam int unsigned OVERSAMPLE  = 8;
  localparam time CLK_PERIOD = 100ns;

  logic clk;
  logic rst_n;
  uart_parity_e parity_mode;
  logic clear_errors;
  logic [DATA_WIDTH-1:0] tx_data;
  logic tx_valid;
  logic tx_ready;
  logic tx_busy;
  logic tx_done;
  logic uart_tx;
  logic uart_rx;
  logic [DATA_WIDTH-1:0] rx_data;
  logic rx_valid;
  logic rx_ready;
  logic rx_busy;
  logic parity_error;
  logic framing_error;
  logic overrun_error;

  assign uart_rx = uart_tx;

  uart_top #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BAUD_RATE(BAUD_RATE),
    .DATA_WIDTH(DATA_WIDTH),
    .OVERSAMPLE(OVERSAMPLE)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .parity_mode_i(parity_mode),
    .clear_errors_i(clear_errors),
    .tx_data_i(tx_data),
    .tx_valid_i(tx_valid),
    .tx_ready_o(tx_ready),
    .tx_busy_o(tx_busy),
    .tx_done_o(tx_done),
    .uart_tx_o(uart_tx),
    .uart_rx_i(uart_rx),
    .rx_data_o(rx_data),
    .rx_valid_o(rx_valid),
    .rx_ready_i(rx_ready),
    .rx_busy_o(rx_busy),
    .parity_error_o(parity_error),
    .framing_error_o(framing_error),
    .overrun_error_o(overrun_error)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  task automatic send_byte(input logic [7:0] value);
    begin
      @(posedge clk);
      wait (tx_ready);
      tx_data  <= value;
      tx_valid <= 1'b1;
      @(posedge clk);
      tx_valid <= 1'b0;
      wait (rx_valid);
      if (rx_data !== value) begin
        $fatal(1, "RX mismatch: expected %02h got %02h", value, rx_data);
      end
      rx_ready <= 1'b1;
      @(posedge clk);
      rx_ready <= 1'b0;
    end
  endtask

  initial begin
    rst_n         = 1'b0;
    parity_mode   = UART_PARITY_NONE;
    clear_errors  = 1'b0;
    tx_data       = '0;
    tx_valid      = 1'b0;
    rx_ready      = 1'b0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);

    send_byte(8'hA5);
    send_byte(8'h3C);

    parity_mode = UART_PARITY_EVEN;
    repeat (5) @(posedge clk);
    send_byte(8'h55);

    if (parity_error || framing_error || overrun_error) begin
      $fatal(1, "Unexpected error flags parity=%0b framing=%0b overrun=%0b",
             parity_error, framing_error, overrun_error);
    end

    $display("UART smoke test passed");
    $finish;
  end
endmodule
