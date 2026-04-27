"""
Модуль для шифрования/дешифрования API ключа и SMTP пароля.
Использует base64 + простой XOR для обфускации ключа в коде.
ВНИМАНИЕ: Это не криптостойкое шифрование, а лишь обфускация,
чтобы ключ не был виден в открытом виде в репозитории.
Для production используйте переменные окружения или vault.
"""

import base64
import os

# XOR ключ для шифрования/дешифрования
_XOR_KEY = 0x5A

# Зашифрованный API ключ (получен XOR + base64)
# Для генерации нового ключа используйте функцию encrypt_api_key()
_ENCRYPTED_KEY = "KTF3NSh3LCx3Yjw7Pm47P2g+Pjw/PGJjbTk4bT84aT88aDk8Y2JoO2NrOGNsPj9uOTltbmxvOWxjbm1ib2tibD5paztjaT9jaw=="

# Зашифрованный SMTP пароль для отправки email уведомлений
# Для генерации нового пароля используйте функцию encrypt_api_key()
_ENCRYPTED_SMTP_PASSWORD = "LjM0NT84PS8yOyszIDUtIA=="


def decrypt(encrypted_key: str) -> str:
    """
    Дешифрует строку из зашифрованного хранилища.
    
    Args:
        encrypted_key (str): Зашифрованная строка в base64
        
    Returns:
        str: Расшифрованная строка
    """
    decoded = base64.b64decode(encrypted_key)
    decrypted = bytes([b ^ _XOR_KEY for b in decoded]).decode()
    return decrypted


def encrypt(plain_text: str) -> str:
    """
    Шифрует строку для хранения в коде.
    Используйте эту функцию для генерации нового зашифрованного значения.
    
    Args:
        plain_text (str): Исходная строка
        
    Returns:
        str: Зашифрованная строка в base64
    """
    encrypted_bytes = bytes([b ^ _XOR_KEY for b in plain_text.encode()])
    return base64.b64encode(encrypted_bytes).decode()


def decrypt_api_key() -> str:
    """
    Дешифрует API ключ из зашифрованного хранилища.
    
    Returns:
        str: Расшифрованный API ключ
    """
    return decrypt(_ENCRYPTED_KEY)


def encrypt_api_key(api_key: str) -> str:
    """
    Шифрует API ключ для хранения в коде.
    Используйте эту функцию для генерации нового зашифрованного ключа.
    
    Args:
        api_key (str): Исходный API ключ
        
    Returns:
        str: Зашифрованный ключ в base64
    """
    return encrypt(api_key)


def get_api_key() -> str:
    """
    Получение API ключа.
    Сначала пытается получить из переменной окружения VSEGPT_API_KEY,
    если не найдено - использует зашифрованный ключ из кода.
    
    Returns:
        str: API ключ
    """
    env_key = os.getenv("VSEGPT_API_KEY")
    if env_key:
        return env_key
    return decrypt_api_key()


def get_smtp_password() -> str:
    """
    Получение SMTP пароля.
    Сначала пытается получить из переменной окружения SMTP_PASSWORD,
    если не найдено - использует зашифрованный пароль из кода.
    
    Returns:
        str: SMTP пароль
    """
    env_password = os.getenv("SMTP_PASSWORD")
    if env_password:
        return env_password
    return decrypt(_ENCRYPTED_SMTP_PASSWORD)
