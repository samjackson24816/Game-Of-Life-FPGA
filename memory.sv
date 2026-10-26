module memory #(
    parameter INIT_FILE = "initial_grid.txt"
)(
    input logic clk,
    input logic [2:0] read_address,
    output logic [7:0] read_data
);

    logic [7:0] mem [0:7];

    initial if (INIT_FILE) begin
        $readmemh(INIT_FILE, mem);
    end

    always_ff @(posedge clk) begin
        read_data <= mem[read_address];
    end

endmodule
