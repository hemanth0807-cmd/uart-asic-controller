module uart_rx_datapath #(
  parameter int unsigned DATA_WIDTH = 8
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic                  clear_i,
  input  logic                  data_sample_i,
  input  logic                  parity_sample_i,
  input  logic                  uart_rx_sync_i,
  output logic [DATA_WIDTH-1:0] rx_data_o,
  output logic                  received_parity_o,
  output logic                  bit_last_o
);
  localparam int unsigned BIT_CNT_W = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);

  logic [DATA_WIDTH-1:0] data_q;
  logic [BIT_CNT_W-1:0]  bit_cnt_q;
  logic                  parity_q;

  assign rx_data_o          = data_q;
  assign received_parity_o  = parity_q;
  assign bit_last_o         = (bit_cnt_q == DATA_WIDTH - 1);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      data_q    <= '0;
      bit_cnt_q <= '0;
      parity_q  <= 1'b0;
    end else if (clear_i) begin
      data_q    <= '0;
      bit_cnt_q <= '0;
      parity_q  <= 1'b0;
    end else begin
      if (data_sample_i) begin
        data_q[bit_cnt_q] <= uart_rx_sync_i;
        if (!bit_last_o) begin
          bit_cnt_q <= bit_cnt_q + 1'b1;
        end
      end

      if (parity_sample_i) begin
        parity_q <= uart_rx_sync_i;
      end
    end
  end
endmodule
