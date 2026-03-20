`timescale 1ns/1ps

module dds_core #(
    parameter int AMP_W = 10,
    parameter int PHASE_W = 32,          //! Phase counter width
    parameter int LUT_W = 10,            //! Sine lut addr width
    parameter int OUT_W = 14             //! Output signal width
    //parameter int AMP_W = 8,             // Amplitude control width
    //parameter int MUL_W = OUT_W + AMP_W, // Multiplier width
) (             
    input  logic                clk,
    input  logic                rst, 
    input  logic [PHASE_W-1:0]  phase_step,
    input  logic [1:0]          wave_sel,
    input  logic [AMP_W-1:0]    amplitude, // Unsigned: 0 - silence, max - impower 1.0
    input logic signed [OUT_W-1:0] offset, // constant offset
    input  logic [PHASE_W-1:0] duty_threshold, // для скважности
    output logic signed [OUT_W-1:0]    dds_out
);

    logic [PHASE_W-1:0] phase_acc;

    always_ff @(posedge clk) begin
        if (rst)
            phase_acc <= 0;
        else
            phase_acc <= phase_acc + phase_step;
    end


    // SINE
    logic [1:0] quadrant;
    logic [LUT_W-1:0] phase_bits;
    logic [LUT_W-1:0] lut_addr;
    logic sign_invert;
    
    assign quadrant = phase_acc[PHASE_W-1:PHASE_W-2];
    assign phase_bits = phase_acc[PHASE_W-3-:LUT_W];
    
    always_comb begin
        case (quadrant)
            2'b00: begin // 0-90°
                lut_addr = phase_bits;
                sign_invert = 1'b0;
            end
            2'b01: begin // 90-180°
                lut_addr = ~phase_bits; // Mirrored
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
    logic sign_invert_pipe;

    quarter_sine_lut #(
        .ADDR_W(LUT_W),
        .DATA_W(OUT_W)
    ) quarter_sine_lut_inst (
        .clk(clk),
        .addr(lut_addr),
        .data_out(quarter_sine_val)
    );
    
    always_ff @( posedge clk ) begin
        if (rst)
            sign_invert_pipe <= 1'b0;
        else
            sign_invert_pipe <= sign_invert;
    end

    always_ff @(posedge clk) begin
        if (sign_invert_pipe)
            sine_val <= -quarter_sine_val;
        else
            sine_val <= quarter_sine_val;
    end


    // OTHER SIGNALS
    localparam signed [OUT_W-1:0] MAX_VAL = (1 << (OUT_W-1)) - 1;
    localparam signed [OUT_W-1:0] MIN_VAL = -(1 << (OUT_W-1));
    localparam int CENTER_VAL = 1 << (OUT_W-1);

    logic signed [OUT_W-1:0] square_raw;
    logic signed [OUT_W-1:0] saw_raw;
    logic signed [OUT_W-1:0] tri_raw;

    // SQUARE
    assign square_raw = (phase_acc < duty_threshold) ? MIN_VAL : MAX_VAL;


    // SAW
    assign saw_raw = phase_acc[PHASE_W-1 -: OUT_W] - CENTER_VAL;


    // TRIANGLE
    logic [OUT_W-1:0] tri_abs;
    assign tri_abs = phase_acc[PHASE_W-1] ? ~phase_acc[PHASE_W-2 -: OUT_W] : phase_acc[PHASE_W-2 -: OUT_W];
    assign tri_raw = $signed({1'b0, tri_abs}) - CENTER_VAL;

    logic signed [OUT_W-1:0] square_pipe [0:1];
    logic signed [OUT_W-1:0] saw_pipe [0:1];
    logic signed [OUT_W-1:0] tri_pipe [0:1];

    logic [1:0] wave_sel_pipe [0:1];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 2; i++) begin
                square_pipe[i]   <= '0;
                saw_pipe[i]      <= '0;
                tri_pipe[i]      <= '0;
                wave_sel_pipe[i] <= '0;
            end
        end else begin
            square_pipe[0] <= square_raw;
            square_pipe[1] <= square_pipe[0];

            saw_pipe[0] <= saw_raw;
            saw_pipe[1] <= saw_pipe[0];

            tri_pipe[0] <= tri_raw;
            tri_pipe[1] <= tri_pipe[0];

            wave_sel_pipe[0] <= wave_sel;
            wave_sel_pipe[1] <= wave_sel_pipe[0];
        end
    end


    // OUTPUT
    logic signed [OUT_W-1:0] wave_raw;

    always_comb begin
        case (wave_sel_pipe[1])
            2'b00: wave_raw = sine_val;
            2'b01: wave_raw = square_pipe[1];
            2'b10: wave_raw = saw_pipe[1];
            2'b11: wave_raw = tri_pipe[1];
            default: wave_raw = '0;
        endcase
    end

    localparam int MUL_W = OUT_W + AMP_W;

    // STAGE 1
    logic signed [OUT_W-1:0] dsp_s1_wave;
    logic [AMP_W-1:0]        dsp_s1_amp;
    logic signed [OUT_W-1:0] dsp_s1_offset;

    // STAGE 2
    logic signed [MUL_W-1:0] dsp_s2_mul_res;
    logic signed [OUT_W-1:0] dsp_s2_offset_pipe;
    
    // STAGE 3
    logic signed [OUT_W-1:0] dsp_s3_scaled_wave;
    logic signed [OUT_W:0]   dsp_s3_sum_wide;

    always_comb begin
        dsp_s3_scaled_wave = dsp_s2_mul_res >>> AMP_W;
        dsp_s3_sum_wide = $signed({dsp_s3_scaled_wave[OUT_W-1], dsp_s3_scaled_wave}) + 
                          $signed({dsp_s2_offset_pipe[OUT_W-1], dsp_s2_offset_pipe});
    end

    always_ff @( posedge clk ) begin
        if (rst) begin
            dsp_s1_wave   <= '0;
            dsp_s1_amp    <= '0;
            dsp_s1_offset <= '0;
            dsp_s2_mul_res <= '0;
            dsp_s2_offset_pipe <= '0;
            dds_out <= '0;
        end else begin
            dsp_s1_wave <= wave_raw;
            dsp_s1_amp <= amplitude;
            dsp_s1_offset <= offset;

            dsp_s2_mul_res <= dsp_s1_wave * $signed({1'b0, dsp_s1_amp});
            dsp_s2_offset_pipe <= dsp_s1_offset;

            if (dsp_s3_sum_wide > $signed({2'b0, MAX_VAL})) begin
                dds_out <= MAX_VAL;
            end else if (dsp_s3_sum_wide < $signed({2'b11, MIN_VAL[OUT_W-2:0]})) begin
                dds_out <= MIN_VAL;    
            end else begin
                dds_out <= dsp_s3_sum_wide[OUT_W-1:0];
            end
        end
    end
endmodule
