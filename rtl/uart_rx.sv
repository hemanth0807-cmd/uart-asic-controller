module uart_rx #(
  parameter DATA_WIDTH = 8,
  parameter OVERSAMPLE = 16
) (
  clk,
  rst_n,
  sample_tick,
  rx,
  rx_data,
  rx_valid,
  rx_busy,
  framing_error
);
  input clk;
  input rst_n;
  input sample_tick;
  input rx;
  output [DATA_WIDTH-1:0] rx_data;
  output rx_valid;
  output rx_busy;
  output framing_error;

  localparam [1:0] RX_IDLE  = 2'd0;
  localparam [1:0] RX_START = 2'd1;
  localparam [1:0] RX_DATA  = 2'd2;
  localparam [1:0] RX_STOP  = 2'd3;
  localparam integer SAMPLE_COUNT_WIDTH =
      (OVERSAMPLE <= 1) ? 1 : $clog2(OVERSAMPLE);

  reg [1:0] state;
  reg rx_meta;
  reg rx_sync;
  reg [SAMPLE_COUNT_WIDTH-1:0] sample_count;
  reg [$clog2(DATA_WIDTH)-1:0] bit_index;
  reg [DATA_WIDTH-1:0] shift_reg;
  reg [DATA_WIDTH-1:0] rx_data;
  reg rx_valid;
  reg rx_busy;
  reg framing_error;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_meta <= 1'b1;
      rx_sync <= 1'b1;
    end else begin
      rx_meta <= rx;
      rx_sync <= rx_meta;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= RX_IDLE;
      sample_count  <= {SAMPLE_COUNT_WIDTH{1'b0}};
      bit_index     <= {$clog2(DATA_WIDTH){1'b0}};
      shift_reg     <= {DATA_WIDTH{1'b0}};
      rx_data       <= {DATA_WIDTH{1'b0}};
      rx_valid      <= 1'b0;
      rx_busy       <= 1'b0;
      framing_error <= 1'b0;
    end else begin
      rx_valid      <= 1'b0;
      framing_error <= 1'b0;

      case (state)
        RX_IDLE: begin
          rx_busy      <= 1'b0;
          sample_count <= {SAMPLE_COUNT_WIDTH{1'b0}};
          bit_index    <= {$clog2(DATA_WIDTH){1'b0}};

          if (!rx_sync) begin
            rx_busy <= 1'b1;
            state   <= RX_START;
          end
        end

        RX_START: begin
          rx_busy <= 1'b1;

          if (sample_tick) begin
            if (sample_count == (OVERSAMPLE / 2) - 1) begin
              sample_count <= {SAMPLE_COUNT_WIDTH{1'b0}};

              if (!rx_sync) begin
                state <= RX_DATA;
              end else begin
                state   <= RX_IDLE;
                rx_busy <= 1'b0;
              end
            end else begin
              sample_count <= sample_count + 1'b1;
            end
          end
        end

        RX_DATA: begin
          rx_busy <= 1'b1;

          if (sample_tick) begin
            if (sample_count == OVERSAMPLE - 1) begin
              sample_count          <= {SAMPLE_COUNT_WIDTH{1'b0}};
              shift_reg[bit_index] <= rx_sync;

              if (bit_index == DATA_WIDTH - 1) begin
                bit_index <= {$clog2(DATA_WIDTH){1'b0}};
                state     <= RX_STOP;
              end else begin
                bit_index <= bit_index + 1'b1;
              end
            end else begin
              sample_count <= sample_count + 1'b1;
            end
          end
        end

        RX_STOP: begin
          rx_busy <= 1'b1;

          if (sample_tick) begin
            if (sample_count == OVERSAMPLE - 1) begin
              sample_count <= {SAMPLE_COUNT_WIDTH{1'b0}};
              rx_busy      <= 1'b0;
              state        <= RX_IDLE;

              if (rx_sync) begin
                rx_data  <= shift_reg;
                rx_valid <= 1'b1;
              end else begin
                framing_error <= 1'b1;
              end
            end else begin
              sample_count <= sample_count + 1'b1;
            end
          end
        end

        default: begin
          state <= RX_IDLE;
        end
      endcase
    end
  end
endmodule
