#!/usr/bin/env python3
import sys
import subprocess
import os
import argparse
import tempfile # Для более надежных временных файлов

def BytesToHexWords(binary_file_path, word_size_bytes, start_addr_bytes, output_file_path, endian='little'):
    if start_addr_bytes % word_size_bytes != 0:
        print(f"Warning: Start address 0x{start_addr_bytes:x} is not word-aligned for word size {word_size_bytes}. This might affect $readmemh @address.")

    start_word_addr = start_addr_bytes // word_size_bytes

    try:
        with open(binary_file_path, 'rb') as f_bin, open(output_file_path, 'w') as f_hex:
            f_hex.write(f"@{start_word_addr:08X}\n") # $readmemh uses word address

            while True:
                word_bytes = f_bin.read(word_size_bytes)
                if not word_bytes:
                    break

                if len(word_bytes) < word_size_bytes:
                    word_bytes = word_bytes.ljust(word_size_bytes, b'\0')

                if endian == 'little':
                    hex_val = int.from_bytes(word_bytes, byteorder='little')
                else:
                    hex_val = int.from_bytes(word_bytes, byteorder='big')

                f_hex.write(f"{hex_val:0{word_size_bytes*2}X}\n")
        print(f"Successfully converted {binary_file_path} to {output_file_path}")
        return True # Успех
    except Exception as e:
        print(f"Error during binary to hex conversion (BytesToHexWords): {e}")
        return False # Неудача

def main():
    parser = argparse.ArgumentParser(description="Convert RISC-V ELF file to Verilog $readmemh format.")
    parser.add_argument("elf_file", help="Input ELF file path.")
    parser.add_argument("output_hex_file", help="Output Verilog .hex file path.")
    parser.add_argument("--objcopy", default="riscv64-unknown-elf-objcopy", help="Path to riscv64-unknown-elf-objcopy.")
    parser.add_argument("--section", default=".text", help="ELF section to extract (e.g., .text, .data).")
    parser.add_argument("--wordsize", type=int, default=4, help="Word size in bytes for the hex file (e.g., 4 for 32-bit words).")
    parser.add_argument("--readelf", default="riscv64-unknown-elf-readelf", help="Path to riscv64-unknown-elf-readelf.")
    args = parser.parse_args()

    # Используем tempfile для создания временного файла с уникальным именем
    # и гарантированным удалением
    temp_bin_fd, temp_bin_file_path = tempfile.mkstemp(suffix=".bin", prefix="section_")
    os.close(temp_bin_fd) # Закрываем дескриптор, objcopy сам откроет файл по имени

    try:
        # 1. Get the start address of the section
        section_addr_cmd = [args.readelf, "-S", args.elf_file]
        start_addr_bytes = -1

        print(f"Running: {' '.join(section_addr_cmd)}")
        result = subprocess.run(section_addr_cmd, capture_output=True, text=True, check=True)
        for line in result.stdout.splitlines():
            if args.section in line and "PROGBITS" in line:
                parts = line.split()
                idx_name = -1
                for i, p in enumerate(parts):
                    if p == args.section:
                        idx_name = i
                        break
                if idx_name != -1 and len(parts) > idx_name + 2:
                    start_addr_str = parts[idx_name + 2]
                    start_addr_bytes = int(start_addr_str, 16)
                    print(f"Found section '{args.section}' starting at address 0x{start_addr_bytes:X}")
                    break
        if start_addr_bytes == -1:
            print(f"Error: Could not find section '{args.section}' or its address in ELF file: {args.elf_file}")
            sys.exit(1)

        # 2. Extract the specified section to a raw binary file
        objcopy_cmd = [
            args.objcopy,
            "-O", "binary",
            f"--only-section={args.section}",
            args.elf_file,
            temp_bin_file_path  # Используем полный путь к временному файлу
        ]

        print(f"Running: {' '.join(objcopy_cmd)}")
        subprocess.run(objcopy_cmd, check=True)
        if not os.path.exists(temp_bin_file_path) or os.path.getsize(temp_bin_file_path) == 0:
            print(f"Error: objcopy did not create a valid temp binary file: {temp_bin_file_path}")
            sys.exit(1)

        # 3. Convert the binary file to $readmemh format
        if not BytesToHexWords(temp_bin_file_path, args.wordsize, start_addr_bytes, args.output_hex_file):
            sys.exit(1) # Выход, если конвертация не удалась

    except subprocess.CalledProcessError as e:
        print(f"Error during ELF processing for {args.elf_file}: {e}")
        if e.stderr: print(f"Stderr: {e.stderr}")
        if e.stdout: print(f"Stdout: {e.stdout}")
        sys.exit(1)
    except FileNotFoundError as e:
        print(f"Error: A tool was not found: {e}")
        sys.exit(1)
    except ValueError as e:
        print(f"Error parsing number: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        sys.exit(1)
    finally:
        # 4. Clean up temporary binary file
        if os.path.exists(temp_bin_file_path):
            try:
                os.remove(temp_bin_file_path)
                print(f"Removed temporary file: {temp_bin_file_path}")
            except OSError as e:
                print(f"Error removing temporary file {temp_bin_file_path}: {e}")
        else:
            # Это может быть нормально, если objcopy не создал файл из-за пустой секции,
            # но мы добавили проверку выше.
            print(f"Warning: Temporary file {temp_bin_file_path} was not found for removal (check for earlier errors).")

if __name__ == "__main__":
    main()  