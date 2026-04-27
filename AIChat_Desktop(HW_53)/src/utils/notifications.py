"""
Модуль для отправки email уведомлений о низком балансе.
Использует smtplib для отправки через SMTP сервер Gmail.
"""

import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
from utils.logger import AppLogger
from utils.crypto_key import get_smtp_password


# Конфигурация SMTP сервера
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 465  # SSL порт

# Email отправителя (с которого отправляются уведомления)
SENDER_EMAIL = "ilnur.mustafinn@gmail.com"

# Email получателя (администратор приложения)
ADMIN_EMAIL = "ilnur.mustafin1994@gmail.com"

# Порог баланса для отправки уведомления (в рублях)
BALANCE_THRESHOLD = 500.0


class EmailNotifier:
    """
    Класс для отправки email уведомлений.
    Использует SMTP сервер Gmail с SSL шифрованием.
    """
    
    def __init__(self):
        self.logger = AppLogger()
        self._last_notification_time = None
        self._min_notification_interval = 300  # Минимум 5 минут между уведомлениями
        
    def _can_send_notification(self) -> bool:
        """
        Проверка, можно ли отправить уведомление.
        Ограничивает частоту отправки (не чаще 1 раза в 5 минут).
        
        Returns:
            bool: True если можно отправить, False если слишком часто
        """
        if self._last_notification_time is None:
            return True
        
        elapsed = (datetime.now() - self._last_notification_time).total_seconds()
        return elapsed >= self._min_notification_interval
    
    def send_low_balance_notification(self, balance: float) -> bool:
        """
        Отправка уведомления о низком балансе.
        
        Args:
            balance (float): Текущий баланс в рублях
            
        Returns:
            bool: True если уведомление отправлено, False в противном случае
        """
        if not self._can_send_notification():
            self.logger.debug("Уведомление не отправлено: слишком часто")
            return False
        
        try:
            password = get_smtp_password()
            
            # Создание письма
            message = MIMEMultipart("alternative")
            message["Subject"] = "⚠️ Низкий баланс AI Chat (VseGPT)"
            message["From"] = SENDER_EMAIL
            message["To"] = ADMIN_EMAIL
            
            # Текстовая версия письма
            text = f"""
Здравствуйте!

Баланс вашего аккаунта VseGPT составляет {balance:.2f} ₽.

Порог низкого баланса: {BALANCE_THRESHOLD:.2f} ₽

Пожалуйста, пополните баланс, чтобы продолжить использование AI Chat.

Время проверки: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

С уважением,
AI Chat приложение
            """
            
            # HTML версия письма
            html = f"""
<html>
<body style="font-family: Arial, sans-serif; padding: 20px; background-color: #f5f5f5;">
    <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 10px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
        <h2 style="color: #e74c3c; margin-bottom: 20px;">⚠️ Низкий баланс AI Chat</h2>
        
        <p style="font-size: 16px; color: #333;">Здравствуйте!</p>
        
        <p style="font-size: 16px; color: #333;">
            Баланс вашего аккаунта <strong>VseGPT</strong> составляет:
        </p>
        
        <div style="text-align: center; padding: 20px; margin: 20px 0; background-color: #fff3cd; border-radius: 8px; border: 1px solid #ffc107;">
            <span style="font-size: 36px; font-weight: bold; color: #e74c3c;">{balance:.2f} ₽</span>
        </div>
        
        <p style="font-size: 14px; color: #666;">
            Порог низкого баланса: <strong>{BALANCE_THRESHOLD:.2f} ₽</strong>
        </p>
        
        <p style="font-size: 16px; color: #333;">
            Пожалуйста, <a href="https://vsegpt.ru" style="color: #3498db;">пополните баланс</a>, 
            чтобы продолжить использование AI Chat.
        </p>
        
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
        
        <p style="font-size: 12px; color: #999;">
            Время проверки: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}<br>
            AI Chat приложение
        </p>
    </div>
</body>
</html>
            """
            
            # Прикрепление обеих версий
            part1 = MIMEText(text, "plain", "utf-8")
            part2 = MIMEText(html, "html", "utf-8")
            message.attach(part1)
            message.attach(part2)
            
            # Отправка через SMTP SSL
            context = ssl.create_default_context()
            with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT, context=context) as server:
                server.login(SENDER_EMAIL, password)
                server.sendmail(SENDER_EMAIL, ADMIN_EMAIL, message.as_string())
            
            self._last_notification_time = datetime.now()
            self.logger.info(f"Уведомление о низком балансе ({balance:.2f} ₽) отправлено на {ADMIN_EMAIL}")
            return True
            
        except smtplib.SMTPAuthenticationError:
            self.logger.error(
                "Ошибка аутентификации SMTP. "
                "Для Gmail необходимо использовать пароль приложения (App Password), "
                "а не обычный пароль. "
                "Создайте пароль приложения в настройках Google Аккаунта -> Безопасность -> "
                "Пароли приложений. Или установите переменную окружения SMTP_PASSWORD."
            )
            return False
        except smtplib.SMTPException as e:
            self.logger.error(f"SMTP ошибка при отправке уведомления: {e}")
            return False
        except Exception as e:
            self.logger.error(f"Ошибка при отправке email уведомления: {e}")
            return False


def check_and_notify_low_balance(balance_value: str, notifier: EmailNotifier = None) -> bool:
    """
    Проверка баланса и отправка уведомления если он ниже порога.
    
    Args:
        balance_value (str): Строка с балансом (например "165.61 ₽")
        notifier (EmailNotifier, optional): Экземпляр уведомителя
        
    Returns:
        bool: True если уведомление отправлено, False в противном случае
    """
    if notifier is None:
        notifier = EmailNotifier()
    
    try:
        # Извлекаем числовое значение баланса из строки
        # Формат: "Баланс: 402.09 ₽" или "402.09 ₽"
        balance_str = balance_value.replace("Баланс: ", "").replace(" ₽", "").replace(",", ".").strip()
        balance = float(balance_str)
        
        if balance < BALANCE_THRESHOLD:
            return notifier.send_low_balance_notification(balance)
        
        return False
        
    except (ValueError, AttributeError) as e:
        logger = AppLogger()
        logger.error(f"Ошибка парсинга баланса для уведомления: {e}")
        return False