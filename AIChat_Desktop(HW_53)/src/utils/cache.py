import sqlite3
import json
from datetime import datetime
import threading


class ChatCache:
    """
    Класс для кэширования истории чата в SQLite базе данных.
    """
    
    def __init__(self):
        self.db_name = 'chat_cache.db'
        self.local = threading.local()
        self.create_tables()

    def get_connection(self):
        if not hasattr(self.local, 'connection'):
            self.local.connection = sqlite3.connect(self.db_name)
        return self.local.connection

    def create_tables(self):
        conn = sqlite3.connect(self.db_name)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                model TEXT,
                user_message TEXT,
                ai_response TEXT,
                timestamp DATETIME,
                tokens_used INTEGER
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS analytics_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME,
                model TEXT,
                message_length INTEGER,
                response_time FLOAT,
                tokens_used INTEGER
            )
        ''')
        
        conn.commit()
        conn.close()

    def save_message(self, model, user_message, ai_response, tokens_used):
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO messages (model, user_message, ai_response, timestamp, tokens_used)
            VALUES (?, ?, ?, ?, ?)
        ''', (model, user_message, ai_response, datetime.now(), tokens_used))
        conn.commit()

    def get_chat_history(self, limit=50):
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT * FROM messages 
            ORDER BY timestamp DESC 
            LIMIT ?
        ''', (limit,))
        return cursor.fetchall()

    def save_analytics(self, timestamp, model, message_length, response_time, tokens_used):
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO analytics_messages 
            (timestamp, model, message_length, response_time, tokens_used)
            VALUES (?, ?, ?, ?, ?)
        ''', (timestamp, model, message_length, response_time, tokens_used))
        conn.commit()

    def get_analytics_history(self):
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT timestamp, model, message_length, response_time, tokens_used
            FROM analytics_messages
            ORDER BY timestamp ASC
        ''')
        return cursor.fetchall()

    def __del__(self):
        if hasattr(self.local, 'connection'):
            self.local.connection.close()
            
    def clear_history(self):
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('DELETE FROM messages')
        conn.commit()

    def get_formatted_history(self):
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT 
                id,
                model,
                user_message,
                ai_response,
                timestamp,
                tokens_used
            FROM messages 
            ORDER BY timestamp ASC
        ''')
        
        history = []
        for row in cursor.fetchall():
            history.append({
                "id": row[0],
                "model": row[1],
                "user_message": row[2],
                "ai_response": row[3],
                "timestamp": row[4],
                "tokens_used": row[5]
            })
        return history