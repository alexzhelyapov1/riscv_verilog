function(add_verilator_test test_name)
    set(VERILOG_MODULE_NAME ${test_name}) # Имя Verilog модуля и .sv файла (regfile, ram)
    set(CPP_TESTBENCH_FILE ${CMAKE_CURRENT_SOURCE_DIR}/${test_name}.cpp) # tests/unit/regfile.cpp

    set(RTL_FILE ${CMAKE_SOURCE_DIR}/rtl/core/${VERILOG_MODULE_NAME}.sv)
    set(RTL_INCLUDE_PATH ${CMAKE_SOURCE_DIR}/rtl)

    # Директория, куда Verilator поместит свои объектные файлы и исполняемый файл теста
    set(OBJ_DIR ${CMAKE_CURRENT_BINARY_DIR}/obj_dir_${test_name})
    # Имя исполняемого файла, которое Verilator создаст (V<top_module_name>)
    set(VERILATOR_GENERATED_EXE ${OBJ_DIR}/V${VERILOG_MODULE_NAME})

    # Цель для сборки теста с помощью Verilator --exe --build
    set(BUILD_TARGET_NAME ${test_name}_build_verilated_exe)
    add_custom_target(${BUILD_TARGET_NAME} ALL
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OBJ_DIR}
        # Запускаем системный Verilator. VERILATOR_ROOT обычно не нужен.
        COMMAND ${PROJECT_VERILATOR_EXECUTABLE} # Используем найденный системный Verilator
                -Wall --Wno-fatal --cc --exe --build --trace
                # -j $(nproc) # Убираем для простоты и переносимости, make сам разберется
                --top-module ${VERILOG_MODULE_NAME}
                -I${RTL_INCLUDE_PATH}
                "${RTL_FILE}"
                "${CPP_TESTBENCH_FILE}"
                --Mdir "${OBJ_DIR}"
                -CFLAGS "-std=c++17 -Wall"
        DEPENDS ${RTL_FILE} ${CPP_TESTBENCH_FILE} # Зависит только от исходников
        COMMENT "Verilating and Building executable for ${test_name} using system Verilator"
        VERBATIM
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} # Где будет запускаться команда verilator
    )

    # Цель для запуска скомпилированного теста
    set(RUN_TARGET_NAME run_${test_name}_unittest)
    add_custom_target(${RUN_TARGET_NAME}
        COMMAND "${VERILATOR_GENERATED_EXE}"
        DEPENDS ${BUILD_TARGET_NAME}
        WORKING_DIRECTORY ${OBJ_DIR} # Запускаем из директории, где VCD может быть создан
        COMMENT "Running Verilated test for ${test_name}"
        VERBATIM
    )

    message(STATUS "Configured system Verilator test: ${test_name}")
    message(STATUS "  Build target: ${BUILD_TARGET_NAME}")
    message(STATUS "  Run target: ${RUN_TARGET_NAME}")

    if(TARGET tests_full)
        add_dependencies(tests_full ${RUN_TARGET_NAME})
    endif()
endfunction()


add_verilator_test(alu)