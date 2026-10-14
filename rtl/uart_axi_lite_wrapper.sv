import uart_pkg::*;

module uart_axi_lite_wrapper #(
  parameter int unsigned CLK_FREQ_HZ = 100_000_000,
  parameter int unsigned BAUD_RATE   = 115_200,
  parameter int unsigned DATA_WIDTH  = 8,
  parameter int unsigned OVERSAMPLE  = 16
) (
  input  logic        aclk_i,
  input  logic        aresetn_i,
  input  logic [7:0]  s_axi_awaddr_i,
  input  logic        s_axi_awvalid_i,
  output logic        s_axi_awready_o,
  input  logic [31:0] s_axi_wdata_i,
  input  logic [3:0]  s_axi_wstrb_i,
  input  logic        s_axi_wvalid_i,
  output logic        s_axi_wready_o,
  output logic [1:0]  s_axi_bresp_o,
  output logic        s_axi_bvalid_o,
  input  logic        s_axi_bready_i,
  input  logic [7:0]  s_axi_araddr_i,
  input  logic        s_axi_arvalid_i,
  output logic        s_axi_arready_o,
  output logic [31:0] s_axi_rdata_o,
  output logic [1:0]  s_axi_rresp_o,
  output logic        s_axi_rvalid_o,
  input  logic        s_axi_rready_i,
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
  logic                  write_accept;
  logic                  read_accept;
  logic [31:0]           read_data_d;
  logic [31:0]           read_data_q;

  assign s_axi_awready_o = !s_axi_bvalid_o;
  assign s_axi_wready_o  = !s_axi_bvalid_o;
  assign s_axi_arready_o = !s_axi_rvalid_o;
  assign s_axi_bresp_o   = 2'b00;
  assign s_axi_rresp_o   = 2'b00;
  assign write_accept    = s_axi_awvalid_i && s_axi_wvalid_i && s_axi_awready_o && s_axi_wready_o;
  assign read_accept     = s_axi_arvalid_i && s_axi_arready_o;
  assign rx_ready        = read_accept && (s_axi_araddr_i == ADDR_RXDATA);
  assign clear_errors    = write_accept && (s_axi_awaddr_i == ADDR_STATUS) && s_axi_wdata_i[7];
  assign irq_o           = rx_valid | parity_error | framing_error | overrun_error;
  assign s_axi_rdata_o   = read_data_q;

  uart_top #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BAUD_RATE(BAUD_RATE),
    .DATA_WIDTH(DATA_WIDTH),
    .OVERSAMPLE(OVERSAMPLE)
  ) u_uart_top (
    .clk_i(aclk_i),
    .rst_ni(aresetn_i),
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
    read_data_d = 32'h0000_0000;
    unique case (s_axi_araddr_i)
      ADDR_CTRL: begin
        read_data_d[1:0] = parity_mode_q;
      end
      ADDR_STATUS: begin
        read_data_d[0] = tx_ready;
        read_data_d[1] = tx_busy;
        read_data_d[2] = rx_valid;
        read_data_d[3] = rx_busy;
        read_data_d[4] = parity_error;
        read_data_d[5] = framing_error;
        read_data_d[6] = overrun_error;
      end
      ADDR_TXDATA: begin
        read_data_d[DATA_WIDTH-1:0] = tx_data_q;
      end
      ADDR_RXDATA: begin
        read_data_d[DATA_WIDTH-1:0] = rx_data;
      end
      default: begin
        read_data_d = 32'h0000_0000;
      end
    endcase
  end

  always_ff @(posedge aclk_i or negedge aresetn_i) begin
    if (!aresetn_i) begin
      parity_mode_q  <= UART_PARITY_NONE;
      tx_data_q      <= '0;
      tx_valid_q     <= 1'b0;
      s_axi_bvalid_o <= 1'b0;
      s_axi_rvalid_o <= 1'b0;
      read_data_q    <= 32'h0000_0000;
    end else begin
      if (tx_valid_q && tx_ready) begin
        tx_valid_q <= 1'b0;
      end

      if (s_axi_bvalid_o && s_axi_bready_i) begin
        s_axi_bvalid_o <= 1'b0;
      end

      if (s_axi_rvalid_o && s_axi_rready_i) begin
        s_axi_rvalid_o <= 1'b0;
      end

      if (write_accept) begin
        s_axi_bvalid_o <= 1'b1;
        if (s_axi_wstrb_i != 4'b0000) begin
          unique case (s_axi_awaddr_i)
            ADDR_CTRL: begin
              parity_mode_q <= uart_parity_e'(s_axi_wdata_i[1:0]);
            end
            ADDR_TXDATA: begin
              if (tx_ready) begin
                tx_data_q  <= s_axi_wdata_i[DATA_WIDTH-1:0];
                tx_valid_q <= 1'b1;
              end
            end
            default: begin
            end
          endcase
        end
      end

      if (read_accept) begin
        read_data_q    <= read_data_d;
        s_axi_rvalid_o <= 1'b1;
      end
    end
  end
endmodule
