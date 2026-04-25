import 'chat_cache.dart';

class Analytics {
  final ChatCache cache;
  final DateTime startTime;
  Map<String, Map<String, int>> modelUsage = {};
  List<Map<String, dynamic>> sessionData = [];

  Analytics(this.cache) : startTime = DateTime.now();

  Future<void> loadHistoricalData() async {
    final history = await cache.getAnalyticsHistory();
    for (final record in history) {
      final model = record['model'] as String;
      final tokensUsed = record['tokens_used'] as int;

      modelUsage.putIfAbsent(model, () => {'count': 0, 'tokens': 0});
      modelUsage[model]!['count'] = (modelUsage[model]!['count'] ?? 0) + 1;
      modelUsage[model]!['tokens'] = (modelUsage[model]!['tokens'] ?? 0) + tokensUsed;

      sessionData.add({
        'timestamp': record['timestamp'],
        'model': model,
        'message_length': record['message_length'],
        'response_time': record['response_time'],
        'tokens_used': tokensUsed,
      });
    }
  }

  Future<void> trackMessage({
    required String model,
    required int messageLength,
    required double responseTime,
    required int tokensUsed,
  }) async {
    await cache.saveAnalytics(
      timestamp: DateTime.now(),
      model: model,
      messageLength: messageLength,
      responseTime: responseTime,
      tokensUsed: tokensUsed,
    );

    modelUsage.putIfAbsent(model, () => {'count': 0, 'tokens': 0});
    modelUsage[model]!['count'] = (modelUsage[model]!['count'] ?? 0) + 1;
    modelUsage[model]!['tokens'] = (modelUsage[model]!['tokens'] ?? 0) + tokensUsed;

    sessionData.add({
      'timestamp': DateTime.now().toIso8601String(),
      'model': model,
      'message_length': messageLength,
      'response_time': responseTime,
      'tokens_used': tokensUsed,
    });
  }

  Map<String, dynamic> getStatistics() {
    final totalTime = DateTime.now().difference(startTime).inSeconds;
    int totalTokens = 0;
    int totalMessages = 0;

    for (final usage in modelUsage.values) {
      totalTokens += usage['tokens'] ?? 0;
      totalMessages += usage['count'] ?? 0;
    }

    return {
      'total_messages': totalMessages,
      'total_tokens': totalTokens,
      'session_duration': totalTime,
      'messages_per_minute': totalTime > 0 ? (totalMessages * 60) / totalTime : 0,
      'tokens_per_message': totalMessages > 0 ? totalTokens / totalMessages : 0,
      'model_usage': modelUsage,
    };
  }

  void clearData() {
    modelUsage.clear();
    sessionData.clear();
  }
}