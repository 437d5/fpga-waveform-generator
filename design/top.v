module dac_output_top(
    input wire clk,            // Основная частота логики ПЛИС
    input wire rst,            // Сброс (активный высокий)
    input wire spi_clk,        // Частота для SPI (например, 25 МГц. Должна быть <= 30 МГц)
    
    // Твои сигналы из генератора
    input wire [11:0] signal_ch0, // 12-битный сигнал для нулевого канала
    input wire [11:0] signal_ch1, // 12-битный сигнал для первого канала
    
    // Физические пины к Pmod DA2
    output wire [1:0] pmod_sdata, // SDATA (данные)
    output wire pmod_sync,        // SYNC (выбор кристалла/синхронизация)
    output wire pmod_sclk         // SCLK (тактовый сигнал SPI)
);

    wire update_trig;
    wire working_flag;

    // 1. Модуль авто-обновления: сам дергает update, если signal_ch0 или signal_ch1 изменились
    da2AutoUpdate_dual auto_updater (
        .clk(clk),
        .rst(rst),
        .SYNC(pmod_sync),
        .update(update_trig),
        .chmode0(2'b00),      // 00 - канал включен
        .chmode1(2'b00),      // 00 - канал включен
        .value0(signal_ch0),
        .value1(signal_ch1)
    );

    // 2. Основной драйвер ЦАП
    da2_dual dac_driver (
        .clk(clk),
        .rst(rst),
        .SCLK(spi_clk),       // Подаем тактовую частоту SPI
        .SDATA(pmod_sdata),   // Выход данных на пины Pmod
        .SYNC(pmod_sync),     // Выход SYNC на пины Pmod
        .working(working_flag),
        .chmode0(2'b00),      // Режим: 00 = Включен
        .chmode1(2'b00),      // Режим: 00 = Включен
        .value0(signal_ch0),  // Данные канала 0
        .value1(signal_ch1),  // Данные канала 1
        .update(update_trig)  // Триггер от модуля auto_updater
    );

    // 3. Управление тактовым сигналом SCLK наружу
    // В исходниках есть модуль da2ClkEn, но для простоты можно 
    // выводить spi_clk наружу только когда модуль 'working', чтобы не шуметь на линии
    assign pmod_sclk = (working_flag) ? spi_clk : 1'b0;

endmodule