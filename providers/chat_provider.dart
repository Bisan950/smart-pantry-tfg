// lib/providers/chat_provider.dart

import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';

class ChatProvider with ChangeNotifier {
  final EnhancedChatService _chatService = EnhancedChatService();
  
  // Estado interno
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
  
  // Constructor
  ChatProvider() {
    _initialize();
  }
  
  // Inicialización mejorada
  Future<void> _initialize() async {
    try {
      _setLoading(true);
      
      // Inicializar el servicio mejorado
      await _chatService.initialize();
      
      // Suscribirse al stream de mensajes para actualizaciones en tiempo real
      _chatService.getMessagesStream().listen((messages) {
        _messages = messages;
        _isInitialized = true;
        _updateThinkingState();
        notifyListeners();
      }, onError: (e) {
        _setError('Error en stream de mensajes: $e');
      });
      
      // Cargar mensajes iniciales
      await _loadMessages();
      
      // Si no hay mensajes previos, agregar un mensaje de bienvenida avanzado
      if (_messages.isEmpty) {
        await _sendAdvancedWelcomeMessage();
      }
      
      _setLoading(false);
    } catch (e) {
      _setError('Error al inicializar chat: $e');
    }
  }
  
  // Cargar mensajes previos
  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getAllMessages();
      _messages = messages;
      _isInitialized = true;
      _updateThinkingState();
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar mensajes: $e');
    }
  }
  
  // Mensaje de bienvenida avanzado
  Future<void> _sendAdvancedWelcomeMessage() async {
    try {
      // Crear mensaje de bienvenida inteligente
      final hour = DateTime.now().hour;
      String greeting;
      if (hour < 12) {
        greeting = "¡Buenos días! 🌅";
      } else if (hour < 18) {
        greeting = "¡Buenas tardes! ☀️";
      } else {
        greeting = "¡Buenas noches! 🌙";
      }
      
      final welcomeMessage = ChatMessage.createBotMessage(
        "$greeting Soy tu asistente inteligente de SmartPantry con IA avanzada.\n\n" "🤖 **Qué puedo hacer por ti:**\n" "• 📦 Gestionar tu inventario inteligentemente\n" "• 🍳 Generar recetas personalizadas con IA\n" +
        "• 📅 Crear planes de comidas optimizados\n" +
        "• 🛒 Administrar tu lista de compras\n" +
        "• ⚠️ Alertarte sobre productos que caducan\n" +
        "• 📊 Darte estadísticas y análisis detallados\n\n" +
        "💬 **Habla conmigo de forma natural** - Entiendo contexto y puedo mantener conversaciones complejas.\n\n" +
        "¿En qué te gustaría que te ayude hoy?",
      );
      
      await _chatService.saveMessage(welcomeMessage);
      
      // Añadir sugerencias inteligentes basadas en la hora y contexto
      final suggestions = await _generateContextualSuggestions();
      
      for (final suggestion in suggestions) {
        await _chatService.saveMessage(suggestion);
      }
    } catch (e) {
      print('Error al enviar mensaje de bienvenida: $e');
    }
  }
  
  // Generar sugerencias contextuales
  Future<List<ChatMessage>> _generateContextualSuggestions() async {
    final suggestions = <ChatMessage>[];
    final hour = DateTime.now().hour;
    
    try {
      // Sugerencias basadas en la hora del día
      if (hour >= 6 && hour <= 10) {
        suggestions.add(ChatMessage.createSuggestion('Ideas para el desayuno'));
        suggestions.add(ChatMessage.createSuggestion('Mostrar productos que caducan hoy'));
      } else if (hour >= 11 && hour <= 15) {
        suggestions.add(ChatMessage.createSuggestion('Recomiéndame algo para el almuerzo'));
        suggestions.add(ChatMessage.createSuggestion('Ver mi inventario actual'));
      } else if (hour >= 16 && hour <= 21) {
        suggestions.add(ChatMessage.createSuggestion('Qué puedo cocinar para la cena'));
        suggestions.add(ChatMessage.createSuggestion('Generar plan para la semana'));
      } else {
        suggestions.add(ChatMessage.createSuggestion('Mostrar mi inventario'));
        suggestions.add(ChatMessage.createSuggestion('Ver lista de compras'));
      }
      
      // Sugerencias adicionales comunes
      suggestions.add(ChatMessage.createSuggestion('Productos que caducan pronto'));
      
      // Limitar a 4 sugerencias
      return suggestions.take(4).toList();
    } catch (e) {
      // Sugerencias de fallback
      return [
        ChatMessage.createSuggestion('Mostrar inventario'),
        ChatMessage.createSuggestion('Recomiéndame una receta'),
        ChatMessage.createSuggestion('Ver lista de compras'),
        ChatMessage.createSuggestion('Productos que caducan pronto'),
      ];
    }
  }
  
  // Enviar un mensaje de usuario con procesamiento avanzado
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    try {
      _setLoading(true);
      _setThinking(true);
      
      // Procesar el mensaje con el servicio mejorado
      // Esto automáticamente guarda el mensaje del usuario y genera la respuesta
      await _chatService.processUserMessage(text);
      
      _setLoading(false);
      _setThinking(false);
    } catch (e) {
      _setError('Error al enviar mensaje: $e');
      _setThinking(false);
    }
  }
  
  // Usar una sugerencia
  Future<void> useSuggestion(String suggestionText) async {
    await sendMessage(suggestionText);
  }
  
  // Ejecutar una acción específica desde un mensaje
  Future<void> executeActionFromMessage(ChatMessage message) async {
    if (message.type != MessageType.action || message.metadata == null) {
      return;
    }
    
    try {
      _setLoading(true);
      
      final actionType = message.metadata!['actionType'] as String?;
      final actionData = message.metadata!['actionData'] as Map<String, dynamic>?;
      
      if (actionType == null) {
        _setLoading(false);
        return;
      }
      
      await _handleSpecificAction(actionType, actionData ?? {}, message);
      
      _setLoading(false);
    } catch (e) {
      _setError('Error al ejecutar acción: $e');
    }
  }
  
  // Manejar acciones específicas
  Future<void> _handleSpecificAction(String actionType, Map<String, dynamic> actionData, ChatMessage originalMessage) async {
    switch (actionType) {
      case 'multiple_recipe_recommendations':
        await _handleRecipeSelection(actionData);
        break;
        
      case 'meal_plan_preview_advanced':
        await _handleMealPlanPreview(actionData);
        break;
        
      case 'shopping_suggestions':
        await _handleShoppingSuggestions(actionData);
        break;
        
      case 'expiring_products_analysis':
        await _handleExpiringProductsAction(actionData);
        break;
        
      case 'duplicate_item_detected':
        await _handleDuplicateItemAction(actionData);
        break;
        
      case 'barcode_guidance':
        await _handleBarcodeGuidance();
        break;
        
      case 'ocr_guidance':
        await _handleOCRGuidance();
        break;
        
      case 'settings_overview':
        await _handleSettingsAction(actionData);
        break;
        
      case 'multiple_actions_detected':
        await _handleMultipleActionsChoice(actionData);
        break;
        
      case 'unknown_query_help':
        await _handleUnknownQueryHelp(actionData);
        break;
        
      default:
        // Para acciones no reconocidas, enviar un mensaje genérico
        await _chatService.processUserMessage("Ejecutar acción: $actionType");
        break;
    }
  }
  
  // Manejadores específicos de acciones
  
  Future<void> _handleRecipeSelection(Map<String, dynamic> actionData) async {
    final recipes = actionData['recipes'] as List<dynamic>?;
    if (recipes != null && recipes.isNotEmpty) {
      final response = ChatMessage.createBotMessage(
        "¿Cuál de las recetas te interesa más? Puedes decirme:\n" "• 'Ver detalles de la receta 1'\n" "• 'Guardar la segunda receta'\n" "• 'Mostrar ingredientes de la tercera'\n" +
        "• 'Añadir ingredientes faltantes a mi lista'",
      );
      await _chatService.saveMessage(response);
    }
  }
  
  Future<void> _handleMealPlanPreview(Map<String, dynamic> actionData) async {
    final daysGenerated = actionData['daysGenerated'] as int?;
    final recipesCount = (actionData['recipes'] as List?)?.length ?? 0;
    
    final response = ChatMessage.createBotMessage(
      "Tu plan de $daysGenerated días con $recipesCount recetas está listo para guardar.\n\n" "Dime:\n" "• '**Guardar el plan**' - Para guardarlo en tu calendario\n" "• '**Ver detalles de las recetas**' - Para revisar cada receta\n" +
      "• '**Generar plan diferente**' - Para crear alternativas\n" +
      "• '**Añadir ingredientes a la lista**' - Para comprar lo que falta",
    );
    await _chatService.saveMessage(response);
  }
  
  Future<void> _handleShoppingSuggestions(Map<String, dynamic> actionData) async {
    final suggestions = actionData['suggestions'] as List<dynamic>?;
    if (suggestions != null && suggestions.isNotEmpty) {
      final response = ChatMessage.createBotMessage(
        "¿Te gustaría añadir estas sugerencias a tu lista de compras?\n\n" "Puedes decir:\n" "• '**Añadir todas las sugerencias**'\n" "• '**Añadir solo los primeros 3**'\n" +
        "• '**Añadir [nombre del producto]**' para productos específicos",
      );
      await _chatService.saveMessage(response);
    }
  }
  
  Future<void> _handleExpiringProductsAction(Map<String, dynamic> actionData) async {
    final criticalCount = actionData['criticalCount'] as int? ?? 0;
    
    String message = "¿Qué te gustaría hacer con los productos que caducan?\n\n";
    
    if (criticalCount > 0) {
      message += "⚠️ **URGENTE**: Tienes $criticalCount productos críticos\n\n";
    }
    
    message += "Opciones disponibles:\n" "• '**Generar recetas**' - Usar productos que caducan\n" "• '**Crear plan prioritario**' - Planificar comidas urgentes\n" "• '**Marcar como consumidos**' - Actualizar los que ya usaste\n" +
        "• '**Configurar alertas**' - Ajustar notificaciones";
    
    final response = ChatMessage.createBotMessage(message);
    await _chatService.saveMessage(response);
  }
  
  Future<void> _handleDuplicateItemAction(Map<String, dynamic> actionData) async {
    final existingItem = actionData['existingItem'] as Map<String, dynamic>?;
    final newItem = actionData['newItem'] as Map<String, dynamic>?;
    
    if (existingItem != null && newItem != null) {
      final existingName = existingItem['name'] as String? ?? 'producto';
      final response = ChatMessage.createBotMessage(
        "Ya tienes '$existingName' en tu lista. ¿Qué prefieres?\n\n" "• '**Aumentar cantidad**' - Sumar a la cantidad existente\n" "• '**Añadir separado**' - Crear entrada independiente\n" "• '**Reemplazar**' - Actualizar con la nueva información\n" +
        "• '**Cancelar**' - No hacer cambios",
      );
      await _chatService.saveMessage(response);
    }
  }
  
  Future<void> _handleBarcodeGuidance() async {
    final response = ChatMessage.createBotMessage(
      "Te voy a guiar al escáner de códigos de barras.\n\n" "💡 **Consejo**: Asegúrate de tener buena iluminación y mantén el código plano.",
    );
    await _chatService.saveMessage(response);
    
    // Aquí podrías añadir navegación a la pantalla de escáner
    // Por ejemplo, usando un NavigationService o similar
  }
  
  Future<void> _handleOCRGuidance() async {
    final response = ChatMessage.createBotMessage(
      "Te ayudo con el reconocimiento de fechas de caducidad.\n\n" "📸 **Tip**: Enfoca bien la fecha y usa buena iluminación para mejores resultados.",
    );
    await _chatService.saveMessage(response);
  }
  
  Future<void> _handleSettingsAction(Map<String, dynamic> actionData) async {
    final response = ChatMessage.createBotMessage(
      "¿Qué configuración te gustaría cambiar?\n\n" "• '**Alertas de caducidad**' - Modificar días de aviso\n" "• '**Preferencias de cocina**' - Actualizar gustos culinarios\n" "• '**Notificaciones**' - Activar/desactivar alertas\n" +
      "• '**Estadísticas**' - Ver reportes detallados\n" +
      "• '**Restablecer**' - Volver a configuración inicial",
    );
    await _chatService.saveMessage(response);
  }
  
  Future<void> _handleMultipleActionsChoice(Map<String, dynamic> actionData) async {
    final actions = actionData['actions'] as List<dynamic>? ?? [];
    
    final response = ChatMessage.createBotMessage(
      "Perfecto, vamos paso a paso. ¿Con cuál empezamos?\n\n" "Simplemente dime el **número** de la acción o **descríbela** de nuevo:",
    );
    await _chatService.saveMessage(response);
  }
  
  Future<void> _handleUnknownQueryHelp(Map<String, dynamic> actionData) async {
    final originalQuery = actionData['originalQuery'] as String? ?? '';
    
    final response = ChatMessage.createBotMessage(
      "Intenta reformular tu pregunta o elige una de las opciones sugeridas.\n\n" "También puedes escribir '**ayuda**' para ver todos los comandos disponibles.",
    );
    await _chatService.saveMessage(response);
  }
  
  // Gestión de estado de pensamiento
  void _updateThinkingState() {
    final wasThinking = _isThinking;
    _isThinking = _messages.any((message) => 
      message.sender == MessageSender.bot && 
      message.text.contains("...") && 
      DateTime.now().difference(message.timestamp).inSeconds < 30
    );
    
    if (wasThinking != _isThinking) {
      notifyListeners();
    }
  }
  
  void _setThinking(bool thinking) {
    if (_isThinking != thinking) {
      _isThinking = thinking;
      notifyListeners();
    }
  }
  
  // Manejar errores
  void _setError(String errorMsg) {
    _error = errorMsg;
    _isLoading = false;
    _isThinking = false;
    print('Error en ChatProvider: $errorMsg');
    notifyListeners();
  }
  
  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Actualizar estado de carga
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (!loading) _isThinking = false;
    notifyListeners();
  }
  
  
  
  // Obtener sugerencias rápidas basadas en contexto
  List<String> getQuickSuggestions() {
    if (_messages.isEmpty) {
      return [
        'Mostrar mi inventario',
        'Recomiéndame una receta',
        'Ver lista de compras',
        'Productos que caducan pronto'
      ];
    }
    
    final lastMessage = _messages.last;
    if (lastMessage.sender == MessageSender.bot) {
      // Generar sugerencias basadas en el último mensaje del bot
      if (lastMessage.text.toLowerCase().contains('receta')) {
        return [
          'Ver ingredientes',
          'Guardar receta',
          'Otra receta similar',
          'Añadir a plan de comidas'
        ];
      } else if (lastMessage.text.toLowerCase().contains('inventario')) {
        return [
          'Productos que caducan',
          'Añadir producto',
          'Ver estadísticas',
          'Generar recetas'
        ];
      } else if (lastMessage.text.toLowerCase().contains('lista')) {
        return [
          'Añadir producto',
          'Marcar como comprado',
          'Ver sugerencias',
          'Crear lista automática'
        ];
      }
    }
    
    // Sugerencias por defecto
    return [
      'Ayuda',
      'Ver inventario',
      'Generar receta',
      'Planificar comidas'
    ];
  }
  
  // Borrar todos los mensajes (para depuración o reinicio)
  Future<void> clearAllMessages() async {
    try {
      _setLoading(true);
      
      // Usar el método del servicio mejorado para limpiar
      await _chatService.processUserMessage("Limpiar conversación");
      
      _setLoading(false);
    } catch (e) {
      _setError('Error al borrar mensajes: $e');
    }
  }
  
  // Reiniciar chat completamente
  Future<void> resetChat() async {
    try {
      _setLoading(true);
      
      // Limpiar estado local
      _messages.clear();
      _error = null;
      _isThinking = false;
      _isInitialized = false;
      
      // Reinicializar
      await _initialize();
      
    } catch (e) {
      _setError('Error al reiniciar chat: $e');
    }
  }
  
  // Obtener información de debug
  Map<String, dynamic> getDebugInfo() {
    return {
      'messagesCount': _messages.length,
      'isLoading': _isLoading,
      'isInitialized': _isInitialized,
      'isThinking': _isThinking,
      'hasError': _error != null,
      'error': _error,
      'lastMessage': _messages.isNotEmpty ? _messages.last.toMap() : null,
      'chatServiceDebug': _chatService.getDebugInfo(),
    };
  }
  
  // Ejecutar diagnósticos
  Future<Map<String, dynamic>> runDiagnostics() async {
    try {
      final chatServiceDiagnostics = await _chatService.runDiagnostics();
      
      return {
        'provider': {
          'status': 'OK',
          'messagesLoaded': _messages.length,
          'initialized': _isInitialized,
          'loading': _isLoading,
          'thinking': _isThinking,
          'hasError': _error != null,
        },
        'chatService': chatServiceDiagnostics,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'provider': {
          'status': 'ERROR',
          'error': e.toString(),
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
  
  // Obtener resumen de conversación
  String getConversationSummary() {
    if (_messages.isEmpty) return 'No hay mensajes';
    
    final userMessages = _messages.where((m) => m.sender == MessageSender.user).length;
    final botMessages = _messages.where((m) => m.sender == MessageSender.bot).length;
    final suggestions = _messages.where((m) => m.type == MessageType.suggestion).length;
    final actions = _messages.where((m) => m.type == MessageType.action).length;
    
    return 'Total: ${_messages.length} mensajes\n'
           'Usuario: $userMessages\n'
           'Asistente: $botMessages\n'
           'Sugerencias: $suggestions\n'
           'Acciones: $actions';
  }
  
  @override
  void dispose() {
    // Limpiar recursos del servicio
    _chatService.dispose();
    super.dispose();
  }
}