// WS2812B bit sender from the iceBlinkPico led_matrix example.
// Each bit takes 15 cycles. The line stays high for 5 cycles to send a 0 and
// for 10 cycles to send a 1. Shift pulses at the start of each bit so the next one is ready.

module ws2812b (
    input logic clk,
    input logic serial_in,
    input logic transmit,
    output logic ws2812b_out,
    output logic shift
);

    localparam IDLE = 1'b0;
    localparam TRANSMITTING = 1'b1;

    localparam T0_CYCLE_COUNT = 4'd5;
    localparam T1_CYCLE_COUNT = 4'd10;
    localparam MAX_CYCLE_COUNT = 4'd15;

    logic state = IDLE;
    logic [3:0] cycle_count = 0;
    logic bit_being_sent = 0;

    always_ff @(posedge clk) begin
        unique case (state)
            IDLE:
                if (transmit) begin
                    state <= TRANSMITTING;
                    cycle_count <= 0;
                    bit_being_sent <= serial_in;
                end
            TRANSMITTING:
                if (!transmit) begin
                    state <= IDLE;

                end else if (cycle_count == MAX_CYCLE_COUNT - 1) begin
                    cycle_count <= 0;
                    bit_being_sent <= serial_in;

                end else begin
                    cycle_count <= cycle_count + 1;
                end
        endcase
    end

    assign ws2812b_out = (state == TRANSMITTING) &&
                         (cycle_count < (bit_being_sent ? T1_CYCLE_COUNT : T0_CYCLE_COUNT));

    assign shift = (state == TRANSMITTING) && (cycle_count == 0);

endmodule
