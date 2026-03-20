module dual_port_ram_awg #(
    parameter int DATA_WIDTH = 12,
    parameter int ADDR_WIDTH = 10
) (
    input wire clk_w,
    input wire we,
    input wire [ADDR_WIDTH-1:0] addr_w,
    input wire [DATA_WIDTH-1:0] data_in,

    input wire clk_r,
    input wire [ADDR_WIDTH-1:0] addr_r,
    output reg [DATA_WIDTH-1:0] data_out
);
    reg [DATA_WIDTH-1:0] ram_block [0:(2**ADDR_WIDTH)-1];

    always @(posedge clk_w) begin
        if (we) begin
            ram_block[addr_w] <= data_in;
        end
    end

    always @(posedge clk_r) begin
        data_out <= ram_block[addr_r];
    end
endmodule