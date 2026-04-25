import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

enum AIProvider { vsegpt, openRouter }

class AuthService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'auth.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE auth (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            api_key TEXT NOT NULL,
            pin TEXT NOT NULL,
            provider TEXT NOT NULL,
            base_url TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Определяет провайдера по ключу
  AIProvider detectProvider(String apiKey) {
    if (apiKey.startsWith('sk-or-vv-')) {
      return AIProvider.vsegpt;
    } else if (apiKey.startsWith('sk-or-v1-')) {
      return AIProvider.openRouter;
    }
    throw Exception('Неизвестный тип ключа. Ключ должен начинаться с sk-or-vv- (VSEGPT) или sk-or-v1- (OpenRouter)');
  }

  /// Возвращает базовый URL для провайдера
  String getBaseUrl(AIProvider provider) {
    switch (provider) {
      case AIProvider.vsegpt:
        return 'https://api.vsegpt.ru/v1';
      case AIProvider.openRouter:
        return 'https://openrouter.ai/api/v1';
    }
  }

  /// Проверяет баланс ключа через API
  Future<Map<String, dynamic>> checkBalance(String apiKey, AIProvider provider) async {
    final baseUrl = getBaseUrl(provider);
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    try {
      if (provider == AIProvider.vsegpt) {
        // VSEGPT: проверяем баланс через /balance
        final response = await http.get(
          Uri.parse('$baseUrl/balance'),
          headers: headers,
        );
        if (response.statusCode == 200) {
          final responseJson = json.decode(response.body) as Map<String, dynamic>;
          if (responseJson['status'] == 'ok') {
            final data = responseJson['data'] as Map<String, dynamic>?;
            final creditsStr = data?['credits'] as String? ?? '0';
            final credits = double.tryParse(creditsStr) ?? 0.0;
            return {
              'valid': true,
              'balance': credits,
              'hasPositiveBalance': credits > 0,
            };
          }
          return {
            'valid': false,
            'error': responseJson['status'] ?? 'Неизвестный статус',
          };
        }
        return {
          'valid': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
        };
      } else {
        // OpenRouter: проверяем через /auth/key
        final response = await http.get(
          Uri.parse('$baseUrl/auth/key'),
          headers: headers,
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final keyData = data['data'] as Map<String, dynamic>?;
          final credits = (keyData?['credits'] as num?)?.toDouble() ?? 0.0;
          final usage = (keyData?['usage'] as num?)?.toDouble() ?? 0.0;
          final limit = (keyData?['limit'] as num?)?.toDouble();
          final remaining = limit != null ? limit - usage : credits;
          return {
            'valid': true,
            'balance': remaining,
            'hasPositiveBalance': remaining > 0,
          };
        }
        return {
          'valid': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'valid': false,
        'error': e.toString(),
      };
    }
  }

  /// Генерирует 4-значный PIN
  String generatePin() {
    final random = Random();
    return '${random.nextInt(10000)}'.padLeft(4, '0');
  }

  /// Сохраняет ключ и PIN в БД
  Future<void> saveCredentials({
    required String apiKey,
    required String pin,
    required AIProvider provider,
    required String baseUrl,
  }) async {
    final db = await database;
    // Очищаем старые данные
    await db.delete('auth');
    await db.insert('auth', {
      'api_key': apiKey,
      'pin': pin,
      'provider': provider.name,
      'base_url': baseUrl,
    });
  }

  /// Проверяет, есть ли сохраненные учетные данные
  Future<Map<String, dynamic>?> getSavedCredentials() async {
    final db = await database;
    final result = await db.query('auth', limit: 1);
    if (result.isEmpty) return null;
    return result.first;
  }

  /// Проверяет PIN
  Future<bool> verifyPin(String pin) async {
    final credentials = await getSavedCredentials();
    if (credentials == null) return false;
    return credentials['pin'] == pin;
  }

  /// Удаляет сохраненные учетные данные (сброс ключа)
  Future<void> resetCredentials() async {
    final db = await database;
    await db.delete('auth');
  }
}