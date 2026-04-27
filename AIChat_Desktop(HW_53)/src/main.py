"""
AI Chat приложение на Flet с поддержкой macOS, Windows и Linux.
Использует OpenAI API через vsegpt.ru.
"""

import flet as ft
from api.openai_client import OpenAIClient
from ui.styles import AppStyles
from ui.components import MessageBubble, ModelSelector
from utils.cache import ChatCache
from utils.logger import AppLogger
from utils.analytics import Analytics
from utils.monitor import PerformanceMonitor
from utils.notifications import EmailNotifier, check_and_notify_low_balance
import asyncio
import time
import json
from datetime import datetime
import os
import sys


class ChatApp:
    """
    Основной класс приложения чата.
    Управляет всей логикой работы приложения, включая UI и взаимодействие с API.
    """
    def __init__(self):
        # Инициализация основных компонентов
        self.api_client = OpenAIClient()
        self.cache = ChatCache()
        self.logger = AppLogger()
        self.analytics = Analytics(self.cache)
        self.monitor = PerformanceMonitor()

        # Создание компонента для отображения баланса API
        self.balance_text = ft.Text(
            "Баланс: Загрузка...",
            **AppStyles.BALANCE_TEXT
        )
        self.update_balance()

        # Инициализация уведомителя о низком балансе
        self.notifier = EmailNotifier()

        # Создание директории для экспорта истории чата
        self.exports_dir = "exports"
        os.makedirs(self.exports_dir, exist_ok=True)
        
    def load_chat_history(self):
        try:
            history = self.cache.get_chat_history()
            for msg in reversed(history):
                _, model, user_message, ai_response, timestamp, tokens = msg
                self.chat_history.controls.extend([
                    MessageBubble(message=user_message, is_user=True),
                    MessageBubble(message=ai_response, is_user=False)
                ])
        except Exception as e:
            self.logger.error(f"Ошибка загрузки истории чата: {e}")

    def update_balance(self):
        try:
            balance = self.api_client.get_balance()
            self.balance_text.value = f"Баланс: {balance}"
            self.balance_text.color = ft.Colors.GREEN_400
        except Exception as e:
            self.balance_text.value = "Баланс: н/д"
            self.balance_text.color = ft.Colors.RED_400
            self.logger.error(f"Ошибка обновления баланса: {e}")
            
    def main(self, page: ft.Page):
        # Применение базовых настроек страницы
        for key, value in AppStyles.PAGE_SETTINGS.items():
            setattr(page, key, value)

        AppStyles.set_window_size(page)

        # Инициализация выпадающего списка для выбора модели AI
        models = self.api_client.available_models
        self.model_dropdown = ModelSelector(models)
        # Устанавливаем значение как строку ID модели, а не как словарь
        self.model_dropdown.value = models[0]['id'] if models else None

        async def send_message_click(e):
            if not self.message_input.value:
                return

            try:
                self.message_input.border_color = ft.Colors.BLUE_400
                page.update()

                start_time = time.time()
                user_message = self.message_input.value
                self.message_input.value = ""
                page.update()

                # Добавление сообщения пользователя
                self.chat_history.controls.append(
                    MessageBubble(message=user_message, is_user=True)
                )

                # Индикатор загрузки
                loading = ft.ProgressRing()
                self.chat_history.controls.append(loading)
                page.update()

                # Асинхронная отправка запроса
                loop = asyncio.get_event_loop()
                response = await loop.run_in_executor(
                    None,
                    lambda: self.api_client.send_message(
                        user_message, 
                        self.model_dropdown.value
                    )
                )

                # Удаление индикатора загрузки
                self.chat_history.controls.remove(loading)

                # Обработка ответа
                if "error" in response:
                    response_text = f"Ошибка: {response['error']}"
                    tokens_used = 0
                    self.logger.error(f"Ошибка API: {response['error']}")
                else:
                    response_text = response["choices"][0]["message"]["content"]
                    tokens_used = response.get("usage", {}).get("total_tokens", 0)

                # Сохранение в кэш
                self.cache.save_message(
                    model=self.model_dropdown.value,
                    user_message=user_message,
                    ai_response=response_text,
                    tokens_used=tokens_used
                )

                # Добавление ответа в чат
                self.chat_history.controls.append(
                    MessageBubble(message=response_text, is_user=False)
                )

                # Обновление аналитики
                response_time = time.time() - start_time
                self.analytics.track_message(
                    model=self.model_dropdown.value,
                    message_length=len(user_message),
                    response_time=response_time,
                    tokens_used=tokens_used
                )

                self.monitor.log_metrics(self.logger)

                # Проверка баланса и отправка уведомления если низкий баланс
                self.update_balance()
                check_and_notify_low_balance(self.balance_text.value, self.notifier)

                page.update()

            except Exception as e:
                self.logger.error(f"Ошибка отправки сообщения: {e}")
                self.message_input.border_color = ft.Colors.RED_500

                snack = ft.SnackBar(
                    content=ft.Text(
                        str(e),
                        color=ft.Colors.RED_500,
                        weight=ft.FontWeight.BOLD
                    ),
                    bgcolor=ft.Colors.GREY_900,
                    duration=5000,
                )
                page.overlay.append(snack)
                snack.open = True
                page.update()

        def show_error_snack(page, message: str):
            snack = ft.SnackBar(
                content=ft.Text(
                    message,
                    color=ft.Colors.RED_500
                ),
                bgcolor=ft.Colors.GREY_900,
                duration=5000,
            )
            page.overlay.append(snack)
            snack.open = True
            page.update()


        async def show_analytics(e):
            stats = self.analytics.get_statistics()

            dialog = ft.AlertDialog(
                title=ft.Text("Аналитика"),
                content=ft.Column([
                    ft.Text(f"Всего сообщений: {stats['total_messages']}"),
                    ft.Text(f"Всего токенов: {stats['total_tokens']}"),
                    ft.Text(f"Среднее токенов/сообщение: {stats['tokens_per_message']:.2f}"),
                    ft.Text(f"Сообщений в минуту: {stats['messages_per_minute']:.2f}")
                ]),
                actions=[
                    ft.TextButton("Закрыть", on_click=lambda e: close_dialog(dialog)),
                ],
            )

            page.overlay.append(dialog)
            dialog.open = True
            page.update()

        async def clear_history(e):
            try:
                self.cache.clear_history()
                self.analytics.clear_data()
                self.chat_history.controls.clear()
                
            except Exception as e:
                self.logger.error(f"Ошибка очистки истории: {e}")
                show_error_snack(page, f"Ошибка очистки истории: {str(e)}")


        async def confirm_clear_history(e):
            def close_dlg(e):
                close_dialog(dialog)

            async def clear_confirmed(e):
                await clear_history(e)
                close_dialog(dialog)
                

            dialog = ft.AlertDialog(
                modal=True,
                title=ft.Text("Подтверждение удаления"),
                content=ft.Text("Вы уверены? Это действие нельзя отменить!"),
                actions=[
                    ft.TextButton("Отмена", on_click=close_dlg),
                    ft.TextButton("Очистить", on_click=clear_confirmed),
                ],
                actions_alignment=ft.MainAxisAlignment.END,
            )

            page.overlay.append(dialog)
            dialog.open = True
            page.update()
            
        def close_dialog(dialog):
            dialog.open = False
            page.update()
                    
            if dialog in page.overlay:
                page.overlay.remove(dialog)
      

        async def save_dialog(e):
            try:
                history = self.cache.get_chat_history()

                dialog_data = []
                for msg in history:
                    dialog_data.append({
                        "timestamp": msg[4],
                        "model": msg[1],
                        "user_message": msg[2],
                        "ai_response": msg[3],
                        "tokens_used": msg[5]
                    })

                filename = f"chat_history_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
                filepath = os.path.join(self.exports_dir, filename)

                with open(filepath, 'w', encoding='utf-8') as f:
                    json.dump(dialog_data, f, ensure_ascii=False, indent=2, default=str)

                dialog = ft.AlertDialog(
                    modal=True,
                    title=ft.Text("Диалог сохранен"),
                    content=ft.Column([
                        ft.Text("Путь сохранения:"),
                        ft.Text(filepath, selectable=True, weight=ft.FontWeight.BOLD),
                    ]),
                    actions=[
                        ft.TextButton("OK", on_click=lambda e: close_dialog(dialog)),
                        ft.TextButton("Открыть папку", 
                            on_click=lambda e: open_folder(self.exports_dir)
                        ),
                    ],
                )

                page.overlay.append(dialog)
                dialog.open = True
                page.update()

            except Exception as e:
                self.logger.error(f"Ошибка сохранения: {e}")
                show_error_snack(page, f"Ошибка сохранения: {str(e)}")

        def open_folder(path):
            """Открытие папки в файловом менеджере (кроссплатформенная версия)"""
            try:
                if sys.platform == 'darwin':  # macOS
                    os.system(f'open "{path}"')
                elif sys.platform == 'win32':  # Windows
                    os.startfile(path)
                else:  # Linux
                    os.system(f'xdg-open "{path}"')
            except Exception as e:
                self.logger.error(f"Ошибка открытия папки: {e}")


        # Создание компонентов интерфейса
        self.message_input = ft.TextField(**AppStyles.MESSAGE_INPUT)
        self.chat_history = ft.ListView(**AppStyles.CHAT_HISTORY)

        # Загрузка существующей истории
        self.load_chat_history()

        # Создание кнопок управления
        save_button = ft.ElevatedButton(
            on_click=save_dialog,
            **AppStyles.SAVE_BUTTON
        )

        clear_button = ft.ElevatedButton(
            on_click=confirm_clear_history,
            **AppStyles.CLEAR_BUTTON
        )

        send_button = ft.ElevatedButton(
            on_click=send_message_click,
            **AppStyles.SEND_BUTTON
        )

        analytics_button = ft.ElevatedButton(
            on_click=show_analytics,
            **AppStyles.ANALYTICS_BUTTON
        )

        # Создание layout компонентов
        control_buttons = ft.Row(
            controls=[
                save_button,
                analytics_button,
                clear_button
            ],
            **AppStyles.CONTROL_BUTTONS_ROW
        )

        input_row = ft.Row(
            controls=[
                self.message_input,
                send_button
            ],
            **AppStyles.INPUT_ROW
        )

        controls_column = ft.Column(
            controls=[
                input_row,
                control_buttons
            ],
            **AppStyles.CONTROLS_COLUMN
        )

        balance_container = ft.Container(
            content=self.balance_text,
            **AppStyles.BALANCE_CONTAINER
        )

        model_selection = ft.Column(
            controls=[
                self.model_dropdown.search_field,
                self.model_dropdown,
                balance_container
            ],
            **AppStyles.MODEL_SELECTION_COLUMN
        )

        self.main_column = ft.Column(
            controls=[
                model_selection,
                self.chat_history,
                controls_column
            ],
            **AppStyles.MAIN_COLUMN
        )

        page.add(self.main_column)
        
        self.monitor.get_metrics()
        
        self.logger.info("Приложение запущено")

def main():
    """Точка входа в приложение"""
    app = ChatApp()
    ft.app(target=app.main)

if __name__ == "__main__":
    main()