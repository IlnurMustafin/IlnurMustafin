# AI Chat (VseGPT)

Кроссплатформенное десктопное приложение для общения с AI моделями через [vsegpt.ru](https://vsegpt.ru) (OpenAI-совместимый API).

## Возможности

- 🤖 Поддержка различных AI моделей (GPT-4o, GPT-4o-mini, GPT-3.5, DeepSeek, Claude и др.)
- 💬 Удобный интерфейс чата с пузырьками сообщений
- 🔍 Поиск и фильтрация моделей
- 💰 Отображение баланса аккаунта vsegpt.ru
- 📊 Аналитика использования (токены, сообщения, время ответа)
- 💾 Сохранение и экспорт истории диалогов в JSON
- 🗑️ Очистка истории чата
- 📝 Логирование работы приложения
- 🔒 API ключ зашифрован в коде (безопасно для GitHub)

## Поддерживаемые платформы

- **macOS** (Intel и Apple Silicon)
- **Windows** 10/11
- **Linux** (Ubuntu 20.04+)

## Быстрый старт

```bash
# Установка зависимостей
pip install -r requirements.txt

# Запуск
python3 src/main.py
```

Подробная инструкция: [INSTALL.md](INSTALL.md)

## Структура проекта

```
51-macOs/
├── src/
│   ├── main.py              # Точка входа в приложение
│   ├── api/
│   │   └── openai_client.py # Клиент для OpenAI API (vsegpt.ru)
│   ├── ui/
│   │   ├── styles.py        # Стили интерфейса
│   │   └── components.py    # UI компоненты
│   └── utils/
│       ├── cache.py         # Кэширование истории (SQLite)
│       ├── logger.py        # Логирование
│       ├── analytics.py     # Аналитика использования
│       ├── monitor.py       # Мониторинг производительности
│       └── crypto_key.py    # Шифрование API ключа
├── assets/
│   └── icon.ico             # Иконка приложения
├── build.py                 # Скрипт сборки
├── requirements.txt         # Зависимости
├── INSTALL.md               # Инструкция по установке
└── README.md                # Этот файл
```

## Технологии

- [Flet](https://flet.dev/) - кроссплатформенный UI фреймворк
- [VseGPT.ru](https://vsegpt.ru) - OpenAI-совместимый API
- SQLite - хранение истории чата
- PyInstaller - сборка в исполняемый файл

## Лицензия

MIT