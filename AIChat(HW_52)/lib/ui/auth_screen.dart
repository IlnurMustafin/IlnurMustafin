import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  final _keyController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _hasCredentials = false;
  String? _errorMessage;
  String? _providerName;

  @override
  void initState() {
    super.initState();
    _checkCredentials();
  }

  Future<void> _checkCredentials() async {
    final credentials = await _authService.getSavedCredentials();
    if (credentials != null && mounted) {
      setState(() {
        _hasCredentials = true;
        _providerName = credentials['provider'] as String?;
      });
    }
  }

  Future<void> _submitKey() async {
    final apiKey = _keyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _errorMessage = 'Введите ключ API');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Определяем провайдера
      final provider = _authService.detectProvider(apiKey);

      // Проверяем баланс
      final balanceResult = await _authService.checkBalance(apiKey, provider);

      if (!balanceResult['valid']) {
        setState(() {
          _errorMessage = 'Не удалось проверить ключ: ${balanceResult['error']}';
          _isLoading = false;
        });
        return;
      }

      if (!balanceResult['hasPositiveBalance']) {
        setState(() {
          _errorMessage = 'Баланс ключа нулевой или отрицательный. Пополните счет и попробуйте снова.';
          _isLoading = false;
        });
        return;
      }

      // Генерируем PIN и сохраняем
      final pin = _authService.generatePin();
      final baseUrl = _authService.getBaseUrl(provider);

      await _authService.saveCredentials(
        apiKey: apiKey,
        pin: pin,
        provider: provider,
        baseUrl: baseUrl,
      );

      if (!mounted) return;

      // Показываем PIN пользователю
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Ключ успешно активирован!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Провайдер: ${provider == AIProvider.vsegpt ? "VSEGPT" : "OpenRouter"}'),
              const SizedBox(height: 8),
              Text('Баланс: ${balanceResult['balance']} ${provider == AIProvider.vsegpt ? "руб." : "USD"}'),
              const SizedBox(height: 16),
              const Text(
                'Ваш PIN-код для входа:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade400),
                  ),
                  child: Text(
                    pin,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                      letterSpacing: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Запомните этот PIN. При следующем входе нужно будет ввести его.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => _buildChatScreen(apiKey, baseUrl, provider),
                  ),
                );
              },
              child: const Text('Начать чат'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Введите PIN-код');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = await _authService.verifyPin(pin);

    if (!mounted) return;

    if (isValid) {
      final credentials = await _authService.getSavedCredentials();
      if (credentials != null && mounted) {
        final provider = credentials['provider'] == 'vsegpt'
            ? AIProvider.vsegpt
            : AIProvider.openRouter;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => _buildChatScreen(
              credentials['api_key'] as String,
              credentials['base_url'] as String,
              provider,
            ),
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = 'Неверный PIN-код. Попробуйте снова.';
        _isLoading = false;
      });
    }
  }

  Future<void> _resetKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить ключ?'),
        content: const Text('Текущий ключ и PIN будут удалены. Потребуется ввести новый ключ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.resetCredentials();
      if (mounted) {
        setState(() {
          _hasCredentials = false;
          _providerName = null;
          _errorMessage = null;
          _keyController.clear();
          _pinController.clear();
        });
      }
    }
  }

  Widget _buildChatScreen(String apiKey, String baseUrl, AIProvider provider) {
    return ChatScreen(
      apiKey: apiKey,
      baseUrl: baseUrl,
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Логотип
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.blue.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'AI Chat',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade300,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Мульти-провайдерный AI чат',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 40),

                if (_hasCredentials) ...[
                  // Экран входа по PIN
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 40,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Вход по PIN-коду',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade200,
                          ),
                        ),
                        if (_providerName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Провайдер: ${_providerName == 'vsegpt' ? 'VSEGPT' : 'OpenRouter'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            letterSpacing: 8,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Введите PIN',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            counterText: '',
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
                              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                            ),
                          ),
                          onSubmitted: (_) => _submitPin(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitPin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Войти', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _resetKey,
                          child: Text(
                            'Сбросить ключ',
                            style: TextStyle(color: Colors.red.shade300),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Экран ввода ключа
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.vpn_key_outlined,
                          size: 40,
                          color: Colors.orange.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Введите ключ API',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade200,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Поддерживаются ключи VSEGPT (sk-or-vv-...) и OpenRouter (sk-or-v1-...)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _keyController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'sk-or-...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
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
                              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                            ),
                          ),
                          onSubmitted: (_) => _submitKey(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitKey,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Проверить и войти', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade700),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade200, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

