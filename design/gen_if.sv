interface gen_if #(
    parameter int AMP_W = 10,
    parameter int PHASE_W = 32, // Phase counter width         
    parameter int LUT_W = 10,   // Sine lut addr width
    parameter int OUT_W = 14,   // Output signal width
    parameter int AWG_W = 10
) (input logic clk);

    logic                    rst;
    logic [PHASE_W-1:0]      phase_step;
    logic [2:0]              wave_sel;
    logic [AMP_W-1:0]        amplitude;      // unsigned: 0 - silence, max - impower 1.0
    logic signed [OUT_W-1:0] offset;         // dc offset
    logic [PHASE_W-1:0]      duty_threshold; // duty cycle
    
    logic                    awg_we;
    logic [AWG_W-1:0]        awg_addr_w;
    logic signed [OUT_W-1:0] awg_data_in;
    logic signed [OUT_W-1:0] dds_out;

    modport dut(
        input clk, rst, phase_step, wave_sel, amplitude, offset, duty_threshold, awg_we, awg_addr_w, awg_data_in,
        output dds_out
    );

    modport tb(
        output rst, phase_step, wave_sel, amplitude, offset, duty_threshold, awg_we, awg_addr_w, awg_data_in,
        input  clk, dds_out
    );

endinterface