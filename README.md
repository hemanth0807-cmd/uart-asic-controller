# UART RTL Design and Verification using SystemVerilog

A parameterized UART transmitter and receiver implemented in SystemVerilog, with a self-checking loopback testbench, directed and randomized testing, scoreboard-based checking, and functional coverage.

## Overview

This project implements a Universal Asynchronous Receiver/Transmitter (UART) for serial communication between digital systems. The design is divided into modular transmitter, receiver, baud generator, and top-level integration blocks.

The receiver uses a two-flip-flop synchronizer, falling-edge detection, and 16× oversampling to receive serial data. A SystemVerilog testbench verifies the design through loopback communication and compares received data against expected transactions using a self-checking scoreboard.

## Features

- Parameterized data width, clock frequency, and baud rate
- UART transmitter with finite-state-machine control
- UART receiver with 16× oversampling
- Two-flip-flop synchronizer for the asynchronous RX input
- Start-bit detection and validation
- LSB-first serial data transmission and reception
- Stop-bit checking and framing-error indication
- TX busy and RX completion signals
- Self-checking SystemVerilog testbench
- Driver, monitor, and queue-based scoreboard
- Directed and randomized stimulus
- Functional coverage using covergroups and coverpoints
- SystemVerilog Assertions (SVA) developed as a separate verification component

## Architecture

```text
                    UART TOP
              +-------------------+
              |                   |
 tx_start ---->|    UART TX        |----> tx
 tx_data   ---->|                   |
              +-------------------+
                                         
              +-------------------+
 rx <---------|    UART RX        |
              |                   |----> rx_data
              |                   |----> rx_done
              |                   |----> framing_error
              +-------------------+
```

The transmitter and receiver are independent modules. They are not internally connected in the UART top module. The testbench creates a loopback connection by connecting the TX output to the RX input.

```systemverilog
assign rx = tx;
```

This allows the transmitted serial data to be received and checked automatically during simulation.

## Design Parameters

| Parameter | Value | Description |
|---|---:|---|
| `DATA_WIDTH` | 8 | Number of data bits |
| `CLK_FREQ` | 50,000,000 Hz | System clock frequency |
| `BAUD_RATE` | 115200 | Target UART baud rate |
| Oversampling | 16× on RX | Receiver sampling approach |

The implemented test configuration uses an 8-bit data frame with one start bit, eight data bits, and one stop bit, without parity.

## UART Frame Format

```text
        Start       Data bits (LSB first)       Stop
          0       D0 D1 D2 D3 D4 D5 D6 D7        1

Idle: 1 ───┐                                  ┌──────
           └──────────────────────────────────┘
```

- **Idle:** The serial line remains HIGH.
- **Start bit:** The transmitter drives the line LOW.
- **Data:** Eight bits are transmitted, least significant bit first.
- **Stop bit:** The line returns HIGH to indicate the end of the frame.

## RTL Modules

### 1. `baud_gen.sv`

Generates timing-enable pulses used by the transmitter and receiver.

- Uses a counter driven by the system clock.
- Generates a baud-rate tick for TX.
- Supports the faster sampling tick required by the RX oversampling architecture through parameterized configuration.

For an integer divider:

\[
D = \frac{f_{\text{clk}}}{f_{\text{baud}}\times O}
\]

where \(O\) is the oversampling factor. TX uses \(O=1\), while RX uses \(O=16\).

Integer division introduces baud-rate error when the requested rate is not an exact divisor of the clock frequency. The generated tick is a clock-enable pulse, not a separate clock domain.

### 2. `uart_tx.sv`

Implements the UART transmitter.

**FSM states:**

- `IDLE` — waits for a transmission request.
- `START` — transmits the start bit.
- `DATA` — serializes the data using a shift register.
- `STOP` — transmits the stop bit.

**Key signals:**

- `tx_start` — requests transmission.
- `tx_data` — parallel input data.
- `tx` — serial output.
- `tx_busy` — indicates that transmission is active.
- `baud_tick` — controls bit timing.

The transmitter loads the input data into a shift register and shifts right after each transmitted data bit, exposing the least significant bit first.

### 3. `uart_rx.sv`

Implements the UART receiver.

**FSM states:**

- `IDLE` — waits for a possible start bit.
- `START` — validates the start bit.
- `DATA` — samples and assembles incoming data.
- `STOP` — checks the stop bit.
- `DONE` — publishes the received byte and signals completion.

**Key signals:**

- `rx` — asynchronous serial input.
- `baud_x16_tick` — oversampling timing enable.
- `rx_data` — received parallel data.
- `rx_done` — indicates that a frame has been received.
- `framing_error` — indicates an invalid stop bit.

The receiver synchronizes the incoming signal, detects a falling edge, validates the start bit near its midpoint, and samples subsequent data bits at bit intervals. It assembles the received bits in the correct order and checks the stop bit.

The two-flip-flop synchronizer reduces the probability of metastability propagating into downstream logic; it does not eliminate metastability entirely.

### 4. `uart_top.sv`

Integrates the transmitter, receiver, and baud-generation logic.

The top module exposes the transmit and receive interfaces without forcing an internal loopback connection. This keeps the UART reusable in systems where TX and RX connect to external devices.

## Verification Environment

The testbench is implemented in `tb_uart_top.sv`.

### Testbench Components

**Driver**

A reusable `send_byte()` task drives `tx_data` and pulses `tx_start`. It waits for the transmitter to become available before requesting the next byte.

**Monitor**

Observes `rx_done`, `rx_data`, and `framing_error`, reporting received transactions and any detected framing errors.

**Scoreboard**

Uses a SystemVerilog queue to store expected bytes. When the receiver signals completion, the scoreboard removes the next expected byte and compares it with `rx_data`.

```text
Stimulus
   |
   v
 Driver ---> UART TX ---> Loopback ---> UART RX
                                         |
                                         v
                                      Monitor
                                         |
                                         v
                                    Scoreboard
                                         |
                                    PASS / FAIL
```

The scoreboard makes the testbench self-checking: received data is checked automatically rather than relying only on waveform inspection.

## Test Plan

### Directed Tests

The following data patterns are exercised:

| Test | Data | Purpose |
|---|---|---|
| All zeros | `8'h00` | Checks zero-valued data |
| All ones | `8'hFF` | Checks all HIGH data bits |
| Alternating | `8'h55` | Exercises alternating bits |
| Inverse alternating | `8'hAA` | Exercises the complementary pattern |
| Walking ones | `01, 02, 04, 08, 10, 20, 40, 80` | Checks individual bit positions |

### Randomized Tests

The testbench also sends 20 randomized byte values using `$urandom`.

Randomized testing supplements directed tests by exercising additional data patterns.

## Simulation Results

The recorded loopback regression completed **32 transactions**:

| Metric | Result |
|---|---:|
| Directed transactions | 12 |
| Randomized transactions | 20 |
| Total transactions | 32 |
| Passed transactions | 32 |
| Failed transactions | 0 |

All 32 received bytes matched their expected values in the recorded run, and no framing-error messages were reported.

These results apply to the recorded simulation configuration; they do not establish exhaustive protocol verification or operation across all clock and baud-rate combinations.

## SystemVerilog Assertions

SVA is used to express temporal properties of the design and check protocol behavior during simulation.

Planned assertion categories include:

- TX busy behavior after a transmission request
- TX idle, start-bit, and stop-bit behavior
- Legal FSM states
- TX and RX counter bounds
- RX completion behavior
- Baud-tick pulse behavior
- Framing-error behavior

The assertion files are maintained separately from the synthesizable RTL. Individual properties should be compiled, exercised, and debugged before being reported as passing verification checks.

## Functional Coverage

The testbench includes a functional coverage structure intended to track important data patterns and receiver events.

Coverage goals include:

- `8'h00` and `8'hFF`
- `8'h55` and `8'hAA`
- Walking-one patterns
- Other randomized data values
- RX completion
- Framing-error and no-error scenarios

Cross coverage can be used to study combinations of data patterns and error conditions.

**Important:** Functional coverage measures which specified scenarios were sampled; it does not prove that the design is correct. Framing-error coverage requires explicit stimulus that generates an invalid stop bit. Coverage results should be reported only after the relevant bins and sampling behavior have been validated.

## Debugging Methodology

The project used waveform-based debugging to investigate receiver timing and data-assembly behavior.

Important signals to inspect include:

- `tx` and `rx`
- TX and RX FSM states
- `baud_tick` and `baud_x16_tick`
- `sample_count`
- `bit_count`
- `shift_reg`
- `rx_done`
- `rx_data`
- `framing_error`

A useful debugging sequence is:

1. Reproduce the failure with a small, deterministic test.
2. Find the first incorrect event or sampled bit.
3. Check state transitions and counter timing.
4. Inspect shift-register contents and bit ordering.
5. Compare expected and actual transactions.
6. Make one targeted change and rerun regression tests.

## Design Trade-offs

### Modular TX and RX

Separating TX and RX improves reuse, debugging, and independent verification compared with a monolithic UART implementation.

### Loopback in the Testbench

Keeping loopback outside the RTL allows the same UART design to connect to real external devices without modification.

### Receiver Oversampling

Oversampling helps align sampling to incoming bit timing and validate the start bit. Its actual tolerance depends on the clock divider, synchronizer latency, and sampling implementation.

### Shift Registers

Shift registers provide a compact implementation for serial-to-parallel and parallel-to-serial conversion. The chosen direction must be consistent with UART's LSB-first transmission convention.

## Limitations and Future Improvements

Possible extensions include:

- Parity generation and checking
- Configurable parity and stop-bit settings
- FIFO-based buffering
- Explicit invalid-start-bit testing
- Dedicated framing-error injection tests
- Additional SVA properties and assertion regression
- Validated functional coverage closure
- Fractional baud-rate generation for reduced divider error
- Majority-vote sampling
- APB or AXI-Lite register interface
- Additional baud-rate and clock-frequency configurations

These are future improvements and should not be interpreted as already implemented features.

## Repository Structure

A suggested organization is:

```text
UART-RTL-Design-and-Verification/
├── README.md
├── rtl/
│   ├── baud_gen.sv
│   ├── uart_tx.sv
│   ├── uart_rx.sv
│   └── uart_top.sv
├── tb/
│   ├── tb_uart_top.sv
│   ├── uart_sva.sv
│   ├── uart_tx_sva.sv
│   └── uart_rx_sva.sv
├── docs/
│   ├── block_diagram.png
│   └── waveform.png
└── .gitignore
```

Adjust the structure to match the actual files in the repository.

## Skills Demonstrated

- SystemVerilog RTL design
- Finite-state-machine design
- Counters and shift registers
- UART serial protocol timing
- Asynchronous input synchronization
- Oversampling-based reception
- Self-checking testbench development
- Driver, monitor, and scoreboard methodology
- Directed and randomized testing
- Functional coverage concepts
- Waveform-based debugging

## Conclusion

This project demonstrates the design and simulation-based verification of a modular UART transmitter and receiver in SystemVerilog. It combines protocol-oriented RTL with a self-checking loopback testbench and provides a foundation for further work in assertion-based verification, coverage closure, and SoC peripheral integration.
