# Инструкция по установке и сборке

## Системные требования

- **macOS**: macOS 11 (Big Sur) или выше
- **Windows**: Windows 10/11
- **Linux**: Ubuntu 20.04+ / аналоги
- Python 3.8 или выше
- pip (Python package manager)
- Минимум 2 ГБ свободного места на диске
- Стабильное интернет-соединение

## Быстрый запуск (без сборки)

### macOS / Linux

```bash
# 1. Перейдите в директорию проекта
cd 51-macOs

# 2. (Рекомендуется) Создайте виртуальное окружение
python3 -m venv venv
source venv/bin/activate

# 3. Установите зависимости
pip install -r requirements.txt

# 4. Запустите приложение (один из способов)
# Способ 1: через run.sh (автоматически найдет Python)
./run.sh

# Способ 2: напрямую
python3 src/main.py
```

### Windows

```cmd
cd 51-macOs
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python src\main.py
```

## Сборка приложения

### macOS

```bash
# 1. Перейдите в директорию проекта
cd 51-macOs

# 2. Запустите сборку
python3 build.py

# 3. Готовое приложение будет в директории `bin/AI Chat.app`
```

### Windows

```cmd
cd 51-macOs
python build.py
REM Исполняемый файл: bin/AIChat.exe
```

### Linux

```bash
cd 51-macOs
python3 build.py
chmod +x bin/aichat
# Исполняемый файл: bin/aichat
```

## Использование своего API ключа

По умолчанию API ключ зашифрован в коде. Чтобы использовать свой ключ:

1. Установите переменную окружения `VSEGPT_API_KEY`:
   ```bash
   export VSEGPT_API_KEY="ваш-ключ-от-vsegpt"
   ```
   Или добавьте в `~/.zshrc` (macOS) / `~/.bashrc` (Linux) для постоянного использования.

2. Либо создайте файл `.env` в корне проекта:
   ```
   VSEGPT_API_KEY=ваш-ключ-от-vsegpt
   ```

## Примечания

- Логи сборки можно найти в папке `build/logs/`
- История чата сохраняется в файле `chat_cache.db`
- Экспортированные диалоги сохраняются в папку `exports/`
- Логи приложения находятся в папке `logs/`
- При возникновении проблем:
  1. Убедитесь что есть доступ в интернет
  2. Проверьте наличие свободного места
  3. Попробуйте запустить сборку повторно
  4. Проверьте логи в папке `logs/`