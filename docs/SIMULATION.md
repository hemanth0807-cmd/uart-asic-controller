# Simulation Notes

## Source Order

Use `filelist.f` from the repository root. It lists the UART package first, followed by leaf modules, the top-level UART, wrappers, and the testbench.

## Running A Simulation

Use a SystemVerilog-capable simulator and compile the files in `filelist.f` order. The provided testbench is `sim/tb_uart_top.sv`.

The testbench targets the core UART top-level module and validates basic transmit/receive behavior around the parameterized baud generator, TX/RX FSMs, parity logic, and error reporting.
