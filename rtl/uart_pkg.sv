package uart_pkg;
  typedef enum logic [1:0] {
    UART_PARITY_NONE = 2'b00,
    UART_PARITY_EVEN = 2'b01,
    UART_PARITY_ODD  = 2'b10
  } uart_parity_e;

  typedef enum logic [2:0] {
    UART_TX_IDLE   = 3'd0,
    UART_TX_START  = 3'd1,
    UART_TX_DATA   = 3'd2,
    UART_TX_PARITY = 3'd3,
    UART_TX_STOP   = 3'd4,
    UART_TX_DONE   = 3'd5
  } uart_tx_state_e;

  typedef enum logic [2:0] {
    UART_RX_IDLE   = 3'd0,
    UART_RX_START  = 3'd1,
    UART_RX_DATA   = 3'd2,
    UART_RX_PARITY = 3'd3,
    UART_RX_STOP   = 3'd4,
    UART_RX_DONE   = 3'd5
  } uart_rx_state_e;

  typedef enum logic [1:0] {
    UART_TX_SEL_START  = 2'd0,
    UART_TX_SEL_DATA   = 2'd1,
    UART_TX_SEL_PARITY = 2'd2,
    UART_TX_SEL_STOP   = 2'd3
  } uart_tx_sel_e;

  function automatic logic uart_parity_bit(
    input logic [31:0] data,
    input int unsigned data_width,
    input uart_parity_e parity_mode
  );
    logic reduce_xor;
    begin
      reduce_xor = 1'b0;
      for (int i = 0; i < data_width; i++) begin
        reduce_xor = reduce_xor ^ data[i];
      end

      unique case (parity_mode)
        UART_PARITY_EVEN: uart_parity_bit = reduce_xor;
        UART_PARITY_ODD:  uart_parity_bit = ~reduce_xor;
        default:          uart_parity_bit = 1'b0;
      endcase
    end
  endfunction
endpackage
