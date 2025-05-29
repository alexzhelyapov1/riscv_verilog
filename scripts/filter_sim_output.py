#!/usr/bin/env python3
import argparse
import sys

def filter_log(input_filepath, output_filepath, skip_header_lines, skip_footer_lines):
    try:
        with open(input_filepath, 'r') as infile:
            lines = infile.readlines()

        if skip_header_lines > len(lines):
            print(f"Warning: skip_header_lines ({skip_header_lines}) is greater than total lines ({len(lines)}). Output will be empty.")
            processed_lines = []
        else:
            # Убираем заголовок
            lines_after_header = lines[skip_header_lines:]

            # Убираем подвал
            if skip_footer_lines >= len(lines_after_header):
                # Если нужно убрать больше строк, чем осталось после заголовка, результат - пустой
                processed_lines = []
                if skip_footer_lines > 0 : # Печатаем предупреждение только если действительно пытались убрать подвал
                     print(f"Warning: skip_footer_lines ({skip_footer_lines}) is greater than remaining lines after header ({len(lines_after_header)}). Resulting data is empty.")
            else:
                if skip_footer_lines > 0:
                    processed_lines = lines_after_header[:-skip_footer_lines]
                else: # Если skip_footer_lines = 0, берем все до конца
                    processed_lines = lines_after_header

        with open(output_filepath, 'w') as outfile:
            for line in processed_lines:
                outfile.write(line) # Сохраняем строку как есть, включая перевод строки

        print(f"Filtered log: Read {len(lines)} lines from {input_filepath}, wrote {len(processed_lines)} lines to {output_filepath}.")

    except Exception as e:
        print(f"Error filtering log file {input_filepath}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Filters simulator output log.")
    parser.add_argument("input_file", help="Path to the raw simulator output file.")
    parser.add_argument("output_file", help="Path to the filtered output file.")
    parser.add_argument("--skip_header", type=int, default=4, help="Number of header lines to skip.")
    parser.add_argument("--skip_footer", type=int, default=3, help="Number of footer lines to skip.")

    args = parser.parse_args()

    filter_log(args.input_file, args.output_file, args.skip_header, args.skip_footer)