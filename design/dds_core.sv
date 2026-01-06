module dds_core #(
    parameter int PHASE_W = 32,
    parameter int LUT_W = 10,
    parameter int OUT_W = 14
) (
    input logic clk,
    input logic rst, 
    input logic [PHASE_W-1:0] phase_step,
    input logic [1:0] wave_sel,
    output logic [OUT_W-1:0] dds_out
);

    logic [PHASE_W-1:0] phase_acc;

    always_ff @(posedge clk) begin
        if (rst)
            phase_acc <= 0;
        else
            phase_acc <= phase_acc + phase_step;
    end

    logic [1:0] quadrant;
    logic [LUT_W-1:0] phase_bits;
    logic [LUT_W-1:0] lut_addr;
    logic sign_invert;
    
    assign phase_bits = phase_acc >> (PHASE_W - 2 - LUT_W);
    assign quadrant = phase_acc[PHASE_W-1:PHASE_W-2];
    
    always_comb begin
        case (quadrant)
            2'b00: begin // 0-90°
                lut_addr = phase_bits;
                sign_invert = 1'b0;
            end
            2'b01: begin // 90-180°
                lut_addr = ~phase_bits; // Зеркально
                sign_invert = 1'b0;
            end
            2'b10: begin // 180-270°
                lut_addr = phase_bits;
                sign_invert = 1'b1;
            end
            2'b11: begin // 270-360°
                lut_addr = ~phase_bits; // Зеркально
                sign_invert = 1'b1;
            end
        endcase
    end

    logic signed [OUT_W-1:0] quarter_sine_val;
    logic signed [OUT_W-1:0] sine_val;

    quarter_sine_lut #(
        .ADDR_W(LUT_W),
        .DATA_W(OUT_W)
    ) quarter_sine_lut_inst (
        .clk(clk),
        .addr(lut_addr),
        .data_out(quarter_sine_val)
    );
    
    always_ff @(posedge clk) begin
        if (sign_invert)
            sine_val <= -quarter_sine_val;
        else
            sine_val <= quarter_sine_val;
    end

    localparam signed [OUT_W-1:0] MAX_VAL = (1 << (OUT_W-1)) - 1;
    localparam signed [OUT_W-1:0] MIN_VAL = -(1 << (OUT_W-1));
    localparam int CENTER_VAL = 1 << (OUT_W-1);

    logic signed [OUT_W-1:0] square_val;
    assign square_val = phase_acc[PHASE_W-1] ? MIN_VAL : MAX_VAL;

    logic signed [OUT_W-1:0] saw_val;
    assign saw_val = phase_acc[PHASE_W-1 -: OUT_W] - CENTER_VAL;

    logic signed [OUT_W-1:0] tri_val;
    logic [OUT_W-1:0] tri_raw;
    logic tri_half;
    
    assign tri_raw = phase_acc[PHASE_W-1 -: OUT_W];
    assign tri_half = phase_acc[PHASE_W-1];
    
    always_comb begin
        if (tri_half)
            tri_val = CENTER_VAL - tri_raw;
        else
            tri_val = tri_raw - CENTER_VAL;
    end

    logic signed [OUT_W-1:0] wave_raw;

    always_comb begin
        case (wave_sel)
            2'b00: wave_raw = sine_val;
            2'b01: wave_raw = square_val;
            2'b10: wave_raw = saw_val;
            2'b11: wave_raw = tri_val;
            default: wave_raw = '0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst)
            dds_out <= '0;
        else 
            dds_out <= wave_raw;
    end

endmodule