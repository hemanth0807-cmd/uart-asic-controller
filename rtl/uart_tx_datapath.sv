import uart_pkg::*;

module uart_tx_datapath #(
  parameter int unsigned DATA_WIDTH = 8
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic [DATA_WIDTH-1:0] tx_data_i,
  input  logic                  load_i,
  input  logic                  shift_i,
  input  uart_tx_sel_e          tx_sel_i,
  input  uart_parity_e          parity_mode_i,
  output logic                  bit_last_o,
  output logic                  uart_tx_o
);
  localparam int unsigned BIT_CNT_W = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);

  logic [DATA_WIDTH-1:0] shift_reg_q;
  logic [BIT_CNT_W-1:0]  bit_cnt_q;
  logic                  parity_bit_d;
  logic                  parity_bit_q;

  assign bit_last_o = (bit_cnt_q == DATA_WIDTH - 1);

  uart_parity_gen #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_parity_gen (
    .data_i(tx_data_i),
    .parity_mode_i(parity_mode_i),
    .parity_bit_o(parity_bit_d)
  );

  always_comb begin
    unique case (tx_sel_i)
      UART_TX_SEL_START:  uart_tx_o = 1'b0;
      UART_TX_SEL_DATA:   uart_tx_o = shift_reg_q[0];
      UART_TX_SEL_PARITY: uart_tx_o = parity_bit_q;
      default:            uart_tx_o = 1'b1;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shift_reg_q <= '0;
      bit_cnt_q   <= '0;
      parity_bit_q <= 1'b0;
    end else if (load_i) begin
      shift_reg_q <= tx_data_i;
      bit_cnt_q   <= '0;
      parity_bit_q <= parity_bit_d;
    end else if (shift_i) begin
      shift_reg_q <= {1'b0, shift_reg_q[DATA_WIDTH-1:1]};
      bit_cnt_q   <= bit_cnt_q + 1'b1;
    end
  end
endmodule
