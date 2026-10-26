`timescale 1ns/1ps

`include "top.sv"

// TODO: Implement testbench to verify your Game of Life circuit
module top_tb;

    logic clk;
    logic SW;
    logic BOOT;
    logic _48b;
    logic _45a;

    top uut (
        .clk(clk),
        .SW(SW),
        .BOOT(BOOT),
        ._48b(_48b),
        ._45a(_45a)
    );

    always #41.67 clk = ~clk;

    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, top_tb);

        clk = 0;
        SW = 1;
        BOOT = 0;
        #200;
        BOOT = 1;

        // TODO: Add test vectors / stimulus here
        #10000;
        $finish;
    end

endmodule
