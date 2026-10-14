module uart_fifo #(
  parameter int unsigned DATA_WIDTH = 8,
  parameter int unsigned DEPTH      = 16
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic                  clear_i,
  input  logic                  push_i,
  input  logic [DATA_WIDTH-1:0] push_data_i,
  input  logic                  pop_i,
  output logic [DATA_WIDTH-1:0] pop_data_o,
  output logic                  full_o,
  output logic                  empty_o,
  output logic                  overflow_o,
  output logic                  underflow_o,
  output logic [$clog2(DEPTH+1)-1:0] level_o
);
  localparam int unsigned PTR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam int unsigned LVL_W = $clog2(DEPTH + 1);

  logic [DATA_WIDTH-1:0] mem_q [DEPTH];
  logic [PTR_W-1:0] wr_ptr_q;
  logic [PTR_W-1:0] rd_ptr_q;
  logic [LVL_W-1:0] level_q;

  logic push_ok;
  logic pop_ok;

  assign full_o     = (level_q == DEPTH);
  assign empty_o    = (level_q == '0);
  assign push_ok    = push_i && !full_o;
  assign pop_ok     = pop_i && !empty_o;
  assign pop_data_o = mem_q[rd_ptr_q];
  assign level_o    = level_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      wr_ptr_q    <= '0;
      rd_ptr_q    <= '0;
      level_q     <= '0;
      overflow_o  <= 1'b0;
      underflow_o <= 1'b0;
    end else if (clear_i) begin
      wr_ptr_q    <= '0;
      rd_ptr_q    <= '0;
      level_q     <= '0;
      overflow_o  <= 1'b0;
      underflow_o <= 1'b0;
    end else begin
      overflow_o  <= push_i && full_o;
      underflow_o <= pop_i && empty_o;

      if (push_ok) begin
        mem_q[wr_ptr_q] <= push_data_i;
        if (wr_ptr_q == DEPTH - 1) begin
          wr_ptr_q <= '0;
        end else begin
          wr_ptr_q <= wr_ptr_q + 1'b1;
        end
      end

      if (pop_ok) begin
        if (rd_ptr_q == DEPTH - 1) begin
          rd_ptr_q <= '0;
        end else begin
          rd_ptr_q <= rd_ptr_q + 1'b1;
        end
      end

      unique case ({push_ok, pop_ok})
        2'b10: level_q <= level_q + 1'b1;
        2'b01: level_q <= level_q - 1'b1;
        default: level_q <= level_q;
      endcase
    end
  end
endmodule
