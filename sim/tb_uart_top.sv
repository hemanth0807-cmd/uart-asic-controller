`timescale 1ns/1ps

module tb_uart_top;
  localparam integer CLK_FREQ   = 50_000_000;
  localparam integer BAUD_RATE  = 115_200;
  localparam integer DATA_WIDTH = 8;
  localparam integer OVERSAMPLE = 16;
  localparam integer CLK_PERIOD = 20;
  localparam integer TEST_COUNT = 32;

  reg clk;
  reg rst_n;
  reg tx_start;
  reg [DATA_WIDTH-1:0] tx_data;
  wire tx_line;
  wire rx_line;
  wire tx_busy;
  wire tx_done;
  wire [DATA_WIDTH-1:0] rx_data;
  wire rx_valid;
  wire rx_busy;
  wire framing_error;

`ifdef LEGACY_ICARUS
  reg [7:0] expected_mem [0:TEST_COUNT-1];
  integer write_index;
  integer read_index;
`else
  byte unsigned expected_q[$];
`endif
  reg [7:0] expected_value;
  integer pass_count;
  integer fail_count;
  integer i;
  integer random_value;

  assign rx_line = tx_line;

  uart_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE),
    .OVERSAMPLE(OVERSAMPLE)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx(tx_line),
    .tx_busy(tx_busy),
    .tx_done(tx_done),
    .rx(rx_line),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_busy(rx_busy),
    .framing_error(framing_error)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  task send_byte;
    input [7:0] value;
    begin
      @(posedge clk);
      wait (!tx_busy);
      tx_data <= value;
`ifdef LEGACY_ICARUS
      expected_mem[write_index] = value;
      write_index = write_index + 1;
`else
      expected_q.push_back(value);
`endif
      tx_start <= 1'b1;
      @(posedge clk);
      tx_start <= 1'b0;
    end
  endtask

  always @(posedge clk) begin
    if (rst_n && rx_valid) begin
`ifdef LEGACY_ICARUS
      if (read_index >= write_index) begin
`else
      if (expected_q.size() == 0) begin
`endif
        fail_count = fail_count + 1;
        $display("FAIL: unexpected RX byte %02h", rx_data);
      end else begin
`ifdef LEGACY_ICARUS
        expected_value = expected_mem[read_index];
`else
        expected_value = expected_q.pop_front();
`endif

        if (rx_data === expected_value) begin
          pass_count = pass_count + 1;
          $display("PASS[%0d]: expected %02h got %02h",
                   pass_count, expected_value, rx_data);
        end else begin
          fail_count = fail_count + 1;
          $display("FAIL: expected %02h got %02h",
                   expected_value, rx_data);
        end
      end

`ifdef LEGACY_ICARUS
      read_index = read_index + 1;
`endif
    end

    if (rst_n && framing_error) begin
      fail_count = fail_count + 1;
      $display("FAIL: unexpected framing_error");
    end
  end

  initial begin
    rst_n       = 1'b0;
    tx_data     = {DATA_WIDTH{1'b0}};
    tx_start    = 1'b0;
`ifdef LEGACY_ICARUS
    write_index = 0;
    read_index  = 0;
`endif
    pass_count  = 0;
    fail_count  = 0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);

    send_byte(8'h00);
    send_byte(8'hFF);
    send_byte(8'h55);
    send_byte(8'hAA);

    for (i = 0; i < DATA_WIDTH; i = i + 1) begin
      send_byte(8'h01 << i);
    end

    for (i = 0; i < 20; i = i + 1) begin
      random_value = $random;
      send_byte(random_value[7:0]);
    end

    wait (pass_count + fail_count == TEST_COUNT);
    repeat (20) @(posedge clk);

`ifdef LEGACY_ICARUS
    if (read_index != write_index) begin
      fail_count = fail_count + (write_index - read_index);
      $display("FAIL: scoreboard still has %0d expected byte(s)",
               write_index - read_index);
    end
`else
    if (expected_q.size() != 0) begin
      fail_count = fail_count + expected_q.size();
      $display("FAIL: scoreboard still has %0d expected byte(s)",
               expected_q.size());
    end
`endif

    $display("UART loopback test complete: %0d PASS, %0d FAIL",
             pass_count, fail_count);

    if (pass_count != TEST_COUNT || fail_count != 0) begin
      $display("UART loopback regression failed");
      $finish;
    end

    $finish;
  end
endmodule
