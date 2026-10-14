module uart_rx_synchronizer (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic uart_rx_i,
  output logic uart_rx_sync_o
);
  logic rx_meta_q;
  logic rx_sync_q;

  assign uart_rx_sync_o = rx_sync_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rx_meta_q <= 1'b1;
      rx_sync_q <= 1'b1;
    end else begin
      rx_meta_q <= uart_rx_i;
      rx_sync_q <= rx_meta_q;
    end
  end
endmodule
