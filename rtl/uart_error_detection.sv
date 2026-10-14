module uart_error_detection (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic clear_errors_i,
  input  logic frame_start_i,
  input  logic stop_sample_i,
  input  logic stop_bit_i,
  input  logic parity_sample_i,
  input  logic parity_error_i,
  input  logic overrun_i,
  output logic frame_has_error_o,
  output logic parity_error_o,
  output logic framing_error_o,
  output logic overrun_error_o
);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      frame_has_error_o <= 1'b0;
      parity_error_o    <= 1'b0;
      framing_error_o   <= 1'b0;
      overrun_error_o   <= 1'b0;
    end else begin
      if (clear_errors_i) begin
        parity_error_o  <= 1'b0;
        framing_error_o <= 1'b0;
        overrun_error_o <= 1'b0;
      end

      if (frame_start_i) begin
        frame_has_error_o <= 1'b0;
      end

      if (parity_sample_i && parity_error_i) begin
        parity_error_o    <= 1'b1;
        frame_has_error_o <= 1'b1;
      end

      if (stop_sample_i && !stop_bit_i) begin
        framing_error_o   <= 1'b1;
        frame_has_error_o <= 1'b1;
      end

      if (overrun_i) begin
        overrun_error_o <= 1'b1;
      end
    end
  end
endmodule
