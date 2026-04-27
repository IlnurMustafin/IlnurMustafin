"""
Клиент для взаимодействия с OpenAI API через vsegpt.ru.
Поддерживает отправку сообщений, получение списка моделей и проверку баланса.
"""

import requests
from utils.logger import AppLogger
from utils.crypto_key import get_api_key


class OpenAIClient:
    """
    Клиент для взаимодействия с OpenAI API через vsegpt.ru.
    
    VseGPT.ru предоставляет доступ к различным языковым моделям
    через OpenAI-совместимый API интерфейс.
    """
    
    def __init__(self):
        """
        Инициализация клиента OpenAI.
        
        Настраивает:
        - Систему логирования
        - API ключ и базовый URL
        - Заголовки для HTTP запросов
        - Список доступных моделей
        """
        self.logger = AppLogger()
        
        # Получение API ключа (из переменной окружения или из зашифрованного хранилища)
        self.api_key = get_api_key()
        self.base_url = "https://api.vsegpt.ru/v1"
        
        # Настройка заголовков для всех API запросов
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        self.logger.info("OpenAIClient initialized successfully")
        
        # Загрузка списка доступных моделей при инициализации
        self.available_models = self.get_models()

    def get_models(self):
        """
        Получение списка доступных языковых моделей.
        
        Returns:
            list: Список словарей с информацией о моделях:
                 [{"id": "model-id", "name": "Model Name"}, ...]
                 
        Note:
            При ошибке запроса возвращает список базовых моделей по умолчанию
        """
        self.logger.debug("Fetching available models")
        
        try:
            response = requests.get(
                f"{self.base_url}/models",
                headers=self.headers
            )
            models_data = response.json()
            
            self.logger.info(f"Retrieved {len(models_data['data'])} models")
            
            return [
                {
                    "id": model["id"],
                    "name": model.get("id", model["id"])  # Используем id как имя, если name нет
                }
                for model in models_data["data"]
            ]
        except Exception as e:
            # Список моделей по умолчанию при ошибке API
            models_default = [
                {"id": "gpt-4o", "name": "GPT-4o"},
                {"id": "gpt-4o-mini", "name": "GPT-4o Mini"},
                {"id": "gpt-3.5-turbo", "name": "GPT-3.5 Turbo"},
                {"id": "deepseek-chat", "name": "DeepSeek Chat"},
                {"id": "claude-3-haiku", "name": "Claude 3 Haiku"}
            ]
            self.logger.info(f"Retrieved {len(models_default)} models with Error: {e}")
            return models_default

    def send_message(self, message: str, model: str):
        """
        Отправка сообщения выбранной языковой модели.
        
        Args:
            message (str): Текст сообщения для отправки
            model (str): Идентификатор выбранной модели
            
        Returns:
            dict: Ответ от API, содержащий либо ответ модели, либо информацию об ошибке
        """
        self.logger.debug(f"Sending message to model: {model}")
        
        data = {
            "model": model,
            "messages": [{"role": "user", "content": message}]
        }
        
        try:
            self.logger.debug("Making API request")
            
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=self.headers,
                json=data
            )
            
            response.raise_for_status()
            
            self.logger.info("Successfully received response from API")
            
            return response.json()
            
        except Exception as e:
            error_msg = f"API request failed: {str(e)}"
            self.logger.error(error_msg, exc_info=True)
            return {"error": str(e)}

    def get_balance(self):
        """
        Получение текущего баланса аккаунта vsegpt.ru.
        
        Returns:
            str: Строка с балансом в формате 'X.XX ₽' или 'Ошибка' при неудаче
        """
        try:
            # VseGPT использует эндпоинт /balance для проверки баланса
            response = requests.get(
                f"{self.base_url}/balance",
                headers=self.headers
            )
            data = response.json()
            
            # Формат ответа vsegpt: {"status":"ok","data":{"credits":"187.66",...}}
            if data and data.get("status") == "ok":
                credits_data = data.get("data", {})
                if credits_data and "credits" in credits_data:
                    balance = float(credits_data["credits"])
                    return f"{balance:.2f} ₽"
            
            return "Ошибка"
            
        except Exception as e:
            error_msg = f"API request failed: {str(e)}"
            self.logger.error(error_msg, exc_info=True)
            return "Ошибка"
