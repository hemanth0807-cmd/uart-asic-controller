module baud_gen #(
  parameter CLK_FREQ   = 50_000_000,
  parameter BAUD_RATE  = 115_200,
  parameter OVERSAMPLE = 1
) (
  clk,
  rst_n,
  tick
);
  input  clk;
  input  rst_n;
  output tick;

  localparam integer DIVISOR =
      (CLK_FREQ + (BAUD_RATE * OVERSAMPLE / 2)) / (BAUD_RATE * OVERSAMPLE);
  localparam integer COUNT_WIDTH = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

  reg [COUNT_WIDTH-1:0] count;
  reg tick;

  initial begin
    if (CLK_FREQ == 0 || BAUD_RATE == 0 || OVERSAMPLE == 0) begin
      $display("ERROR: baud_gen parameters must be non-zero");
      $finish;
    end

    if (DIVISOR == 0) begin
      $display("ERROR: baud_gen DIVISOR resolved to zero");
      $finish;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= {COUNT_WIDTH{1'b0}};
      tick  <= 1'b0;
    end else begin
      tick <= 1'b0;

      if (count == DIVISOR - 1) begin
        count <= {COUNT_WIDTH{1'b0}};
        tick  <= 1'b1;
      end else begin
        count <= count + 1'b1;
      end
    end
  end
endmodule
