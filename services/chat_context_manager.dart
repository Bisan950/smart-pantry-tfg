class ChatContextManager {
  final Map<String, dynamic> _context = {};
  final List<String> _conversationHistory = [];
  static const int _maxHistoryLength = 10;

  Future<void> initialize() async {
    _context.clear();
    _conversationHistory.clear();
  }

  void updateContext(String userMessage, dynamic intent) {
    // Actualizar historial
    _conversationHistory.add(userMessage);
    if (_conversationHistory.length > _maxHistoryLength) {
      _conversationHistory.removeAt(0);
    }

    // Actualizar contexto
    _context['lastMessage'] = userMessage;
    _context['lastIntent'] = intent.toString();
    _context['timestamp'] = DateTime.now().toIso8601String();
    _context['conversationHistory'] = List.from(_conversationHistory);
  }

  Map<String, dynamic> getContext() {
    return Map.from(_context);
  }

  void clearContext() {
    _context.clear();
    _conversationHistory.clear();
  }

  bool hasRecentIntent(String intentType) {
    return _context['lastIntent']?.toString().contains(intentType) ?? false;
  }

  String? getLastMessage() {
    return _context['lastMessage'];
  }
}