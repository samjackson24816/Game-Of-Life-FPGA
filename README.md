# Game of Life FPGA Project (Miniproject 3)

Conway's Game of Life implemented on an $8 \times 8$ grid with cyclic boundary conditions, running on the iceBlinkPico FPGA board and displayed on an $8 \times 8$ WS2812B RGB LED matrix.

## Project Structure
- `top.sv`: Top-level module integrating clock divider, initial memory loading, Game of Life engine, color mapping, and WS2812B driver/controller.
- `game_of_life.sv`: Cellular automaton logic implementing Conway's 4 rules with cyclic boundary wrapping across 8x8 grid.
- `controller.sv`: Frame and pixel timing controller for WS2812B LED matrix refresh (~32 FPS).
- `ws2812b.sv`: Serial communication driver for WS2812B RGB LEDs.
- `memory.sv` & `initial_grid.txt`: Initial pattern specification using `$memh`.
- `top_tb.sv`: Testbench for simulation verification using Icarus Verilog (`iverilog`).
- `iceBlinkPico.pcf`: Pin constraint file.
- `Makefile`: Build commands for synthesis, simulation, and programming.

## Usage
- **Simulate**: `make sim`
- **Synthesize & Build**: `make build`
- **Program FPGA**: `make prog`
