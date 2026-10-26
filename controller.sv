module controller (
    input logic clk,
    output logic load_sreg,
    output logic transmit_pixel,
    output logic [5:0] pixel,
    output logic [4:0] frame,
    output logic frame_idle
);

    // Main states
    localparam TRANSMIT_FRAME = 1'b0;
    localparam IDLE = 1'b1;

    localparam [1:0] READ_CH_VALS = 2'd0; // 1-cycle lookup preparation
    localparam [1:0] LOAD_SREG = 2'd1; // 1-cycle shift register load pulse
    localparam [1:0] TRANSMIT_PIXEL = 2'd2; // bit-stream transmission cycles

    localparam [8:0] TRANSMIT_CYCLES = 9'd360; // 24 bits / pixel * 15 cycles / bit
    localparam [19:0] IDLE_CYCLES = 20'd200000 - (64 * TRANSMIT_CYCLES); // (12M / 60 FPS = 200k total cycles) minus (64 pixels * TRANSMIT_CYCLES)

    // Main state
    logic state = TRANSMIT_FRAME;
    logic next_state;

    // Transmitting substate
    logic [1:0] transmit_phase = READ_CH_VALS;
    logic [1:0] next_transmit_phase;

    logic [5:0] pixel_counter = 6'd0; // tracks which of the 64 pixels is being sent
    logic [4:0] frame_counter = 5'd0; // tracks completed frames
    logic [8:0] transmit_counter = 9'd0; // counts cycles within a single pixel transmission
    logic [19:0] idle_counter = 20'd0; // counts cycles during idle period

    // Flags for completing
    logic transmit_pixel_done;
    logic idle_done;

    assign transmit_pixel_done = (transmit_counter == TRANSMIT_CYCLES - 1);
    assign idle_done = (idle_counter == IDLE_CYCLES - 1);

    assign pixel = pixel_counter;
    assign frame = frame_counter;
    assign load_sreg = (transmit_phase == LOAD_SREG);
    assign transmit_pixel = (transmit_phase == TRANSMIT_PIXEL);
    assign frame_idle = (state == IDLE);

    // Updating state with buffered new state
    always_ff @(posedge clk) begin
        state <= next_state;
        transmit_phase <= next_transmit_phase;
    end

    // State computing
    always_comb begin
        next_state = TRANSMIT_FRAME;
        unique case (state)
            TRANSMIT_FRAME:
                if ((pixel_counter == 6'd63) && (transmit_pixel_done))
                    next_state = IDLE;
                else
                    next_state = TRANSMIT_FRAME;
            IDLE:
                if (idle_done)
                    next_state = TRANSMIT_FRAME;
                else
                    next_state = IDLE;
        endcase
    end

    // Update substate
    always_comb begin
        next_transmit_phase = READ_CH_VALS;
        if (state == TRANSMIT_FRAME) begin
            unique case (transmit_phase)
                READ_CH_VALS:
                    next_transmit_phase = LOAD_SREG;
                LOAD_SREG:
                    next_transmit_phase = TRANSMIT_PIXEL;
                TRANSMIT_PIXEL:
                    next_transmit_phase = transmit_pixel_done ? READ_CH_VALS : TRANSMIT_PIXEL;
            endcase
        end
    end

    // Count up and loop counters

    always_ff @(posedge clk) begin
        if ((state == TRANSMIT_FRAME) && transmit_pixel_done) begin
            pixel_counter <= pixel_counter + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (idle_done) begin
            frame_counter <= frame_counter + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (transmit_phase == TRANSMIT_PIXEL) begin
            transmit_counter <= transmit_counter + 1;
        end
        else begin
            transmit_counter <= 9'd0;
        end
    end

    always_ff @(posedge clk) begin
        if (state == IDLE) begin
            idle_counter <= idle_counter + 1;
        end
        else begin
            idle_counter <= 20'd0;
        end
    end

endmodule
