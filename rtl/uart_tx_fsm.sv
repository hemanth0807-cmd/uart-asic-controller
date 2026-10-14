import uart_pkg::*;

module uart_tx_fsm (
  input  logic           clk_i,
  input  logic           rst_ni,
  input  logic           tx_start_i,
  input  logic           baud_tick_i,
  input  logic           bit_last_i,
  input  uart_parity_e   parity_mode_i,
  output uart_tx_state_e tx_state_o,
  output uart_tx_sel_e   tx_sel_o,
  output logic           tx_load_o,
  output logic           tx_shift_o,
  output logic           tx_ready_o,
  output logic           tx_busy_o,
  output logic           tx_done_o
);
  uart_tx_state_e state_q;
  uart_tx_state_e state_d;

  logic parity_en;

  assign parity_en  = (parity_mode_i != UART_PARITY_NONE);
  assign tx_state_o = state_q;
  assign tx_ready_o = (state_q == UART_TX_IDLE);
  assign tx_busy_o  = (state_q != UART_TX_IDLE);

  always_comb begin
    state_d    = state_q;
    tx_load_o  = 1'b0;
    tx_shift_o = 1'b0;
    tx_done_o  = 1'b0;
    tx_sel_o   = UART_TX_SEL_STOP;

    unique case (state_q)
      UART_TX_IDLE: begin
        tx_sel_o = UART_TX_SEL_STOP;
        if (tx_start_i) begin
          tx_load_o = 1'b1;
          state_d   = UART_TX_START;
        end
      end

      UART_TX_START: begin
        tx_sel_o = UART_TX_SEL_START;
        if (baud_tick_i) begin
          state_d = UART_TX_DATA;
        end
      end

      UART_TX_DATA: begin
        tx_sel_o = UART_TX_SEL_DATA;
        if (baud_tick_i) begin
          if (bit_last_i) begin
            state_d = parity_en ? UART_TX_PARITY : UART_TX_STOP;
          end else begin
            tx_shift_o = 1'b1;
          end
        end
      end

      UART_TX_PARITY: begin
        tx_sel_o = UART_TX_SEL_PARITY;
        if (baud_tick_i) begin
          state_d = UART_TX_STOP;
        end
      end

      UART_TX_STOP: begin
        tx_sel_o = UART_TX_SEL_STOP;
        if (baud_tick_i) begin
          state_d = UART_TX_DONE;
        end
      end

      UART_TX_DONE: begin
        tx_sel_o  = UART_TX_SEL_STOP;
        tx_done_o = 1'b1;
        state_d   = UART_TX_IDLE;
      end

      default: begin
        state_d = UART_TX_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= UART_TX_IDLE;
    end else begin
      state_q <= state_d;
    end
  end
endmodule
