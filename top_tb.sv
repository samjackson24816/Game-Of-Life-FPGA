`timescale 1ns/1ps

`include "top.sv"

module top_tb;

    logic clk;
    logic BOOT;
    logic _48b;

    top uut (
        .clk(clk),
        .BOOT(BOOT),
        ._48b(_48b)
    );

    always #41.67 clk = ~clk;

    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, top_tb);

        clk = 0;
        BOOT = 0;
        #200;
        BOOT = 1;

        #10000;
        $finish;
    end

endmodule
