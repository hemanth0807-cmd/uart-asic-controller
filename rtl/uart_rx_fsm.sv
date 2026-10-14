import uart_pkg::*;

module uart_rx_fsm #(
  parameter int unsigned DATA_WIDTH = 8,
  parameter int unsigned OVERSAMPLE = 16
) (
  input  logic           clk_i,
  input  logic           rst_ni,
  input  logic           sample_tick_i,
  input  logic           uart_rx_sync_i,
  input  logic           bit_last_i,
  input  uart_parity_e   parity_mode_i,
  output uart_rx_state_e rx_state_o,
  output logic           frame_start_o,
  output logic           bit_count_clear_o,
  output logic           data_sample_o,
  output logic           parity_sample_o,
  output logic           stop_sample_o,
  output logic           rx_busy_o,
  output logic           rx_done_o
);
  localparam int unsigned SAMPLE_CNT_W = (OVERSAMPLE <= 1) ? 1 : $clog2(OVERSAMPLE);
  localparam int unsigned HALF_SAMPLE_INT = (OVERSAMPLE <= 2) ? 1 : (OVERSAMPLE / 2);
  localparam int unsigned FULL_SAMPLE_INT = (OVERSAMPLE <= 1) ? 1 : OVERSAMPLE;
  localparam logic [SAMPLE_CNT_W-1:0] HALF_SAMPLE_COUNT = HALF_SAMPLE_INT - 1;
  localparam logic [SAMPLE_CNT_W-1:0] FULL_SAMPLE_COUNT = FULL_SAMPLE_INT - 1;

  uart_rx_state_e state_q;
  uart_rx_state_e state_d;
  logic [SAMPLE_CNT_W-1:0] sample_cnt_q;
  logic [SAMPLE_CNT_W-1:0] sample_cnt_d;
  logic parity_en;

  assign parity_en  = (parity_mode_i != UART_PARITY_NONE);
  assign rx_state_o = state_q;
  assign rx_busy_o  = (state_q != UART_RX_IDLE);

  always_comb begin
    state_d           = state_q;
    sample_cnt_d      = sample_cnt_q;
    frame_start_o     = 1'b0;
    bit_count_clear_o = 1'b0;
    data_sample_o     = 1'b0;
    parity_sample_o   = 1'b0;
    stop_sample_o     = 1'b0;
    rx_done_o         = 1'b0;

    unique case (state_q)
      UART_RX_IDLE: begin
        sample_cnt_d = '0;
        if (!uart_rx_sync_i) begin
          frame_start_o = 1'b1;
          state_d       = UART_RX_START;
        end
      end

      UART_RX_START: begin
        if (sample_tick_i) begin
          if (sample_cnt_q == HALF_SAMPLE_COUNT) begin
            sample_cnt_d = '0;
            if (!uart_rx_sync_i) begin
              bit_count_clear_o = 1'b1;
              state_d           = UART_RX_DATA;
            end else begin
              state_d = UART_RX_IDLE;
            end
          end else begin
            sample_cnt_d = sample_cnt_q + 1'b1;
          end
        end
      end

      UART_RX_DATA: begin
        if (sample_tick_i) begin
          if (sample_cnt_q == FULL_SAMPLE_COUNT) begin
            sample_cnt_d  = '0;
            data_sample_o = 1'b1;
            if (bit_last_i) begin
              state_d = parity_en ? UART_RX_PARITY : UART_RX_STOP;
            end
          end else begin
            sample_cnt_d = sample_cnt_q + 1'b1;
          end
        end
      end

      UART_RX_PARITY: begin
        if (sample_tick_i) begin
          if (sample_cnt_q == FULL_SAMPLE_COUNT) begin
            sample_cnt_d    = '0;
            parity_sample_o = 1'b1;
            state_d         = UART_RX_STOP;
          end else begin
            sample_cnt_d = sample_cnt_q + 1'b1;
          end
        end
      end

      UART_RX_STOP: begin
        if (sample_tick_i) begin
          if (sample_cnt_q == FULL_SAMPLE_COUNT) begin
            sample_cnt_d  = '0;
            stop_sample_o = 1'b1;
            state_d       = UART_RX_DONE;
          end else begin
            sample_cnt_d = sample_cnt_q + 1'b1;
          end
        end
      end

      UART_RX_DONE: begin
        rx_done_o = 1'b1;
        state_d   = UART_RX_IDLE;
      end

      default: begin
        state_d      = UART_RX_IDLE;
        sample_cnt_d = '0;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q      <= UART_RX_IDLE;
      sample_cnt_q <= '0;
    end else begin
      state_q      <= state_d;
      sample_cnt_q <= sample_cnt_d;
    end
  end
endmodule
