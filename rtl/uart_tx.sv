module uart_tx #(
  parameter DATA_WIDTH = 8
) (
  clk,
  rst_n,
  baud_tick,
  tx_start,
  tx_data,
  tx,
  tx_busy,
  tx_done
);
  input clk;
  input rst_n;
  input baud_tick;
  input tx_start;
  input [DATA_WIDTH-1:0] tx_data;
  output tx;
  output tx_busy;
  output tx_done;

  localparam [1:0] IDLE  = 2'd0;
  localparam [1:0] START = 2'd1;
  localparam [1:0] DATA  = 2'd2;
  localparam [1:0] STOP  = 2'd3;

  reg [1:0] state;
  reg [DATA_WIDTH-1:0] shift_reg;
  reg [$clog2(DATA_WIDTH)-1:0] bit_index;
  reg tx;
  reg tx_busy;
  reg tx_done;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      shift_reg <= {DATA_WIDTH{1'b0}};
      bit_index <= {$clog2(DATA_WIDTH){1'b0}};
      tx        <= 1'b1;
      tx_busy   <= 1'b0;
      tx_done   <= 1'b0;
    end else begin
      tx_done <= 1'b0;

      case (state)
        IDLE: begin
          tx      <= 1'b1;
          tx_busy <= 1'b0;

          if (tx_start) begin
            shift_reg <= tx_data;
            bit_index <= {$clog2(DATA_WIDTH){1'b0}};
            tx        <= 1'b0;
            tx_busy   <= 1'b1;
            state     <= START;
          end
        end

        START: begin
          tx_busy <= 1'b1;
          tx      <= 1'b0;

          if (baud_tick) begin
            tx    <= shift_reg[0];
            state <= DATA;
          end
        end

        DATA: begin
          tx_busy <= 1'b1;

          if (baud_tick) begin
            if (bit_index == DATA_WIDTH - 1) begin
              tx    <= 1'b1;
              state <= STOP;
            end else begin
              shift_reg <= {1'b0, shift_reg[DATA_WIDTH-1:1]};
              bit_index <= bit_index + 1'b1;
              tx        <= shift_reg[1];
            end
          end
        end

        STOP: begin
          tx_busy <= 1'b1;
          tx      <= 1'b1;

          if (baud_tick) begin
            tx_busy <= 1'b0;
            tx_done <= 1'b1;
            state   <= IDLE;
          end
        end

        default: begin
          state <= IDLE;
          tx    <= 1'b1;
        end
      endcase
    end
  end
endmodule
