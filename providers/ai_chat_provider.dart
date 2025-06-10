// lib/providers/ai_chat_provider.dart
import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../services/ai_chat_service.dart';

class AIChatProvider with ChangeNotifier {
  final AIChatService _chatService = AIChatService();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _isThinking = false;

  // Getters
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isThinking => _isThinking;
  bool get hasError => _error != null;

  AIChatProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _setLoading(true);
      await _chatService.initialize();
      
      // Escuchar cambios en mensajes
      _chatService.getMessagesStream().listen(
        (messages) {
          _messages = messages;
          _isInitialized = true;
          _updateThinkingState();
          notifyListeners();
        },
        onError: (error) {
          _setError('Error en stream: $error');
        },
      );
      
      _setLoading(false);
    } catch (e) {
      _setError('Error inicializando: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      _setLoading(true);
      _setThinking(true);
      await _chatService.processMessage(text);
    } catch (e) {
      _setError('Error enviando mensaje: $e');
    } finally {
      _setLoading(false);
      _setThinking(false);
    }
  }

  Future<void> clearConversation() async {
    try {
      _setLoading(true);
      await _chatService.clearConversation();
    } catch (e) {
      _setError('Error limpiando conversación: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 🆕 MÉTODOS FALTANTES
  Future<void> clearMessages() async {
    await clearConversation();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Map<String, dynamic> getDebugInfo() {
    final lastMessage = _messages.isNotEmpty ? _messages.last : null;
    return {
      'isInitialized': _isInitialized,
      'isLoading': _isLoading,
      'isThinking': _isThinking,
      'hasError': hasError,
      'error': _error,
      'messageCount': _messages.length,
      'lastMessage': lastMessage != null ? {
        'type': lastMessage.type.toString(),
        'sender': lastMessage.sender.toString(),
        'timestamp': lastMessage.timestamp.toIso8601String(),
      } : null,
    };
  }

  void _updateThinkingState() {
    // Lógica para determinar si el bot está "pensando"
    _isThinking = _isLoading;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _updateThinkingState();
    notifyListeners();
  }

  void _setThinking(bool thinking) {
    _isThinking = thinking;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    _isLoading = false;
    _isThinking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}