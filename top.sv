`include "game_of_life.sv"
`include "ws2812b.sv"
`include "controller.sv"

module top (
    input logic clk, // 12 MHz
    input logic BOOT, // reset button, low when pressed
    output logic _48b // data line to the LED matrix
);

    // PARAMETERS FOR THE PROGRAM

    localparam int CLK_HZ = 12_000_000;
    localparam int GENS_PER_SEC = 3; // how many generations of the game of life to compute per second
    localparam int FADE_IN_MS = 200; // dark to full brightness
    localparam int FADE_OUT_MS = 1500; // full brightness to dark
    localparam int GEN_CYCLES = CLK_HZ / GENS_PER_SEC;
    localparam int FADE_IN_CYCLES = (CLK_HZ / 1000) * FADE_IN_MS / 7; // 7 brightness steps
    localparam int FADE_OUT_CYCLES = (CLK_HZ / 1000) * FADE_OUT_MS / 7; 

    // Hold reset for the first 31 cycles after power up and while the button is pressed.
    // We do this because the ws2812b driver needs a few cycles to initialize and stablize

    logic [4:0] por_count = 0;
    always_ff @(posedge clk)
        if (por_count != 31) por_count <= por_count + 1;

    logic reset;
    assign reset = (por_count != 31) || !BOOT;

    logic gen_tick, fade_in_tick, fade_out_tick;

    // Ticker is a simple counter implemented below
    ticker #(GEN_CYCLES) gen_ticker (.clk, .reset, .tick(gen_tick));
    ticker #(FADE_IN_CYCLES) fade_in_ticker (.clk, .reset, .tick(fade_in_tick));
    ticker #(FADE_OUT_CYCLES) fade_out_ticker (.clk, .reset, .tick(fade_out_tick));

    // The seed file has one line per row with one hex byte per cell, starting at column 0.
    logic [63:0] seed_rows [0:7];
    logic [511:0] seed;
    initial $readmemh("initial_grid.txt", seed_rows);
    always_comb begin
        for (int r = 0; r < 8; r++)
            for (int c = 0; c < 8; c++)
                seed[(r*8 + c)*8 +: 8] = seed_rows[r][(7 - c)*8 +: 8];
    end

    logic [511:0] grid;
    game_of_life gol (
        .clk,
        .reset,
        .enable_gen(gen_tick),
        .fade_in_tick,
        .fade_out_tick,
        .init_grid(seed),
        .grid_out(grid)
    );

    // Color of the pixel the controller is about to send. The pixel number
    // matches the cell number, so it can pick the cell directly.
    logic [5:0] pixel;
    logic [7:0] cell_byte;
    logic [7:0] hue;
    logic [2:0] brightness;
    assign cell_byte = grid[pixel*8 +: 8];
    assign hue = {cell_byte[3:0], 4'd0}; // spreads 16 hues around the color wheel
    assign brightness = cell_byte[6:4];

    // Standard six part color wheel. Each brightness step below full halves the
    // color, which uses shifts instead of multipliers and looks even to the eye.
    // this is a simple way to get a rainbow effect without using a lookup table
    // https://www.rapidtables.com/convert/color/hsv-to-rgb.html

    logic [7:0] red = 0, green = 0, blue = 0;
    always_ff @(posedge clk) begin
        logic [7:0] r, g, b;
        if (hue < 43) begin r = 255; g = hue * 6; b = 0; end
        else if (hue < 85) begin r = 255 - (hue-43)*6; g = 255; b = 0; end
        else if (hue < 128) begin r = 0; g = 255; b = (hue-85)*6; end
        else if (hue < 170) begin r = 0; g = 255 - (hue-128)*6; b = 255; end
        else if (hue < 213) begin r = (hue-170)*6; g = 0; b = 255; end
        else begin r = 255; g = 0; b = 255 - (hue-213)*6; end

        if (brightness != 0) begin
            red <= r >> (7 - brightness);
            green <= g >> (7 - brightness);
            blue <= b >> (7 - brightness);

        end else begin
            red <= 0; green <= 0; blue <= 0; // shifting alone would leave a faint glow

        end

    end

    logic load_sreg, transmit_pixel, shift;
    logic [23:0] shift_reg = 0;

    controller ctrl (.clk, .load_sreg, .transmit_pixel, .pixel);

    ws2812b driver (
        .clk,
        .serial_in(shift_reg[23]),
        .transmit(transmit_pixel),
        .ws2812b_out(_48b),
        .shift
    );

    always_ff @(posedge clk) begin
        if (load_sreg)
            shift_reg <= {green, red, blue}; // the LEDs want green, red, blue, highest bit first
        else if (shift)
            shift_reg <= {shift_reg[22:0], 1'b0};
    end

endmodule


// Raises tick for one cycle out of every period cycles.
module ticker #(
    parameter int PERIOD = 2
)(
    input logic clk,
    input logic reset,
    output logic tick
);

    logic [$clog2(PERIOD)-1:0] count = 0;

    always_ff @(posedge clk) begin
        if (reset || count == PERIOD - 1) count <= 0;
        else count <= count + 1;
        tick <= !reset && count == PERIOD - 1;
    end

endmodule
