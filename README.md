# UART ASIC Controller RTL

Synthesizable SystemVerilog UART controller intended for ASIC-style integration and Vivado import.

## Project Contents

- `rtl/uart_top.sv` - core UART top-level module with valid/ready TX and RX interfaces.
- `rtl/uart_baud_gen.sv` - parameterized baud and oversampling tick generator.
- `rtl/uart_tx_fsm.sv`, `rtl/uart_tx_datapath.sv` - transmit control and datapath.
- `rtl/uart_rx_fsm.sv`, `rtl/uart_rx_datapath.sv`, `rtl/uart_rx_synchronizer.sv` - receive control, datapath, and input synchronization.
- `rtl/uart_parity_gen.sv`, `rtl/uart_parity_checker.sv`, `rtl/uart_error_detection.sv` - parity and error handling logic.
- `rtl/uart_apb_wrapper.sv` - APB register wrapper around `uart_top`.
- `rtl/uart_axi_lite_wrapper.sv` - AXI-Lite register wrapper around `uart_top`.
- `rtl/uart_fifo.sv` - optional synchronous FIFO building block for buffered variants.
- `sim/tb_uart_top.sv` - UART top-level testbench.
- `docs/module_01_uart_specification.md` - detailed UART specification notes.
- `filelist.f` - ordered source list for simulation or scripted builds.

## Register Map For Wrappers

| Address | Name | Description |
|---:|---|---|
| `0x00` | CTRL | `[1:0] parity mode`: 0 none, 1 even, 2 odd |
| `0x04` | STATUS | `[0] tx_ready`, `[1] tx_busy`, `[2] rx_valid`, `[3] rx_busy`, `[4] parity_error`, `[5] framing_error`, `[6] overrun_error`; write bit 7 to clear errors |
| `0x08` | TXDATA | Write transmit byte when TX is ready |
| `0x0C` | RXDATA | Read received byte; read also consumes RX valid |

## Design Notes

- Baud rate is static and parameterized through `CLK_FREQ_HZ` and `BAUD_RATE`.
- RX uses a two-flop synchronizer and 16x oversampling by default.
- The design uses clock-enable ticks, not generated clocks.
- Optional APB and AXI-Lite wrappers expose a small register interface around the core UART.

## Simulation

See `docs/SIMULATION.md` for simulation guidance.
