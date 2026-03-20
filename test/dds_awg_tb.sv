`timescale 1ns / 1ps

module tb_dds_awg;

    // Параметры (должны совпадать с dds_core)
    localparam int AMP_W   = 10;
    localparam int PHASE_W = 32;
    localparam int LUT_W   = 10;
    localparam int OUT_W   = 14;
    localparam int AWG_W   = 10;

    // [ДОБАВЛЕНО ДЛЯ CSV] Имя выходного файла
    localparam string OUTPUT_FILE = "awg_test_output.csv";

    // Сигналы
    logic                clk;
    logic                rst;
    logic [PHASE_W-1:0]  phase_step;
    logic [2:0]          wave_sel;
    logic [AMP_W-1:0]    amplitude;
    logic signed [OUT_W-1:0] offset;
    logic [PHASE_W-1:0]  duty_threshold;
    
    // Интерфейс AWG
    logic                awg_we;
    logic [AWG_W-1:0]    awg_addr_w;
    logic signed [OUT_W-1:0] awg_data_in;
    
    // Выход
    logic signed [OUT_W-1:0] dds_out;

    // Инстанцирование ядра
    dds_core #(
        .AMP_W(AMP_W),
        .PHASE_W(PHASE_W),
        .LUT_W(LUT_W),
        .OUT_W(OUT_W),
        .AWG_W(AWG_W)
    ) dut (
        .clk(clk),
        .rst(rst),
        .phase_step(phase_step),
        .wave_sel(wave_sel),
        .amplitude(amplitude),
        .offset(offset),
        .duty_threshold(duty_threshold),
        .awg_we(awg_we),
        .awg_addr_w(awg_addr_w),
        .awg_data_in(awg_data_in),
        .dds_out(dds_out)
    );

    // Генерация тактового сигнала (100 МГц)
    always #5 clk = ~clk;

    // ==========================================
    // [ДОБАВЛЕНО ДЛЯ CSV] Логика выгрузки в файл
    // ==========================================
    integer fd;
    int current_test_id = 0; // 0 - загрузка памяти (не пишем в файл), >0 - генерация

    initial begin
        fd = $fopen(OUTPUT_FILE, "w");
        if (fd == 0) begin
            $display("Ошибка: Не удалось открыть файл %s!", OUTPUT_FILE);
            $stop;
        end
        $fdisplay(fd, "time_ns,test_id,dds_out_dec");
    end

    // Пишем каждый такт, если снят сброс и мы перешли к тестам (current_test_id > 0)
    always @(posedge clk) begin
        if (!rst && current_test_id > 0) begin
            $fdisplay(fd, "%0d,%0d,%0d", $time, current_test_id, $signed(dds_out));
        end
    end

    final begin
        if (fd != 0) begin
            $fclose(fd);
            $display("Данные сохранены в файл: %s", OUTPUT_FILE);
        end
    end
    // ==========================================

    // Основной процесс тестирования
    initial begin
        // 1. Инициализация сигналов
        clk = 0;
        rst = 1;
        phase_step = 0;
        wave_sel = 3'b000;
        amplitude = 0;
        offset = 0;
        duty_threshold = 0;
        awg_we = 0;
        awg_addr_w = 0;
        awg_data_in = 0;
        
        current_test_id = 0; // Фаза загрузки (в CSV не попадает)

        // Ждем немного и снимаем сброс
        #20 rst = 0;
        #20;

        // 2. ФАЗА ЗАГРУЗКИ ПАМЯТИ AWG
        $display("Начинаем загрузку произвольной формы в память AWG...");
        
        // Заполним 1024 ячейки памяти кастомной формой (Трапеция)
        // Диапазон значений для 14-бит signed: от -8192 до +8191
        for (int i = 0; i < (1 << AWG_W); i++) begin
            @(posedge clk);
            awg_we = 1;
            awg_addr_w = i;
            
            // Формируем форму сигнала:
            if (i < 256) 
                awg_data_in = i * 30;              // Подъем
            else if (i < 768) 
                awg_data_in = 7680;                // Полка (максимум)
            else 
                awg_data_in = (1023 - i) * 30;     // Спад
        end
        
        // Отключаем запись
        @(posedge clk);
        awg_we = 0;
        $display("Загрузка завершена.");
        #50;

        // 3. ЗАПУСК ГЕНЕРАЦИИ AWG
        $display("Запуск DDS в режиме AWG...");
        
        // Настройки DDS
        phase_step = 32'd42949672; // Примерно 1/100 от частоты клока
        wave_sel = 3'b100;         // Режим 4 - наш AWG
        amplitude = 10'h3FF;       // Максимальная амплитуда (множитель 1.0)
        offset = 0;                // Без смещения
        
        // Начинаем писать в CSV
        current_test_id = 1;       // ID 1: Максимальная амплитуда
        #5000;

        // Проверим цифровую регулировку амплитуды на лету
        $display("Снижаем амплитуду в 2 раза...");
        current_test_id = 2;       // ID 2: Половинная амплитуда
        amplitude = 10'h1FF;       // ~0.5 от максимума
        #3000;

        // Проверим постоянное смещение
        $display("Добавляем постоянное смещение (Offset)...");
        current_test_id = 3;       // ID 3: Сигнал со смещением
        offset = 14'd2000;         // Смещаем сигнал вверх
        #3000;

        $display("Тест завершен.");
        
        // Надежное закрытие файла перед финишем
        if (fd != 0) begin
            $fclose(fd);
            fd = 0;
        end
        $finish;
    end

endmodule