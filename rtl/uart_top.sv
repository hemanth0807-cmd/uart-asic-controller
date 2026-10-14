import uart_pkg::*;

module uart_top #(
  parameter int unsigned CLK_FREQ_HZ = 100_000_000,
  parameter int unsigned BAUD_RATE   = 115_200,
  parameter int unsigned DATA_WIDTH  = 8,
  parameter int unsigned OVERSAMPLE  = 16
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  uart_parity_e          parity_mode_i,
  input  logic                  clear_errors_i,

  input  logic [DATA_WIDTH-1:0] tx_data_i,
  input  logic                  tx_valid_i,
  output logic                  tx_ready_o,
  output logic                  tx_busy_o,
  output logic                  tx_done_o,
  output logic                  uart_tx_o,

  input  logic                  uart_rx_i,
  output logic [DATA_WIDTH-1:0] rx_data_o,
  output logic                  rx_valid_o,
  input  logic                  rx_ready_i,
  output logic                  rx_busy_o,

  output logic                  parity_error_o,
  output logic                  framing_error_o,
  output logic                  overrun_error_o
);
  logic           baud_tick;
  logic           sample_tick;
  logic           tx_start;
  logic           tx_load;
  logic           tx_shift;
  logic           tx_bit_last;
  uart_tx_sel_e   tx_sel;
  uart_tx_state_e tx_state;

  logic           uart_rx_sync;
  logic           rx_frame_start;
  logic           rx_bit_clear;
  logic           rx_data_sample;
  logic           rx_parity_sample;
  logic           rx_stop_sample;
  logic           rx_bit_last;
  logic           rx_done;
  logic           received_parity;
  logic           expected_rx_parity;
  logic           parity_error_at_sample;
  logic           frame_has_error;
  logic           overrun_event;
  uart_rx_state_e rx_state;

  assign tx_start      = tx_valid_i && tx_ready_o;
  assign overrun_event = rx_done && rx_valid_o && !rx_ready_i;

  uart_baud_gen #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BAUD_RATE(BAUD_RATE),
    .OVERSAMPLE(OVERSAMPLE)
  ) u_baud_gen (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .baud_tick_o(baud_tick),
    .sample_tick_o(sample_tick)
  );

  uart_tx_fsm u_tx_fsm (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .tx_start_i(tx_start),
    .baud_tick_i(baud_tick),
    .bit_last_i(tx_bit_last),
    .parity_mode_i(parity_mode_i),
    .tx_state_o(tx_state),
    .tx_sel_o(tx_sel),
    .tx_load_o(tx_load),
    .tx_shift_o(tx_shift),
    .tx_ready_o(tx_ready_o),
    .tx_busy_o(tx_busy_o),
    .tx_done_o(tx_done_o)
  );

  uart_tx_datapath #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_tx_datapath (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .tx_data_i(tx_data_i),
    .load_i(tx_load),
    .shift_i(tx_shift),
    .tx_sel_i(tx_sel),
    .parity_mode_i(parity_mode_i),
    .bit_last_o(tx_bit_last),
    .uart_tx_o(uart_tx_o)
  );

  uart_rx_synchronizer u_rx_synchronizer (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .uart_rx_i(uart_rx_i),
    .uart_rx_sync_o(uart_rx_sync)
  );

  uart_rx_fsm #(
    .DATA_WIDTH(DATA_WIDTH),
    .OVERSAMPLE(OVERSAMPLE)
  ) u_rx_fsm (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .sample_tick_i(sample_tick),
    .uart_rx_sync_i(uart_rx_sync),
    .bit_last_i(rx_bit_last),
    .parity_mode_i(parity_mode_i),
    .rx_state_o(rx_state),
    .frame_start_o(rx_frame_start),
    .bit_count_clear_o(rx_bit_clear),
    .data_sample_o(rx_data_sample),
    .parity_sample_o(rx_parity_sample),
    .stop_sample_o(rx_stop_sample),
    .rx_busy_o(rx_busy_o),
    .rx_done_o(rx_done)
  );

  uart_rx_datapath #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_rx_datapath (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .clear_i(rx_bit_clear),
    .data_sample_i(rx_data_sample),
    .parity_sample_i(rx_parity_sample),
    .uart_rx_sync_i(uart_rx_sync),
    .rx_data_o(rx_data_o),
    .received_parity_o(received_parity),
    .bit_last_o(rx_bit_last)
  );

  uart_parity_gen #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_rx_parity_gen (
    .data_i(rx_data_o),
    .parity_mode_i(parity_mode_i),
    .parity_bit_o(expected_rx_parity)
  );

  assign parity_error_at_sample = (parity_mode_i != UART_PARITY_NONE) &&
                                  (uart_rx_sync ^ expected_rx_parity);

  uart_error_detection u_error_detection (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .clear_errors_i(clear_errors_i),
    .frame_start_i(rx_frame_start),
    .stop_sample_i(rx_stop_sample),
    .stop_bit_i(uart_rx_sync),
    .parity_sample_i(rx_parity_sample),
    .parity_error_i(parity_error_at_sample),
    .overrun_i(overrun_event),
    .frame_has_error_o(frame_has_error),
    .parity_error_o(parity_error_o),
    .framing_error_o(framing_error_o),
    .overrun_error_o(overrun_error_o)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rx_valid_o <= 1'b0;
    end else begin
      if (rx_ready_i) begin
        rx_valid_o <= 1'b0;
      end

      if (rx_done && !frame_has_error && !(rx_valid_o && !rx_ready_i)) begin
        rx_valid_o <= 1'b1;
      end
    end
  end
endmodule
