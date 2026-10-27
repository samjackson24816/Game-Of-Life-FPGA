// Game of Life on an 8x8 grid whose edges wrap around.
//
// Each cell is one byte. The top bit says whether it is alive, the next three
// bits are its brightness, and the low four bits are its hue. Brightness only
// affects the display and is never used by the rules.
//
// A generation takes 10 cycles. One row is worked out per cycle and saved in
// next_alive and next_hue, then the whole grid is updated at once.
//
// Brightness and colors are handled seperately

module game_of_life (
    input logic clk,
    input logic reset, // loads init_grid into the grid
    input logic enable_gen, // starts a new generation
    input logic fade_in_tick,
    input logic fade_out_tick,
    input logic [511:0] init_grid, // byte number r*8 + c holds the cell at row r, column c
    output logic [511:0] grid_out // same layout as init_grid
);

    logic [7:0] grid [7:0][7:0];
    logic next_alive [7:0][7:0];
    logic [3:0] next_hue [7:0][7:0];

    typedef enum logic [1:0] {IDLE = 2'd0, CALC = 2'd1, DONE = 2'd2} state_t;
    state_t state = IDLE;
    logic [2:0] row = 3'd0;

    // Next alive bit and hue for every cell in the current row.
    // Row and column numbers are 3 bits wide, so going past 7 or below 0 wraps around on its own.
    logic row_alive [7:0];
    logic [3:0] row_hue [7:0];
    always_comb begin
        for (int c = 0; c < 8; c++) begin
            logic [2:0] nr, nc;
            logic [3:0] neighbors;
            logic [7:0] hue_sum;
            logic alive;

            neighbors = 0;
            hue_sum = 0;
            for (int dr = -1; dr <= 1; dr++) begin
                for (int dc = -1; dc <= 1; dc++) begin
                    if (dr != 0 || dc != 0) begin
                        nr = row + dr;
                        nc = c + dc;
                        if (grid[nr][nc][7]) begin
                            neighbors = neighbors + 1;
                            hue_sum = hue_sum + grid[nr][nc][3:0];

                        end
                    end
                end
            end

            alive = grid[row][c][7];
            row_alive[c] = (neighbors == 3) || (alive && neighbors == 2);

            // A newborn takes the average hue of its three parents

            // We use a trick here: multiplying by 85 and shifting by 8 is a strat for division by 3
            if (!alive && row_alive[c])
                row_hue[c] = (hue_sum * 85) >> 8;
            else
                row_hue[c] = grid[row][c][3:0] + 4'd1;
        end
    end

    // Brightness after this cycle's fade ticks.
    logic [2:0] faded [7:0][7:0];

    always_comb begin
        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++) begin
                logic alive;
                logic [2:0] b;

                alive = grid[r][c][7];
                b = grid[r][c][6:4];

                if (alive && fade_in_tick && b != 7)
                    faded[r][c] = b + 1;

                else if (!alive && fade_out_tick && b != 0)
                    faded[r][c] = b - 1;

                else
                    faded[r][c] = b;

            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int r = 0; r < 8; r++)
                for (int c = 0; c < 8; c++)
                    grid[r][c] <= init_grid[(r*8 + c)*8 +: 8];
            state <= IDLE;
            row <= 0;

        end else begin
            // Fades keep running even while a generation is being worked out.
            for (int r = 0; r < 8; r++)
                for (int c = 0; c < 8; c++)
                    grid[r][c][6:4] <= faded[r][c];

            case (state)
                IDLE: if (enable_gen) state <= CALC;

                CALC: begin
                    for (int c = 0; c < 8; c++) begin
                        // Save the next alive bit and hue for this cell in the current row
                        next_alive[row][c] <= row_alive[c];
                        next_hue[row][c] <= row_hue[c];
                    end
                    row <= row + 1;
                    if (row == 7) state <= DONE;
                end

                DONE: begin
                    for (int r = 0; r < 8; r++) begin
                        for (int c = 0; c < 8; c++) begin
                            // If a cell just died, its brightness fades down one step. Otherwise it stays the same.
                            logic just_died;
                            logic [2:0] b;
                            just_died = grid[r][c][7] && !next_alive[r][c];
                            b = faded[r][c];
                            if (just_died && b != 0) b = b - 1;
                            grid[r][c] <= {next_alive[r][c], b, next_hue[r][c]};
                        end
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Output
    always_comb begin
        for (int r = 0; r < 8; r++)
            for (int c = 0; c < 8; c++)
                grid_out[(r*8 + c)*8 +: 8] = grid[r][c];
    end

endmodule
