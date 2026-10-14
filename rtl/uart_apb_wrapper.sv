import uart_pkg::*;

module uart_apb_wrapper #(
  parameter int unsigned CLK_FREQ_HZ = 100_000_000,
  parameter int unsigned BAUD_RATE   = 115_200,
  parameter int unsigned DATA_WIDTH  = 8,
  parameter int unsigned OVERSAMPLE  = 16
) (
  input  logic        pclk_i,
  input  logic        preset_ni,
  input  logic        psel_i,
  input  logic        penable_i,
  input  logic        pwrite_i,
  input  logic [7:0]  paddr_i,
  input  logic [31:0] pwdata_i,
  output logic [31:0] prdata_o,
  output logic        pready_o,
  output logic        pslverr_o,
  output logic        irq_o,
  input  logic        uart_rx_i,
  output logic        uart_tx_o
);
  localparam logic [7:0] ADDR_CTRL   = 8'h00;
  localparam logic [7:0] ADDR_STATUS = 8'h04;
  localparam logic [7:0] ADDR_TXDATA = 8'h08;
  localparam logic [7:0] ADDR_RXDATA = 8'h0C;

  uart_parity_e          parity_mode_q;
  logic [DATA_WIDTH-1:0] tx_data_q;
  logic                  tx_valid_q;
  logic                  tx_ready;
  logic                  tx_busy;
  logic                  tx_done;
  logic [DATA_WIDTH-1:0] rx_data;
  logic                  rx_valid;
  logic                  rx_ready;
  logic                  rx_busy;
  logic                  clear_errors;
  logic                  parity_error;
  logic                  framing_error;
  logic                  overrun_error;
  logic                  apb_access;
  logic                  apb_write;
  logic                  apb_read;

  assign apb_access   = psel_i && penable_i;
  assign apb_write    = apb_access && pwrite_i;
  assign apb_read     = apb_access && !pwrite_i;
  assign pready_o     = 1'b1;
  assign pslverr_o    = 1'b0;
  assign irq_o        = rx_valid | parity_error | framing_error | overrun_error;
  assign rx_ready     = apb_read && (paddr_i == ADDR_RXDATA);
  assign clear_errors = apb_write && (paddr_i == ADDR_STATUS) && pwdata_i[7];

  uart_top #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BAUD_RATE(BAUD_RATE),
    .DATA_WIDTH(DATA_WIDTH),
    .OVERSAMPLE(OVERSAMPLE)
  ) u_uart_top (
    .clk_i(pclk_i),
    .rst_ni(preset_ni),
    .parity_mode_i(parity_mode_q),
    .clear_errors_i(clear_errors),
    .tx_data_i(tx_data_q),
    .tx_valid_i(tx_valid_q),
    .tx_ready_o(tx_ready),
    .tx_busy_o(tx_busy),
    .tx_done_o(tx_done),
    .uart_tx_o(uart_tx_o),
    .uart_rx_i(uart_rx_i),
    .rx_data_o(rx_data),
    .rx_valid_o(rx_valid),
    .rx_ready_i(rx_ready),
    .rx_busy_o(rx_busy),
    .parity_error_o(parity_error),
    .framing_error_o(framing_error),
    .overrun_error_o(overrun_error)
  );

  always_comb begin
    prdata_o = 32'h0000_0000;
    unique case (paddr_i)
      ADDR_CTRL: begin
        prdata_o[1:0] = parity_mode_q;
      end
      ADDR_STATUS: begin
        prdata_o[0] = tx_ready;
        prdata_o[1] = tx_busy;
        prdata_o[2] = rx_valid;
        prdata_o[3] = rx_busy;
        prdata_o[4] = parity_error;
        prdata_o[5] = framing_error;
        prdata_o[6] = overrun_error;
      end
      ADDR_TXDATA: begin
        prdata_o[DATA_WIDTH-1:0] = tx_data_q;
      end
      ADDR_RXDATA: begin
        prdata_o[DATA_WIDTH-1:0] = rx_data;
      end
      default: begin
        prdata_o = 32'h0000_0000;
      end
    endcase
  end

  always_ff @(posedge pclk_i or negedge preset_ni) begin
    if (!preset_ni) begin
      parity_mode_q <= UART_PARITY_NONE;
      tx_data_q     <= '0;
      tx_valid_q    <= 1'b0;
    end else begin
      if (tx_valid_q && tx_ready) begin
        tx_valid_q <= 1'b0;
      end

      if (apb_write) begin
        unique case (paddr_i)
          ADDR_CTRL: begin
            parity_mode_q <= uart_parity_e'(pwdata_i[1:0]);
          end
          ADDR_TXDATA: begin
            if (tx_ready) begin
              tx_data_q  <= pwdata_i[DATA_WIDTH-1:0];
              tx_valid_q <= 1'b1;
            end
          end
          default: begin
          end
        endcase
      end
    end
  end
endmodule
