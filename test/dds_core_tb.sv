`timescale 1ns/1ps

module dds_core_tb;

    parameter PHASE_W = 32;
    parameter OUT_W   = 14;
    parameter LUT_W   = 10;  

    logic clk;
    logic rst;
    logic [PHASE_W-1:0] phase_step;
    logic [1:0]          wave_sel;
    logic signed [OUT_W-1:0] dds_out;

    logic [OUT_W-1:0] square_val;
    logic [OUT_W-1:0] saw_val;
    logic [OUT_W-1:0] tri_val;
    logic signed [OUT_W-1:0] sin_val;

    initial clk = 0;
    always #5 clk = ~clk;

    dds_core #(
        .PHASE_W(PHASE_W),
        .LUT_W(LUT_W),
        .OUT_W(OUT_W)
    ) uut (
        .clk(clk),
        .rst(rst),
        .phase_step(phase_step),
        .wave_sel(wave_sel),
        .dds_out(dds_out)
    );

    always_ff @(posedge clk) begin
        case (wave_sel)
            2'b00: sin_val <= dds_out;
            2'b01: square_val <= dds_out;
            2'b10: saw_val    <= dds_out;
            2'b11: tri_val    <= dds_out;
            default: begin
                square_val <= 0;
                saw_val    <= 0;
                tri_val    <= 0;
            end
        endcase
    end

    initial begin
        rst = 1;
        phase_step = 32'd429496729;
        wave_sel = 2'b00;
        #20;
        rst = 0;

//        #100 wave_sel = 2'b11;    // пила
//        #100 wave_sel = 2'b10;    // треугольник
//        #300 wave_sel = 2'b01;    // обратно меандр

        repeat (1000) @(posedge clk);

        $display("Симуляция завершена");
        $finish;
    end

    initial begin
        $dumpfile("dds_core_tb.vcd");
        $dumpvars(0, dds_core_tb);
    end

endmodule
