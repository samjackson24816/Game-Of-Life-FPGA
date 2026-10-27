`timescale 1ns/1ps

`include "game_of_life.sv"

// Testbench for game_of_life.
//
// Test 1 is a block, which should never change.
// Test 2 is a blinker that sits across the edges of the grid. It should flip
// between flat and upright every generation, which shows the edges wrap around.
//
// In the printed grids O is alive and a dot is dead.

module game_of_life_tb;

    logic clk = 0;
    logic reset = 1;
    logic enable_gen = 0;
    logic [511:0] init_grid = 0;
    logic [511:0] grid_out;

    game_of_life uut (
        .clk(clk),
        .reset(reset),
        .enable_gen(enable_gen),
        .fade_in_tick(1'b0),
        .fade_out_tick(1'b0),
        .init_grid(init_grid),
        .grid_out(grid_out)
    );

    always #41.667 clk = ~clk; // 12 MHz clock

    int errors = 0;

    // Rows are written top row first, with the leftmost bit as column 0.
    // The result has one bit per cell, where bit r*8 + c is the cell at row r, column c.
    function automatic logic [63:0] picture(input logic [63:0] rows);
        for (int i = 0; i < 64; i++) picture[i] = rows[63 - i];
    endfunction

    // Which cells are alive in the engine right now.
    function automatic logic [63:0] alive();
        for (int i = 0; i < 64; i++) alive[i] = grid_out[i*8 + 7];
    endfunction

    task automatic print_grid();
        logic [63:0] cells = alive();
        for (int r = 0; r < 8; r++) begin
            string line = "    ";
            for (int c = 0; c < 8; c++) line = {line, cells[r*8 + c] ? "O " : ". "};
            $display("%s", line);
        end
    endtask

    task automatic load(input logic [63:0] cells);
        for (int i = 0; i < 64; i++) init_grid[i*8 +: 8] = {cells[i], 7'd0};
        reset = 1;
        repeat (2) @(negedge clk);
        reset = 0;

    endtask

    // Runs one generation. It takes 10 cycles and we wait 12 to be safe.
    task automatic step();
        enable_gen = 1;
        @(negedge clk);
        enable_gen = 0;
        repeat (12) @(negedge clk);

    endtask

    task automatic check(input string name, input int gen, input logic [63:0] expected);
        $display("%s, generation %0d", name, gen);
        print_grid();
        if (alive() !== expected) begin
            errors++;
            $display("    FAIL, this is not the expected pattern");

        end
    endtask

    logic [63:0] block, blinker_flat, blinker_upright;

    initial begin
        $dumpfile("game_of_life_tb.vcd");
        $dumpvars(0, game_of_life_tb);

        block = picture({8'b00000000,
                         8'b00000000,
                         8'b00011000,
                         8'b00011000,
                         8'b00000000,
                         8'b00000000,
                         8'b00000000,
                         8'b00000000});

        // Flat on row 0 across columns 7, 0 and 1. Upright on column 0 across rows 7, 0 and 1.
        blinker_flat = picture({8'b11000001,
                                8'b00000000,
                                8'b00000000,
                                8'b00000000,
                                8'b00000000,
                                8'b00000000,
                                8'b00000000,
                                8'b00000000});
        blinker_upright = picture({8'b10000000,
                                   8'b10000000,
                                   8'b00000000,
                                   8'b00000000,
                                   8'b00000000,
                                   8'b00000000,
                                   8'b00000000,
                                   8'b10000000});

        load(block);
        for (int g = 0; g <= 3; g++) begin
            check("Block", g, block);
            step();
        end

        load(blinker_flat);
        for (int g = 0; g <= 3; g++) begin
            check("Blinker across the edges", g, (g % 2 == 0) ? blinker_flat : blinker_upright);
            step();
        end

        if (errors == 0) $display("All tests passed");
        else $display("%0d checks failed", errors);
        $finish;
    end

endmodule
