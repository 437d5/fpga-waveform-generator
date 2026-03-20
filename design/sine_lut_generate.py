import math

def generate_quarter_sine_table(addr_w=10, data_w=14):    
    depth = 1 << addr_w
    max_val = (1 << (data_w - 1)) - 1
    
    print(f"Генерация таблицы 1/4 синусоиды:")
    print(f"  Биты адреса: {addr_w}")
    print(f"  Биты данных: {data_w}")
    print(f"  Размер таблицы: {depth} записей")
    print(f"  Максимальное значение: {max_val}")
    
    with open("quarter_sine_lut.mem", "w") as f:
        # Динамическая маска и количество HEX-символов
        mask = (1 << data_w) - 1
        hex_chars = (data_w + 3) // 4 # Вычисляем, сколько символов нужно (8 бит = 2, 12 бит = 3, 14 бит = 4)

        for i in range(depth):
            if depth > 1:
                angle = (i / (depth - 1)) * (math.pi / 2)
            else:
                angle = 0
            
            sine_val = math.sin(angle)
            value = int(round(sine_val * max_val))
            
            # Динамическое форматирование
            hex_str = f"{value & mask:0{hex_chars}X}"
            f.write(f"{hex_str}\n")
    
    print(f"\nФайл 'quarter_sine_lut.mem' создан успешно!")
    print(f"  Общий размер: {depth} записей по {data_w} бит")

if __name__ == "__main__":
    ADDR_W = 10
    DATA_W = 12
    
    generate_quarter_sine_table(ADDR_W, DATA_W)
