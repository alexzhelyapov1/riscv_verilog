#!/usr/bin/env python3
import argparse
import sys

def parse_value(line_str, line_num, filename):
    """
    Пытается распарсить строку как hex или dec число.
    Возвращает int или None, если не удалось.
    """
    line_str = line_str.strip()
    if not line_str:
        return None

    original_str = line_str # Сохраняем для вывода ошибки

    # Если строка "X" или "x", это специальный маркер "не важно" / "нет записи"
    if line_str.lower() == "x":
        return "X_MARKER" # Используем специальный строковый маркер

    try:
        if line_str.lower().startswith("0x"):
            return int(line_str, 16)
        else:
            # Сначала пробуем как десятичное. Если не удается, пробуем как hex.
            try:
                return int(line_str, 10)
            except ValueError:
                # Если не чисто десятичное, но может быть hex без 0x
                is_hex_str = all(c in '0123456789abcdefABCDEF' for c in line_str)
                if is_hex_str:
                    return int(line_str, 16)
                else:
                    # print(f"Warning: File '{filename}', line {line_num}: Could not parse as dec or hex: '{original_str}'")
                    return None # Не смогли распознать
    except ValueError:
        # print(f"Warning: File '{filename}', line {line_num}: General parse error: '{original_str}'")
        return None

def compare_files(file1_path, file2_path):
    parsed_values1 = []
    parsed_values2 = []

    try:
        with open(file1_path, 'r') as f1:
            for i, line in enumerate(f1):
                val = parse_value(line, i + 1, file1_path)
                if val is not None:
                    parsed_values1.append(val)
        with open(file2_path, 'r') as f2:
            for i, line in enumerate(f2):
                val = parse_value(line, i + 1, file2_path)
                if val is not None:
                    parsed_values2.append(val)
    except FileNotFoundError as e:
        print(f"Error: File not found - {e.filename}")
        return False
    except Exception as e:
        print(f"Error reading files: {e}")
        return False

    print(f"Parsed {len(parsed_values1)} numeric/X values from {file1_path}")
    print(f"Parsed {len(parsed_values2)} numeric/X values from {file2_path}")

    mismatches = 0
    compare_len = min(len(parsed_values1), len(parsed_values2))

    if compare_len == 0 and (len(parsed_values1) > 0 or len(parsed_values2) > 0):
        print("Error: One of the files contains no valid numeric/X data to compare after parsing.")
        return False
    elif len(parsed_values1) == 0 and len(parsed_values2) == 0:
        print("Both files are effectively empty (no numeric/X data). Considered a match.")
        return True

    print(f"Comparing up to {compare_len} entries...")
    for i in range(compare_len):
        val1 = parsed_values1[i]
        val2 = parsed_values2[i]

        # Обработка маркера 'X' (не важно/нет записи)
        # Если в одном файле X, а в другом число, это несовпадение, *если мы ожидаем число*.
        # Но если оба X, это совпадение.
        # Если один X, а другой нет, и тестбенч, который произвел X, прав (т.е. WE=0),
        # то сравнение должно это учитывать.
        # Текущий pipeline_cosim_tb.cpp пишет значение только если WE=1.
        # Плагин пишет значение всегда при setReg (кроме x0).
        # Значит, если Verilog не записал (X), а плагин записал (число), это может быть нормально, если это не x0.
        # Проще всего, если оба файла выводят 'X' или оба выводят число.

        match = False
        if val1 == "X_MARKER" and val2 == "X_MARKER":
            match = True
        elif val1 == "X_MARKER": # File1 (Verilog) не ожидает записи
            # File2 (Simulator) мог записать что-то. Если это x0, то норм.
            # Но мы уже фильтруем x0 в плагине.
            # Если Verilog говорит X, а симулятор что-то пишет, это может быть ошибкой симулятора.
            # Но для простоты, если один X, а другой нет - считаем несовпадением.
            # Для более тонкой настройки нужна информация о WE из симулятора.
            match = False
        elif val2 == "X_MARKER": # Simulator не ожидает записи (маловероятно при текущем плагине)
            match = False
        elif val1 == val2:
            match = True

        if not match:
            print(f"Mismatch at entry {i+1}:")
            if val1 == "X_MARKER": print(f"  File1 (Verilog): Expected NO WRITE (X)")
            else: print(f"  File1 (Verilog): 0x{val1:<16X} ({val1:<20})") # Выводим и hex и dec

            if val2 == "X_MARKER": print(f"  File2 (Sim): Expected NO WRITE (X)")
            else: print(f"  File2 (Sim):     0x{val2:<16X} ({val2:<20})")
            mismatches += 1

    if len(parsed_values1) != len(parsed_values2):
        print(f"Warning: Files have different number of valid entries after parsing ({len(parsed_values1)} vs {len(parsed_values2)}). Compared up to {compare_len} entries.")

    if mismatches > 0:
        print(f"Found {mismatches} mismatches.")
        return False
    else:
        print("Files match numerically up to the shortest length of valid entries.")
        return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compares two trace files numerically.")
    parser.add_argument("file1", help="Path to the first trace file (e.g., Verilog output).")
    parser.add_argument("file2", help="Path to the second trace file (e.g., filtered C++ simulator output).")
    args = parser.parse_args()
    if compare_files(args.file1, args.file2):
        sys.exit(0)
    else:
        sys.exit(1)