import time
from datetime import datetime


class Analytics:
    """
    Класс для сбора и анализа данных об использовании приложения.
    """

    def __init__(self, cache):
        self.cache = cache
        self.start_time = time.time()
        self.model_usage = {}
        self.session_data = []
        
        self._load_historical_data()
        
    def _load_historical_data(self):
        history = self.cache.get_analytics_history()
        
        for record in history:
            timestamp, model, message_length, response_time, tokens_used = record
            
            if model not in self.model_usage:
                self.model_usage[model] = {
                    'count': 0,
                    'tokens': 0
                }
            self.model_usage[model]['count'] += 1
            self.model_usage[model]['tokens'] += tokens_used
            
            self.session_data.append({
                'timestamp': datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S.%f'),
                'model': model,
                'message_length': message_length,
                'response_time': response_time,
                'tokens_used': tokens_used
            })

    def track_message(self, model: str, message_length: int, response_time: float, tokens_used: int):
        timestamp = datetime.now()
        
        self.cache.save_analytics(timestamp, model, message_length, response_time, tokens_used)
        
        if model not in self.model_usage:
            self.model_usage[model] = {
                'count': 0,
                'tokens': 0
            }

        self.model_usage[model]['count'] += 1
        self.model_usage[model]['tokens'] += tokens_used

        self.session_data.append({
            'timestamp': timestamp,
            'model': model,
            'message_length': message_length,
            'response_time': response_time,
            'tokens_used': tokens_used
        })

    def get_statistics(self) -> dict:
        total_time = time.time() - self.start_time
        
        total_tokens = sum(model['tokens'] for model in self.model_usage.values())
        total_messages = sum(model['count'] for model in self.model_usage.values())

        return {
            'total_messages': total_messages,
            'total_tokens': total_tokens,
            'session_duration': total_time,
            'messages_per_minute': (total_messages * 60) / total_time if total_time > 0 else 0,
            'tokens_per_message': total_tokens / total_messages if total_messages > 0 else 0,
            'model_usage': self.model_usage
        }

    def export_data(self) -> list:
        return self.session_data

    def clear_data(self):
        self.model_usage.clear()
        self.session_data.clear()