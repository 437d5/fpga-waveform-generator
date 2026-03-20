`timescale 1ns/1ps

module dds_core_tb;

    // --- ПАРАМЕТРЫ ТЕСТИРОВАНИЯ ---
    localparam int PHASE_W = 32;
    localparam int LUT_W   = 10;
    localparam int OUT_W   = 12;
    localparam int AMP_W   = 10;

    localparam CLK_PERIOD = 10;
    localparam POINTS_PER_WAVE = 2000;
    localparam string OUTPUT_FILE = "dds_features_test.csv";

    // --- СИГНАЛЫ ---
    logic                clk;
    logic                rst;
    logic [PHASE_W-1:0]  phase_step;
    logic [1:0]          wave_sel;
    logic [AMP_W-1:0]    amplitude;      // НОВОЕ
    logic signed [OUT_W-1:0] offset;     // НОВОЕ
    logic [PHASE_W-1:0]  duty_threshold; // НОВОЕ
    logic signed [OUT_W-1:0] dds_out;

    // --- ИНСТАНЦИРОВАНИЕ DUT ---
    dds_core #(
        .PHASE_W(PHASE_W),
        .LUT_W(LUT_W),
        .OUT_W(OUT_W),
        .AMP_W(AMP_W)
    ) dut (
        .clk(clk),
        .rst(rst),
        .phase_step(phase_step),
        .wave_sel(wave_sel),
        .amplitude(amplitude),
        .offset(offset),
        .duty_threshold(duty_threshold),
        .dds_out(dds_out)
    );

    // --- ГЕНЕРАЦИЯ CLK ---
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // --- ЗАПИСЬ В ФАЙЛ ---
    integer fd;
    initial begin
        fd = $fopen(OUTPUT_FILE, "w");
        if (fd == 0) begin
            $display("Ошибка: Не удалось открыть файл %s!", OUTPUT_FILE);
            $stop;
        end
        // Добавили тестовый сценарий (test_id) в CSV для удобства фильтрации в Python
        $fdisplay(fd, "time_ns,test_id,dds_out_dec");
    end

    int current_test_id = 0; // Переменная для маркировки тестов

    always @(posedge clk) begin
        if (!rst) begin
            $fdisplay(fd, "%0d,%0d,%0d", $time, current_test_id, $signed(dds_out));
        end
    end

    final begin
        if (fd != 0) begin
            $fclose(fd);
            $display("Данные сохранены в файл: %s", OUTPUT_FILE);
        end
    end

    // --- СЦЕНАРИИ ТЕСТИРОВАНИЯ ---
    initial begin
        rst = 1;
        phase_step = 32'd42949673; // ~1 МГц при 100 МГц тактовой
        wave_sel = 0;
        
        // Значения по умолчанию
        amplitude = (1 << AMP_W) - 1; // Максимальная амплитуда
        offset = 0;                   // Без смещения
        duty_threshold = 32'h7FFFFFFF;// Скважность 50%

        #(CLK_PERIOD * 5);
        @(posedge clk);
        rst = 0; 
        @(posedge clk);

        // ТЕСТ 1: Базовый синус (Максимальная амплитуда)
        current_test_id = 1;
        wave_sel = 2'b00; 
        $display("Тест 1: Базовый синус");
        repeat(POINTS_PER_WAVE) @(posedge clk);

        // ТЕСТ 2: Синус с половинной амплитудой (Аттенюация)
        current_test_id = 2;
        amplitude = (1 << (AMP_W-1)); // Амплитуда 50%
        $display("Тест 2: Синус 50%% амплитуды");
        repeat(POINTS_PER_WAVE) @(posedge clk);

        // ТЕСТ 3: Синус со смещением (DC Offset)
        current_test_id = 3;
        amplitude = (1 << (AMP_W-1)); // Оставляем 50%
        offset = 1000;                // Поднимаем вверх на 1000 единиц
        $display("Тест 3: Синус со смещением +1000");
        repeat(POINTS_PER_WAVE) @(posedge clk);

        // ТЕСТ 4: Проверка обрезки (Saturation/Clipping)
        current_test_id = 4;
        amplitude = (1 << AMP_W) - 1; // Макс амплитуда
        offset = 1500;                // + Огромное смещение (Должно обрезать верхушки)
        $display("Тест 4: Проверка защиты от переполнения (Clipping)");
        repeat(POINTS_PER_WAVE) @(posedge clk);

        // ТЕСТ 5: ШИМ (Квадрат 25% скважности)
        current_test_id = 5;
        wave_sel = 2'b01;             // Квадрат
        offset = 0;
        duty_threshold = 32'h3FFFFFFF;// 25% от 2^32
        $display("Тест 5: Квадрат со скважностью 25%%");
        repeat(POINTS_PER_WAVE) @(posedge clk);

        // Завершение
        #(CLK_PERIOD * 10);
        $display("Все тесты завершены.");

        current_test_id = 6;
        wave_sel = 2'b00;             // Синус
        amplitude = (1 << AMP_W) - 1; // Макс амплитуда
        offset = 0;
        phase_step = 32'h80000000;    // Шаг ровно в половину фазы
        $display("Тест 6: Максимальная частота (Nyquist limit, 2 точки на период)");
        repeat(50) @(posedge clk);    // Тут хватит и 50 точек, период крошечный

        // ТЕСТ 7: Практический максимум (f_clk / 4 = 25 МГц)
        current_test_id = 7;
        phase_step = 32'h40000000;    // Шаг в четверть фазы
        $display("Тест 7: Высокая частота (4 точки на период)");
        repeat(50) @(posedge clk);

        $finish;
    end

endmodule