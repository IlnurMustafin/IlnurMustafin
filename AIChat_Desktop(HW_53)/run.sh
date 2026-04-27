#!/bin/bash
# Скрипт для запуска AI Chat приложения
# Автоматически определяет правильный Python интерпретатор

# Ищем python с установленным flet
PYTHON=""
for cmd in python3 python python3.12 python3.11; do
    if command -v $cmd &> /dev/null; then
        if $cmd -c "import flet" &> /dev/null; then
            PYTHON=$cmd
            break
        fi
    fi
done

# Проверяем miniconda
if [ -z "$PYTHON" ]; then
    for conda_path in "$HOME/miniconda3/bin/python3" "$HOME/miniconda3/bin/python" "/usr/local/miniconda3/bin/python3"; do
        if [ -f "$conda_path" ]; then
            if $conda_path -c "import flet" &> /dev/null; then
                PYTHON=$conda_path
                break
            fi
        fi
    done
fi

if [ -z "$PYTHON" ]; then
    echo "Ошибка: Python с установленным flet не найден."
    echo "Установите зависимости: pip install -r requirements.txt"
    exit 1
fi

echo "Запуск AI Chat с использованием: $PYTHON"
cd "$(dirname "$0")"
$PYTHON src/main.py