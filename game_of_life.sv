module game_of_life (
    input logic clk,
    input logic reset,
    input logic enable_gen, // pulses once per generation
    input logic [7:0][7:0] init_grid, // Packed 2D array for initial seed
    output logic [7:0][7:0] grid_out, // Packed 2D array for grid output
    output logic [7:0] generation_count
);

    // Packed 2D Array: 8 rows of 8 bits each
    logic [7:0][7:0] current_grid;
    logic [7:0][7:0] next_grid;

    // Compute next gen combinatorally
    always_comb begin
        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++) begin

                logic [3:0] neighbors; // 0-8 possible so we need 4 bits

                int r_up, r_down, c_left, c_right;
                
                // Ternary for wrapping values
                r_up   = (r == 0) ? 7 : r - 1;
                r_down = (r == 7) ? 0 : r + 1;
                c_left = (c == 0) ? 7 : c - 1;
                c_right= (c == 7) ? 0 : c + 1;

                neighbors = current_grid[r_up][c_left] +
                            current_grid[r_up][c] +
                            current_grid[r_up][c_right] +
                            current_grid[r][c_left] +
                            current_grid[r][c_right] +
                            current_grid[r_down][c_left] +
                            current_grid[r_down][c] +
                            current_grid[r_down][c_right];

                if (current_grid[r][c]) begin
                    // Cell lives if there are 2 or 3 neighbors
                    next_grid[r][c] = (neighbors == 2 || neighbors == 3);
                end else begin
                    // Cell is born if there are 3 neighbors
                    next_grid[r][c] = (neighbors == 3);
                end
            end
        end
    end

    // Sequential update of grid and generation counter
    always_ff @(posedge clk) begin

        if (reset) begin
            current_grid <= init_grid;
            generation_count <= 8'd0;

        end else if (enable_gen) begin
            current_grid <= next_grid;
            generation_count <= generation_count + 1;

        end
    end

    // Output 2D packed array directly
    assign grid_out = current_grid;

endmodule
