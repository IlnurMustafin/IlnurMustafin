import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'api/openrouter_client.dart' as api;
import 'ui/message_bubble.dart';
import 'ui/auth_screen.dart';
import 'utils/chat_cache.dart';
import 'utils/analytics.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.grey.shade900,
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade700,
          secondary: Colors.green.shade700,
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String apiKey;
  final String baseUrl;

  const ChatScreen({
    super.key,
    required this.apiKey,
    required this.baseUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late api.AIClient _apiClient;
  late ChatCache _cache;
  late Analytics _analytics;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  String? _selectedModel;
  bool _isLoading = false;
  bool _isInitialized = false;
  List<Map<String, String>> _filteredModels = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _apiClient = api.AIClient(apiKey: widget.apiKey, baseUrl: widget.baseUrl);
    _cache = ChatCache();
    _analytics = Analytics(_cache);
    await _analytics.loadHistoricalData();

    // Try to fetch models from API, fall back to defaults on error
    try {
      await _apiClient.getModels();
    } catch (_) {
      // Use default models
    }

    if (_apiClient.availableModels.isNotEmpty) {
      _selectedModel = _apiClient.availableModels.first['id'];
      _filteredModels = List.from(_apiClient.availableModels);
    }

    await _loadChatHistory();

    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _loadChatHistory() async {
    final history = await _cache.getChatHistory();
    for (final msg in history) {
      _messages.add({
        'text': msg['user_message'],
        'isUser': true,
      });
      _messages.add({
        'text': msg['ai_response'],
        'isUser': false,
      });
    }
    setState(() {});
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedModel == null) return;

    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    final startTime = DateTime.now();
    final response = await _apiClient.sendMessage(text, _selectedModel!);
    final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000.0;

    String responseText;
    int tokensUsed = 0;

    if (response.containsKey('error')) {
      responseText = 'Ошибка: ${response['error']}';
    } else {
      try {
        responseText = response['choices'][0]['message']['content'] ?? 'Нет ответа';
        tokensUsed = response['usage']?['total_tokens'] ?? 0;
      } catch (e) {
        responseText = 'Ошибка обработки ответа';
      }
    }

    await _cache.saveMessage(
      model: _selectedModel!,
      userMessage: text,
      aiResponse: responseText,
      tokensUsed: tokensUsed,
    );

    await _analytics.trackMessage(
      model: _selectedModel!,
      messageLength: text.length,
      responseTime: elapsed,
      tokensUsed: tokensUsed,
    );

    setState(() {
      _messages.add({'text': responseText, 'isUser': false});
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAnalytics() {
    final stats = _analytics.getStatistics();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Аналитика'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Всего сообщений: ${stats['total_messages']}'),
            Text('Всего токенов: ${stats['total_tokens']}'),
            Text('Среднее токенов/сообщение: ${(stats['tokens_per_message'] as num).toStringAsFixed(2)}'),
            Text('Сообщений в минуту: ${(stats['messages_per_minute'] as num).toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBalance() async {
    final balance = await _apiClient.getBalance();
    if (!mounted) return;

    String balanceText;
    if (balance['status'] == 'error') {
      balanceText = 'Баланс недоступен.\nВключите отображение баланса\nв настройках на сайте vsegpt.\n\nОшибка: ${balance['reason'] ?? balance['error']}';
    } else {
      try {
        final data = balance['data'] as Map<String, dynamic>?;
        final creditsStr = data?['credits'] as String? ?? '0';
        final credits = double.tryParse(creditsStr) ?? 0.0;
        final subscriptionStatus = data?['subscription_status'] as String? ?? '';
        final subscriptionEnd = data?['subscription_end'] as String? ?? '';

        balanceText = 'Баланс: ${credits.toStringAsFixed(2)} руб.';
        if (subscriptionStatus == 'ok' && subscriptionEnd.isNotEmpty) {
          balanceText += '\n\nПодписка активна до:\n$subscriptionEnd';
        }
      } catch (e) {
        balanceText = 'Ошибка обработки данных баланса';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Баланс'),
        content: Text(balanceText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение удаления'),
        content: const Text('Вы уверены? Это действие нельзя отменить!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cache.clearHistory();
      _analytics.clearData();
      setState(() {
        _messages.clear();
      });
    }
  }

  Future<void> _saveDialog() async {
    final history = await _cache.getChatHistory();
    final dialogData = history.map((msg) => {
      'timestamp': msg['timestamp'],
      'model': msg['model'],
      'user_message': msg['user_message'],
      'ai_response': msg['ai_response'],
      'tokens_used': msg['tokens_used'],
    }).toList();

    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${dir.path}/exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final filename = 'chat_history_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
    final filepath = '${exportsDir.path}/$filename';
    final file = File(filepath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(dialogData),
      encoding: utf8,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Диалог сохранен'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Путь сохранения:'),
            SelectableText(filepath, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _filterModels(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredModels = List.from(_apiClient.availableModels);
      } else {
        _filteredModels = _apiClient.availableModels.where((m) =>
          m['name']!.toLowerCase().contains(query.toLowerCase()) ||
          m['id']!.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
        backgroundColor: Colors.grey.shade900,
        actions: [],
      ),
      body: Column(
        children: [
          // Model selection area
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.grey.shade800,
            child: Column(
              children: [
                TextField(
                  onChanged: _filterModels,
                  decoration: InputDecoration(
                    hintText: 'Поиск модели',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade400),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedModel,
                      isExpanded: true,
                      dropdownColor: Colors.grey.shade900,
                      hint: const Text('Выбор модели', style: TextStyle(color: Colors.white70)),
                      items: _filteredModels.map((model) {
                        return DropdownMenuItem<String>(
                          value: model['id'],
                          child: Text(
                            model['name'] ?? model['id'] ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedModel = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chat history
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(10),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final msg = _messages[index];
                return MessageBubble(
                  message: msg['text'] as String,
                  isUser: msg['isUser'] as bool,
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.grey.shade800,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Введите сообщение здесь...',
                          filled: true,
                          fillColor: Colors.grey.shade800,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        cursorColor: Colors.white,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: const Icon(Icons.send),
                      label: const Text('Отправка'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveDialog,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Сохранить', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _showAnalytics,
                        icon: const Icon(Icons.analytics, size: 18),
                        label: const Text('Аналитика', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _showBalance,
                        icon: const Icon(Icons.account_balance_wallet, size: 18),
                        label: const Text('Баланс', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _confirmClearHistory,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Очистить', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}