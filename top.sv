`include "memory.sv"
`include "game_of_life.sv"
`include "ws2812b.sv"
`include "controller.sv"

// TODO: Top-level module for Miniproject 3 (Game of Life FPGA)
module top(
    input logic     clk, 
    input logic     SW, 
    input logic     BOOT, 
    output logic    _48b, 
    output logic    _45a
);

    // TODO: Instantiate your game_of_life module, memory, WS2812B driver, and display mapping logic here

endmodule
