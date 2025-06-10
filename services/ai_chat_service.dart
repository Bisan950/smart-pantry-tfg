import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../models/chat_message_model.dart';
import 'chat_intent_detector.dart';
import 'chat_response_generator.dart';
import 'chat_context_manager.dart';
import 'gemini_ai_service.dart';

class AIChatService {
  static final AIChatService _instance = AIChatService._internal();
  factory AIChatService() => _instance;
  AIChatService._internal();

  // Servicios modulares
  final ChatIntentDetector _intentDetector = ChatIntentDetector();
  final ChatResponseGenerator _responseGenerator = ChatResponseGenerator();
  final ChatContextManager _contextManager = ChatContextManager();
  final GeminiAIService _geminiService = GeminiAIService();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  
  bool _isInitialized = false;
  final StreamController<List<ChatMessage>> _messagesController = 
      StreamController<List<ChatMessage>>.broadcast();

  // Inicialización
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _intentDetector.initialize();
      await _responseGenerator.initialize();
      await _contextManager.initialize();
      await _geminiService.initialize();
      
      _isInitialized = true;
      debugPrint('✅ AIChatService inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error inicializando AIChatService: $e');
      rethrow;
    }
  }

  // Procesar mensaje del usuario
  Future<ChatMessage> processMessage(String userText) async {
    if (!_isInitialized) {
      throw StateError('AIChatService no está inicializado');
    }

    try {
      // 1. Guardar mensaje del usuario
      final userMessage = ChatMessage.createUserMessage(userText);
      await _saveMessage(userMessage);

      // 2. Detectar intención
      final intent = await _intentDetector.detectIntent(
        userText, 
        _contextManager.getContext()
      );

      // 3. Actualizar contexto
      _contextManager.updateContext(userText, intent);

      // 4. Generar respuesta
      final botResponse = await _responseGenerator.generateResponse(
        intent: intent,
        userText: userText,
        context: _contextManager.getContext(),
      );

      // 5. Guardar respuesta
      await _saveMessage(botResponse);

      // 6. Notificar cambios
      _notifyMessagesChanged();

      return botResponse;
    } catch (e) {
      debugPrint('❌ Error procesando mensaje: $e');
      final errorMessage = ChatMessage.createBotMessage(
        'Lo siento, ha ocurrido un error. ¿Podrías reformular tu pregunta?'
      );
      await _saveMessage(errorMessage);
      return errorMessage;
    }
  }

  // Stream de mensajes
  Stream<List<ChatMessage>> getMessagesStream() {
    final userId = _userId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }

  // Guardar mensaje
  Future<void> _saveMessage(ChatMessage message) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuario no autenticado');

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_messages')
        .add(message.toMap());
  }

  // Notificar cambios
  void _notifyMessagesChanged() {
    // Implementar si es necesario
  }

  // Limpiar conversación
  Future<void> clearConversation() async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuario no autenticado');

    final batch = _firestore.batch();
    final messages = await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_messages')
        .get();

    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    _contextManager.clearContext();
  }

  void dispose() {
    _messagesController.close();
  }
}