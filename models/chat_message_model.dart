// lib/models/chat_message_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum para representar el tipo de mensaje
enum MessageType {
  text,
  suggestion,
  action;

  /// Método para convertir de string a enum
  static MessageType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'text':
        return MessageType.text;
      case 'suggestion':
        return MessageType.suggestion;
      case 'action':
        return MessageType.action;
      default:
        return MessageType.text;
    }
  }

  /// Método para convertir a String para almacenamiento en base de datos
  @override
  String toString() {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.suggestion:
        return 'suggestion';
      case MessageType.action:
        return 'action';
    }
  }
}

/// Enum para representar el remitente del mensaje
enum MessageSender {
  user,
  bot;

  /// Método para convertir de string a enum
  static MessageSender fromString(String value) {
    switch (value.toLowerCase()) {
      case 'user':
        return MessageSender.user;
      case 'bot':
        return MessageSender.bot;
      default:
        return MessageSender.bot;
    }
  }

  /// Método para convertir a String para almacenamiento en base de datos
  @override
  String toString() {
    switch (this) {
      case MessageSender.user:
        return 'user';
      case MessageSender.bot:
        return 'bot';
    }
  }
}

/// Modelo para representar un mensaje en el chatbot
class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // Para almacenar datos adicionales

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.type,
    required this.timestamp,
    this.metadata,
  });

  /// Factory para crear desde un mapa (JSON/Firestore)
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    // Manejar la conversión de timestamp
    DateTime timestamp;
    if (map['timestamp'] is Timestamp) {
      timestamp = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      timestamp = DateTime.parse(map['timestamp']);
    } else {
      timestamp = DateTime.now();
    }

    return ChatMessage(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      sender: MessageSender.fromString(map['sender'] ?? 'bot'),
      type: MessageType.fromString(map['type'] ?? 'text'),
      timestamp: timestamp,
      metadata: map['metadata'],
    );
  }

  /// Método para convertir a un mapa (para guardar en Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'sender': sender.toString(),
      'type': type.toString(),
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Método para crear una copia con algunos campos modificados
  ChatMessage copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    MessageType? type,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Método para crear un mensaje de usuario
  static ChatMessage createUserMessage(String text) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: MessageSender.user,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );
  }

  /// Método para crear un mensaje del bot
  static ChatMessage createBotMessage(String text, {MessageType type = MessageType.text, Map<String, dynamic>? metadata}) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: MessageSender.bot,
      type: type,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Método para crear un mensaje de sugerencia del bot
  static ChatMessage createSuggestion(String text, {Map<String, dynamic>? metadata}) {
    return createBotMessage(
      text,
      type: MessageType.suggestion,
      metadata: metadata,
    );
  }

  /// Método para crear un mensaje de acción del bot
  static ChatMessage createAction(String text, {required String actionType, Map<String, dynamic>? actionData}) {
    return createBotMessage(
      text,
      type: MessageType.action,
      metadata: {
        'actionType': actionType,
        if (actionData != null) 'actionData': actionData,
      },
    );
  }
}