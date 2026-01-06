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
        for i in range(depth):
            if depth > 1:
                angle = (i / (depth - 1)) * (math.pi / 2)
            else:
                angle = 0
            
            sine_val = math.sin(angle)
            
            value = int(round(sine_val * max_val))
            
            hex_str = f"{value & 0x3FFF:04X}"
            f.write(f"{hex_str}\n")
    
    print(f"\nФайл 'quarter_sine_lut.mem' создан успешно!")
    print(f"  Общий размер: {depth} записей по {data_w} бит")

if __name__ == "__main__":
    ADDR_W = 10
    DATA_W = 14
    
    generate_quarter_sine_table(ADDR_W, DATA_W)
