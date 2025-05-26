#!/bin/bash

cd $(dirname "$0")

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root: sudo $0"
    exit 1
fi

if ! command -v lsb_release >/dev/null || [ "$(lsb_release -is)" != "Ubuntu" ]; then
    echo "[ERROR] This script for Ubuntu OS only."
    exit 1
fi

sudo apt update
sudo apt upgrade
sudo apt install -y verilator