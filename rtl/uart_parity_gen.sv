import uart_pkg::*;

module uart_parity_gen #(
  parameter int unsigned DATA_WIDTH = 8
) (
  input  logic [DATA_WIDTH-1:0] data_i,
  input  uart_parity_e          parity_mode_i,
  output logic                  parity_bit_o
);
  always_comb begin
    unique case (parity_mode_i)
      UART_PARITY_EVEN: parity_bit_o = ^data_i;
      UART_PARITY_ODD:  parity_bit_o = ~(^data_i);
      default:          parity_bit_o = 1'b0;
    endcase
  end
endmodule
