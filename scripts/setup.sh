#!/bin/bash

echo "Attempting to install Verilator and its dependencies..."
echo "This script assumes you are on a Debian-based system (like Ubuntu) and have sudo privileges."

# Обновить список пакетов
sudo apt-get update

# Установить Verilator и основные зависимости для сборки C++
sudo apt-get install -y verilator g++ make git perl python3 autoconf flex bison ccache libfl-dev zlib1g-dev

# Проверка установки
if command -v verilator &> /dev/null
then
    echo "Verilator appears to be installed."
    verilator --version
else
    echo "Verilator installation failed or Verilator is not in PATH."
    echo "Please check the output above for errors."
    exit 1
fi

echo "Dependency installation script finished."
echo "Please re-run CMake configuration for your project."
exit 0