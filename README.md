# UART RTL Design and Verification using SystemVerilog

Synthesizable SystemVerilog UART transmitter/receiver with a self-checking loopback verification testbench.

This repository has been corrected to match the implemented UART project:

- `DATA_WIDTH = 8`
- `CLK_FREQ = 50_000_000`
- `BAUD_RATE = 115200`
- 1 start bit, 8 data bits, 1 stop bit
- LSB-first serial data
- TX FSM states: `IDLE`, `START`, `DATA`, `STOP`
- RX input synchronizer
- RX 16x oversampling
- Start-bit validation
- Stop-bit check with framing-error detection

## Overview

UART stands for Universal Asynchronous Receiver/Transmitter. This project implements a simple UART core using one system clock and clock-enable baud ticks rather than generated clocks.

The transmitter converts an 8-bit parallel byte into a serial UART frame. The receiver synchronizes the asynchronous RX input, validates the start bit, samples the data bits using a 16x oversampling tick, and checks the stop bit before reporting a received byte.

## Repository Contents

- `rtl/baud_gen.sv` - parameterized baud tick generator.
- `rtl/uart_tx.sv` - UART transmitter FSM and shift datapath.
- `rtl/uart_rx.sv` - UART receiver with synchronizer, 16x oversampling, start validation, and framing-error detection.
- `rtl/uart_top.sv` - top-level integration of baud generators, TX, and RX.
- `sim/tb_uart_top.sv` - self-checking UART loopback testbench.
- `docs/SIMULATION.md` - simulator command notes.
- `filelist.f` - ordered source list for simulation or scripted builds.

## Architecture

```text
                    uart_top
              +-------------------+
 tx_start --->|                   |
 tx_data  --->|      uart_tx      |----> tx
              |                   |
              +-------------------+

              +-------------------+
 rx      ---->|      uart_rx      |----> rx_data
              |                   |----> rx_valid
              |                   |----> framing_error
              +-------------------+
```

The top module does not force an internal loopback connection. The testbench creates loopback by connecting `tx` to `rx`, which keeps the RTL reusable for a real external UART connection.

## UART Frame Format

```text
Idle   Start      Data bits, LSB first       Stop
  1      0      D0 D1 D2 D3 D4 D5 D6 D7       1
```

## RTL Notes

- `baud_gen.sv` creates clock-enable pulses from `CLK_FREQ`, `BAUD_RATE`, and `OVERSAMPLE`.
- `uart_tx.sv` drives idle high, start low, eight data bits LSB first, and stop high.
- `uart_rx.sv` uses a two-flop synchronizer before the RX FSM.
- RX validates the start bit near the middle of the start-bit window.
- RX samples each data bit and the stop bit using the 16x oversampling tick.
- A low stop-bit sample raises `framing_error`.

## Verification

The loopback testbench sends 32 total bytes:

- Directed bytes: `00`, `FF`, `55`, `AA`
- Walking-one bytes: `01`, `02`, `04`, `08`, `10`, `20`, `40`, `80`
- 20 random bytes

The default SystemVerilog testbench uses a queue scoreboard. Because the local verification machine has Icarus Verilog 0.9.7, which does not support SystemVerilog queues, the testbench also includes a guarded `LEGACY_ICARUS` scoreboard fallback for that simulator only.

Recorded local result:

```text
UART loopback test complete: 32 PASS, 0 FAIL
```

## Run Simulation

With a modern SystemVerilog simulator:

```sh
iverilog -gsystem-verilog -o sim/uart_top_tb.vvp -f filelist.f
vvp sim/uart_top_tb.vvp
```

With the local legacy Icarus Verilog 0.9.7 fallback:

```sh
iverilog -gsystem-verilog -DLEGACY_ICARUS -o sim/uart_top_tb.vvp -f filelist.f
vvp sim/uart_top_tb.vvp
```

## Verification Status

Verified:

- UART TX-to-RX loopback path
- Directed patterns
- Walking-one patterns
- 20 random byte transfers
- Queue scoreboard in the default testbench
- No framing errors during valid loopback frames

Not claimed as complete:

- SVA was discussed during design, but assertion files are not included because they were not proven to compile and pass.
- Functional coverage was discussed, but the earlier sampling approach was flawed and no passing coverage result is claimed here.
- Parity, FIFO, APB, and AXI-Lite wrappers are not part of this corrected UART project.

## Future Improvements

- Framing-error injection test
- Invalid start-bit rejection test
- Majority-vote RX sampling
- Fractional baud-rate generator
- Proven SVA regression
- Corrected functional coverage model
- Optional parity, FIFO buffering, or bus wrapper added only after implementation and verification
