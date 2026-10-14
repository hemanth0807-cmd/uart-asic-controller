module uart_baud_gen #(
  parameter int unsigned CLK_FREQ_HZ = 100_000_000,
  parameter int unsigned BAUD_RATE   = 115_200,
  parameter int unsigned OVERSAMPLE  = 16
) (
  input  logic clk_i,
  input  logic rst_ni,
  output logic baud_tick_o,
  output logic sample_tick_o
);
  localparam int unsigned BAUD_DIV_RAW   = (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;
  localparam int unsigned SAMPLE_RATE    = BAUD_RATE * OVERSAMPLE;
  localparam int unsigned SAMPLE_DIV_RAW = (CLK_FREQ_HZ + (SAMPLE_RATE / 2)) / SAMPLE_RATE;
  localparam int unsigned BAUD_DIV       = (BAUD_DIV_RAW < 1) ? 1 : BAUD_DIV_RAW;
  localparam int unsigned SAMPLE_DIV     = (SAMPLE_DIV_RAW < 1) ? 1 : SAMPLE_DIV_RAW;
  localparam int unsigned BAUD_CNT_W     = (BAUD_DIV <= 1) ? 1 : $clog2(BAUD_DIV);
  localparam int unsigned SAMPLE_CNT_W   = (SAMPLE_DIV <= 1) ? 1 : $clog2(SAMPLE_DIV);

  logic [BAUD_CNT_W-1:0]   baud_cnt_q;
  logic [SAMPLE_CNT_W-1:0] sample_cnt_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      baud_cnt_q    <= '0;
      sample_cnt_q  <= '0;
      baud_tick_o   <= 1'b0;
      sample_tick_o <= 1'b0;
    end else begin
      baud_tick_o   <= 1'b0;
      sample_tick_o <= 1'b0;

      if (baud_cnt_q == BAUD_DIV - 1) begin
        baud_cnt_q  <= '0;
        baud_tick_o <= 1'b1;
      end else begin
        baud_cnt_q <= baud_cnt_q + 1'b1;
      end

      if (sample_cnt_q == SAMPLE_DIV - 1) begin
        sample_cnt_q  <= '0;
        sample_tick_o <= 1'b1;
      end else begin
        sample_cnt_q <= sample_cnt_q + 1'b1;
      end
    end
  end
endmodule
