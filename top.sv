`include "memory.sv"
`include "game_of_life.sv"
`include "ws2812b.sv"
`include "controller.sv"

module top (
    input logic clk, // 12 MHz system clock
    input logic BOOT, // Active-low board reset button
    output logic _48b // WS2812B data output pin
);

    // 32-cycle power-on reset generator
    logic [4:0] por_counter = 5'd0;
    logic por_active;
    assign por_active = (por_counter != 5'd31);


    always_ff @(posedge clk) begin
        if (por_active) por_counter <= por_counter + 1;
    end


    // Combined internal reset signal
    logic sys_reset;
    assign sys_reset = por_active || (~BOOT);


    // Configuration Parameters
    localparam int SYSTEM_CLOCK_HZ = 12_000_000;
    localparam int GENERATIONS_PER_SEC = 10;
    localparam [22:0] AUTO_CYCLES = SYSTEM_CLOCK_HZ / GENERATIONS_PER_SEC;

    localparam [7:0]  MAX_BRIGHTNESS = 8'd100; // Peak brightness intensity when alive (0-255)
    localparam [7:0]  RAMP_STEP = 8'd10; // Brightness increase step per frame when cell becomes alive 
    localparam [7:0]  FADE_STEP = 8'd2; // Brightness decrease step per frame when cell dies
    localparam [7:0]  FADE_FLOOR = 8'd2; // Threshold below which brightness snaps directly to absolute zero (fully dark)


    logic [22:0] auto_counter = 23'd0;
    logic auto_tick = 1'b0;


    always_ff @(posedge clk) begin
        if (sys_reset) begin
            auto_counter <= 23'd0;
            auto_tick <= 1'b0;

        end else if (auto_counter == AUTO_CYCLES - 1) begin
            auto_counter <= 23'd0;
            auto_tick <= 1'b1;

        end else begin
            auto_counter <= auto_counter + 1;
            auto_tick <= 1'b0;

        end
    end

    // Load initial grid from ROM into packed 2D array on startup
    logic [7:0] rom_row_data;
    logic [2:0] load_counter = 3'd0;
    logic [7:0][7:0] initial_grid;
    logic grid_loaded = 1'b0;

    memory #(
        .INIT_FILE("initial_grid.txt")
    ) u_mem (
        .clk(clk),
        .read_address(load_counter),
        .read_data(rom_row_data)
    );

    // Read 8 rows sequentially from ROM on startup
    always_ff @(posedge clk) begin
        if (sys_reset) begin
            load_counter <= 3'd0;
            grid_loaded <= 1'b0;

        end else if (!grid_loaded) begin

            initial_grid[load_counter] <= rom_row_data;

            if (load_counter == 3'd7) begin
                grid_loaded <= 1'b1;

            end else begin
                load_counter <= load_counter + 1;

            end
        end
    end


    // Generation pulse trigger when automatic tick fires and grid is loaded
    logic enable_gen;
    assign enable_gen = grid_loaded ? auto_tick : 1'b0;


    // Keep Game of Life engine in reset until ROM initial grid is fully loaded
    logic gol_reset;
    assign gol_reset = sys_reset || !grid_loaded;


    // Game of Life cellular automaton core
    logic [7:0][7:0] gol_grid_out;
    logic [7:0] gen_count;


    game_of_life u_gol (
        .clk(clk),
        .reset(gol_reset),
        .enable_gen(enable_gen),
        .init_grid(initial_grid),
        .grid_out(gol_grid_out),
        .generation_count(gen_count)
    );


    // Pixel tracking and display controller output declarations
    logic [5:0] pixel;
    logic [4:0] frame;
    logic frame_idle;


    // Frame start edge detector for smooth real-time 60 FPS animation
    logic frame_idle_d = 1'b0;
    logic frame_start;


    always_ff @(posedge clk) begin
        if (sys_reset) begin
            frame_idle_d <= 1'b0;
        end else begin
            frame_idle_d <= frame_idle;
        end
    end


    assign frame_start = frame_idle && !frame_idle_d;


    // Smooth real-time intensity display buffer (updated at 60 FPS on frame_start)
    logic [7:0][7:0][7:0] display_grid;


    always_ff @(posedge clk) begin
        if (sys_reset) begin
            display_grid <= '0;
            
        end else if (!grid_loaded) begin
            display_grid <= '0;

        end else if (frame_start) begin
            for (int r = 0; r < 8; r++) begin
                for (int c = 0; c < 8; c++) begin
                    if (gol_grid_out[r][c]) begin
                        // Ramp up brightness smoothly toward MAX_BRIGHTNESS
                        if (display_grid[r][c] < MAX_BRIGHTNESS) begin
                            display_grid[r][c] <= (display_grid[r][c] + RAMP_STEP > MAX_BRIGHTNESS) ? MAX_BRIGHTNESS : display_grid[r][c] + RAMP_STEP;

                        end

                    end else begin

                        // linear fade-out
                        if (display_grid[r][c] < FADE_FLOOR) begin
                            display_grid[r][c] <= 8'd0;

                        end else begin
                            display_grid[r][c] <= display_grid[r][c] - FADE_STEP;

                        end
                    end
                end
            end
        end
    end

    // Index mapping from display controller
    logic [2:0] r_idx, c_idx;
    assign r_idx = pixel[5:3]; // Row index (0-7)
    assign c_idx = pixel[2:0]; // Column index (0-7)

    // Get current pixel intensity from display buffer
    logic [7:0] pixel_intensity;
    assign pixel_intensity = display_grid[r_idx][c_idx];

    // RGB color mapping (using green for now)
    logic [7:0] red_data, green_data, blue_data;
    assign red_data = 8'd0;
    assign green_data = pixel_intensity;
    assign blue_data = 8'd0;

    // serial driver and controller instantiation
    logic [23:0] shift_reg = 24'd0;
    logic load_sreg;
    logic transmit_pixel;
    logic shift;
    logic ws2812b_out;

    ws2812b u_ws2812b (
        .clk(clk),
        .serial_in(shift_reg[23]),
        .transmit(transmit_pixel),
        .ws2812b_out(ws2812b_out),
        .shift(shift)
    );

    controller u_ctrl (
        .clk(clk),
        .load_sreg(load_sreg),
        .transmit_pixel(transmit_pixel),
        .pixel(pixel),
        .frame(frame),
        .frame_idle(frame_idle)
    );

    // Shift register parallel load and bit-stream shift logic
    always_ff @(posedge clk) begin
        if (load_sreg) begin
            shift_reg <= { green_data, red_data, blue_data }; // Load 24-bit GRB color
        end else if (shift) begin
            shift_reg <= { shift_reg[22:0], 1'b0 }; // Shift out MSB first
        end
    end

    // Assign final physical LED output
    assign _48b = ws2812b_out;

endmodule
