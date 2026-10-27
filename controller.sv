// Frame timing for the LED matrix, adapted from the iceBlinkPico led_matrix example.
// It sends all 64 pixels back to back and then waits, so a new frame starts 60 times a second.
// Each pixel gets one cycle for top.sv to look up its color, one cycle to load
// the shift register, and 360 cycles to send its 24 bits.

module controller (
    input logic clk,
    output logic load_sreg,
    output logic transmit_pixel,
    output logic [5:0] pixel
);

    localparam TRANSMIT_FRAME = 1'b0;
    localparam IDLE = 1'b1;

    localparam [1:0] READ_CH_VALS = 2'd0;
    localparam [1:0] LOAD_SREG = 2'd1;
    localparam [1:0] TRANSMIT_PIXEL = 2'd2;

    localparam [8:0] TRANSMIT_CYCLES = 9'd360; // 24 bits at 15 cycles each
    localparam [19:0] IDLE_CYCLES = 20'd200000 - 64 * TRANSMIT_CYCLES; // a frame is 200000 cycles at 60 frames a second

    logic state = TRANSMIT_FRAME;
    logic next_state;
    logic [1:0] transmit_phase = READ_CH_VALS;
    logic [1:0] next_transmit_phase;

    logic [5:0] pixel_counter = 0;
    logic [8:0] transmit_counter = 0;
    logic [19:0] idle_counter = 0;

    logic transmit_pixel_done, idle_done;
    assign transmit_pixel_done = (transmit_counter == TRANSMIT_CYCLES - 1);
    assign idle_done = (idle_counter == IDLE_CYCLES - 1);

    assign pixel = pixel_counter;
    assign load_sreg = (transmit_phase == LOAD_SREG);
    assign transmit_pixel = (transmit_phase == TRANSMIT_PIXEL);

    always_ff @(posedge clk) begin
        state <= next_state;
        transmit_phase <= next_transmit_phase;
    end

    always_comb begin
        unique case (state)
            TRANSMIT_FRAME: next_state = (pixel_counter == 63 && transmit_pixel_done) ? IDLE : TRANSMIT_FRAME;
            IDLE: next_state = idle_done ? TRANSMIT_FRAME : IDLE;
        endcase
    end

    always_comb begin
        next_transmit_phase = READ_CH_VALS;
        if (state == TRANSMIT_FRAME) begin
            unique case (transmit_phase)
                READ_CH_VALS: next_transmit_phase = LOAD_SREG;
                LOAD_SREG: next_transmit_phase = TRANSMIT_PIXEL;
                TRANSMIT_PIXEL: next_transmit_phase = transmit_pixel_done ? READ_CH_VALS : TRANSMIT_PIXEL;
            endcase

        end
    end

    always_ff @(posedge clk) begin
        if (state == TRANSMIT_FRAME && transmit_pixel_done)
            pixel_counter <= pixel_counter + 1;

        if (transmit_phase == TRANSMIT_PIXEL) transmit_counter <= transmit_counter + 1;
        else transmit_counter <= 0;

        if (state == IDLE) idle_counter <= idle_counter + 1;
        else idle_counter <= 0;
    end

endmodule
