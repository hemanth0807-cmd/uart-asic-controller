# Module 1: UART Specification

## 1. Purpose

The UART specification defines exactly what the design must do before any RTL is written. In an ASIC project, this document is the contract between architecture, RTL design, design verification, synthesis, firmware, and validation teams.

UART stands for Universal Asynchronous Receiver/Transmitter. It converts parallel data inside a digital system into serial data on a wire, and converts received serial data back into parallel data.

This module does not contain RTL. It defines the behavior, configuration options, timing assumptions, error cases, verification targets, and interview-level reasoning for the UART project.

### Why This Specification Exists

- Prevents ambiguous RTL behavior.
- Defines the exact frame format.
- Defines how baud timing is generated.
- Defines TX and RX handshakes.
- Defines parity, stop bit, and error behavior.
- Gives verification a measurable reference model.
- Helps interviewers see that the project was developed like a real ASIC block.

### Where It Fits

```text
             System Bus / Control Interface
                         |
                         v
               +-------------------+
               |    UART Top       |
               |                   |
TX parallel -->| TX Control + Data |--> uart_tx_o
RX parallel <--| RX Control + Data |<-- uart_rx_i
               | Baud Generator    |
               | Error Logic       |
               +-------------------+
                         |
                         v
               Interrupt / Status / Flags
```

The specification guides every later module:

- Package constants and typedefs.
- Baud generator parameters.
- TX FSM states.
- RX sampling algorithm.
- Parity generator and checker.
- Error detection.
- Top-level integration.
- Assertions and coverage.
- APB or AXI-Lite wrapper behavior.

## 2. Inputs and Outputs

At specification level, the final UART block will expose two groups of signals:

- A core UART datapath/control interface.
- A future bus-facing register interface through APB or AXI-Lite.

For the initial synthesizable UART core, the expected top-level signals are:

| Signal | Direction | Width | Purpose | Timing Relationship | Interview Questions |
|---|---:|---:|---|---|---|
| `clk_i` | Input | 1 | Main synchronous clock for the UART core. | All sequential logic samples on rising edge. | Why should all UART logic use one clock? |
| `rst_ni` | Input | 1 | Active-low reset. | Asynchronous assert or synchronous deassert policy will be defined in RTL modules. | Why is reset polarity important in ASICs? |
| `tx_data_i` | Input | `DATA_WIDTH` | Parallel data byte to transmit. | Sampled when `tx_valid_i && tx_ready_o`. | What happens if data changes while valid is high? |
| `tx_valid_i` | Input | 1 | Request to transmit `tx_data_i`. | Handshake with `tx_ready_o`. | Why use valid/ready instead of a one-cycle start pulse? |
| `tx_ready_o` | Output | 1 | UART can accept a new TX byte. | High when TX path is idle or able to accept data. | Can ready be combinational? What are timing risks? |
| `tx_busy_o` | Output | 1 | TX is actively sending a frame. | High from start bit through stop bit. | Difference between busy and ready? |
| `tx_done_o` | Output | 1 | One-cycle pulse after a frame completes. | Synchronous to `clk_i`. | Why should done be a pulse instead of a level? |
| `uart_tx_o` | Output | 1 | Serial UART transmit pin. | Changes on baud tick boundaries. Idle value is 1. | Why is UART idle high? |
| `uart_rx_i` | Input | 1 | Serial UART receive pin. | Asynchronous to `clk_i`; must be synchronized. | Why is RX a CDC signal? |
| `rx_data_o` | Output | `DATA_WIDTH` | Received parallel data byte. | Valid when `rx_valid_o` pulses or remains asserted. | When is received data considered stable? |
| `rx_valid_o` | Output | 1 | Indicates valid received data. | Asserted after stop bit and error checks. | Should invalid frames produce valid data? |
| `rx_ready_i` | Input | 1 | Consumer can accept received data. | Used for future buffering or simple handshaking. | What happens if RX data is not consumed? |
| `rx_busy_o` | Output | 1 | RX is currently receiving a frame. | High from detected start bit through stop bit. | Why is RX busy useful for debug? |
| `parity_error_o` | Output | 1 | Received parity mismatch. | Set when parity check fails. | Should parity error be sticky or pulsed? |
| `framing_error_o` | Output | 1 | Stop bit was not high. | Set at stop-bit sample point. | What causes framing errors? |
| `overrun_error_o` | Output | 1 | New data arrived before old data was consumed. | Relevant when no FIFO or FIFO full. | How is overrun different from framing error? |

## 3. Internal Architecture

The final UART core will be built from small modules with clear ownership.

```text
                       +----------------------+
                       |     uart_pkg.sv      |
                       | params, enums, types |
                       +----------+-----------+
                                  |
                                  v
clk_i, rst_ni ---> +--------------------------+
                   |    Baud Rate Generator  |
                   | bit_tick / sample_tick  |
                   +-----------+--------------+
                               |
                 +-------------+-------------+
                 |                           |
                 v                           v
        +----------------+          +----------------+
        |    TX FSM      |          | RX Synchronizer|
        +-------+--------+          +--------+-------+
                |                            |
                v                            v
        +----------------+          +----------------+
        |  TX Datapath   |          |    RX FSM      |
        +-------+--------+          +--------+-------+
                |                            |
                v                            v
          uart_tx_o                 +----------------+
                                    |  RX Datapath   |
                                    +--------+-------+
                                             |
                                             v
                                    Error / Status Logic
```

### Major Architectural Blocks

| Block | Responsibility |
|---|---|
| Package | Shared parameters, enums, structs, constants. |
| Baud Rate Generator | Converts system clock cycles into UART bit timing events. |
| TX FSM | Controls start bit, data bits, optional parity bit, and stop bit. |
| TX Datapath | Holds transmit data and shifts bits onto `uart_tx_o`. |
| RX Synchronizer | Safely brings asynchronous `uart_rx_i` into `clk_i` domain. |
| RX FSM | Detects start bit, schedules samples, controls receive sequence. |
| RX Datapath | Samples serial bits and reconstructs parallel data. |
| Parity Generator | Computes parity for transmitted data. |
| Parity Checker | Compares received parity against expected parity. |
| Error Detection | Produces framing, parity, overrun, and optional break errors. |
| Top Module | Integrates all UART submodules. |
| FIFO | Optional buffering for TX and RX. |
| APB/AXI-Lite Wrapper | Optional register-programmable SoC interface. |

## 4. Algorithms

### UART Frame Format

The baseline frame format will be:

```text
Idle   Start      Data Bits LSB First       Optional Parity   Stop
  1      0      d0 d1 d2 d3 d4 d5 d6 d7          p             1
```

Default configuration:

| Feature | Default |
|---|---|
| Data bits | 8 |
| Start bits | 1 |
| Stop bits | 1 |
| Bit order | LSB first |
| Idle line value | 1 |
| Baud rate | Parameterized |
| Oversampling | Parameterized, default 16x for RX |
| Parity | Configurable: none, even, odd |
| Flow control | Not included in baseline |

### Transmit Algorithm

1. Wait in idle state with `uart_tx_o = 1`.
2. When `tx_valid_i && tx_ready_o`, capture `tx_data_i`.
3. Drive start bit `0` for one baud period.
4. Shift out data bits from bit 0 to bit `DATA_WIDTH-1`.
5. If parity is enabled, transmit computed parity bit.
6. Drive stop bit `1` for configured stop-bit duration.
7. Pulse `tx_done_o`.
8. Return to idle or accept next byte.

### Receive Algorithm

1. Synchronize `uart_rx_i` using a two-flop synchronizer.
2. Wait for a high-to-low transition that indicates a possible start bit.
3. Confirm the start bit near its center to reject glitches.
4. Sample each data bit at the center of its bit period.
5. Shift sampled bits into the RX data register LSB first.
6. If parity is enabled, sample and check parity bit.
7. Sample stop bit and verify it is high.
8. If no errors, assert `rx_valid_o` with `rx_data_o`.
9. If errors exist, update error flags and follow the specified data-valid policy.

### Baud Generation Algorithm

The baud generator divides `clk_i` down to a bit timing tick.

For an integer divider:

```text
BAUD_DIV = CLK_FREQ_HZ / BAUD_RATE
```

For RX oversampling:

```text
SAMPLE_DIV = CLK_FREQ_HZ / (BAUD_RATE * OVERSAMPLE)
```

Because real clock and baud combinations may not divide evenly, later design discussion will cover:

- Integer divider error.
- Fractional baud generation.
- Accumulating phase error.
- Tolerance between transmitter and receiver.

## 5. RTL Code

No RTL is generated in Module 1. This module is the design specification.

The first RTL artifact will be Module 2, the package file. It will define:

- `DATA_WIDTH`
- Baud-related parameters
- Parity mode enum
- TX state enum
- RX state enum
- Error/status struct types where appropriate

## 6. Line-by-Line Explanation

Because Module 1 is not RTL, the important explanation is specification intent:

- A UART is asynchronous because no clock travels with the data.
- Both endpoints must agree on baud rate and frame format.
- TX is simpler because it creates timing from the local clock.
- RX is harder because the serial input arrives asynchronously and must be synchronized.
- RX sampling should occur near the center of each bit for maximum timing margin.
- Start-bit validation is necessary because noise may create false falling edges.
- Stop-bit checking detects framing mismatch, baud mismatch, or line disturbance.
- Parity detects some data corruption, but it is not a full error correction scheme.

## 7. Timing Diagram

Example transmission of `8'hA5`.

`8'hA5 = 1010_0101`, transmitted LSB first as `1,0,1,0,0,1,0,1`.

```text
Frame field:   IDLE START  d0  d1  d2  d3  d4  d5  d6  d7  STOP IDLE
Bit value:       1    0     1   0   1   0   0   1   0   1    1    1

uart_tx_o:    ___       ___     ___         _______     _____________
                 \_____/   \___/   \_______/       \___/

Baud ticks:      |     |   |   |   |   |   |   |   |   |   |
                 S     0   1   2   3   4   5   6   7  STOP
```

RX should sample near the center of each bit:

```text
Bit window:    |--------- one UART bit period ---------|
RX sample:                         ^
Best point:                  center of bit
Bad points:     near edges, where transitions may occur
```

## 8. Hardware View

The complete UART will synthesize into:

- Counters for baud and oversampling timing.
- FSM flip-flops for TX and RX control.
- Shift registers for TX and RX datapaths.
- Comparators for counters and state transitions.
- XOR logic for parity generation and checking.
- Status flip-flops for valid, busy, done, and errors.
- Two or more synchronizer flip-flops for asynchronous RX input.
- Optional FIFO memories implemented as register arrays or inferred SRAM-like structures, depending on depth and technology.

No gated clocks are required. Clock enables from baud ticks will control when registers update.

## 9. Common Bugs

| Bug | Why It Happens | Correct Approach |
|---|---|---|
| Sampling RX at bit edges | Designer uses baud tick directly after detecting start. | Wait half a bit period before first confirmation/sample. |
| Transmitting MSB first | Confusing UART with SPI-like protocols. | UART sends LSB first. |
| Missing RX synchronizer | Treating serial input as synchronous. | Use a two-flop synchronizer before RX FSM. |
| Latch inference | Incomplete `always_comb` assignments. | Assign defaults in combinational blocks. |
| Gated baud clock | Using divided clock as a real clock. | Use one main clock and baud clock-enable ticks. |
| Done stuck high | Done implemented as a level. | Generate one-cycle pulse. |
| Parity mismatch | Wrong odd/even definition or bit order confusion. | Define parity mode clearly and test both modes. |
| Stop bit ignored | RX accepts corrupted frames. | Sample stop bit and raise framing error if low. |
| No overrun policy | New RX byte overwrites unread data. | Define valid/ready or FIFO behavior. |
| Reset ambiguity | Some registers reset, others not. | Define reset behavior per register. |

## 10. Debugging

### Signals to Inspect First

- `clk_i`
- `rst_ni`
- `baud_tick`
- `sample_tick`
- `tx_state`
- `rx_state`
- `tx_bit_count`
- `rx_bit_count`
- `tx_shift_reg`
- `rx_shift_reg`
- `uart_tx_o`
- synchronized RX signal
- `tx_done_o`
- `rx_valid_o`
- error flags

### Correct TX Waveform

```text
tx_valid_i:   ____|----|________________________________
tx_ready_o:   ----|____|_________________________|------
tx_busy_o:    _____|----------------------------|_______
tx_done_o:    _________________________________|-|______
uart_tx_o:    ----\___ data bits/parity/stop ___/-------
```

### Wrong TX Waveform Examples

```text
Problem: tx_done_o remains high

tx_done_o:    ____________________|---------------------
Expected:     ____________________|-|___________________
```

```text
Problem: line idles low after reset

uart_tx_o:    __________________________________________
Expected:     ------------------------------------------
```

### Debug Method

1. Check reset values.
2. Check baud tick frequency.
3. Check state transitions.
4. Check bit counter terminal count.
5. Check serial bit order.
6. Check done and valid pulse width.
7. Check parity and stop bit behavior.

## 11. Verification

Module 1 defines the verification plan. Later modules will implement testbenches, assertions, and coverage.

### Directed Tests

| Test | Purpose |
|---|---|
| Reset test | Confirm idle TX, cleared valid/done/error flags. |
| Single TX byte | Confirm start, 8 data bits LSB first, stop. |
| Single RX byte | Confirm correct reconstructed data. |
| Back-to-back TX | Confirm ready/busy behavior. |
| Back-to-back RX | Confirm valid/overrun/FIFO behavior. |
| Even parity | Confirm parity bit generation and checking. |
| Odd parity | Confirm opposite parity behavior. |
| Framing error | Force stop bit low and expect framing error. |
| Parity error | Corrupt parity bit and expect parity error. |
| Baud corner | Test minimum and maximum supported divider values. |

### Assertion Ideas

- TX output must be high during idle.
- `tx_done_o` must be one cycle wide.
- TX FSM must use only legal transitions.
- RX valid must not assert during reset.
- RX start bit must be confirmed before data sampling.
- Baud counter must not exceed terminal count.
- Framing error must assert when sampled stop bit is low.
- Parity error must match parity checker result.

### Coverage Ideas

- All data patterns of interest: `8'h00`, `8'hFF`, `8'h55`, `8'hAA`, walking 1, walking 0.
- Parity disabled, even, odd.
- Different baud divider values.
- TX busy and idle states.
- RX valid with and without errors.
- Back-to-back frames.
- Reset during idle.
- Reset during active TX/RX.
- Error flag combinations.

## 12. Interview Questions

### Basic Questions

**Q1. What is UART?**  
UART is a serial communication block that sends and receives data without a shared clock. It uses agreed baud rate and frame format to recover data.

**Q2. Why is UART called asynchronous?**  
Because the transmitter does not send a clock signal with the data. The receiver uses its own clock and samples based on the configured baud rate.

**Q3. What is the idle value of a UART line?**  
The idle value is logic 1. A frame begins with a falling edge into the start bit, which is logic 0.

**Q4. In what order are UART data bits transmitted?**  
UART transmits least significant bit first.

### Intermediate Questions

**Q5. Why should RX use a synchronizer?**  
`uart_rx_i` is asynchronous to the local clock. Sampling it directly can cause metastability. A two-flop synchronizer reduces the probability of metastability propagating into the RX FSM.

**Q6. Why sample in the middle of a bit?**  
The bit center is farthest from transitions. Sampling there gives the maximum timing margin against baud mismatch, jitter, and signal delay.

**Q7. What is a framing error?**  
A framing error occurs when the receiver expects a stop bit but samples a low value instead of high.

**Q8. What is parity used for?**  
Parity provides simple error detection. Even parity makes the total number of 1s even. Odd parity makes the total number of 1s odd.

### Advanced Questions

**Q9. Why avoid generating a divided baud clock?**  
Generated clocks complicate clock tree synthesis, timing constraints, CDC analysis, and power. A better ASIC style is to keep one main clock and use baud tick enables.

**Q10. What limits maximum UART baud rate?**  
Limits include system clock frequency, divider accuracy, RX oversampling ratio, synchronizer latency, FSM/datapath timing, IO timing, and allowed baud mismatch.

**Q11. How much baud mismatch can UART tolerate?**  
It depends on frame length and sampling strategy. Since RX resynchronizes on each start bit, the accumulated timing error across one frame must stay small enough that the stop-bit sample still lands inside the correct bit window.

**Q12. Why might a fractional baud generator be needed?**  
Many system clocks do not divide exactly into common baud rates. A fractional accumulator can reduce long-term baud error compared with integer division.

### Very Difficult ASIC Interview Questions

**Q13. Is a two-flop synchronizer enough for UART RX?**  
It is standard for metastability reduction, but it does not remove all risk. The required synchronizer depth depends on clock frequency, metastability parameters, target MTBF, and technology. UART also needs start-bit filtering or validation for noise rejection.

**Q14. How would you constrain this block for synthesis and STA?**  
The main UART logic is synchronous to `clk_i`. The asynchronous RX input should be constrained as an input from an external asynchronous source. Generated baud ticks are clock enables, not clocks. Timing exceptions may be needed around synchronizer paths depending on methodology.

**Q15. What is the critical path likely to be?**  
For a simple UART, likely paths include baud counter compare/increment logic, RX sample control, parity XOR reduction, or bus wrapper decode if included. The exact critical path depends on parameters and integration.

### Verification Questions

**Q16. How would you verify bit order?**  
Transmit asymmetric patterns like `8'hA5`, `8'h96`, walking 1s, and walking 0s. The monitor should reconstruct serial bits and compare against expected LSB-first order.

**Q17. How would you test framing error?**  
Drive a valid start and data sequence, then force the stop bit low at the stop-bit sample point. The checker should expect `framing_error_o`.

**Q18. What should functional coverage include?**  
Data patterns, parity modes, baud settings, reset scenarios, busy behavior, valid/done pulses, error conditions, and back-to-back transfers.

### SystemVerilog Questions

**Q19. Why use `always_ff` and `always_comb`?**  
They express design intent clearly. `always_ff` is for sequential logic and `always_comb` is for combinational logic. Tools can catch some accidental coding mistakes.

**Q20. Why use `typedef enum logic` for FSMs?**  
It improves readability, type safety, debug visibility, and maintainability compared with raw numeric state encodings.

### FSM Questions

**Q21. What are likely TX FSM states?**  
Idle, start, data, parity, stop, and done or cleanup.

**Q22. What are likely RX FSM states?**  
Idle, start check, data sample, parity sample, stop sample, done, and error handling.

### Timing Questions

**Q23. Why are done pulses usually one clock wide?**  
One-cycle pulses are easy for downstream synchronous logic to detect and prevent repeated event counting.

**Q24. What happens if the baud divider is wrong?**  
The receiver samples too early or too late. Small error may work; large error causes data corruption, parity errors, or framing errors.

### CDC Questions

**Q25. Is UART RX a CDC problem?**  
Yes. The external serial input is asynchronous to the local clock. The RX path must synchronize it before FSM use.

**Q26. Is UART TX a CDC problem?**  
The TX output itself is launched from the local clock domain. It becomes asynchronous to the remote receiver, but inside the local UART TX logic it is not a CDC path.

### Coding Questions

**Q27. Why avoid latches?**  
Unintended latches create timing and verification complexity. In ASIC RTL, combinational logic should assign all outputs in all paths.

**Q28. Why use parameters?**  
Parameters make the design reusable for different data widths, baud rates, parity modes, FIFO depths, and clock frequencies.

### Behavioral vs Synthesizable Questions

**Q29. Can delays like `#10` be used in RTL?**  
No. Delays are simulation constructs and are not synthesizable into real ASIC hardware. Timing must be represented with counters and clocked logic.

**Q30. Can a testbench use delays?**  
Yes. Testbenches are not synthesized, so delays are acceptable for stimulus, though clocking blocks and cycle-based control are often cleaner.

## Synthesis Discussion

Even though Module 1 has no RTL, the specification already shapes synthesis quality.

### Critical Path

The design should avoid long combinational paths across multiple submodules. Each FSM and datapath should have clear registered boundaries.

### Area

Major area contributors will be counters, optional FIFOs, parity logic, and bus wrapper registers.

### Power

Clock enables should prevent unnecessary shift-register and counter activity. No gated clocks should be inferred in baseline RTL.

### Fanout

Reset, baud tick, and control enables may have meaningful fanout. Large fanout signals should be reviewed after synthesis.

### Timing Optimization

Possible improvements include:

- Registering status outputs.
- Keeping baud compare logic simple.
- Avoiding wide combinational decode paths.
- Separating bus interface timing from UART datapath timing.

## Revision Notes

- UART is asynchronous because there is no shared clock.
- TX is timing generation plus shifting.
- RX is synchronization plus center sampling.
- UART sends LSB first.
- Idle line is high.
- Start bit is low.
- Stop bit is high.
- Use baud tick enables, not generated clocks.
- RX must handle metastability and false starts.
- Verification must include normal frames, errors, reset, and corner timing.

## Approval Checkpoint

Module 1 is complete as the project specification chapter.

Next module after approval: **Module 2: Package**.
