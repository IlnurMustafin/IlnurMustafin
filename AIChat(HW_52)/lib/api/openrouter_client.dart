import 'dart:convert';
import 'package:http/http.dart' as http;

class AIClient {
  final String apiKey;
  final String baseUrl;
  List<Map<String, String>> availableModels = [];

  AIClient({required this.apiKey, required this.baseUrl}) {
    _loadModels();
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  void _loadModels() {
    try {
      final defaultModels = [
        {'id': 'openai/gpt-4o-mini', 'name': 'GPT-4o Mini'},
        {'id': 'openai/gpt-4o', 'name': 'GPT-4o'},
        {'id': 'openai/gpt-3.5-turbo', 'name': 'GPT-3.5 Turbo'},
      ];
      availableModels = defaultModels.map((m) => Map<String, String>.from(m)).toList();
    } catch (e) {
      availableModels = [];
    }
  }

  Future<List<Map<String, String>>> getModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/models'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = (data['data'] as List).map((model) => {
          'id': model['id'] as String,
          'name': model['name'] as String,
        }).toList();
        availableModels = models;
        return models;
      }
    } catch (e) {
      // Return default models on error
    }
    return availableModels;
  }

  Future<Map<String, dynamic>> getBalance() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/balance'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {
        'error': 'HTTP ${response.statusCode}: ${response.body}',
        'status': 'error',
      };
    } catch (e) {
      return {'error': e.toString(), 'status': 'error'};
    }
  }

  Future<Map<String, dynamic>> sendMessage(String message, String model) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: _headers,
        body: json.encode({
          'model': model,
          'messages': [{'role': 'user', 'content': message}],
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'HTTP ${response.statusCode}: ${response.body}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}