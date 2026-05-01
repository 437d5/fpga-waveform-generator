`timescale 1ns/1ps

module dds_dac_top #(
    parameter int AMP_W = 10,
    parameter int PHASE_W = 32,
    parameter int LUT_W = 10,
    parameter int OUT_W = 14,
    parameter int AWG_W = 10
)(
    input  logic       clk,            // Основная частота ПЛИС (например, 100 МГц)
    input  logic       spi_clk,        // Частота для SPI интерфейса (<= 30 МГц, например 25 МГц)
    input  logic       rst,            // Кнопка сброса (активный высокий)
    input  logic [2:0] wave_sel_sw,    // 3 свитча для выбора формы сигнала
    
    // Физические пины для подключения Pmod DA2
    output logic [1:0] pmod_sdata,
    output logic       pmod_sync,
    output logic       pmod_sclk
);

    // =======================================================
    // 1. Инициализация интерфейса
    // =======================================================
    gen_if #(
        .AMP_W(AMP_W),
        .PHASE_W(PHASE_W),
        .LUT_W(LUT_W),
        .OUT_W(OUT_W),
        .AWG_W(AWG_W)
    ) bus_if (
        .clk(clk)
    );

    // --- ПОДКЛЮЧЕНИЕ ВНЕШНИХ ПОРТОВ ---
    assign bus_if.rst      = rst;
    assign bus_if.wave_sel = wave_sel_sw;
    
    // --- ХАРДКОД ОСТАЛЬНЫХ ЗНАЧЕНИЙ ---
    
    // Шаг фазы: 42950 даст частоту ~1 кГц при clk = 100 МГц
    assign bus_if.phase_step     = 32'd42950; 
    
    // Амплитуда на максимум (для 10 бит это 1023)
    assign bus_if.amplitude      = 10'd1023;
    
    // Постоянное смещение равно нулю
    assign bus_if.offset         = 14'sd0;
    
    // Скважность 50% для квадратного сигнала (середина от 2^32)
    assign bus_if.duty_threshold = 32'h80000000;
    
    // Отключаем запись в память AWG
    assign bus_if.awg_we         = 1'b0;
    assign bus_if.awg_addr_w     = '0;
    assign bus_if.awg_data_in    = '0;

    // =======================================================
    // 2. Инстанцирование ядра DDS
    // =======================================================
    dds_core #(
        .AMP_W(AMP_W),
        .PHASE_W(PHASE_W),
        .LUT_W(LUT_W),
        .OUT_W(OUT_W),
        .AWG_W(AWG_W)
    ) dds_inst (
        .bus(bus_if.dut)
    );

    // =======================================================
    // 3. Преобразование: 14-bit Signed -> 12-bit Unsigned 
    // =======================================================
    logic [11:0] dac_data;
    
    // Инвертируем старший бит (знак) и отбрасываем 2 младших бита
    assign dac_data = {~bus_if.dds_out[OUT_W-1], bus_if.dds_out[OUT_W-2 : 2]};

    // =======================================================
    // 4. Подключение драйвера Pmod DA2
    // =======================================================
    wire update_trig;
    wire working_flag;

    // Автоматический запуск отправки при изменении данных
    da2AutoUpdate_dual auto_updater (
        .clk(clk),
        .rst(rst),
        .SYNC(pmod_sync),
        .update(update_trig),
        .chmode0(2'b00),       // Канал 0 включен
        .chmode1(2'b00),       // Канал 1 включен
        .value0(dac_data),     // Данные канала 0
        .value1(dac_data)      // Дублируем на канал 1
    );

    // Основной SPI драйвер
    da2_dual dac_driver (
        .clk(clk),
        .rst(rst),
        .SCLK(spi_clk),       
        .SDATA(pmod_sdata),   
        .SYNC(pmod_sync),     
        .working(working_flag),
        .chmode0(2'b00),      
        .chmode1(2'b00),      
        .value0(dac_data),
        .value1(dac_data),
        .update(update_trig)
    );

    // SCLK активен только во время передачи
    assign pmod_sclk = (working_flag) ? spi_clk : 1'b0;

endmodule