import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class ChatCache {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'chat_cache.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            model TEXT,
            user_message TEXT,
            ai_response TEXT,
            timestamp TEXT,
            tokens_used INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE analytics_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            model TEXT,
            message_length INTEGER,
            response_time REAL,
            tokens_used INTEGER
          )
        ''');
      },
    );
  }

  Future<void> saveMessage({
    required String model,
    required String userMessage,
    required String aiResponse,
    required int tokensUsed,
  }) async {
    final db = await database;
    await db.insert('messages', {
      'model': model,
      'user_message': userMessage,
      'ai_response': aiResponse,
      'timestamp': DateTime.now().toIso8601String(),
      'tokens_used': tokensUsed,
    });
  }

  Future<List<Map<String, dynamic>>> getChatHistory({int limit = 50}) async {
    final db = await database;
    final result = await db.query(
      'messages',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.reversed.toList();
  }

  Future<void> saveAnalytics({
    required DateTime timestamp,
    required String model,
    required int messageLength,
    required double responseTime,
    required int tokensUsed,
  }) async {
    final db = await database;
    await db.insert('analytics_messages', {
      'timestamp': timestamp.toIso8601String(),
      'model': model,
      'message_length': messageLength,
      'response_time': responseTime,
      'tokens_used': tokensUsed,
    });
  }

  Future<List<Map<String, dynamic>>> getAnalyticsHistory() async {
    final db = await database;
    return await db.query(
      'analytics_messages',
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('messages');
  }
}