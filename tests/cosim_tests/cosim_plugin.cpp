// Файл: tests/cosim_tests/cosim_plugin.cpp
#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#include "hart.h" // Предполагается, что hart.h доступен из include_directories C++ симулятора

// Глобальный файл для вывода из плагина (или передавать имя через окружение/аргумент)
// Для простоты пока захардкодим или будем ожидать, что имя передаст CMake
std::ofstream cosim_plugin_output_file;
bool cosim_plugin_file_opened = false;

// Эта функция может быть вызвана один раз при загрузке плагина, если это возможно.
// Или при первом вызове setReg.
void initialize_plugin_output(const std::string& filename) {
    if (!cosim_plugin_file_opened) {
        // Имя файла должно быть уникальным для каждого тестового случая
        // Например, ${OBJ_DIR_SIMULATOR_PART}/cosim_plugin_output_${test_case_name}.txt
        // CMake должен передать это имя файла, например, через переменную окружения,
        // или мы можем попытаться сконструировать его на основе имени ELF файла.
        // Пока что сделаем проще - CMake будет передавать путь через переменную окружения.
        const char* out_file_env = std::getenv("COSIM_PLUGIN_OUTPUT_FILE");
        std::string actual_filename = filename; // Резервное имя, если переменная не установлена

        if (out_file_env) {
            actual_filename = std::string(out_file_env);
        } else {
            std::cerr << "PLUGIN WARNING: COSIM_PLUGIN_OUTPUT_FILE env var not set. Using default: " << actual_filename << std::endl;
        }

        cosim_plugin_output_file.open(actual_filename, std::ios::out | std::ios::trunc);
        if (cosim_plugin_output_file.is_open()) {
            cosim_plugin_file_opened = true;
            std::cout << "PLUGIN: Output file opened: " << actual_filename << std::endl;
        } else {
            std::cerr << "PLUGIN ERROR: Could not open output file: " << actual_filename << std::endl;
        }
    }
}


extern "C" {
    // Вызывается симулятором при каждой записи в регистр
    void setReg(Machine::Hart *hart, Machine::RegId *reg_id_ptr, Machine::Instr *instr) {
        // Инициализируем файл при первом вызове (или можно сделать отдельную init функцию)
        // Для простоты, CMake должен передать имя файла через переменную окружения
        if (!cosim_plugin_file_opened) {
             const char* out_file_env = std::getenv("COSIM_PLUGIN_OUTPUT_FILE");
             if (out_file_env) {
                cosim_plugin_output_file.open(out_file_env, std::ios::out | std::ios::app); // Используем append, если много записей
                if (cosim_plugin_output_file.is_open()) {
                    cosim_plugin_file_opened = true;
                    // std::cout << "PLUGIN: Output file opened: " << out_file_env << std::endl;
                } else {
                    std::cerr << "PLUGIN ERROR: Could not open output file: " << out_file_env << std::endl;
                }
             } else {
                 std::cerr << "PLUGIN ERROR: COSIM_PLUGIN_OUTPUT_FILE env var not set in setReg." << std::endl;
                 return;
             }
        }

        if (cosim_plugin_file_opened && reg_id_ptr != nullptr) {
            Machine::RegId reg = *reg_id_ptr;
            if (reg != 0) { // Не логируем запись в x0, т.к. она не должна происходить
                Machine::RegValue val = hart->getReg(reg); // Получаем значение ПОСЛЕ того, как симулятор его установил
                // Записываем только значение wd3 (val)
                cosim_plugin_output_file << std::hex << std::setw(16) << std::setfill('0') << val << std::endl;
                // Для отладки плагина:
                // std::cout << "PLUGIN setReg: r" << static_cast<int>(reg) << " = 0x" << std::hex << val << std::dec << std::endl;
            }
        }
    }

} // extern "C"