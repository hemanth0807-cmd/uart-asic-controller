# Simulation Notes

## Source Order

Use `filelist.f` from the repository root. It lists the four RTL modules and the loopback testbench in compile order.

## Running A Simulation

Use a SystemVerilog-capable simulator and compile the files in `filelist.f` order. The provided testbench is `sim/tb_uart_top.sv`.

With a modern SystemVerilog simulator:

```sh
iverilog -gsystem-verilog -o sim/uart_top_tb.vvp -f filelist.f
vvp sim/uart_top_tb.vvp
```

The testbench connects TX directly to RX, sends 32 bytes through the UART loopback path, and checks each received byte with a queue scoreboard.

The local verification environment used Icarus Verilog 0.9.7, which does not support SystemVerilog queues. For that legacy simulator only:

```sh
iverilog -gsystem-verilog -DLEGACY_ICARUS -o sim/uart_top_tb.vvp -f filelist.f
vvp sim/uart_top_tb.vvp
```
