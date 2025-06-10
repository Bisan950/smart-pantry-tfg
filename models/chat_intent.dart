class ChatIntent {
  final String type;
  final double confidence;
  final Map<String, dynamic> entities;

  ChatIntent({
    required this.type,
    required this.confidence,
    required this.entities,
  });

  @override
  String toString() {
    return 'ChatIntent(type: $type, confidence: $confidence, entities: $entities)';
  }
}