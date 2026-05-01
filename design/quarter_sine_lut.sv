`timescale 1ns/1ps

module quarter_sine_lut #(
    parameter ADDR_W = 10, 
    parameter DATA_W = 14  
) (
    input clk,
    input [ADDR_W-1:0] addr,
    output reg signed [DATA_W-1:0] data_out
);

    reg signed [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];

    initial begin
        $readmemh("design/quarter_sine_lut.mem", mem);
    end

    always @(posedge clk) begin
        data_out <= mem[addr];
    end

endmodule
