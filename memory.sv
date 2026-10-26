module memory #(
    parameter INIT_FILE = "initial_grid.txt"
)(
    input logic clk,
    input logic [2:0] read_address,
    output logic [7:0] read_data
);

    logic [7:0] mem [0:7];

    initial if (INIT_FILE) begin
        $readmemb(INIT_FILE, mem);
    end

    // Combinational read for 8-byte distributed memory ensures 0-cycle latency
    assign read_data = mem[read_address];

endmodule
