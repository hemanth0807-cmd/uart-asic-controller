import uart_pkg::*;

module uart_parity_checker #(
  parameter int unsigned DATA_WIDTH = 8
) (
  input  logic [DATA_WIDTH-1:0] data_i,
  input  logic                  received_parity_i,
  input  uart_parity_e          parity_mode_i,
  output logic                  parity_error_o
);
  logic expected_parity;

  uart_parity_gen #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_parity_gen (
    .data_i(data_i),
    .parity_mode_i(parity_mode_i),
    .parity_bit_o(expected_parity)
  );

  always_comb begin
    if (parity_mode_i == UART_PARITY_NONE) begin
      parity_error_o = 1'b0;
    end else begin
      parity_error_o = received_parity_i ^ expected_parity;
    end
  end
endmodule
