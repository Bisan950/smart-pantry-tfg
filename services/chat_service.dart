// lib/services/enhanced_chat_service.dart
// Servicio de chat inteligente mejorado con todas las funcionalidades

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:math';

import '../models/chat_message_model.dart';
import '../models/product_model.dart';
import '../models/recipe_model.dart';
import '../models/meal_plan_model.dart';
import '../models/product_location_model.dart';
import '../models/expiry_settings_model.dart';
import 'inventory_service.dart';
import 'recipe_service.dart';
import 'meal_plan_service.dart';
import 'shopping_list_service.dart';
import 'gemini_recipe_service.dart';
import 'barcode_service.dart';
import 'ocr_service.dart';
import 'notification_service.dart';
import 'expiry_settings_service.dart';
import '../providers/shopping_list_provider.dart';

class EnhancedChatService {
  static final EnhancedChatService _instance = EnhancedChatService._internal();
  factory EnhancedChatService() => _instance;
  EnhancedChatService._internal();

  // === SERVICIOS INTEGRADOS ===
  final InventoryService _inventoryService = InventoryService();
  final RecipeService _recipeService = RecipeService();
  final MealPlanService _mealPlanService = MealPlanService();
  final ShoppingListService _shoppingListService = ShoppingListService();
  final GeminiRecipeService _geminiService = GeminiRecipeService();
  final BarcodeService _barcodeService = BarcodeService();
  final OCRService _ocrService = OCRService();
  final NotificationService _notificationService = NotificationService();
  final ExpirySettingsService _expirySettingsService = ExpirySettingsService();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // === CONTEXTO Y CACHE INTELIGENTE ===
  final Map<String, dynamic> _conversationContext = {};
  final List<String> _recentConversation = [];
  Map<String, dynamic> _userPreferences = {};
  DateTime _lastInteraction = DateTime.now();
  
  // Cache para mejorar rendimiento
  final Map<String, List<Product>> _cachedInventory = {};
  final Map<String, List<Recipe>> _cachedRecipes = {};
  final Map<String, List<ShoppingItem>> _cachedShoppingList = {};
  DateTime _lastCacheUpdate = DateTime.now().subtract(Duration(minutes: 10));
  
  CollectionReference? get _userMessages {
    final userId = _userId;
    if (userId == null) return null;
    return _firestore.collection('users').doc(userId).collection('chat_messages');
  }

  // === GESTIÓN DE CONTEXTO INTELIGENTE ===
  
  void _updateConversationContext(String userMessage, String intent) {
    _conversationContext['lastIntent'] = intent;
    _conversationContext['lastMessage'] = userMessage;
    _conversationContext['timestamp'] = DateTime.now();
    
    // Mantener historial de los últimos 10 mensajes
    _recentConversation.add(userMessage);
    if (_recentConversation.length > 10) {
      _recentConversation.removeAt(0);
    }
    
    // Actualizar preferencias del usuario basadas en el uso
    _updateUserPreferences(intent, userMessage);
  }
  
  void _updateUserPreferences(String intent, String message) {
    final preferences = _userPreferences['preferences'] ??= <String, dynamic>{};
    
    // Contar uso de diferentes funcionalidades
    preferences[intent] = (preferences[intent] ?? 0) + 1;
    
    // Detectar preferencias de cocina
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('vegetariana')) {
      _userPreferences['dietaryPreference'] = 'vegetariana';
    } else if (lowerMessage.contains('vegana')) {
      _userPreferences['dietaryPreference'] = 'vegana';
    }
    
    // Detectar cocinas favoritas
    final cuisines = ['italiana', 'mexicana', 'asiática', 'mediterránea', 'española'];
    for (final cuisine in cuisines) {
      if (lowerMessage.contains(cuisine)) {
        _userPreferences['favoriteCuisine'] = cuisine;
        break;
      }
    }
  }

  // === CACHE INTELIGENTE ===
  
  Future<void> _updateCache() async {
    final now = DateTime.now();
    if (now.difference(_lastCacheUpdate).inMinutes < 5) return;
    
    try {
      // Cache inventario
      final inventory = await _inventoryService.getAllProducts();
      _cachedInventory['all'] = inventory;
      _cachedInventory['expiring'] = await _inventoryService.getExpiringProducts(7);
      
      // Cache recetas
      final recipes = await _recipeService.getAllRecipes();
      _cachedRecipes['all'] = recipes;
      _cachedRecipes['favorites'] = await _recipeService.getFavoriteRecipes();
      
      // Cache lista de compras
      final shoppingList = await _shoppingListService.getShoppingList();
      _cachedShoppingList['all'] = shoppingList;
      
      _lastCacheUpdate = now;
    } catch (e) {
      print('Error actualizando cache: $e');
    }
  }

  // === MÉTODOS DE GESTIÓN DE MENSAJES ===

  Future<void> saveMessage(ChatMessage message) async {
    try {
      final userId = _userId;
      if (userId == null || _userMessages == null) {
        throw Exception('Usuario no autenticado');
      }
      
      final messageMap = message.toMap();
      
      if (message.id.isNotEmpty) {
        await _userMessages!.doc(message.id).set(messageMap);
      } else {
        await _userMessages!.add(messageMap);
      }
    } catch (e) {
      print('Error al guardar mensaje: $e');
      rethrow;
    }
  }

  Future<List<ChatMessage>> getAllMessages() async {
    try {
      final userId = _userId;
      if (userId == null || _userMessages == null) return [];
      
      final snapshot = await _userMessages!
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ChatMessage.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      print('Error al obtener mensajes: $e');
      return [];
    }
  }

  Stream<List<ChatMessage>> getMessagesStream() {
    try {
      final userId = _userId;
      if (userId == null || _userMessages == null) {
        return Stream.value([]);
      }
      
      return _userMessages!
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) {
            final messages = snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ChatMessage.fromMap({
                'id': doc.id,
                ...data,
              });
            }).toList();
            
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            return messages;
          });
    } catch (e) {
      print('Error al obtener stream de mensajes: $e');
      return Stream.value([]);
    }
  }

  // === PROCESAMIENTO PRINCIPAL DE MENSAJES ===

  Future<ChatMessage> processUserMessage(String userText) async {
    try {
      // Actualizar cache
      await _updateCache();
      
      // Guardar mensaje del usuario
      final userMessage = ChatMessage.createUserMessage(userText);
      await saveMessage(userMessage);
      
      // Detectar intención con IA mejorada
      final intent = await _detectIntentWithAdvancedAI(userText);
      
      // Actualizar contexto de conversación
      _updateConversationContext(userText, intent);
      
      // Procesar según la intención
      ChatMessage botResponse = await _routeToHandler(intent, userText);
      
      // Guardar respuesta del bot
      await saveMessage(botResponse);
      
      // Generar sugerencias inteligentes
      final suggestions = await _generateIntelligentSuggestions(intent, userText);
      for (final suggestion in suggestions) {
        await saveMessage(suggestion);
      }
      
      // Actualizar última interacción
      _lastInteraction = DateTime.now();
      
      return botResponse;
    } catch (e) {
      print('Error al procesar mensaje: $e');
      
      final errorMessage = ChatMessage.createBotMessage(
        "Lo siento, ha ocurrido un error. ¿Podrías intentarlo de nuevo de otra manera?",
      );
      
      await saveMessage(errorMessage);
      return errorMessage;
    }
  }

  // === DETECCIÓN DE INTENCIÓN MEJORADA ===

  Future<String> _detectIntentWithAdvancedAI(String text) async {
    final lowerText = text.toLowerCase().trim();
    
    // Patrones de contexto - considerar conversación previa
    final lastIntent = _conversationContext['lastIntent'];
    
    // Respuestas de confirmación en contexto
    if (_isConfirmationResponse(lowerText) && lastIntent != null) {
      switch (lastIntent) {
        case 'meal_plan_preview':
          return 'save_meal_plan';
        case 'recipe_recommendation':
          return 'save_recipe';
        case 'add_ingredients_to_list':
          return 'confirm_add_ingredients';
        default:
          return 'confirm_action';
      }
    }
    
    // Respuestas de negación en contexto
    if (_isNegationResponse(lowerText) && lastIntent != null) {
      switch (lastIntent) {
        case 'meal_plan_preview':
          return 'generate_new_meal_plan';
        case 'recipe_recommendation':
          return 'recipe_recommendation';
        default:
          return 'unknown';
      }
    }

    // Patrones básicos mejorados
    final patterns = {
      'greet': [
        RegExp(r'\b(hola|hey|saludos|buenos días|buenas tardes|buenas noches|qué tal)\b'),
        RegExp(r'^(hi|hello|good morning|good afternoon|good evening)\b', caseSensitive: false),
      ],
      'help': [
        RegExp(r'\b(ayuda|help|ayúdame|qué puedes hacer|comandos|manual)\b'),
        RegExp(r'\b(cómo funciona|instrucciones|guía)\b'),
      ],
      'inventory_query': [
        RegExp(r'\b(inventario|stock|productos|qué tengo|cuánto tengo|disponible)\b'),
        RegExp(r'\b(despensa|nevera|congelador|almacén)\b'),
        RegExp(r'\b(mostrar|ver|listar)\b.+\b(productos|inventario)\b'),
      ],
      'recipe_recommendation': [
        RegExp(r'\b(recomienda|sugerir|sugiéreme|qué puedo cocinar|ideas de cocina)\b'),
        RegExp(r'\b(receta|recetas)\b.*\b(con|usando|para)\b'),
        RegExp(r'\b(qué cocino|qué hago de comer|qué preparo)\b'),
      ],
      'recipe_query': [
        RegExp(r'\b(receta|recetas|buscar receta)\b'),
        RegExp(r'\b(cocinar|preparar|plato|comida)\b'),
      ],
      'shopping_list_query': [
        RegExp(r'\b(lista de compras|lista|compra|compras|carrito)\b'),
        RegExp(r'\b(qué necesito comprar|qué falta)\b'),
      ],
      'add_to_shopping_list': [
        RegExp(r'\b(añadir|agregar|poner|incluir)\b.*\b(lista|compras|carrito)\b'),
        RegExp(r'\b(necesito|comprar|añade)\b.+\b(a la lista|al carrito)\b'),
      ],
      'meal_plan_query': [
        RegExp(r'\b(plan de comidas|planificador|menú|menu)\b'),
        RegExp(r'\b(qué voy a comer|planificación|programar comidas)\b'),
      ],
      'generate_meal_plan': [
        RegExp(r'\b(genera|generar|crear|hacer|prepara|preparar)\b.*\b(plan|menú|menu)\b'),
        RegExp(r'\b(planifica|planificar|organizar)\b.*\b(comidas|semana)\b'),
      ],
      'show_expiring': [
        RegExp(r'\b(caducar|caducan|vencer|vencen|expira|expiran|caducidad)\b'),
        RegExp(r'\b(próximo a vencer|cerca de caducar|por vencer)\b'),
      ],
      'show_favorites': [
        RegExp(r'\b(favoritos|favoritas|preferidos|destacados)\b'),
      ],
      'add_to_inventory': [
        RegExp(r'\b(añadir|agregar|meter|poner)\b.*\b(inventario|despensa|nevera|congelador)\b'),
      ],
      'remove_from_inventory': [
        RegExp(r'\b(quitar|eliminar|remover|sacar)\b.*\b(inventario|despensa)\b'),
        RegExp(r'\b(consumí|usé|gasté|terminé)\b'),
      ],
      'mark_as_purchased': [
        RegExp(r'\b(marcar|completar|comprado|compré|ya tengo)\b'),
        RegExp(r'\b(terminé de comprar|ya lo compré)\b'),
      ],
      'barcode_scan': [
        RegExp(r'\b(escanear|código|barras|código de barras)\b'),
        RegExp(r'\b(scan|scanner|leer código)\b'),
      ],
      'ocr_scan': [
        RegExp(r'\b(fecha de caducidad|leer fecha|detectar fecha)\b'),
        RegExp(r'\b(escanear texto|OCR|reconocer texto)\b'),
      ],
      'settings': [
        RegExp(r'\b(configuración|ajustes|preferencias|configurar)\b'),
        RegExp(r'\b(cambiar|modificar|personalizar)\b.*\b(alertas|notificaciones)\b'),
      ],
      'statistics': [
        RegExp(r'\b(estadísticas|stats|reportes|resumen|análisis)\b'),
        RegExp(r'\b(cuánto gasto|consumo|tendencias)\b'),
      ],
      'clear_conversation': [
        RegExp(r'\b(limpiar|borrar|eliminar)\b.*\b(chat|conversación|historial)\b'),
      ],
    };

    // Buscar coincidencias
    for (final entry in patterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.hasMatch(lowerText)) {
          return entry.key;
        }
      }
    }

    // Usar IA de Gemini si está disponible para casos complejos
    try {
      final isGeminiAvailable = await _geminiService.testGeminiConnection();
      if (isGeminiAvailable) {
        return await _classifyWithGemini(text);
      }
    } catch (e) {
      print('Error usando Gemini para clasificación: $e');
    }

    return 'unknown';
  }

  Future<String> _classifyWithGemini(String text) async {
    // Implementar clasificación con Gemini aquí
    // Por ahora, usar heurísticas avanzadas
    final lowerText = text.toLowerCase();
    
    // Análisis semántico básico
    if (_containsWords(lowerText, ['tengo', 'ingredientes', 'qué', 'cocinar', 'hacer'])) {
      return 'recipe_recommendation';
    }
    
    if (_containsWords(lowerText, ['plan', 'semana', 'días', 'organizar', 'menú'])) {
      return 'generate_meal_plan';
    }
    
    if (_containsWords(lowerText, ['comprar', 'necesito', 'falta', 'lista'])) {
      return 'shopping_list_query';
    }
    
    return 'unknown';
  }

  bool _containsWords(String text, List<String> words) {
    return words.any((word) => text.contains(word));
  }

  bool _isConfirmationResponse(String text) {
    final confirmations = ['sí', 'si', 'vale', 'okay', 'ok', 'perfecto', 'genial', 
                          'me gusta', 'guardar', 'guarda', 'guardalo', 'confirmar',
                          'adelante', 'hazlo', 'procede', 'acepto'];
    return confirmations.any((conf) => text.contains(conf));
  }

  bool _isNegationResponse(String text) {
    final negations = ['no', 'nah', 'no gracias', 'mejor no', 'cancelar',
                      'otro', 'otra', 'diferente', 'cambiar'];
    return negations.any((neg) => text.contains(neg));
  }

  // === ENRUTADOR DE MANEJADORES ===

  Future<ChatMessage> _routeToHandler(String intent, String userText) async {
    switch (intent) {
      case 'greet':
        return await _handleGreetingAdvanced(userText);
      case 'help':
        return _handleHelpAdvanced();
      case 'inventory_query':
        return await _handleInventoryQueryAdvanced(userText);
      case 'recipe_recommendation':
        return await _handleRecipeRecommendationAdvanced(userText);
      case 'recipe_query':
        return await _handleRecipeQueryAdvanced(userText);
      case 'shopping_list_query':
        return await _handleShoppingListQueryAdvanced(userText);
      case 'add_to_shopping_list':
        return await _handleAddToShoppingListAdvanced(userText);
      case 'meal_plan_query':
        return await _handleMealPlanQueryAdvanced(userText);
      case 'generate_meal_plan':
        return await _handleGenerateMealPlanAdvanced(userText);
      case 'save_meal_plan':
        return await _handleSaveMealPlan(userText);
      case 'show_expiring':
        return await _handleExpiringProductsAdvanced();
      case 'show_favorites':
        return await _handleFavoritesAdvanced();
      case 'add_to_inventory':
        return await _handleAddToInventoryAdvanced(userText);
      case 'remove_from_inventory':
        return await _handleRemoveFromInventoryAdvanced(userText);
      case 'mark_as_purchased':
        return await _handleMarkAsPurchasedAdvanced(userText);
      case 'barcode_scan':
        return await _handleBarcodeScanGuidance();
      case 'ocr_scan':
        return await _handleOCRScanGuidance();
      case 'settings':
        return await _handleSettingsQuery(userText);
      case 'statistics':
        return await _handleStatisticsQuery();
      case 'clear_conversation':
        return await _handleClearConversation();
      case 'unknown':
      default:
        return await _handleUnknownQuery(userText);
    }
  }

  // === MANEJADORES AVANZADOS ===

  Future<ChatMessage> _handleGreetingAdvanced(String text) async {
    final hour = DateTime.now().hour;
    final userName = await _getUserName();
    
    String greeting;
    if (hour < 12) {
      greeting = "¡Buenos días";
    } else if (hour < 18) {
      greeting = "¡Buenas tardes";
    } else {
      greeting = "¡Buenas noches";
    }
    
    if (userName.isNotEmpty) {
      greeting += ", $userName";
    }
    greeting += "! ";
    
    // Personalizar saludo basado en el contexto
    final timeSinceLastInteraction = DateTime.now().difference(_lastInteraction);
    String contextMessage;
    
    if (timeSinceLastInteraction.inHours > 24) {
      contextMessage = "Me alegra verte de nuevo. ";
    } else if (timeSinceLastInteraction.inHours > 6) {
      contextMessage = "¡Bienvenido de vuelta! ";
    } else {
      contextMessage = "";
    }
    
    // Sugerir acciones basadas en el estado actual
    final suggestions = await _getPersonalizedGreetingSuggestions();
    
    return ChatMessage.createBotMessage(
      "$greeting${contextMessage}Soy tu asistente inteligente de SmartPantry. $suggestions",
    );
  }

  Future<String> _getPersonalizedGreetingSuggestions() async {
    final suggestions = <String>[];
    
    // Verificar productos que caducan pronto
    final expiringProducts = _cachedInventory['expiring'] ?? 
                            await _inventoryService.getExpiringProducts(3);
    if (expiringProducts.isNotEmpty) {
      suggestions.add("Tienes ${expiringProducts.length} productos que caducan pronto");
    }
    
    // Verificar lista de compras pendiente
    final shoppingList = _cachedShoppingList['all'] ?? 
                        await _shoppingListService.getShoppingList();
    final pendingItems = shoppingList.where((item) => !item.isPurchased).length;
    if (pendingItems > 0) {
      suggestions.add("tienes $pendingItems productos pendientes en tu lista de compras");
    }
    
    // Verificar si es hora de planificar comidas
    final today = DateTime.now();
    final mealPlans = await _mealPlanService.getMealPlansForDate(today);
    if (mealPlans.isEmpty && today.hour >= 8 && today.hour <= 20) {
      suggestions.add("podrías planificar las comidas de hoy");
    }
    
    if (suggestions.isEmpty) {
      return "¿En qué puedo ayudarte hoy?";
    } else if (suggestions.length == 1) {
      return "${suggestions.first}. ¿Te ayudo con eso?";
    } else {
      return "${suggestions.join(', ')}. ¿Con qué empezamos?";
    }
  }

  Future<String> _getUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user?.displayName ?? '';
    } catch (e) {
      return '';
    }
  }

  ChatMessage _handleHelpAdvanced() {
    final mostUsedFeatures = _getMostUsedFeatures();
    
    String helpText = "Soy tu asistente inteligente de SmartPantry. Puedo ayudarte con:\n\n";
    
    // Funciones básicas
    helpText += "🏠 **INVENTARIO**\n";
    helpText += "• Ver productos disponibles\n";
    helpText += "• Añadir/quitar productos\n";
    helpText += "• Productos que caducan pronto\n";
    helpText += "• Escanear códigos de barras\n\n";
    
    helpText += "🛒 **LISTA DE COMPRAS**\n";
    helpText += "• Gestionar tu lista de compras\n";
    helpText += "• Marcar productos como comprados\n";
    helpText += "• Sugerencias automáticas\n\n";
    
    helpText += "👨‍🍳 **RECETAS Y COCINA**\n";
    helpText += "• Recomendaciones personalizadas con IA\n";
    helpText += "• Buscar recetas por ingredientes\n";
    helpText += "• Guardar recetas favoritas\n\n";
    
    helpText += "📅 **PLANIFICACIÓN DE COMIDAS**\n";
    helpText += "• Generar menús semanales con IA\n";
    helpText += "• Organizar comidas por días\n";
    helpText += "• Optimizar uso de ingredientes\n\n";
    
    helpText += "🔧 **FUNCIONES AVANZADAS**\n";
    helpText += "• Escaneo de fechas de caducidad (OCR)\n";
    helpText += "• Notificaciones inteligentes\n";
    helpText += "• Estadísticas y reportes\n";
    helpText += "• Ajustes personalizables\n\n";
    
    // Personalizar ayuda basada en uso
    if (mostUsedFeatures.isNotEmpty) {
      helpText += "📊 **Tus funciones más usadas**: ${mostUsedFeatures.join(', ')}\n\n";
    }
    
    helpText += "💬 **Ejemplos de comandos**:\n";
    helpText += "• \"¿Qué productos van a caducar?\"\n";
    helpText += "• \"Recomiéndame una receta con pollo\"\n";
    helpText += "• \"Genera un menú para la semana\"\n";
    helpText += "• \"Añadir leche a la lista de compras\"\n";
    helpText += "• \"Mostrar estadísticas de consumo\"\n\n";
    
    helpText += "¡Habla conmigo de forma natural y te ayudaré! 😊";
    
    return ChatMessage.createBotMessage(helpText);
  }

  List<String> _getMostUsedFeatures() {
    final preferences = _userPreferences['preferences'] as Map<String, dynamic>? ?? {};
    final sorted = preferences.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    
    return sorted.take(3).map((e) => _getFeatureFriendlyName(e.key)).toList();
  }

  String _getFeatureFriendlyName(String feature) {
    switch (feature) {
      case 'inventory_query': return 'Consultar inventario';
      case 'recipe_recommendation': return 'Recomendaciones de recetas';
      case 'shopping_list_query': return 'Lista de compras';
      case 'meal_plan_query': return 'Planificación de comidas';
      default: return feature;
    }
  }

  Future<ChatMessage> _handleInventoryQueryAdvanced(String userText) async {
    try {
      final products = _cachedInventory['all'] ?? await _inventoryService.getAllProducts();
      
      if (products.isEmpty) {
        return ChatMessage.createBotMessage(
          "Tu inventario está vacío. ¿Te gustaría que te ayude a añadir productos? Puedo guiarte para escanear códigos de barras o añadirlos manualmente.",
        );
      }

      // Análisis inteligente del inventario
      final analysis = _analyzeInventory(products);
      
      String response = "📦 **Resumen de tu inventario**\n\n";
      response += "**Total**: ${products.length} productos\n";
      response += "**Por ubicación**:\n";
      
      analysis['byLocation'].forEach((location, count) {
        response += "  • $location: $count productos\n";
      });
      
      response += "\n**Por categoría**:\n";
      analysis['byCategory'].entries.take(5).forEach((entry) {
        response += "  • ${entry.key}: ${entry.value} productos\n";
      });
      
      // Alertas importantes
      final alerts = <String>[];
      if (analysis['expiringSoon'] > 0) {
        alerts.add("⚠️ ${analysis['expiringSoon']} productos caducan pronto");
      }
      if (analysis['lowStock'] > 0) {
        alerts.add("📉 ${analysis['lowStock']} productos con poco stock");
      }
      if (analysis['expired'] > 0) {
        alerts.add("🚨 ${analysis['expired']} productos caducados");
      }
      
      if (alerts.isNotEmpty) {
        response += "\n**⚠️ Alertas**:\n";
        for (var alert in alerts) {
          response += "• $alert\n";
        }
      }
      
      // Sugerencias inteligentes
      final suggestions = _getInventorySuggestions(analysis);
      if (suggestions.isNotEmpty) {
        response += "\n💡 **Sugerencias**:\n";
        for (var suggestion in suggestions) {
          response += "• $suggestion\n";
        }
      }
      
      return ChatMessage.createBotMessage(response);
    } catch (e) {
      return ChatMessage.createBotMessage(
        "No pude acceder a tu inventario en este momento. ¿Quieres que lo intente de nuevo?",
      );
    }
  }

  Map<String, dynamic> _analyzeInventory(List<Product> products) {
    final analysis = <String, dynamic>{};
    final byLocation = <String, int>{};
    final byCategory = <String, int>{};
    int expiringSoon = 0;
    int lowStock = 0;
    int expired = 0;
    
    final now = DateTime.now();
    
    for (final product in products) {
      // Por ubicación
      byLocation[product.location] = (byLocation[product.location] ?? 0) + 1;
      
      // Por categoría
      byCategory[product.category] = (byCategory[product.category] ?? 0) + 1;
      
      // Análisis de caducidad
      if (product.expiryDate != null) {
        final daysUntilExpiry = product.expiryDate!.difference(now).inDays;
        if (daysUntilExpiry < 0) {
          expired++;
        } else if (daysUntilExpiry <= 3) {
          expiringSoon++;
        }
      }
      
      // Stock bajo
      if (product.quantity <= (product.maxQuantity * 0.2)) {
        lowStock++;
      }
    }
    
    // Ordenar categorías por cantidad
    final sortedCategories = byCategory.entries.toList()
      // Continuación del código...

     ..sort((a, b) => b.value.compareTo(a.value));
   
   analysis['byLocation'] = byLocation;
   analysis['byCategory'] = Map.fromEntries(sortedCategories);
   analysis['expiringSoon'] = expiringSoon;
   analysis['lowStock'] = lowStock;
   analysis['expired'] = expired;
   analysis['totalValue'] = products.length;
   
   return analysis;
 }

 List<String> _getInventorySuggestions(Map<String, dynamic> analysis) {
   final suggestions = <String>[];
   
   if (analysis['expiringSoon'] > 0) {
     suggestions.add("Usa productos que caducan pronto en tus próximas recetas");
   }
   
   if (analysis['lowStock'] > 0) {
     suggestions.add("Añade productos con poco stock a tu lista de compras");
   }
   
   if (analysis['expired'] > 0) {
     suggestions.add("Revisa y elimina productos caducados");
   }
   
   // Sugerencia de organización
   final locations = analysis['byLocation'] as Map<String, int>;
   if (locations.length > 4) {
     suggestions.add("Considera organizar mejor tus productos por ubicación");
   }
   
   return suggestions;
 }

 Future<ChatMessage> _handleRecipeRecommendationAdvanced(String userText) async {
   try {
     final products = _cachedInventory['all'] ?? await _inventoryService.getAllProducts();
     final expiringProducts = _cachedInventory['expiring'] ?? 
                             await _inventoryService.getExpiringProducts(7);
     
     if (products.isEmpty) {
       return ChatMessage.createBotMessage(
         "No tienes productos en tu inventario para generar recomendaciones. ¿Te gustaría añadir algunos productos primero? Puedo ayudarte a escanear códigos de barras.",
       );
     }

     // Extraer preferencias del mensaje y del historial del usuario
     final preferences = _extractAdvancedPreferences(userText);
     
     // Priorizar productos que caducan pronto
     final priorityProducts = expiringProducts.isNotEmpty ? expiringProducts : products;
     
     // Generar múltiples opciones con IA
     final recipes = await _geminiService.generateRecipesFromIngredients(
       availableIngredients: priorityProducts,
       expiringIngredients: expiringProducts.isNotEmpty ? expiringProducts : null,
       cuisine: preferences['cuisine'],
       mealType: preferences['mealType'],
       numberOfRecipes: 3,
     );

     if (recipes.isEmpty) {
       return await _handleFallbackRecipeRecommendation(products, preferences);
     }

     // Crear respuesta detallada con múltiples opciones
     String response = "🍳 **Recomendaciones personalizadas de recetas**\n\n";
     
     if (expiringProducts.isNotEmpty) {
       response += "⚠️ *Priorizando productos que caducan pronto*\n\n";
     }
     
     for (int i = 0; i < recipes.length && i < 3; i++) {
       final recipe = recipes[i];
       final availableIngredients = recipe.ingredients.where((ing) => ing.isAvailable).length;
       final totalIngredients = recipe.ingredients.length;
       final availability = (availableIngredients / totalIngredients * 100).round();
       
       response += "**${i + 1}. ${recipe.name}**\n";
       response += "⏱️ ${recipe.totalTime} min | ";
       response += "👥 ${recipe.servings} porciones | ";
       response += "📊 ${_getDifficultyText(recipe.difficulty)}\n";
       response += "✅ $availableIngredients/$totalIngredients ingredientes disponibles ($availability%)\n";
       
       if (expiringProducts.any((prod) => 
           recipe.ingredients.any((ing) => 
               ing.name.toLowerCase().contains(prod.name.toLowerCase())))) {
         response += "⚠️ *Usa productos que caducan pronto*\n";
       }
       
       response += "\n**Ingredientes principales:**\n";
       recipe.ingredients.take(4).forEach((ingredient) {
         final icon = ingredient.isAvailable ? "✅" : "🛒";
         response += "$icon ${ingredient.name} (${ingredient.quantity} ${ingredient.unit})\n";
       });
       
       if (recipe.ingredients.length > 4) {
         response += "... y ${recipe.ingredients.length - 4} más\n";
       }
       
       response += "\n";
     }
     
     response += "¿Cuál te gusta más? Puedo mostrarte los pasos de preparación, ";
     response += "guardar la receta, o añadir ingredientes faltantes a tu lista de compras.";

     return ChatMessage.createBotMessage(
       response,
       type: MessageType.action,
       metadata: {
         'actionType': 'multiple_recipe_recommendations',
         'actionData': {
           'recipes': recipes.map((r) => r.toMap()).toList(),
           'hasExpiringIngredients': expiringProducts.isNotEmpty,
         },
       },
     );
   } catch (e) {
     return ChatMessage.createBotMessage(
       "No pude generar recomendaciones en este momento. ¿Te gustaría que revise recetas ya guardadas o intentemos de otra manera?",
     );
   }
 }

 Map<String, dynamic> _extractAdvancedPreferences(String text) {
   final lowerText = text.toLowerCase();
   final preferences = <String, dynamic>{};
   
   // Preferencias de cocina
   final cuisines = {
     'italiana': ['italiana', 'pasta', 'pizza', 'risotto'],
     'mexicana': ['mexicana', 'tacos', 'enchiladas', 'picante'],
     'asiática': ['asiática', 'china', 'japonesa', 'wok', 'arroz'],
     'mediterránea': ['mediterránea', 'griega', 'aceite de oliva'],
     'española': ['española', 'paella', 'tapas', 'tortilla'],
     'india': ['india', 'curry', 'especias'],
     'francesa': ['francesa', 'sofisticada', 'salsa'],
   };
   
   for (final entry in cuisines.entries) {
     if (entry.value.any((keyword) => lowerText.contains(keyword))) {
       preferences['cuisine'] = entry.key;
       break;
     }
   }
   
   // Tipo de comida
   if (lowerText.contains('desayuno') || lowerText.contains('mañana')) {
     preferences['mealType'] = 'breakfast';
   } else if (lowerText.contains('almuerzo') || lowerText.contains('comida')) {
     preferences['mealType'] = 'lunch';
   } else if (lowerText.contains('cena') || lowerText.contains('noche')) {
     preferences['mealType'] = 'dinner';
   }
   
   // Restricciones dietéticas
   if (lowerText.contains('vegetariana')) {
     preferences['diet'] = 'vegetariana';
   } else if (lowerText.contains('vegana')) {
     preferences['diet'] = 'vegana';
   } else if (lowerText.contains('sin gluten')) {
     preferences['diet'] = 'sin gluten';
   }
   
   // Tiempo disponible
   if (lowerText.contains('rápid') || lowerText.contains('poco tiempo')) {
     preferences['maxTime'] = 30;
   } else if (lowerText.contains('elaborad') || lowerText.contains('tiempo')) {
     preferences['maxTime'] = 120;
   }
   
   // Dificultad
   if (lowerText.contains('fácil') || lowerText.contains('simple')) {
     preferences['difficulty'] = 'easy';
   } else if (lowerText.contains('difícil') || lowerText.contains('complej')) {
     preferences['difficulty'] = 'hard';
   }
   
   // Combinar con preferencias del usuario guardadas
   preferences.addAll(_userPreferences);
   
   return preferences;
 }

 Future<ChatMessage> _handleFallbackRecipeRecommendation(
     List<Product> products, Map<String, dynamic> preferences) async {
   // Generar recomendación básica basada en productos disponibles
   final commonIngredients = ['pollo', 'arroz', 'pasta', 'huevos', 'tomate'];
   final availableCommon = products.where((p) => 
       commonIngredients.any((ing) => p.name.toLowerCase().contains(ing))).toList();
   
   if (availableCommon.isEmpty) {
     return ChatMessage.createBotMessage(
       "Tienes ingredientes únicos en tu inventario. ¿Podrías decirme específicamente qué te gustaría cocinar? Por ejemplo: 'una ensalada', 'algo con verduras', etc.",
     );
   }
   
   final suggestions = <String>[];
   for (final product in availableCommon.take(3)) {
     if (product.name.toLowerCase().contains('pollo')) {
       suggestions.add("Pollo a la plancha con verduras");
     } else if (product.name.toLowerCase().contains('arroz')) {
       suggestions.add("Arroz con verduras");
     } else if (product.name.toLowerCase().contains('pasta')) {
       suggestions.add("Pasta con salsa de tomate");
     } else if (product.name.toLowerCase().contains('huevos')) {
       suggestions.add("Tortilla francesa o revueltos");
     }
   }
   
   String response = "Basándome en tus ingredientes disponibles, te sugiero:\n\n";
   suggestions.asMap().forEach((index, suggestion) {
     response += "${index + 1}. $suggestion\n";
   });
   
   response += "\n¿Te interesa alguna de estas opciones? Puedo darte la receta completa.";
   
   return ChatMessage.createBotMessage(response);
 }

 Future<ChatMessage> _handleShoppingListQueryAdvanced(String userText) async {
   try {
     final items = _cachedShoppingList['all'] ?? await _shoppingListService.getShoppingList();
     
     if (items.isEmpty) {
       // Generar sugerencias automáticas
       final suggestions = await _shoppingListService.generateSuggestions();
       
       if (suggestions.isEmpty) {
         return ChatMessage.createBotMessage(
           "Tu lista de compras está vacía. ¿Te gustaría que genere sugerencias automáticas basadas en tu inventario?",
         );
       } else {
         String response = "Tu lista está vacía, pero he generado algunas sugerencias automáticas:\n\n";
         suggestions.take(5).forEach((item) {
           response += "🛒 ${item.name} (${item.quantity} ${item.unit})\n";
         });
         response += "\n¿Te gustaría añadir alguna de estas sugerencias a tu lista?";
         
         return ChatMessage.createBotMessage(
           response,
           type: MessageType.action,
           metadata: {
             'actionType': 'shopping_suggestions',
             'actionData': {
               'suggestions': suggestions.map((s) => s.toMap()).toList(),
             },
           },
         );
       }
     }

     // Análisis avanzado de la lista
     final analysis = _analyzeShoppingList(items);
     
     String response = "🛒 **Tu lista de compras**\n\n";
     response += "**Resumen**: ${items.length} productos\n";
     response += "✅ ${analysis['purchased']} comprados\n";
     response += "⏳ ${analysis['pending']} pendientes\n";
     
     if (analysis['total_cost'] > 0) {
       response += "💰 Costo estimado: \$${analysis['total_cost'].toStringAsFixed(2)}\n";
     }
     
     response += "\n**Por categoría**:\n";
     analysis['by_category'].forEach((category, count) {
       final emoji = _getCategoryEmoji(category);
       response += "$emoji $category: $count items\n";
     });
     
     // Mostrar items prioritarios
     final priorityItems = items.where((item) => !item.isPurchased && item.isSuggested).toList();
     if (priorityItems.isNotEmpty) {
       response += "\n⭐ **Sugerencias automáticas**:\n";
       priorityItems.take(3).forEach((item) {
         response += "• ${item.name} (${item.quantity} ${item.unit})\n";
       });
     }
     
     // Items próximos a caducar en inventario
     final expiringProducts = await _inventoryService.getExpiringProducts(3);
     if (expiringProducts.isNotEmpty) {
       response += "\n⚠️ **Reemplazar pronto** (productos que caducan):\n";
       expiringProducts.take(3).forEach((product) {
         final days = product.daysUntilExpiry;
         response += "• ${product.name} (caduca en $days días)\n";
       });
     }
     
     response += "\n¿Te ayudo a marcar productos como comprados o añadir algo más a la lista?";
     
     return ChatMessage.createBotMessage(response);
   } catch (e) {
     return ChatMessage.createBotMessage(
       "No pude acceder a tu lista de compras. ¿Quieres que lo intente de nuevo?",
     );
   }
 }

 Map<String, dynamic> _analyzeShoppingList(List<ShoppingItem> items) {
   final analysis = <String, dynamic>{};
   final byCategory = <String, int>{};
   int purchased = 0;
   int pending = 0;
   double totalCost = 0.0;
   
   for (final item in items) {
     byCategory[item.category] = (byCategory[item.category] ?? 0) + 1;
     
     if (item.isPurchased) {
       purchased++;
     } else {
       pending++;
     }
     
     // Estimación básica de costo (esto se podría mejorar con una base de datos de precios)
     totalCost += _estimateItemCost(item);
   }
   
   analysis['by_category'] = byCategory;
   analysis['purchased'] = purchased;
   analysis['pending'] = pending;
   analysis['total_cost'] = totalCost;
   
   return analysis;
 }

 double _estimateItemCost(ShoppingItem item) {
   // Estimaciones básicas de costos por categoría (se puede mejorar)
   final costEstimates = {
     'Lácteos': 3.5,
     'Carnes': 8.0,
     'Verduras': 2.0,
     'Frutas': 2.5,
     'Cereales': 4.0,
     'Bebidas': 2.0,
     'Snacks': 3.0,
     'Congelados': 5.0,
     'Panadería': 2.5,
   };
   
   final baseCost = costEstimates[item.category] ?? 3.0;
   return baseCost * item.quantity;
 }

 String _getCategoryEmoji(String category) {
   switch (category.toLowerCase()) {
     case 'lácteos': return '🥛';
     case 'carnes': return '🥩';
     case 'verduras': return '🥬';
     case 'frutas': return '🍎';
     case 'cereales': return '🌾';
     case 'bebidas': return '🥤';
     case 'snacks': return '🍿';
     case 'congelados': return '🧊';
     case 'panadería': return '🍞';
     default: return '📦';
   }
 }

 Future<ChatMessage> _handleAddToShoppingListAdvanced(String userText) async {
   try {
     final productInfo = _extractDetailedProductInfo(userText);
     
     if (productInfo['name'] == null || productInfo['name'].toString().isEmpty) {
       return ChatMessage.createBotMessage(
         "No pude identificar qué producto quieres añadir. Intenta ser más específico, por ejemplo:\n" "• 'Añadir 2 litros de leche'\n" "• 'Poner pan integral en la lista'\n" "• 'Necesito 500g de arroz'",
       );
     }

     // Crear item mejorado
     final item = ShoppingItem(
       id: const Uuid().v4(),
       name: productInfo['name'],
       quantity: (productInfo['quantity'] ?? 1).toDouble(),
       unit: productInfo['unit'] ?? _suggestUnit(productInfo['name']),
       category: productInfo['category'] ?? _categorizeProduct(productInfo['name']),
       isPurchased: false,
       isSuggested: false,
       location: productInfo['preferredLocation'],
     );
     
     // Verificar si ya existe un producto similar
     final existingItems = await _shoppingListService.getShoppingList();
     final similarItem = existingItems.firstWhere(
       (existing) => _areProductsSimilar(existing.name, item.name),
       orElse: () => ShoppingItem(id: '', name: '', quantity: 0, unit: '', category: '', isPurchased: false, isSuggested: false),
     );
     
     if (similarItem.id.isNotEmpty) {
       return ChatMessage.createBotMessage(
         "Ya tienes '${similarItem.name}' en tu lista de compras (${similarItem.quantity} ${similarItem.unit}). ¿Quieres aumentar la cantidad o añadir otro producto diferente?",
         type: MessageType.action,
         metadata: {
           'actionType': 'duplicate_item_detected',
           'actionData': {
             'existingItem': similarItem.toMap(),
             'newItem': item.toMap(),
           },
         },
       );
     }
     
     // Añadir a la lista
     final itemId = await _shoppingListService.addShoppingItem(item);
     
     // Sugerir productos relacionados
     final relatedSuggestions = _getRelatedProducts(item.name);
     
     String response = "✅ He añadido **${item.name}** (${item.quantity} ${item.unit}) a tu lista de compras.";
     
     if (relatedSuggestions.isNotEmpty) {
       response += "\n\n💡 **¿También necesitas?**\n";
       relatedSuggestions.take(3).forEach((suggestion) {
         response += "• $suggestion\n";
       });
     }
     
     // Verificar si hay ofertas o consejos
     final tips = _getShoppingTips(item);
     if (tips.isNotEmpty) {
       response += "\n\n💰 **Consejo**: $tips";
     }
     
     return ChatMessage.createBotMessage(
       response,
       type: MessageType.action,
       metadata: {
         'actionType': 'item_added_successfully',
         'actionData': {
           'itemId': itemId,
           'itemName': item.name,
           'relatedSuggestions': relatedSuggestions,
         },
       },
     );
      } catch (e) {
     return ChatMessage.createBotMessage(
       "Hubo un problema al añadir el producto. ¿Puedes intentar reformular tu petición?",
     );
   }
 }

 Map<String, dynamic> _extractDetailedProductInfo(String text) {
   final lowerText = text.toLowerCase();
   final productInfo = <String, dynamic>{};
   
   // Patrones más sofisticados para cantidad
   final quantityPatterns = [
     RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|kilo|kilos|kilogramos?|gr?|gramos?|litros?|ml|mililitros?|unidades?|piezas?|latas?|botellas?|paquetes?|cajas?)\b'),
     RegExp(r'(\d+(?:[.,]\d+)?)\s*([a-z]+)'),
     RegExp(r'(\d+(?:[.,]\d+)?)'),
   ];
   
   double? quantity;
   String? unit;
   
   for (final pattern in quantityPatterns) {
     final match = pattern.firstMatch(lowerText);
     if (match != null) {
       quantity = double.tryParse(match.group(1)?.replaceAll(',', '.') ?? '1');
       unit = match.group(2)?.toLowerCase();
       break;
     }
   }
   
   // Normalizar unidades
   if (unit != null) {
     unit = _normalizeUnit(unit);
   }
   
   // Extraer nombre del producto con patrones mejorados
   final productPatterns = [
     RegExp(r'(?:añadir|agregar|poner|incluir|necesito|comprar)\s+(?:\d+(?:[.,]\d+)?\s*\w+\s+(?:de\s+)?)?([a-záéíóúñü\s]+)(?:\s+a\s+la\s+lista)?'),
     RegExp(r'\b([a-záéíóúñü]{3,}(?:\s+[a-záéíóúñü]+)*)\b'),
   ];
   
   String? productName;
   for (final pattern in productPatterns) {
     final match = pattern.firstMatch(lowerText);
     if (match != null) {
       productName = match.group(1)?.trim();
       if (productName != null && productName.length > 2) {
         // Limpiar palabras comunes que no son parte del producto
         final cleanedName = _cleanProductName(productName);
         if (cleanedName.isNotEmpty) {
           productName = cleanedName;
           break;
         }
       }
     }
   }
   
   productInfo['name'] = productName;
   productInfo['quantity'] = quantity ?? 1.0;
   productInfo['unit'] = unit ?? 'unidades';
   productInfo['category'] = _categorizeProduct(productName ?? '');
   productInfo['preferredLocation'] = _suggestLocation(productName ?? '');
   
   return productInfo;
 }

 String _cleanProductName(String name) {
   final stopWords = ['a', 'la', 'lista', 'de', 'compras', 'el', 'los', 'las', 'un', 'una', 'del', 'al'];
   final words = name.split(' ').where((word) => 
       word.length > 1 && !stopWords.contains(word.toLowerCase())).toList();
   return words.join(' ');
 }

 String _normalizeUnit(String unit) {
   switch (unit.toLowerCase()) {
     case 'kg': case 'kilo': case 'kilos': case 'kilogramos': case 'kilogramo':
       return 'kg';
     case 'gr': case 'g': case 'gramos': case 'gramo':
       return 'g';
     case 'litros': case 'litro': case 'l':
       return 'L';
     case 'ml': case 'mililitros': case 'mililitro':
       return 'ml';
     case 'unidades': case 'unidad': case 'piezas': case 'pieza': case 'u':
       return 'unidades';
     case 'latas': case 'lata':
       return 'latas';
     case 'botellas': case 'botella':
       return 'botellas';
     case 'paquetes': case 'paquete': case 'pqt':
       return 'paquetes';
     case 'cajas': case 'caja':
       return 'cajas';
     default:
       return unit;
   }
 }

 String _suggestUnit(String productName) {
   final lowerName = productName.toLowerCase();
   
   if (lowerName.contains('leche') || lowerName.contains('aceite') || 
       lowerName.contains('agua') || lowerName.contains('zumo')) {
     return 'L';
   } else if (lowerName.contains('carne') || lowerName.contains('pescado') || 
              lowerName.contains('queso') || lowerName.contains('arroz')) {
     return 'kg';
   } else if (lowerName.contains('yogur') || lowerName.contains('mantequilla')) {
     return 'g';
   } else {
     return 'unidades';
   }
 }

 String _categorizeProduct(String productName) {
   final lowerName = productName.toLowerCase();
   
   final categories = {
     'Lácteos': ['leche', 'yogur', 'queso', 'mantequilla', 'nata', 'crema'],
     'Carnes': ['pollo', 'carne', 'ternera', 'cerdo', 'jamón', 'chorizo', 'salchichas'],
     'Pescados': ['pescado', 'salmón', 'atún', 'sardinas', 'merluza', 'gambas'],
     'Verduras': ['lechuga', 'tomate', 'cebolla', 'ajo', 'zanahoria', 'pimiento', 'calabacín'],
     'Frutas': ['manzana', 'plátano', 'naranja', 'pera', 'uvas', 'fresas'],
     'Cereales': ['arroz', 'pasta', 'pan', 'cereales', 'avena', 'quinoa'],
     'Bebidas': ['agua', 'zumo', 'refresco', 'cerveza', 'vino', 'café', 'té'],
     'Limpieza': ['detergente', 'jabón', 'lejía', 'suavizante', 'papel'],
     'Congelados': ['helado', 'pizza', 'patatas fritas'],
   };
   
   for (final entry in categories.entries) {
     if (entry.value.any((keyword) => lowerName.contains(keyword))) {
       return entry.key;
     }
   }
   
   return 'Otros';
 }

 String? _suggestLocation(String productName) {
   final lowerName = productName.toLowerCase();
   
   if (lowerName.contains('leche') || lowerName.contains('yogur') || 
       lowerName.contains('carne') || lowerName.contains('verdura')) {
     return 'Nevera';
   } else if (lowerName.contains('helado') || lowerName.contains('congelado')) {
     return 'Congelador';
   } else if (lowerName.contains('arroz') || lowerName.contains('pasta') || 
              lowerName.contains('cereales')) {
     return 'Despensa';
   }
   
   return null;
 }

 bool _areProductsSimilar(String name1, String name2) {
   final normalized1 = name1.toLowerCase().trim();
   final normalized2 = name2.toLowerCase().trim();
   
   // Comparación exacta
   if (normalized1 == normalized2) return true;
   
   // Comparación por palabras clave
   final words1 = normalized1.split(' ');
   final words2 = normalized2.split(' ');
   
   // Si comparten al menos una palabra significativa
   final significantWords1 = words1.where((w) => w.length > 3).toSet();
   final significantWords2 = words2.where((w) => w.length > 3).toSet();
   
   return significantWords1.intersection(significantWords2).isNotEmpty;
 }

 List<String> _getRelatedProducts(String productName) {
   final lowerName = productName.toLowerCase();
   final suggestions = <String>[];
   
   // Sugerencias basadas en combinaciones comunes
   if (lowerName.contains('leche')) {
     suggestions.addAll(['Cereales', 'Galletas', 'Café']);
   } else if (lowerName.contains('pan')) {
     suggestions.addAll(['Mantequilla', 'Jamón', 'Queso']);
   } else if (lowerName.contains('pasta')) {
     suggestions.addAll(['Tomate frito', 'Queso rallado', 'Aceite de oliva']);
   } else if (lowerName.contains('arroz')) {
     suggestions.addAll(['Verduras', 'Pollo', 'Aceite']);
   } else if (lowerName.contains('huevos')) {
     suggestions.addAll(['Pan', 'Aceite', 'Patatas']);
   }
   
   return suggestions;
 }

 String _getShoppingTips(ShoppingItem item) {
   final lowerName = item.name.toLowerCase();
   
   if (lowerName.contains('fruta') || lowerName.contains('verdura')) {
     return "Compra productos de temporada para mejor precio y calidad";
   } else if (lowerName.contains('carne') || lowerName.contains('pescado')) {
     return "Revisa la fecha de caducidad y congela si no vas a consumir pronto";
   } else if (lowerName.contains('leche') || lowerName.contains('yogur')) {
     return "Verifica las ofertas por volumen, a veces sale más económico";
   }
   
   return '';
 }

 Future<ChatMessage> _handleGenerateMealPlanAdvanced(String userText) async {
   try {
     final products = _cachedInventory['all'] ?? await _inventoryService.getAllProducts();
     final expiringProducts = _cachedInventory['expiring'] ?? 
                             await _inventoryService.getExpiringProducts(7);
     
     if (products.isEmpty) {
       return ChatMessage.createBotMessage(
         "No tienes productos en tu inventario para generar un plan de comidas. ¿Te gustaría añadir productos primero? Puedo ayudarte a escanear códigos de barras.",
       );
     }

     // Extraer detalles avanzados del plan
     final planDetails = _extractAdvancedMealPlanDetails(userText);
     final preferences = _extractAdvancedPreferences(userText);
     
     // Mostrar plan detallado antes de generar
     String planSummary = "📅 **Generando plan personalizado**\n\n";
     planSummary += "**Duración**: ${planDetails['days']} días\n";
     planSummary += "**Comidas**: ${planDetails['mealTypes'].map(_getMealTypeName).join(', ')}\n";
     
     if (preferences['cuisine'] != null) {
       planSummary += "**Cocina**: ${preferences['cuisine']}\n";
     }
     // Continuación del código...

     if (preferences['diet'] != null) {
       planSummary += "**Dieta**: ${preferences['diet']}\n";
     }
     
     planSummary += "**Productos disponibles**: ${products.length}\n";
     
     if (expiringProducts.isNotEmpty) {
       planSummary += "⚠️ **Productos prioritarios**: ${expiringProducts.length} que caducan pronto\n";
     }
     
     planSummary += "\n🤖 Generando recetas con IA...";
     
     // Enviar mensaje de progreso
     final progressMessage = ChatMessage.createBotMessage(planSummary);
     await saveMessage(progressMessage);

     // Calcular número de recetas necesarias
     final int daysCount = planDetails['days'] ?? 3;
     final List<String> mealTypes = planDetails['mealTypes'] ?? ['breakfast', 'lunch', 'dinner'];
     final int recipesNeeded = (daysCount * mealTypes.length).clamp(1, 12);

     // Generar recetas con IA
     final recipes = await _geminiService.generateRecipesFromIngredients(
       availableIngredients: products,
       expiringIngredients: expiringProducts.isNotEmpty ? expiringProducts : null,
       cuisine: preferences['cuisine'],
       numberOfRecipes: recipesNeeded,
     );

     if (recipes.isEmpty) {
       return ChatMessage.createBotMessage(
         "No pude generar recetas con los ingredientes disponibles. ¿Te gustaría que intente con diferentes parámetros o añadas más productos a tu inventario?",
       );
     }

     // Crear plan detallado
     final mealPlan = _createDetailedMealPlan(recipes, daysCount, mealTypes, expiringProducts);
     
     String response = "📅 **Plan de comidas generado con IA**\n\n";
     response += "**Duración**: $daysCount días\n";
     response += "**Recetas generadas**: ${recipes.length}\n";
     response += "**Aprovechamiento de inventario**: ${_calculateInventoryUsage(recipes, products)}%\n\n";
     
     if (expiringProducts.isNotEmpty) {
       final expiringUsed = recipes.where((recipe) => 
         recipe.ingredients.any((ing) => 
           expiringProducts.any((prod) => 
             prod.name.toLowerCase().contains(ing.name.toLowerCase())))).length;
       response += "⚠️ **Productos próximos a caducar utilizados**: $expiringUsed/${expiringProducts.length}\n\n";
     }
     
     // Mostrar distribución del plan
     response += "**Distribución del plan**:\n";
     for (int day = 0; day < daysCount && day < 5; day++) {
       final dayName = _getDayName(day);
       response += "\n**$dayName**:\n";
       
       for (final mealType in mealTypes) {
         final mealIndex = (day * mealTypes.length + mealTypes.indexOf(mealType)) % recipes.length;
         final recipe = recipes[mealIndex];
         final mealName = _getMealTypeName(mealType);
         response += "  • $mealName: ${recipe.name}\n";
       }
     }
     
     if (daysCount > 5) {
       response += "\n... y menús para ${daysCount - 5} días más\n";
     }
     
     // Análisis nutricional básico
     final nutritionSummary = _analyzeNutrition(recipes);
     response += "\n📊 **Análisis nutricional promedio por día**:\n";
     response += "• Calorías: ${nutritionSummary['calories']} kcal\n";
     response += "• Proteínas: ${nutritionSummary['protein']}g\n";
     response += "• Carbohidratos: ${nutritionSummary['carbs']}g\n";
     response += "• Grasas: ${nutritionSummary['fats']}g\n";
     
     // Lista de compras automática
     final missingIngredients = _calculateMissingIngredients(recipes, products);
     if (missingIngredients.isNotEmpty) {
       response += "\n🛒 **Ingredientes que necesitas comprar**: ${missingIngredients.length}\n";
       missingIngredients.take(5).forEach((ingredient) {
         response += "• ${ingredient['name']} (${ingredient['quantity']} ${ingredient['unit']})\n";
       });
       if (missingIngredients.length > 5) {
         response += "• ... y ${missingIngredients.length - 5} más\n";
       }
     }
     
     response += "\n**¿Qué te gustaría hacer?**\n";
     response += "• **Guardar el plan** en tu calendario\n";
     response += "• **Ver recetas detalladas**\n";
     response += "• **Añadir ingredientes faltantes** a la lista de compras\n";
     response += "• **Generar un plan diferente**\n";

     return ChatMessage.createBotMessage(
       response,
       type: MessageType.action,
       metadata: {
         'actionType': 'meal_plan_preview_advanced',
         'actionData': {
           'daysGenerated': daysCount,
           'mealTypes': mealTypes,
           'recipes': recipes.map((r) => r.toMap()).toList(),
           'mealPlan': mealPlan,
           'missingIngredients': missingIngredients,
           'nutritionSummary': nutritionSummary,
           'inventoryUsage': _calculateInventoryUsage(recipes, products),
         },
       },
     );
   } catch (e) {
     return ChatMessage.createBotMessage(
       "No pude generar el plan de comidas. ¿Te gustaría que lo intente con parámetros más simples o prefieres hacerlo manualmente?",
     );
   }
 }

 Map<String, dynamic> _extractAdvancedMealPlanDetails(String text) {
   final lowerText = text.toLowerCase();
   final details = <String, dynamic>{};
   
   // Duración
   int daysCount = 3; // Por defecto
   if (lowerText.contains('semana') || lowerText.contains('semanal') || lowerText.contains('7 días')) {
     daysCount = 7;
   } else if (lowerText.contains('fin de semana')) {
     daysCount = 2;
   } else if (lowerText.contains('3 días') || lowerText.contains('tres días')) {
     daysCount = 3;
   } else if (lowerText.contains('5 días') || lowerText.contains('cinco días')) {
     daysCount = 5;
   } else if (lowerText.contains('2 semanas') || lowerText.contains('quincena')) {
     daysCount = 14;
   }
   
   // Extracto directo de números
   final numberPattern = RegExp(r'(\d+)\s*días?');
   final numberMatch = numberPattern.firstMatch(lowerText);
   if (numberMatch != null) {
     daysCount = int.tryParse(numberMatch.group(1) ?? '3') ?? daysCount;
   }
   
   // Tipos de comida
   List<String> mealTypes = ['breakfast', 'lunch', 'dinner']; // Por defecto
   
   if (lowerText.contains('solo desayun')) {
     mealTypes = ['breakfast'];
   } else if (lowerText.contains('solo almuerzos') || lowerText.contains('solo comidas')) {
     mealTypes = ['lunch'];
   } else if (lowerText.contains('solo cenas')) {
     mealTypes = ['dinner'];
   } else if (lowerText.contains('desayuno y almuerzo')) {
     mealTypes = ['breakfast', 'lunch'];
   } else if (lowerText.contains('almuerzo y cena') || lowerText.contains('comida y cena')) {
     mealTypes = ['lunch', 'dinner'];
   } else if (lowerText.contains('incluir merienda') || lowerText.contains('con merienda')) {
     mealTypes = ['breakfast', 'lunch', 'snack', 'dinner'];
   }
   
   // Preferencias especiales
   details['days'] = daysCount;
   details['mealTypes'] = mealTypes;
   details['includeSnacks'] = lowerText.contains('merienda') || lowerText.contains('snack');
   details['familySize'] = _extractFamilySize(lowerText);
   details['budget'] = _extractBudget(lowerText);
   
   return details;
 }

 int _extractFamilySize(String text) {
   final familyPatterns = [
     RegExp(r'para (\d+) personas?'),
     RegExp(r'familia de (\d+)'),
     RegExp(r'(\d+) comensales'),
   ];
   
   for (final pattern in familyPatterns) {
     final match = pattern.firstMatch(text);
     if (match != null) {
       return int.tryParse(match.group(1) ?? '2') ?? 2;
     }
   }
   
   if (text.contains('familia grande')) return 6;
   if (text.contains('pareja')) return 2;
   if (text.contains('solo') || text.contains('individual')) return 1;
   
   return 2; // Por defecto
 }

 String? _extractBudget(String text) {
   if (text.contains('económico') || text.contains('barato') || text.contains('ahorro')) {
     return 'low';
   } else if (text.contains('premium') || text.contains('gourmet') || text.contains('especial')) {
     return 'high';
   }
   return null;
 }

 Map<String, dynamic> _createDetailedMealPlan(
     List<Recipe> recipes, int days, List<String> mealTypes, List<Product> expiringProducts) {
   final mealPlan = <String, dynamic>{};
   final dailyPlans = <Map<String, dynamic>>[];
   
   for (int day = 0; day < days; day++) {
     final dayPlan = <String, dynamic>{};
     dayPlan['day'] = day + 1;
     dayPlan['date'] = DateTime.now().add(Duration(days: day));
     dayPlan['meals'] = <Map<String, dynamic>>[];
     
     for (int mealIndex = 0; mealIndex < mealTypes.length; mealIndex++) {
       final recipeIndex = (day * mealTypes.length + mealIndex) % recipes.length;
       final recipe = recipes[recipeIndex];
       final mealType = mealTypes[mealIndex];
       
       final mealInfo = {
         'mealType': mealType,
         'mealTypeName': _getMealTypeName(mealType),
         'recipe': recipe.toMap(),
         'usesExpiringIngredients': _recipeUsesExpiringProducts(recipe, expiringProducts),
       };
       
       dayPlan['meals'].add(mealInfo);
     }
     
     dailyPlans.add(dayPlan);
   }
   
   mealPlan['days'] = dailyPlans;
   mealPlan['totalRecipes'] = recipes.length;
   mealPlan['duration'] = days;
   
   return mealPlan;
 }

 bool _recipeUsesExpiringProducts(Recipe recipe, List<Product> expiringProducts) {
   return recipe.ingredients.any((ingredient) =>
       expiringProducts.any((product) =>
           product.name.toLowerCase().contains(ingredient.name.toLowerCase()) ||
           ingredient.name.toLowerCase().contains(product.name.toLowerCase())));
 }

 int _calculateInventoryUsage(List<Recipe> recipes, List<Product> products) {
   if (products.isEmpty) return 0;
   
   final usedProducts = <String>{};
   
   for (final recipe in recipes) {
     for (final ingredient in recipe.ingredients) {
       for (final product in products) {
         if (_areIngredientsRelated(ingredient.name, product.name)) {
           usedProducts.add(product.name.toLowerCase());
         }
       }
     }
   }
   
   return ((usedProducts.length / products.length) * 100).round();
 }

 bool _areIngredientsRelated(String ingredientName, String productName) {
   final ingredient = ingredientName.toLowerCase();
   final product = productName.toLowerCase();
   
   return ingredient.contains(product) || 
          product.contains(ingredient) ||
          _haveSimilarWords(ingredient, product);
 }

 bool _haveSimilarWords(String text1, String text2) {
   final words1 = text1.split(' ').where((w) => w.length > 3).toSet();
   final words2 = text2.split(' ').where((w) => w.length > 3).toSet();
   
   return words1.intersection(words2).isNotEmpty;
 }

 Map<String, int> _analyzeNutrition(List<Recipe> recipes) {
   if (recipes.isEmpty) {
     return {'calories': 0, 'protein': 0, 'carbs': 0, 'fats': 0};
   }
   
   final totalCalories = recipes.fold<int>(0, (sum, recipe) => sum + recipe.calories);
   final totalProtein = recipes.fold<int>(0, (sum, recipe) => 
       sum + ((recipe.nutrition['protein'] as num?)?.toInt() ?? 0));
   final totalCarbs = recipes.fold<int>(0, (sum, recipe) => 
       sum + ((recipe.nutrition['carbs'] as num?)?.toInt() ?? 0));
   final totalFats = recipes.fold<int>(0, (sum, recipe) => 
       sum + ((recipe.nutrition['fats'] as num?)?.toInt() ?? 0));
   
   return {
     'calories': (totalCalories / recipes.length).round(),
     'protein': (totalProtein / recipes.length).round(),
     'carbs': (totalCarbs / recipes.length).round(),
     'fats': (totalFats / recipes.length).round(),
   };
 }

 List<Map<String, dynamic>> _calculateMissingIngredients(List<Recipe> recipes, List<Product> products) {
   final missingIngredients = <Map<String, dynamic>>[];
   final ingredientQuantities = <String, Map<String, dynamic>>{};
   
   // Consolidar ingredientes de todas las recetas
   for (final recipe in recipes) {
     for (final ingredient in recipe.ingredients) {
       final key = ingredient.name.toLowerCase();
       
       if (ingredientQuantities.containsKey(key)) {
         // Sumar cantidades si ya existe
         final existing = ingredientQuantities[key]!;
         if (existing['unit'] == ingredient.unit) {
           existing['quantity'] = (existing['quantity'] as num) + (ingredient.quantity as num);
         }
       } else {
         ingredientQuantities[key] = {
           'name': ingredient.name,
           'quantity': ingredient.quantity,
           'unit': ingredient.unit,
           'available': false,
         };
       }
     }
   }
   
   // Verificar disponibilidad en inventario
   for (final entry in ingredientQuantities.entries) {
     final ingredientName = entry.key;
     final ingredientData = entry.value;
     
     final isAvailable = products.any((product) => 
         _areIngredientsRelated(ingredientName, product.name.toLowerCase()));
     
     if (!isAvailable) {
       missingIngredients.add(ingredientData);
     }
   }
   
   // Ordenar por importancia (ingredientes principales primero)
   missingIngredients.sort((a, b) => (b['quantity'] as num).compareTo(a['quantity'] as num));
   
   return missingIngredients;
 }

 String _getDayName(int dayIndex) {
   final today = DateTime.now();
   final targetDate = today.add(Duration(days: dayIndex));
   
   if (dayIndex == 0) return "Hoy";
   if (dayIndex == 1) return "Mañana";
   
   final weekDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
   final weekDay = weekDays[targetDate.weekday - 1];
   
   return "$weekDay ${targetDate.day}/${targetDate.month}";
 }

 Future<ChatMessage> _handleSaveMealPlan(String userText) async {
   try {
     // Buscar el último plan generado
     final recentMessages = await getAllMessages();
     final planPreviewMessage = recentMessages.reversed.firstWhere(
       (msg) => msg.type == MessageType.action && 
                (msg.metadata?['actionType'] == 'meal_plan_preview_advanced' ||
                 msg.metadata?['actionType'] == 'meal_plan_preview'),
       orElse: () => ChatMessage.createBotMessage(''),
     );

     if (planPreviewMessage.text.isEmpty) {
       return ChatMessage.createBotMessage(
         "No encuentro un plan de comidas reciente para guardar. ¿Quieres que genere un nuevo plan?",
       );
     }

     final actionData = planPreviewMessage.metadata!['actionData'] as Map<String, dynamic>;
     final recipesData = actionData['recipes'] as List<dynamic>;
     final daysCount = actionData['daysGenerated'] as int;
     final mealTypes = actionData['mealTypes'] as List<dynamic>;

     // Progreso de guardado
     final progressMessage = ChatMessage.createBotMessage(
       "💾 Guardando tu plan de comidas...\n\n⏳ Esto puede tomar unos segundos mientras guardo las recetas y organizo tu calendario.",
     );
     await saveMessage(progressMessage);

     // Convertir recetas de Map a objetos Recipe
     final recipes = recipesData.map((r) => Recipe.fromMap(r as Map<String, dynamic>)).toList();

     // Guardar recetas primero
     final savedRecipeIds = <String>[];
     int savedRecipesCount = 0;
     
     for (final recipe in recipes) {
       try {
         final recipeId = await _recipeService.addRecipe(recipe);
         if (recipeId != null) {
           savedRecipeIds.add(recipeId);
           savedRecipesCount++;
         }
       } catch (e) {
         print('Error guardando receta ${recipe.name}: $e');
       }
     }

     if (savedRecipeIds.isEmpty) {
       return ChatMessage.createBotMessage(
         "No pude guardar las recetas del plan. ¿Quieres que lo intente de nuevo?",
       );
     }

     // Crear y guardar planes de comida
     final List<MealPlan> mealPlans = [];
     final today = DateTime.now();
     
     for (int day = 0; day < daysCount; day++) {
       final date = today.add(Duration(days: day));
       
       for (int mealIndex = 0; mealIndex < mealTypes.length; mealIndex++) {
         if (savedRecipeIds.isNotEmpty) {
           final int recipeIndex = (day * mealTypes.length + mealIndex) % savedRecipeIds.length;
           
           final mealPlan = MealPlan(
             id: '',
             date: date,
             mealTypeId: mealTypes[mealIndex],
             recipeId: savedRecipeIds[recipeIndex],
             isCompleted: false,
           );
           
           mealPlans.add(mealPlan);
         }
       }
     }

     // Guardar planes
     final savedPlanIds = await _mealPlanService.saveMealPlans(mealPlans);

     // Añadir ingredientes faltantes a la lista de compras si se especifica
     bool addedToShoppingList = false;
     if (actionData.containsKey('missingIngredients')) {
       final missingIngredients = actionData['missingIngredients'] as List<dynamic>;
       if (missingIngredients.isNotEmpty && userText.toLowerCase().contains('lista')) {
         addedToShoppingList = await _addMissingIngredientsToShoppingList(missingIngredients);
       }
     }

     // Mensaje de éxito detallado
     String response = "✅ **¡Plan guardado exitosamente!**\n\n";
     response += "📊 **Resumen del guardado**:\n";
     response += "• $savedRecipesCount recetas guardadas\n";
     response += "• ${savedPlanIds.length} comidas planificadas\n";
     response += "• Plan para $daysCount días\n";
     
     if (addedToShoppingList) {
       response += "• Ingredientes faltantes añadidos a tu lista de compras\n";
     }
     
     response += "\n📅 **Tu plan está listo**:\n";
     response += "• Ve a **'Planificador de Comidas'** para ver tu calendario\n";
     response += "• Las recetas están en **'Mis Recetas'**\n";
     
     if (!addedToShoppingList && actionData.containsKey('missingIngredients')) {
       response += "• ¿Quieres que añada los ingredientes faltantes a tu lista de compras?\n";
     }
     
     response += "\n🎉 ¡Disfruta de tus comidas planificadas!";

     // Programar recordatorios si el usuario lo desea
     await _scheduleOptionalReminders(daysCount);

     return ChatMessage.createBotMessage(
       response,
       type: MessageType.action,
       metadata: {
         'actionType': 'meal_plan_saved_successfully',
         'actionData': {
           'planIds': savedPlanIds,
           'recipeIds': savedRecipeIds,
           'daysCount': daysCount,
           'addedToShoppingList': addedToShoppingList,
         },
       },
     );
   } catch (e) {
     return ChatMessage.createBotMessage(
       "Hubo un problema al guardar el plan de comidas. Los datos se han preservado, ¿quieres que lo intente de nuevo?",
     );
   }
 }

 Future<bool> _addMissingIngredientsToShoppingList(List<dynamic> missingIngredients) async {
   try {
     final itemsToAdd = <ShoppingItem>[];
     
     for (final ingredient in missingIngredients) {
       final shoppingItem = ShoppingItem(
         id: const Uuid().v4(),
         name: ingredient['name'],
         quantity: (ingredient['quantity'] as num).toInt(),
         unit: ingredient['unit'] ?? 'unidades',
         category: _categorizeProduct(ingredient['name']),
         isPurchased: false,
         isSuggested: true, // Marcar como sugerencia automática
       );
       
       itemsToAdd.add(shoppingItem);
     }
     
     if (itemsToAdd.isNotEmpty) {
       await _shoppingListService.addMultipleItems(itemsToAdd);
       return true;
     }
   } catch (e) {
     print('Error añadiendo ingredientes a la lista: $e');
   }
   
   return false;
 }

 Future<void> _scheduleOptionalReminders(int daysCount) async {
   try {
     // Programar notificaciones para recordar revisar el plan
     final settings = await _expirySettingsService.getSettings();
     
     if (settings.notificationsEnabled) {
       // Notificación para mañana si el plan es de más de 1 día
       if (daysCount > 1) {
         // Aquí se programarían las notificaciones locales
         // Por ahora solo registramos la intención
         print('Programando recordatorio para mañana: revisar plan de comidas');
       }
     }
   } catch (e) {
     print('Error programando recordatorios: $e');
   }
 }

 Future<ChatMessage> _handleExpiringProductsAdvanced() async {
   try {
     // Obtener productos que caducan en diferentes rangos
     final expiringToday = await _inventoryService.getExpiringProducts(0);
     final expiringTomorrow = await _inventoryService.getExpiringProducts(1);
     final expiringThisWeek = await _inventoryService.getExpiringProducts(7);
     final expiredProducts = await _inventoryService.getExpiredProducts();
     
     if (expiringThisWeek.isEmpty && expiredProducts.isEmpty) {
       return ChatMessage.createBotMessage(
         "🎉 **¡Excelente!** No tienes productos que caduquen en los próximos 7 días.\n\n" "Tu inventario está bien gestionado. Sigue así para evitar desperdicios.",
       );
     }

     String response = "⏰ **Estado de caducidad de tu inventario**\n\n";
     
     // Productos críticos (caducados y de hoy)
     final criticalProducts = [...expiredProducts, ...expiringToday];
     if (criticalProducts.isNotEmpty) {
       response += "🚨 **CRÍTICO - Acción inmediata necesaria**:\n";
       criticalProducts.take(5).forEach((product) {
         final daysLeft = product.daysUntilExpiry;
         String urgency;
         if (daysLeft < 0) {
           urgency = "CADUCADO hace ${-daysLeft} días";
         } else if (daysLeft == 0) {
           urgency = "CADUCA HOY";
         } else {
           urgency = "caduca en $daysLeft días";
         }
         
         response += "• **${product.name}** - $urgency\n";
         response += "  📦 ${product.quantity} ${product.unit} en ${product.location}\n";
       });
       
       if (criticalProducts.length > 5) {
         response += "• ... y ${criticalProducts.length - 5} productos más\n";
       }
       response += "\n";
     }
     
     // Productos que caducan mañana
     if (expiringTomorrow.isNotEmpty && expiringToday.isEmpty) {
       response += "⚠️ **Caducan mañana**:\n";
       expiringTomorrow.take(3).forEach((product) {
         response += "• ${product.name} (${product.quantity} ${product.unit})\n";
       });
       response += "\n";
     }
     
     // Productos que caducan esta semana
     final remainingThisWeek = expiringThisWeek.where((p) => 
         p.daysUntilExpiry > 1).toList();
     if (remainingThisWeek.isNotEmpty) {
       response += "📅 **Caducan esta semana**:\n";
       remainingThisWeek.take(5).forEach((product) {
         final daysLeft = product.daysUntilExpiry;
         response += "• ${product.name} - $daysLeft días (${product.location})\n";
       });
       
       if (remainingThisWeek.length > 5) {
         response += "• ... y ${remainingThisWeek.length - 5} más\n";
       }
       response += "\n";
     }
     
     // Análisis por categorías
     final categoryAnalysis = _analyzeExpiringByCategory(expiringThisWeek);
     if (categoryAnalysis.isNotEmpty) {
       response += "📊 **Por categorías**:\n";
       categoryAnalysis.entries.take(3).forEach((entry) {
         response += "• ${entry.key}: ${entry.value} productos\n";
       });
       response += "\n";
     }
     
     // Sugerencias inteligentes
     response += "💡 **Recomendaciones**:\n";
     
     if (criticalProducts.isNotEmpty) {
       response += "• **Usa inmediatamente** los productos críticos\n";
       response += "• **Elimina productos caducados** para evitar contaminación\n";
     }
     
     if (expiringThisWeek.length >= 3) {
       response += "• **Genera recetas** que usen estos ingredientes\n";
       response += "• **Planifica comidas** priorizando productos que caducan\n";
     }
     
     response += "• **Ajusta las cantidades** de compra para estos productos\n";
     
     // Botones de acción
     response += "\n**¿Qué te gustaría hacer?**\n";
     response += "🍳 Generar recetas con productos que caducan\n";
     response += "📅 Crear plan de comidas prioritario\n";
     response += "🗑️ Marcar productos caducados para eliminar\n";
     response += "⚙️ Ajustar alertas de caducidad";

     return ChatMessage.createBotMessage(
       response,
       type: MessageType.action,
       metadata: {
         'actionType': 'expiring_products_analysis',
         'actionData': {
           'criticalCount': criticalProducts.length,
           'weekCount': expiringThisWeek.length,
           'categories': categoryAnalysis,
           'products': expiringThisWeek.map((p) => p.toMap()).toList(),
         },
       },
     );
   } catch (e) {
     return ChatMessage.createBotMessage(
       "No pude revisar los productos que caducan. ¿Quieres que lo intente de nuevo?",
     );
   }
 }

 Map<String, int> _analyzeExpiringByCategory(List<Product> products) {
   final categoryCount = <String, int>{};
   
   for (final product in products) {
     categoryCount[product.category] = (categoryCount[product.category] ?? 0) + 1;
   }
   
   // Ordenar por cantidad descendente
   final sortedEntries = categoryCount.entries.toList()
     ..sort((a, b) => b.value.compareTo(a.value));
   
   return Map.fromEntries(sortedEntries);
 }

 Future<ChatMessage> _handleBarcodeScanGuidance() async {
   return ChatMessage.createBotMessage(
     "📱 **Escaneo de códigos de barras**\n\n" "Te puedo ayudar con el escaneo de códigos de barras para añadir productos rápidamente.\n\n" "**¿Cómo funciona?**\n" "1. Ve a la sección de **Inventario**\n" +
     "2. Toca el botón de **Escanear código**\n" +
     "3. Apunta la cámara al código de barras\n" +
     "4. La información del producto se completará automáticamente\n\n" +
     // Continuación del código...

     "**Consejos para un mejor escaneo**:\n" +
     "• Asegúrate de tener buena iluminación\n" +
     "• Mantén el código de barras plano y sin arrugas\n" +
     "• Mantén la cámara estable a unos 15-20 cm\n" +
     "• Si no reconoce el producto, puedes añadirlo manualmente\n\n" +
     "**Base de datos**:\n" +
     "• Más de 2 millones de productos registrados\n" +
     "• Información nutricional automática\n" +
     "• Categorización inteligente\n" +
     "• Sugerencias de ubicación\n\n" +
     "¿Te gustaría que te guíe a la pantalla de escaneo o prefieres añadir productos manualmente?",
     type: MessageType.action,
     metadata: {
       'actionType': 'barcode_guidance',
       'actionData': {
         'showScannerButton': true,
         'alternativeActions': ['add_manual', 'inventory_help'],
       },
     },
   );
 }

 Future<ChatMessage> _handleOCRScanGuidance() async {
   return ChatMessage.createBotMessage(
     "📸 **Reconocimiento de fechas de caducidad (OCR)**\n\n" "Puedo ayudarte a detectar automáticamente las fechas de caducidad de tus productos.\n\n" "**¿Cómo funciona?**\n" "1. Ve a **Añadir Producto** en el inventario\n" +
     "2. Toca **Detectar fecha de caducidad**\n" +
     "3. Toma una foto clara de la fecha en el envase\n" +
     "4. La fecha se detectará y añadirá automáticamente\n\n" +
     "**Para mejores resultados**:\n" +
     "• Usa buena iluminación, preferiblemente luz natural\n" +
     "• Enfoca bien la fecha de caducidad\n" +
     "• Mantén el texto lo más recto posible\n" +
     "• Evita sombras sobre el texto\n\n" +
     "**Formatos detectados**:\n" +
     "• DD/MM/YYYY (15/03/2024)\n" +
     "• MM/YYYY (03/2024)\n" +
     "• Consumir antes de...\n" +
     "• Best before...\n" +
     "• CAD: DD/MM/YY\n\n" +
     "**Idiomas soportados**: Español, Inglés, Francés\n\n" +
     "¿Quieres que te ayude a detectar una fecha ahora o prefieres introducirla manualmente?",
     type: MessageType.action,
     metadata: {
       'actionType': 'ocr_guidance',
       'actionData': {
         'showOCRButton': true,
         'supportedFormats': ['DD/MM/YYYY', 'MM/YYYY', 'text_dates'],
       },
     },
   );
 }

 Future<ChatMessage> _handleSettingsQuery(String userText) async {
   try {
     final settings = await _expirySettingsService.getSettings();
     
     String response = "⚙️ **Configuración de SmartPantry**\n\n";
     
     // Configuraciones de caducidad
     response += "📅 **Alertas de caducidad**:\n";
     response += "• Días de aviso: ${settings.warningDays}\n";
     response += "• Días críticos: ${settings.criticalDays}\n";
     response += "• Notificaciones: ${settings.notificationsEnabled ? 'Activadas' : 'Desactivadas'}\n\n";
     
     // Configuraciones de la IA
     response += "🤖 **Asistente IA**:\n";
     final geminiStatus = await _geminiService.testGeminiConnection();
     response += "• Estado de IA: ${geminiStatus ? 'Conectado ✅' : 'Desconectado ❌'}\n";
     response += "• Preferencias de cocina: ${_userPreferences['favoriteCuisine'] ?? 'No configurada'}\n";
     response += "• Restricciones dietéticas: ${_userPreferences['dietaryPreference'] ?? 'Ninguna'}\n\n";
     
     // Estadísticas de uso
     final stats = _getUsageStats();
     response += "📊 **Estadísticas de uso**:\n";
     response += "• Productos en inventario: ${stats['inventoryCount']}\n";
     response += "• Recetas guardadas: ${stats['recipesCount']}\n";
     response += "• Función más usada: ${stats['mostUsedFeature']}\n\n";
     
     // Opciones de configuración
     response += "**¿Qué te gustaría configurar?**\n";
     response += "• 🔔 Cambiar alertas de caducidad\n";
     response += "• 🍽️ Actualizar preferencias de cocina\n";
     response += "• 📱 Configurar notificaciones\n";
     response += "• 🤖 Personalizar asistente IA\n";
     response += "• 📊 Ver estadísticas detalladas\n";
     response += "• 🔄 Restablecer configuración";

     return ChatMessage.createBotMessage(
       response,
       type: MessageType.action,
       metadata: {
         'actionType': 'settings_overview',
         'actionData': {
           'currentSettings': settings.toMap(),
           'geminiConnected': geminiStatus,
           'userPreferences': _userPreferences,
           'usageStats': stats,
         },
       },
     );
   } catch (e) {
     return ChatMessage.createBotMessage(
       "No pude acceder a la configuración en este momento. ¿Quieres que lo intente de nuevo?",
     );
   }
 }

 Map<String, dynamic> _getUsageStats() {
   // Calcular estadísticas básicas (esto se podría expandir con datos reales)
   return {
     'inventoryCount': _cachedInventory['all']?.length ?? 0,
     'recipesCount': _cachedRecipes['all']?.length ?? 0,
     'mostUsedFeature': _getMostUsedFeatures().isNotEmpty ? 
                        _getMostUsedFeatures().first : 'Ninguna',
     'totalInteractions': _recentConversation.length,
   };
 }

 Future<ChatMessage> _handleStatisticsQuery() async {
   try {
     await _updateCache();
     
     final inventory = _cachedInventory['all'] ?? [];
     final recipes = _cachedRecipes['all'] ?? [];
     final shoppingList = _cachedShoppingList['all'] ?? [];
     
     // Análisis de inventario
     final inventoryAnalysis = _analyzeInventory(inventory);
     final expiringProducts = _cachedInventory['expiring'] ?? [];
     
     // Estadísticas de recetas
     final favoriteRecipes = _cachedRecipes['favorites'] ?? [];
     
     // Análisis de la lista de compras
     final shoppingAnalysis = _analyzeShoppingList(shoppingList);
     
     String response = "📊 **Estadísticas de SmartPantry**\n\n";
     
     // Resumen general
     response += "📈 **Resumen general**:\n";
     response += "• Total productos: ${inventory.length}\n";
     response += "• Recetas guardadas: ${recipes.length}\n";
     response += "• Items en lista de compras: ${shoppingList.length}\n";
     response += "• Recetas favoritas: ${favoriteRecipes.length}\n\n";
     
     // Análisis de inventario
     response += "📦 **Análisis de inventario**:\n";
     response += "• Productos por caducar: ${expiringProducts.length}\n";
     response += "• Productos con poco stock: ${inventoryAnalysis['lowStock']}\n";
     response += "• Ubicación principal: ${_getTopLocation(inventoryAnalysis['byLocation'])}\n";
     response += "• Categoría principal: ${_getTopCategory(inventoryAnalysis['byCategory'])}\n\n";
     
     // Tendencias de cocina
     if (recipes.isNotEmpty) {
       final cookingTrends = _analyzeCookingTrends(recipes);
       response += "👨‍🍳 **Tendencias de cocina**:\n";
       response += "• Dificultad preferida: ${cookingTrends['preferredDifficulty']}\n";
       response += "• Tiempo promedio de cocción: ${cookingTrends['avgCookingTime']} min\n";
       response += "• Categoría de recetas favorita: ${cookingTrends['topCategory']}\n\n";
     }
     
     // Eficiencia de compras
     final purchasedItems = shoppingList.where((item) => item.isPurchased).length;
     final completionRate = shoppingList.isNotEmpty ? 
         (purchasedItems / shoppingList.length * 100).round() : 0;
     
     response += "🛒 **Eficiencia de compras**:\n";
     response += "• Tasa de compra: $completionRate%\n";
     response += "• Productos pendientes: ${shoppingList.length - purchasedItems}\n";
     response += "• Gasto estimado mensual: \$${_estimateMonthlyExpenses()}\n\n";
     
     // Sostenibilidad
     final sustainabilityScore = _calculateSustainabilityScore(inventory, expiringProducts);
     response += "🌱 **Puntuación de sostenibilidad**: $sustainabilityScore/100\n";
     response += _getSustainabilityTips(sustainabilityScore);
     
     // Uso del asistente IA
     response += "\n🤖 **Uso del asistente**:\n";
     response += "• Función más usada: ${_getMostUsedFeatures().isNotEmpty ? _getMostUsedFeatures().first : 'N/A'}\n";
     response += "• Total de interacciones: ${_recentConversation.length}\n";
     response += "• Última interacción: ${_formatLastInteraction()}\n\n";
     
     response += "**¿Te gustaría ver estadísticas más detalladas de algún área específica?**";

     return ChatMessage.createBotMessage(
       response,
       type: MessageType.action,
       metadata: {
         'actionType': 'detailed_statistics',
         'actionData': {
           'inventoryStats': inventoryAnalysis,
           'recipesCount': recipes.length,
           'shoppingStats': shoppingAnalysis,
           'sustainabilityScore': sustainabilityScore,
           'completionRate': completionRate,
         },
       },
     );
   } catch (e) {
     return ChatMessage.createBotMessage(
       "No pude generar las estadísticas completas. ¿Te gustaría ver un resumen básico?",
     );
   }
 }

 String _getTopLocation(Map<String, int> locations) {
   if (locations.isEmpty) return 'N/A';
   final sorted = locations.entries.toList()
     ..sort((a, b) => b.value.compareTo(a.value));
   return sorted.first.key;
 }

 String _getTopCategory(Map<String, int> categories) {
   if (categories.isEmpty) return 'N/A';
   final sorted = categories.entries.toList()
     ..sort((a, b) => b.value.compareTo(a.value));
   return sorted.first.key;
 }

 Map<String, dynamic> _analyzeCookingTrends(List<Recipe> recipes) {
   if (recipes.isEmpty) {
     return {
       'preferredDifficulty': 'N/A',
       'avgCookingTime': 0,
       'topCategory': 'N/A',
     };
   }
   
   // Análisis de dificultad
   final difficultyCount = <String, int>{};
   int totalCookingTime = 0;
   final categoryCount = <String, int>{};
   
   for (final recipe in recipes) {
     // Dificultad
     final difficulty = recipe.difficulty.toString().split('.').last;
     difficultyCount[difficulty] = (difficultyCount[difficulty] ?? 0) + 1;
     
     // Tiempo de cocción
     totalCookingTime += recipe.cookingTime;
     
     // Categorías
     for (final category in recipe.categories) {
       categoryCount[category] = (categoryCount[category] ?? 0) + 1;
     }
   }
   
   final preferredDifficulty = difficultyCount.entries
       .reduce((a, b) => a.value > b.value ? a : b).key;
   
   final avgCookingTime = (totalCookingTime / recipes.length).round();
   
   final topCategory = categoryCount.isNotEmpty ? 
       categoryCount.entries.reduce((a, b) => a.value > b.value ? a : b).key : 'N/A';
   
   return {
     'preferredDifficulty': _getDifficultyText(
         DifficultyLevel.values.firstWhere((d) => d.toString().contains(preferredDifficulty))),
     'avgCookingTime': avgCookingTime,
     'topCategory': topCategory,
   };
 }

 int _estimateMonthlyExpenses() {
   final shoppingList = _cachedShoppingList['all'] ?? [];
   if (shoppingList.isEmpty) return 0;
   
   double totalEstimate = 0;
   for (final item in shoppingList) {
     totalEstimate += _estimateItemCost(item);
   }
   
   // Estimación mensual basada en frecuencia de compra
   return (totalEstimate * 4).round(); // Asumiendo compra semanal
 }

 int _calculateSustainabilityScore(List<Product> inventory, List<Product> expiringProducts) {
   if (inventory.isEmpty) return 100;
   
   int score = 100;
   
   // Penalizar por productos caducados/por caducar
   final expiredRatio = expiringProducts.length / inventory.length;
   score -= (expiredRatio * 50).round();
   
   // Bonificar por diversidad de categorías
   final categories = inventory.map((p) => p.category).toSet();
   if (categories.length >= 5) score += 10;
   
   // Bonificar por uso eficiente (basado en rotación de inventario)
   final recentlyAdded = inventory.where((p) => 
       p.createdAt != null && 
       DateTime.now().difference(p.createdAt!).inDays <= 7).length;
   
   if (recentlyAdded > 0 && recentlyAdded <= inventory.length * 0.3) {
     score += 15; // Buena rotación
   }
   
   return score.clamp(0, 100);
 }

 String _getSustainabilityTips(int score) {
   if (score >= 80) {
     return "\n🎉 ¡Excelente gestión! Sigues buenas prácticas sostenibles.";
   } else if (score >= 60) {
     return "\n💡 Consejo: Planifica mejor las compras para reducir desperdicios.";
   } else {
     return "\n⚠️ Mejora: Revisa productos que caducan y planifica recetas para usarlos.";
   }
 }

 String _formatLastInteraction() {
   final diff = DateTime.now().difference(_lastInteraction);
   
   if (diff.inMinutes < 1) {
     return 'Ahora mismo';
   } else if (diff.inHours < 1) {
     return 'Hace ${diff.inMinutes} minutos';
   } else if (diff.inDays < 1) {
     return 'Hace ${diff.inHours} horas';
   } else {
     return 'Hace ${diff.inDays} días';
   }
 }

 Future<ChatMessage> _handleUnknownQuery(String userText) async {
   // Intentar dar una respuesta inteligente basada en contexto
   String response = "🤔 No estoy seguro de cómo ayudarte con eso específicamente, pero puedo sugerir algunas opciones:\n\n";
   
   // Analizar el texto para ofrecer alternativas inteligentes
   final lowerText = userText.toLowerCase();
   
   if (lowerText.contains('cómo') || lowerText.contains('how')) {
     response += "📚 **Para guías de uso**: Escribe 'ayuda' o 'help'\n";
   }
   
   if (lowerText.contains('problema') || lowerText.contains('error')) {
     response += "🔧 **Para problemas técnicos**: Describe específicamente qué no funciona\n";
   }
   
   if (lowerText.contains('receta') || lowerText.contains('cocina')) {
     response += "🍳 **Para recetas**: Prueba 'recomiéndame una receta con [ingredientes]'\n";
   }
   
   if (lowerText.contains('lista') || lowerText.contains('compra')) {
     response += "🛒 **Para lista de compras**: Di 'mostrar mi lista' o 'añadir [producto] a la lista'\n";
   }
   
   if (lowerText.contains('inventario') || lowerText.contains('productos')) {
     response += "📦 **Para inventario**: Pregunta '¿qué tengo en mi inventario?'\n";
   }
   
   // Sugerencias basadas en el contexto de la conversación
   if (_recentConversation.isNotEmpty) {
     response += "\n💡 **Basándome en nuestra conversación anterior**, quizás te interese:\n";
     
     final lastIntent = _conversationContext['lastIntent'];
     if (lastIntent == 'recipe_recommendation') {
       response += "• Ver los pasos de la última receta recomendada\n";
       response += "• Generar más recetas similares\n";
     } else if (lastIntent == 'inventory_query') {
       response += "• Añadir productos al inventario\n";
       response += "• Ver productos que caducan pronto\n";
     }
   }
   
   response += "\n**Ejemplos de cosas que puedo hacer**:\n";
   response += "• 'Recomiéndame una receta vegetariana'\n";
   response += "• 'Qué productos van a caducar esta semana'\n";
   response += "• 'Genera un menú para 5 días'\n";
   response += "• 'Añadir 2 litros de leche a la lista'\n";
   response += "• 'Mostrar estadísticas de mi inventario'\n\n";
   
   response += "¿Alguna de estas opciones te ayuda? También puedes reformular tu pregunta de otra manera.";
   
   return ChatMessage.createBotMessage(
     response,
     type: MessageType.action,
     metadata: {
       'actionType': 'unknown_query_help',
       'actionData': {
         'originalQuery': userText,
         'suggestedActions': ['help', 'recipe_recommendation', 'inventory_query'],
         'contextualSuggestions': _getContextualSuggestions(),
       },
     },
   );
 }

 List<String> _getContextualSuggestions() {
   final suggestions = <String>[];
   
   // Sugerencias basadas en preferencias del usuario
   final preferences = _userPreferences['preferences'] as Map<String, dynamic>? ?? {};
   
   if (preferences.containsKey('recipe_recommendation')) {
     suggestions.add('Ver nuevas recetas');
   }
   
   if (preferences.containsKey('meal_plan_query')) {
     suggestions.add('Planificar comidas');
   }
   
   if (preferences.containsKey('inventory_query')) {
     suggestions.add('Revisar inventario');
   }
   
   return suggestions;
 }

 Future<ChatMessage> _handleClearConversation() async {
   try {
     final success = await _clearConversationHistory();
     
     if (success) {
       // Limpiar también el contexto local
       _conversationContext.clear();
       _recentConversation.clear();
       
       return ChatMessage.createBotMessage(
         "🧹 **Conversación limpiada**\n\n" "He eliminado todo el historial de nuestra conversación. " "Podemos empezar de nuevo desde cero.\n\n" "¿En qué puedo ayudarte hoy?",
       );
     } else {
       return ChatMessage.createBotMessage(
         "No pude limpiar la conversación completamente. ¿Quieres que lo intente de nuevo?",
       );
     }
   } catch (e) {
     return ChatMessage.createBotMessage(
       "Hubo un problema al limpiar la conversación. Los mensajes locales se han limpiado, pero algunos datos remotos pueden persistir.",
     );
   }
 }

 Future<bool> _clearConversationHistory() async {
   try {
     final userId = _userId;
     if (userId == null || _userMessages == null) {
       throw Exception('Usuario no autenticado');
     }
     
     final snapshot = await _userMessages!.get();
     
     if (snapshot.docs.isEmpty) {
       return true;
     }
     
     // Usar batch para mejor rendimiento
     final batch = _firestore.batch();
     const int batchSize = 500; // Límite de Firestore para batch
     
     int processedCount = 0;
     for (final doc in snapshot.docs) {
       batch.delete(doc.reference);
       processedCount++;
       
       // Ejecutar batch cuando alcance el límite
       if (processedCount % batchSize == 0) {
         await batch.commit();
       }
     }
     
     // Ejecutar batch final si quedan documentos
     if (processedCount % batchSize != 0) {
       await batch.commit();
     }
     
     return true;
   } catch (e) {
     print('Error al eliminar la conversación: $e');
     return false;
   }
 }

 // === GENERACIÓN DE SUGERENCIAS INTELIGENTES ===

 Future<List<ChatMessage>> _generateIntelligentSuggestions(String intent, String userText) async {
   final suggestions = <ChatMessage>[];
   
   try {
     // Sugerencias basadas en la intención actual
     final baseSuggestions = await _getBaseSuggestions(intent);
     
     // Sugerencias contextuales basadas en el estado del usuario
     final contextualSuggestions = _getContextualSuggestions();
     
     // Sugerencias basadas en patrones de uso
     final behaviorSuggestions = _getBehaviorBasedSuggestions();
     
     // Combinar y limitar sugerencias
     final allSuggestions = [...baseSuggestions, ...contextualSuggestions, ...behaviorSuggestions];
     final uniqueSuggestions = allSuggestions.toSet().toList();
     
     // Seleccionar las mejores 3-4 sugerencias
     final selectedSuggestions = _selectBestSuggestions(uniqueSuggestions, intent);
     
     for (final suggestion in selectedSuggestions.take(4)) {
       suggestions.add(ChatMessage.createSuggestion(suggestion));
     }
   } catch (e) {
     print('Error generando sugerencias: $e');
     // Fallback a sugerencias básicas
     suggestions.addAll(_getBasicSuggestions(intent));
   }
   
   return suggestions;
 }

 Future<List<String>> _getBaseSuggestions(String intent) async {
   switch (intent) {
     case 'greet':
       return [
         'Mostrar mi inventario',
         'Productos que caducan pronto',
         'Recomiéndame una receta para hoy',
         'Ver mi lista de compras'
       ];
     
     case 'inventory_query':
       return [
         'Productos que caducan esta semana',
         'Añadir producto al inventario',
         'Generar recetas con mis ingredientes',
         'Ver estadísticas del inventario'
       ];
     
     case 'recipe_recommendation':
       return [
         'Guardar esta receta',
         'Ver pasos de preparación',
         'Añadir ingredientes faltantes a la lista',
         'Generar otra receta diferente'
       ];
     
     case 'shopping_list_query':
       return [
         'Añadir producto a la lista',
         'Marcar productos como comprados',
         'Generar sugerencias automáticas',
         'Ver inventario'
       ];
     
     case 'meal_plan_query':
       return [
         'Generar plan para la semana',
         'Ver recetas del plan actual',
         'Modificar plan existente',
         'Crear nuevo plan personalizado'
       ];
     
     case 'generate_meal_plan':
       return [
         'Guardar este plan',
         'Generar plan diferente',
         'Ver detalles de las recetas',
         'Añadir ingredientes a la lista'
       ];
     
     case 'show_expiring':
       return [
         'Generar recetas con productos que caducan',
         'Crear plan de comidas prioritario',
         'Configurar alertas de caducidad',
         'Ver inventario completo'
       ];
     
     default:
       return [
         'Mostrar ayuda',
         'Ver inventario',
         'Recomiéndame una receta',
         'Generar plan de comidas'
       ];
   }
 }

 List<String> _getBehaviorBasedSuggestions() {
   final suggestions = <String>[];
   
   // Basado en preferencias de uso
   final preferences = _userPreferences['preferences'] as Map<String, dynamic>? ?? {};
   
   if (preferences.containsKey('recipe_recommendation') && 
       preferences['recipe_recommendation'] > 3) {
     suggestions.add('Explorar nuevas cocinas');
   }
   
   if (preferences.containsKey('inventory_query') && 
       preferences['inventory_query'] > 2) {
     suggestions.add('Optimizar organización del inventario');
   }
   
   // Basado en patrones temporales
   final hour = DateTime.now().hour;
   if (hour >= 8 && hour <= 10) {
     suggestions.add('Planificar desayuno');
   } else if (hour >= 11 && hour <= 14) {
     suggestions.add('Ideas para el almuerzo');
   } else if (hour >= 17 && hour <= 20) {
     suggestions.add('Qué cocinar para la cena');
   }
   
   // Basado en días de la semana
   final weekday = DateTime.now().weekday;
   if (weekday == 1) { // Lunes
     suggestions.add('Planificar la semana');
   } else if (weekday == 6 || weekday == 7) { // Fin de semana
     suggestions.add('Recetas especiales de fin de semana');
   }
   
   return suggestions;
 }

 List<String> _selectBestSuggestions(List<String> suggestions, String intent) {
   // Algoritmo de selección inteligente basado en relevancia y contexto
   final scored = <Map<String, dynamic>>[];
   
   for (final suggestion in suggestions) {
     int score = 0;
     
     // Puntuación base por relevancia al intent actual
     if (_isRelevantToIntent(suggestion, intent)) {
       score += 10;
     }
     
     // Bonificación por preferencias del usuario
     if (_matchesUserPreferences(suggestion)) {
       score += 5;
     }
     
     // Bonificación por contexto temporal
     if (_isTemporallyRelevant(suggestion)) {
       score += 3;
     }
     
     // Penalización por sugerencias repetidas recientemente
     if (_wasRecentlySuggested(suggestion)) {
       score -= 5;
     }
     
     scored.add({
       'suggestion': suggestion,
       'score': score,
     });
   }
   
   // Ordenar por puntuación y devolver las mejores
   scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
   
   return scored.map((item) => item['suggestion'] as String).toList();
 }

 bool _isRelevantToIntent(String suggestion, String intent) {
   final relevanceMap = {
     'inventory_query': ['inventario', 'productos', 'caducan', 'stock'],
     'recipe_recommendation': ['receta', 'cocinar', 'ingredientes', 'preparar'],
     'shopping_list_query': ['lista', 'compra', 'añadir', 'marcar'],
     'meal_plan_query': ['plan', 'menú', 'semana', 'planificar'],
   };
   
   final keywords = relevanceMap[intent] ?? [];
   return keywords.any((keyword) => suggestion.toLowerCase().contains(keyword));
 }

 bool _matchesUserPreferences(String suggestion) {
   final favoriteCuisine = _userPreferences['favoriteCuisine'] as String?;
   final dietaryPreference = _userPreferences['dietaryPreference'] as String?;
   
   if (favoriteCuisine != null && suggestion.toLowerCase().contains(favoriteCuisine.toLowerCase())) {
     return true;
   }
   
   if (dietaryPreference != null && suggestion.toLowerCase().contains(dietaryPreference.toLowerCase())) {
     return true;
   }
   
   return false;
 }

 bool _isTemporallyRelevant(String suggestion) {
   final hour = DateTime.now().hour;
   final lowerSuggestion = suggestion.toLowerCase();
   
   if (hour >= 6 && hour <= 10 && lowerSuggestion.contains('desayuno')) {
     return true;
   }
   
   if (hour >= 11 && hour <= 15 && lowerSuggestion.contains('almuerzo')) {
     return true;
   }
   
   if (hour >= 17 && hour <= 21 && lowerSuggestion.contains('cena')) {
     return true;
   }
   
   return false;
 }

 bool _wasRecentlySuggested(String suggestion) {
   // Esto se podría implementar manteniendo un historial de sugerencias
   // Por ahora, retorna false
   return false;
 }

 // Continuación del código...

 List<ChatMessage> _getBasicSuggestions(String intent) {
   // Sugerencias de fallback básicas
   final basicSuggestions = [
     'Mostrar ayuda',
     'Ver mi inventario',
     'Recomiéndame una receta',
     'Mostrar lista de compras'
   ];
   
   return basicSuggestions
       .map((suggestion) => ChatMessage.createSuggestion(suggestion))
       .toList();
 }

 // === MÉTODOS AUXILIARES AVANZADOS ===

 String _getDifficultyText(DifficultyLevel difficulty) {
   switch (difficulty) {
     case DifficultyLevel.easy:
       return 'Fácil';
     case DifficultyLevel.medium:
       return 'Media';
     case DifficultyLevel.hard:
       return 'Difícil';
   }
 }

 String _getMealTypeName(String mealTypeId) {
   switch (mealTypeId.toLowerCase()) {
     case 'breakfast':
       return 'Desayuno';
     case 'lunch':
       return 'Almuerzo';
     case 'dinner':
       return 'Cena';
     case 'snack':
       return 'Merienda';
     default:
       return mealTypeId;
   }
 }

 // === MÉTODOS PARA MANEJO DE RECETAS AVANZADO ===

 Future<ChatMessage> _handleRecipeQueryAdvanced(String userText) async {
   try {
     final recipes = _cachedRecipes['all'] ?? await _recipeService.getAllRecipes();
     
     if (recipes.isEmpty) {
       return ChatMessage.createBotMessage(
         "No tienes recetas guardadas todavía. ¿Te gustaría que genere algunas recetas basadas en tu inventario actual?",
       );
     }
     
     // Análisis avanzado de la consulta
     final searchTerms = _extractSearchTerms(userText);
     final filters = _extractRecipeFilters(userText);
     
     // Aplicar filtros y búsqueda
     List<Recipe> filteredRecipes = recipes;
     
     // Filtrar por términos de búsqueda
     if (searchTerms.isNotEmpty) {
       filteredRecipes = _filterRecipesBySearchTerms(filteredRecipes, searchTerms);
     }
     
     // Aplicar filtros adicionales
     filteredRecipes = _applyRecipeFilters(filteredRecipes, filters);
     
     if (filteredRecipes.isEmpty) {
       String response = "No encontré recetas que coincidan con tu búsqueda";
       if (searchTerms.isNotEmpty) {
         response += " para '${searchTerms.join(', ')}'";
       }
       response += ".\n\n¿Te gustaría que:\n";
       response += "• Genere nuevas recetas con esos ingredientes\n";
       response += "• Muestre todas tus recetas guardadas\n";
       response += "• Busque recetas con criterios diferentes";
       
       return ChatMessage.createBotMessage(response);
     }
     
     // Ordenar resultados por relevancia
     filteredRecipes = _sortRecipesByRelevance(filteredRecipes, searchTerms, filters);
     
     // Crear respuesta detallada
     String response = "🔍 **Resultados de búsqueda** (${filteredRecipes.length} recetas encontradas)\n\n";
     
     if (searchTerms.isNotEmpty) {
       response += "**Buscando**: ${searchTerms.join(', ')}\n";
     }
     
     if (filters.isNotEmpty) {
       response += "**Filtros aplicados**: ${_formatFilters(filters)}\n";
     }
     
     response += "\n";
     
     // Mostrar recetas encontradas
     for (int i = 0; i < filteredRecipes.length && i < 5; i++) {
       final recipe = filteredRecipes[i];
       final matchScore = _calculateRecipeMatchScore(recipe, searchTerms, filters);
       
       response += "**${i + 1}. ${recipe.name}** ${_getMatchIndicator(matchScore)}\n";
       response += "⏱️ ${recipe.totalTime} min | 📊 ${_getDifficultyText(recipe.difficulty)} | 👥 ${recipe.servings} porciones\n";
       
       // Mostrar ingredientes principales que coinciden
       final matchingIngredients = _getMatchingIngredients(recipe, searchTerms);
       if (matchingIngredients.isNotEmpty) {
         response += "✅ Incluye: ${matchingIngredients.take(3).join(', ')}\n";
       }
       
       // Mostrar categorías
       if (recipe.categories.isNotEmpty) {
         response += "🏷️ ${recipe.categories.take(2).join(', ')}\n";
       }
       
       response += "\n";
     }
     
     if (filteredRecipes.length > 5) {
       response += "... y ${filteredRecipes.length - 5} recetas más.\n\n";
     }
     
     response += "¿Te gustaría ver los detalles de alguna receta específica o refinar la búsqueda?";
     
     return ChatMessage.createBotMessage(
       response,
       type: MessageType.action,
       metadata: {
         'actionType': 'recipe_search_results',
         'actionData': {
           'searchTerms': searchTerms,
           'filters': filters,
           'results': filteredRecipes.take(10).map((r) => r.toMap()).toList(),
           'totalFound': filteredRecipes.length,
         },
       },
     );
   } catch (e) {
     return ChatMessage.createBotMessage(
       "No pude buscar en tus recetas en este momento. ¿Quieres que lo intente de nuevo?",
     );
   }
 }

 List<String> _extractSearchTerms(String text) {
   final lowerText = text.toLowerCase();
   final searchTerms = <String>[];
   
   // Patrones para extraer términos de búsqueda
   final patterns = [
     RegExp(r'recetas? (?:de|con|para) ([^.!?]+)'),
     RegExp(r'buscar ([^.!?]+)'),
     RegExp(r'(?:con|usando|que tengan) ([^.!?]+)'),
   ];
   
   for (final pattern in patterns) {
     final match = pattern.firstMatch(lowerText);
     if (match != null) {
       final term = match.group(1)?.trim();
       if (term != null && term.isNotEmpty) {
         // Limpiar y dividir términos
         final cleanedTerms = term.split(RegExp(r'[,y\s]+'))
             .map((t) => t.trim())
             .where((t) => t.length > 2)
             .toList();
         searchTerms.addAll(cleanedTerms);
       }
     }
   }
   
   // Si no se encontraron términos específicos, extraer palabras clave generales
   if (searchTerms.isEmpty) {
     final keywords = ['pollo', 'carne', 'pescado', 'pasta', 'arroz', 'verduras', 'frutas'];
     for (final keyword in keywords) {
       if (lowerText.contains(keyword)) {
         searchTerms.add(keyword);
       }
     }
   }
   
   return searchTerms;
 }

 Map<String, dynamic> _extractRecipeFilters(String text) {
   final lowerText = text.toLowerCase();
   final filters = <String, dynamic>{};
   
   // Filtro de dificultad
   if (lowerText.contains('fácil') || lowerText.contains('simple')) {
     filters['difficulty'] = DifficultyLevel.easy;
   } else if (lowerText.contains('difícil') || lowerText.contains('complej')) {
     filters['difficulty'] = DifficultyLevel.hard;
   }
   
   // Filtro de tiempo
   if (lowerText.contains('rápid') || lowerText.contains('poco tiempo')) {
     filters['maxTime'] = 30;
   } else if (lowerText.contains('lent') || lowerText.contains('mucho tiempo')) {
     filters['minTime'] = 60;
   }
   
   // Filtro de tipo de comida
   if (lowerText.contains('desayuno')) {
     filters['categories'] = ['desayuno'];
   } else if (lowerText.contains('almuerzo') || lowerText.contains('comida')) {
     filters['categories'] = ['almuerzo'];
   } else if (lowerText.contains('cena')) {
     filters['categories'] = ['cena'];
   }
   
   // Filtros dietéticos
   if (lowerText.contains('vegetariana')) {
     filters['categories'] = (filters['categories'] as List<String>? ?? [])..add('vegetariana');
   } else if (lowerText.contains('vegana')) {
     filters['categories'] = (filters['categories'] as List<String>? ?? [])..add('vegana');
   }
   
   // Filtro de cocina
   final cuisines = ['italiana', 'mexicana', 'asiática', 'mediterránea', 'española'];
   for (final cuisine in cuisines) {
     if (lowerText.contains(cuisine)) {
       filters['categories'] = (filters['categories'] as List<String>? ?? [])..add(cuisine);
       break;
     }
   }
   
   return filters;
 }

 List<Recipe> _filterRecipesBySearchTerms(List<Recipe> recipes, List<String> searchTerms) {
   if (searchTerms.isEmpty) return recipes;
   
   return recipes.where((recipe) {
     // Buscar en nombre, descripción, ingredientes y categorías
     final searchableText = [
       recipe.name,
       recipe.description,
       ...recipe.ingredients.map((i) => i.name),
       ...recipe.categories,
     ].join(' ').toLowerCase();
     
     // La receta debe coincidir con al menos un término de búsqueda
     return searchTerms.any((term) => 
         searchableText.contains(term.toLowerCase()));
   }).toList();
 }

 List<Recipe> _applyRecipeFilters(List<Recipe> recipes, Map<String, dynamic> filters) {
   List<Recipe> filtered = recipes;
   
   // Filtro de dificultad
   if (filters.containsKey('difficulty')) {
     filtered = filtered.where((recipe) => 
         recipe.difficulty == filters['difficulty']).toList();
   }
   
   // Filtro de tiempo máximo
   if (filters.containsKey('maxTime')) {
     filtered = filtered.where((recipe) => 
         recipe.totalTime <= (filters['maxTime'] as int)).toList();
   }
   
   // Filtro de tiempo mínimo
   if (filters.containsKey('minTime')) {
     filtered = filtered.where((recipe) => 
         recipe.totalTime >= (filters['minTime'] as int)).toList();
   }
   
   // Filtro de categorías
   if (filters.containsKey('categories')) {
     final requiredCategories = filters['categories'] as List<String>;
     filtered = filtered.where((recipe) => 
         requiredCategories.any((cat) => 
             recipe.categories.any((recipeCat) => 
                 recipeCat.toLowerCase().contains(cat.toLowerCase())))).toList();
   }
   
   return filtered;
 }

 List<Recipe> _sortRecipesByRelevance(List<Recipe> recipes, List<String> searchTerms, Map<String, dynamic> filters) {
   // Ordenar por puntuación de relevancia
   final scored = recipes.map((recipe) => {
     'recipe': recipe,
     'score': _calculateRecipeMatchScore(recipe, searchTerms, filters),
   }).toList();
   
   scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
   
   return scored.map((item) => item['recipe'] as Recipe).toList();
 }

 double _calculateRecipeMatchScore(Recipe recipe, List<String> searchTerms, Map<String, dynamic> filters) {
   double score = 0.0;
   
   // Puntuación por coincidencias en el nombre (peso alto)
   for (final term in searchTerms) {
     if (recipe.name.toLowerCase().contains(term.toLowerCase())) {
       score += 10.0;
     }
   }
   
   // Puntuación por coincidencias en ingredientes (peso medio)
   for (final term in searchTerms) {
     final matchingIngredients = recipe.ingredients.where((ing) => 
         ing.name.toLowerCase().contains(term.toLowerCase())).length;
     score += matchingIngredients * 5.0;
   }
   
   // Puntuación por coincidencias en categorías (peso medio)
   for (final term in searchTerms) {
     final matchingCategories = recipe.categories.where((cat) => 
         cat.toLowerCase().contains(term.toLowerCase())).length;
     score += matchingCategories * 3.0;
   }
   
   // Bonificación por filtros específicos
   if (filters.containsKey('difficulty') && recipe.difficulty == filters['difficulty']) {
     score += 5.0;
   }
   
   // Bonificación por disponibilidad de ingredientes
   final availableIngredients = recipe.ingredients.where((ing) => ing.isAvailable).length;
   final totalIngredients = recipe.ingredients.length;
   if (totalIngredients > 0) {
     score += (availableIngredients / totalIngredients) * 8.0;
   }
   
   return score;
 }

 String _getMatchIndicator(double score) {
   if (score >= 15.0) return '🎯';
   if (score >= 10.0) return '✨';
   if (score >= 5.0) return '✓';
   return '';
 }

 List<String> _getMatchingIngredients(Recipe recipe, List<String> searchTerms) {
   final matching = <String>[];
   
   for (final ingredient in recipe.ingredients) {
     for (final term in searchTerms) {
       if (ingredient.name.toLowerCase().contains(term.toLowerCase())) {
         matching.add(ingredient.name);
         break;
       }
     }
   }
   
   return matching;
 }

 String _formatFilters(Map<String, dynamic> filters) {
   final formatted = <String>[];
   
   if (filters.containsKey('difficulty')) {
     formatted.add('Dificultad: ${_getDifficultyText(filters['difficulty'])}');
   }
   
   if (filters.containsKey('maxTime')) {
     formatted.add('Máximo ${filters['maxTime']} min');
   }
   
   if (filters.containsKey('categories')) {
     final categories = filters['categories'] as List<String>;
     formatted.add('Categorías: ${categories.join(', ')}');
   }
   
   return formatted.join(', ');
 }

 // === FUNCIONES DE MANEJO DE INVENTARIO AVANZADO ===

 Future<ChatMessage> _handleAddToInventoryAdvanced(String userText) async {
   try {
     final productInfo = _extractDetailedProductInfo(userText);
     
     if (productInfo['name'] == null || productInfo['name'].toString().isEmpty) {
       return ChatMessage.createBotMessage(
         "Para añadir un producto al inventario, necesito más información. Intenta algo como:\n" "• 'Añadir 2 litros de leche al inventario'\n" "• 'Poner 500g de arroz en la despensa'\n" "• 'Tengo 6 huevos en la nevera'\n\n" +
         "¿O prefieres que te ayude a escanear un código de barras?",
       );
     }

     // Verificar si ya existe un producto similar
     final existingProducts = await _inventoryService.getAllProducts();
     final similarProduct = existingProducts.firstWhere(
       (existing) => _areProductsSimilar(existing.name, productInfo['name']),
       orElse: () => Product(id: '', name: '', quantity: 0, unit: '', category: '', location: '', userId: ''),
     );

     if (similarProduct.id.isNotEmpty) {
       return ChatMessage.createBotMessage(
         "Ya tienes '${similarProduct.name}' en tu inventario (${similarProduct.quantity} ${similarProduct.unit} en ${similarProduct.location}).\n\n" "¿Quieres:\n" "• **Aumentar la cantidad** del producto existente\n" "• **Añadir como producto separado** (diferente ubicación/fecha)\n" +
         "• **Actualizar la información** del producto existente",
         type: MessageType.action,
         metadata: {
           'actionType': 'duplicate_product_detected',
           'actionData': {
             'existingProduct': similarProduct.toMap(),
             'newProductInfo': productInfo,
           },
         },
       );
     }

     // Crear producto con información completa
     final product = Product(
       id: '',
       name: productInfo['name'],
       quantity: (productInfo['quantity'] ?? 1).toInt(),
       maxQuantity: ((productInfo['quantity'] ?? 1) * 2).toInt(),
       unit: productInfo['unit'] ?? _suggestUnit(productInfo['name']),
       category: productInfo['category'] ?? _categorizeProduct(productInfo['name']),
       location: productInfo['location'] ?? productInfo['preferredLocation'] ?? 'Despensa',
       productLocation: ProductLocation.inventory,
       userId: _userId!,
       expiryDate: productInfo['expiryDate'] ?? DateTime.now().add(Duration(days: _estimateShelfLife(productInfo['name']))),
       createdAt: DateTime.now(),
       imageUrl: '',
     );

     // Añadir al inventario
     await _inventoryService.addProduct(product);

     // Invalidar cache
     _cachedInventory.clear();

     // Respuesta de éxito con información adicional
     String response = "✅ **Producto añadido exitosamente**\n\n";
     response += "📦 **${product.name}**\n";
     response += "• Cantidad: ${product.quantity} ${product.unit}\n";
     response += "• Ubicación: ${product.location}\n";
     response += "• Categoría: ${product.category}\n";
     
     if (product.expiryDate != null) {
       final daysUntilExpiry = product.expiryDate!.difference(DateTime.now()).inDays;
       response += "• Caduca en: $daysUntilExpiry días\n";
     }

     // Sugerencias contextuales
     final suggestions = _getInventoryAddSuggestions(product);
     if (suggestions.isNotEmpty) {
       response += "\n💡 **Sugerencias**:\n";
       for (var suggestion in suggestions) {
         response += "• $suggestion\n";
       }
     }

     return ChatMessage.createBotMessage(
       response,
       type: MessageType.action,
       metadata: {
         'actionType': 'product_added_successfully',
         'actionData': {
           'productId': product.id,
           'productName': product.name,
           'location': product.location,
           'suggestions': suggestions,
         },
       },
     );
   } catch (e) {
     return ChatMessage.createBotMessage(
       "No pude añadir el producto al inventario. ¿Quieres intentarlo de otra manera o prefieres añadirlo manualmente desde la app?",
     );
   }
 }

 int _estimateShelfLife(String productName) {
   final lowerName = productName.toLowerCase();
   
   // Estimaciones basadas en categorías de productos
   if (lowerName.contains('leche') || lowerName.contains('yogur')) {
     return 7;
   } else if (lowerName.contains('pan') || lowerName.contains('fruta')) {
     return 5;
   } else if (lowerName.contains('carne') || lowerName.contains('pescado')) {
     return 3;
   } else if (lowerName.contains('verdura') || lowerName.contains('lechuga')) {
     return 7;
   } else if (lowerName.contains('huevo')) {
     return 21;
   } else if (lowerName.contains('arroz') || lowerName.contains('pasta')) {
     return 365;
   } else if (lowerName.contains('conserva') || lowerName.contains('lata')) {
     return 730;
   } else {
     return 30; // Por defecto un mes
   }
 }

 List<String> _getInventoryAddSuggestions(Product product) {
   final suggestions = <String>[];
   
   // Sugerencias basadas en la categoría del producto
   switch (product.category.toLowerCase()) {
     case 'lácteos':
       suggestions.add('Considera añadir cereales o café que combinan bien');
       break;
     case 'carnes':
       suggestions.add('Revisa si tienes verduras para acompañar');
       break;
     case 'verduras':
       suggestions.add('Perfecto para ensaladas o como guarnición');
       break;
     case 'frutas':
       suggestions.add('Ideal para desayunos o meriendas saludables');
       break;
   }
   
   // Sugerencias basadas en la fecha de caducidad
   if (product.expiryDate != null) {
     final daysUntilExpiry = product.expiryDate!.difference(DateTime.now()).inDays;
     if (daysUntilExpiry <= 7) {
       suggestions.add('Úsalo pronto, caduca en $daysUntilExpiry días');
     } else if (daysUntilExpiry <= 3) {
       suggestions.add('¡Prioridad alta! Planifica recetas con este ingrediente');
     }
   }
   
   // Sugerencias de organización
   if (product.location == 'Despensa') {
     suggestions.add('Mantén productos similares juntos para mejor organización');
   }
   
   return suggestions;
 }

 Future<ChatMessage> _handleRemoveFromInventoryAdvanced(String userText) async {
   try {
     final productInfo = _extractDetailedProductInfo(userText);
     
     if (productInfo['name'] == null || productInfo['name'].toString().isEmpty) {
       return ChatMessage.createBotMessage(
         "Para quitar un producto del inventario, especifica el nombre. Por ejemplo:\n" "• 'Quitar 1 litro de leche'\n" "• 'Consumí todo el yogur'\n" "• 'Ya no tengo arroz'\n" +
         "• 'Terminé las manzanas'",
       );
     }

     final products = await _inventoryService.getAllProducts();
     final productName = productInfo['name'].toLowerCase();
     
     // Buscar productos que coincidan
     final matchingProducts = products.where((p) => 
         p.name.toLowerCase().contains(productName) ||
         productName.contains(p.name.toLowerCase())).toList();

     if (matchingProducts.isEmpty) {
       // Sugerir productos similares
       final similarProducts = products.where((p) => 
           _haveSimilarWords(p.name.toLowerCase(), productName)).toList();
       
       String response = "No encontré '${productInfo['name']}' en tu inventario.";
       
       if (similarProducts.isNotEmpty) {
         response += "\n\n¿Te refieres a alguno de estos?";
         similarProducts.take(3).forEach((product) {
           response += "\n• ${product.name} (${product.quantity} ${product.unit} en ${product.location})";
         });
       } else {
         response += "\n\n¿Quieres ver todos los productos de tu inventario para encontrar el que buscas?";
       }
       
       return ChatMessage.createBotMessage(response);
     }

     // Si hay múltiples coincidencias, preguntar al usuario
     if (matchingProducts.length > 1) {
       String response = "Encontré varios productos que coinciden:\n\n";
       
       for (int i = 0; i < matchingProducts.length && i < 5; i++) {
         final product = matchingProducts[i];
         response += "${i + 1}. **${product.name}** - ${product.quantity} ${product.unit} (${product.location})\n";
       }
       
       response += "\n¿Cuál quieres quitar? Puedes ser más específico con el nombre.";
       
       return ChatMessage.createBotMessage(
         response,
         type: MessageType.action,
         metadata: {
           'actionType': 'multiple_products_found',
           'actionData': {
             'products': matchingProducts.take(5).map((p) => p.toMap()).toList(),
             'originalQuery': userText,
           },
         },
       );
     }

     // Producto único encontrado
     final product = matchingProducts.first;
     final quantityToRemove = (productInfo['quantity'] ?? product.quantity).toInt();
     
     String response;
     
     if (quantityToRemove >= product.quantity) {
       // Quitar completamente
       await _inventoryService.deleteProduct(product.id);
       response = "✅ **${product.name}** eliminado completamente del inventario.\n\n";
       
       // Sugerir añadir a la lista de compras
       response += "💡 ¿Quieres añadirlo a tu lista de compras para comprarlo de nuevo?";
       
       return ChatMessage.createBotMessage(
         response,
         type: MessageType.action,
         metadata: {
           'actionType': 'product_removed_completely',
           'actionData': {
             'productName': product.name,
             'productInfo': product.toMap(),
             'suggestAddToShoppingList': true,
           },
         },
       );
     } else {
       // Reducir cantidad
       final int newQuantity = (product.quantity - quantityToRemove).clamp(0, product.quantity).toInt();
       await _inventoryService.updateProductQuantity(product.id, newQuantity);
       
       response = "✅ **${product.name}** actualizado.\n\n";
       response += "📊 **Cambios**:\n";
       response += "• Cantidad anterior: ${product.quantity} ${product.unit}\n";
       response += "• Cantidad actual: $newQuantity ${product.unit}\n";
       response += "• Ubicación: ${product.location}\n";
       
       // Alerta si queda poco stock
       if (newQuantity <= (product.maxQuantity * 0.2)) {
         response += "\n⚠️ **Stock bajo**: Considera añadirlo a tu lista de compras.";
       }
       
       return ChatMessage.createBotMessage(
         response,
         type: MessageType.action,
         metadata: {
           'actionType': 'product_quantity_reduced',
           'actionData': {
             'productId': product.id,
             'productName': product.name,
             'oldQuantity': product.quantity,
             'newQuantity': newQuantity,
             'lowStock': newQuantity <= (product.maxQuantity * 0.2),
           },
         },
       );
     }
   } catch (e) {
     return ChatMessage.createBotMessage(
       "No pude actualizar el producto en el inventario. ¿Quieres intentarlo de nuevo o usar la app directamente?",
     );
   }
 }

 Future<ChatMessage> _handleMarkAsPurchasedAdvanced(String userText) async {
   try {
     final productName = _extractProductName(userText);
     
     if (productName == null || productName.isEmpty) {
       return ChatMessage.createBotMessage(
         "Para marcar productos como comprados, especifica el nombre. Por ejemplo:\n" "• 'Marcar leche como comprado'\n" "• 'Ya compré el pan'\n" "• 'Tengo los huevos'\n" +
         "• 'Completé la compra de arroz'",
       );
     }

     final shoppingItems = await _shoppingListService.getShoppingList();
     final pendingItems = shoppingItems.where((item) => !item.isPurchased).toList();
     
     if (pendingItems.isEmpty) {
       return ChatMessage.createBotMessage(
         "No tienes productos pendientes en tu lista de compras. ¡Parece que ya has comprado todo! 🎉",
       );
     }

     // Buscar coincidencias
     final matchingItems = pendingItems.where((item) => 
         item.name.toLowerCase().contains(productName.toLowerCase()) ||
         productName.toLowerCase().contains(item.name.toLowerCase())).toList();

     if (matchingItems.isEmpty) {
       // Mostrar productos pendientes para ayudar al usuario
       String response = "No encontré '$productName' en tu lista de compras pendientes.\n\n";
       response += "**Productos pendientes**:\n";
       
       pendingItems.take(5).forEach((item) {
         response += "• ${item.name} (${item.quantity} ${item.unit})\n";
       });
       
       if (pendingItems.length > 5) {
         response += "• ... y ${pendingItems.length - 5} más\n";
       }
       
       response += "\n¿Cuál de estos querías marcar como comprado?";
       
       return ChatMessage.createBotMessage(response);
     }

     // Si hay múltiples coincidencias
     if (matchingItems.length > 1) {
       String response = "Encontré varios productos pendientes que coinciden:\n\n";
       
       for (int i = 0; i < matchingItems.length; i++) {
         final item = matchingItems[i];
         response += "${i + 1}. **${item.name}** - ${item.quantity} ${item.unit}\n";
       }
       
       response += "\n¿Cuál específicamente has comprado?";
       
       return ChatMessage.createBotMessage(
         response,
         type: MessageType.action,
         metadata: {
           'actionType': 'multiple_shopping_items_found',
           'actionData': {
             'items': matchingItems.map((item) => item.toMap()).toList(),
             'originalQuery': userText,
           },
         },
       );
     }

     // Marcar como comprado
     final item = matchingItems.first;
     final success = await _shoppingListService.toggleItemPurchased(item.id);

     if (success) {
       String response = "✅ **${item.name}** marcado como comprado.\n\n";
       
       // Estadísticas de progreso
       final allItems = await _shoppingListService.getShoppingList();
       final completedItems = allItems.where((item) => item.isPurchased).length;
       final totalItems = allItems.length;
       final completionRate = ((completedItems / totalItems) * 100).round();

       // Continuación del código...

       response += "📊 **Progreso de compras**: $completedItems/$totalItems completados ($completionRate%)\n";
       
       // Mostrar elementos restantes si quedan pocos
       final remainingItems = allItems.where((item) => !item.isPurchased).toList();
       if (remainingItems.length <= 3 && remainingItems.isNotEmpty) {
         response += "\n**Te faltan solo**:\n";
         for (var item in remainingItems) {
           response += "• ${item.name} (${item.quantity} ${item.unit})\n";
         }
       } else if (remainingItems.isEmpty) {
         response += "\n🎉 **¡Lista de compras completada!** ¡Buen trabajo!";
       }
       
       // Preguntar si quiere añadir al inventario
       response += "\n\n💡 ¿Quieres que añada **${item.name}** a tu inventario automáticamente?";
       
       return ChatMessage.createBotMessage(
         response,
         type: MessageType.action,
         metadata: {
           'actionType': 'item_marked_purchased',
           'actionData': {
             'itemId': item.id,
             'itemName': item.name,
             'completionRate': completionRate,
             'remainingItems': remainingItems.length,
             'suggestAddToInventory': true,
             'itemData': item.toMap(),
           },
         },
       );
     } else {
       return ChatMessage.createBotMessage(
         "No pude marcar '${item.name}' como comprado. ¿Quieres que lo intente de nuevo?",
       );
     }
   } catch (e) {
     return ChatMessage.createBotMessage(
       "Hubo un problema al actualizar el estado del producto en tu lista de compras.",
     );
   }
 }

 // Añadir este método a tu clase EnhancedChatService

Future<ChatMessage> _handleMealPlanQueryAdvanced(String userText) async {
  try {
    final today = DateTime.now();
    final endDate = today.add(const Duration(days: 7));
    
    final mealPlans = await _mealPlanService.getMealPlansForDateRange(today, endDate);
    
    if (mealPlans.isEmpty) {
      return ChatMessage.createBotMessage(
        "No tienes ningún plan de comidas para los próximos días. ¿Te gustaría que te ayude a crear uno con IA?\n\n" "Puedo generar planes personalizados basados en:\n" "• Tus ingredientes disponibles\n" "• Productos que caducan pronto\n" +
        "• Tus preferencias de cocina\n" +
        "• Restricciones dietéticas",
      );
    }
    
    // Analizar el plan existente
    final analysis = _analyzeMealPlans(mealPlans);
    
    // Agrupar por fechas
    final mealPlansByDate = <DateTime, List<MealPlan>>{};
    for (final plan in mealPlans) {
      final date = DateTime(plan.date.year, plan.date.month, plan.date.day);
      
      if (!mealPlansByDate.containsKey(date)) {
        mealPlansByDate[date] = [];
      }
      
      mealPlansByDate[date]!.add(plan);
    }
    
    final sortedDates = mealPlansByDate.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    
    String response = "📅 **Tu planificación de comidas**\n\n";
    response += "**Resumen**: ${mealPlans.length} comidas planificadas para ${sortedDates.length} días\n";
    response += "**Comidas completadas**: ${analysis['completed']}/${mealPlans.length}\n";
    response += "**Progreso**: ${analysis['completionRate']}%\n\n";
    
    // Mostrar próximas comidas
    response += "**📋 Próximos días**:\n";
    
    for (int i = 0; i < sortedDates.length && i < 5; i++) {
      final date = sortedDates[i];
      final plans = mealPlansByDate[date]!;
      
      final isToday = date.year == today.year && 
                     date.month == today.month && 
                     date.day == today.day;
      final isTomorrow = date.year == today.add(const Duration(days: 1)).year && 
                        date.month == today.add(const Duration(days: 1)).month && 
                        date.day == today.add(const Duration(days: 1)).day;
      
      String dateText;
      if (isToday) {
        dateText = "**Hoy** (${date.day}/${date.month})";
      } else if (isTomorrow) {
        dateText = "**Mañana** (${date.day}/${date.month})";
      } else {
        final weekDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        final weekDay = weekDays[date.weekday - 1];
        dateText = "**$weekDay** ${date.day}/${date.month}";
      }
      
      response += "\n$dateText:\n";
      
      // Ordenar comidas por tipo
      final orderedPlans = _orderMealsByTime(plans);
      
      for (final plan in orderedPlans) {
        final mealTypeName = _getMealTypeName(plan.mealTypeId);
        final recipeName = plan.recipe?.name ?? "Receta sin nombre";
        final completedIcon = plan.isCompleted ? "✅" : "⏳";
        
        response += "  $completedIcon $mealTypeName: $recipeName\n";
      }
    }
    
    if (sortedDates.length > 5) {
      response += "\n... y planes para ${sortedDates.length - 5} días más.\n";
    }
    
    // Análisis de ingredientes necesarios
    final missingIngredients = await _analyzeMealPlanIngredients(mealPlans);
    if (missingIngredients.isNotEmpty) {
      response += "\n🛒 **Ingredientes que necesitas**: ${missingIngredients.length}\n";
      missingIngredients.take(3).forEach((ingredient) {
        response += "• $ingredient\n";
      });
      if (missingIngredients.length > 3) {
        response += "• ... y ${missingIngredients.length - 3} más\n";
      }
    }
    
    // Sugerencias de acciones
    response += "\n**¿Qué te gustaría hacer?**\n";
    response += "• Ver detalles de una receta específica\n";
    response += "• Marcar comidas como completadas\n";
    response += "• Modificar el plan existente\n";
    response += "• Generar nuevo plan para más días\n";
    
    if (missingIngredients.isNotEmpty) {
      response += "• Añadir ingredientes faltantes a la lista de compras\n";
    }

    return ChatMessage.createBotMessage(
      response,
      type: MessageType.action,
      metadata: {
        'actionType': 'meal_plan_overview_advanced',
        'actionData': {
          'totalMeals': mealPlans.length,
          'completedMeals': analysis['completed'],
          'completionRate': analysis['completionRate'],
          'daysPlanned': sortedDates.length,
          'missingIngredients': missingIngredients,
          'plans': mealPlans.take(10).map((p) => p.toMap()).toList(),
        },
      },
    );
  } catch (e) {
    return ChatMessage.createBotMessage(
      "No pude acceder a tu planificación de comidas en este momento. ¿Quieres que lo intente de nuevo?",
    );
  }
}

// Métodos auxiliares para el análisis de meal plans

Map<String, dynamic> _analyzeMealPlans(List<MealPlan> mealPlans) {
  if (mealPlans.isEmpty) {
    return {'completed': 0, 'completionRate': 0};
  }
  
  final completed = mealPlans.where((plan) => plan.isCompleted).length;
  final completionRate = ((completed / mealPlans.length) * 100).round();
  
  return {
    'completed': completed,
    'total': mealPlans.length,
    'completionRate': completionRate,
  };
}

List<MealPlan> _orderMealsByTime(List<MealPlan> plans) {
  // Ordenar por tipo de comida (desayuno, almuerzo, cena)
  final mealOrder = {'breakfast': 1, 'lunch': 2, 'dinner': 3, 'snack': 4};
  
  plans.sort((a, b) {
    final orderA = mealOrder[a.mealTypeId] ?? 5;
    final orderB = mealOrder[b.mealTypeId] ?? 5;
    return orderA.compareTo(orderB);
  });
  
  return plans;
}

Future<List<String>> _analyzeMealPlanIngredients(List<MealPlan> mealPlans) async {
  final missingIngredients = <String>[];
  
  try {
    final inventory = await _inventoryService.getAllProducts();
    final inventoryNames = inventory.map((p) => p.name.toLowerCase()).toSet();
    
    for (final plan in mealPlans) {
      if (plan.recipe != null) {
        for (final ingredient in plan.recipe!.ingredients) {
          if (!ingredient.isAvailable && 
              !inventoryNames.any((name) => 
                  name.contains(ingredient.name.toLowerCase()) ||
                  ingredient.name.toLowerCase().contains(name))) {
            
            final ingredientKey = ingredient.name.toLowerCase();
            if (!missingIngredients.any((existing) => 
                existing.toLowerCase().contains(ingredientKey))) {
              missingIngredients.add(ingredient.name);
            }
          }
        }
      }
    }
  } catch (e) {
    print('Error analizando ingredientes del meal plan: $e');
  }
  
  return missingIngredients;
}

 Future<ChatMessage> _handleFavoritesAdvanced() async {
   try {
     final favoriteProducts = await _shoppingListService.getFavoriteProducts();
     final favoriteRecipes = _cachedRecipes['favorites'] ?? await _recipeService.getFavoriteRecipes();
     
     if (favoriteProducts.isEmpty && favoriteRecipes.isEmpty) {
       return ChatMessage.createBotMessage(
         "No tienes productos ni recetas marcados como favoritos todavía.\n\n" "💡 **Para añadir favoritos**:\n" "• En el inventario: toca la estrella en cualquier producto\n" "• En recetas: marca como favorita las que más te gusten\n" +
         "• Los favoritos te ayudan a acceder rápidamente a lo que más usas\n\n" +
         "¿Te gustaría que te muestre cómo añadir favoritos?",
       );
     }

     String response = "⭐ **Tus elementos favoritos**\n\n";
     
     // Productos favoritos
     if (favoriteProducts.isNotEmpty) {
       response += "🛒 **Productos favoritos** (${favoriteProducts.length}):\n";
       
       final productsByCategory = <String, List<Product>>{};
       for (final product in favoriteProducts) {
         if (!productsByCategory.containsKey(product.category)) {
           productsByCategory[product.category] = [];
         }
         productsByCategory[product.category]!.add(product);
       }
       
       productsByCategory.forEach((category, products) {
         response += "\n**$category**:\n";
         products.take(3).forEach((product) {
           response += "• ${product.name}\n";
         });
         if (products.length > 3) {
           response += "• ... y ${products.length - 3} más\n";
         }
       });
       
       response += "\n";
     }
     
     // Recetas favoritas
     if (favoriteRecipes.isNotEmpty) {
       response += "👨‍🍳 **Recetas favoritas** (${favoriteRecipes.length}):\n";
       
       favoriteRecipes.take(5).forEach((recipe) {
         response += "• **${recipe.name}**\n";
         response += "  ⏱️ ${recipe.totalTime} min | 📊 ${_getDifficultyText(recipe.difficulty)}\n";
       });
       
       if (favoriteRecipes.length > 5) {
         response += "• ... y ${favoriteRecipes.length - 5} recetas más\n";
       }
       
       response += "\n";
     }
     
     // Análisis de favoritos
     final analysis = _analyzeFavorites(favoriteProducts, favoriteRecipes);
     if (analysis.isNotEmpty) {
       response += "📊 **Análisis de tus preferencias**:\n";
       analysis.forEach((key, value) {
         response += "• $key: $value\n";
       });
       response += "\n";
     }
     
     // Sugerencias basadas en favoritos
     response += "💡 **Sugerencias basadas en tus favoritos**:\n";
     
     if (favoriteProducts.isNotEmpty) {
       response += "• Crear lista de compras automática con tus productos favoritos\n";
     }
     
     if (favoriteRecipes.isNotEmpty) {
       response += "• Generar plan de comidas priorizando tus recetas favoritas\n";
       response += "• Buscar recetas similares a las que te gustan\n";
     }
     
     if (favoriteProducts.isNotEmpty && favoriteRecipes.isNotEmpty) {
       response += "• Sugerir recetas que usen tus productos favoritos\n";
     }
     
     response += "\n¿Te gustaría que implemente alguna de estas sugerencias?";

     return ChatMessage.createBotMessage(
       response,
       type: MessageType.action,
       metadata: {
         'actionType': 'favorites_overview',
         'actionData': {
           'favoriteProductsCount': favoriteProducts.length,
           'favoriteRecipesCount': favoriteRecipes.length,
           'analysis': analysis,
           'products': favoriteProducts.take(10).map((p) => p.toMap()).toList(),
           'recipes': favoriteRecipes.take(10).map((r) => r.toMap()).toList(),
         },
       },
     );
   } catch (e) {
     return ChatMessage.createBotMessage(
       "No pude acceder a tus favoritos en este momento. ¿Quieres que lo intente de nuevo?",
     );
   }
 }

 Map<String, String> _analyzeFavorites(List<Product> favoriteProducts, List<Recipe> favoriteRecipes) {
   final analysis = <String, String>{};
   
   // Análisis de productos favoritos
   if (favoriteProducts.isNotEmpty) {
     final categoryCount = <String, int>{};
     for (final product in favoriteProducts) {
       categoryCount[product.category] = (categoryCount[product.category] ?? 0) + 1;
     }
     
     final topCategory = categoryCount.entries
         .reduce((a, b) => a.value > b.value ? a : b).key;
     analysis['Categoría de productos preferida'] = topCategory;
     
     final locationCount = <String, int>{};
     for (final product in favoriteProducts) {
       locationCount[product.location] = (locationCount[product.location] ?? 0) + 1;
     }
     
     final topLocation = locationCount.entries
         .reduce((a, b) => a.value > b.value ? a : b).key;
     analysis['Ubicación más usada'] = topLocation;
   }
   
   // Análisis de recetas favoritas
   if (favoriteRecipes.isNotEmpty) {
     final difficultyCount = <String, int>{};
     final avgCookingTime = favoriteRecipes
         .map((r) => r.cookingTime)
         .reduce((a, b) => a + b) / favoriteRecipes.length;
     
     for (final recipe in favoriteRecipes) {
       final difficulty = _getDifficultyText(recipe.difficulty);
       difficultyCount[difficulty] = (difficultyCount[difficulty] ?? 0) + 1;
     }
     
     if (difficultyCount.isNotEmpty) {
       final preferredDifficulty = difficultyCount.entries
           .reduce((a, b) => a.value > b.value ? a : b).key;
       analysis['Dificultad de recetas preferida'] = preferredDifficulty;
     }
     
     analysis['Tiempo promedio de cocción'] = '${avgCookingTime.round()} minutos';
     
     // Análisis de categorías de recetas
     final recipeCategoryCount = <String, int>{};
     for (final recipe in favoriteRecipes) {
       for (final category in recipe.categories) {
         recipeCategoryCount[category] = (recipeCategoryCount[category] ?? 0) + 1;
       }
     }
     
     if (recipeCategoryCount.isNotEmpty) {
       final topRecipeCategory = recipeCategoryCount.entries
           .reduce((a, b) => a.value > b.value ? a : b).key;
       analysis['Tipo de cocina favorita'] = topRecipeCategory;
     }
   }
   
   return analysis;
 }

 // === FUNCIONES DE UTILIDAD Y HELPERS ===

 String? _extractProductName(String text) {
   final lowerText = text.toLowerCase();
   
   // Patrones para extraer nombres de productos
   final patterns = [
     RegExp(r'(?:marcar|completar|comprado|compré|ya tengo)\s+(?:el\s+|la\s+|los\s+|las\s+)?([a-záéíóúñü\s]+?)(?:\s+como\s+|$)'),
     RegExp(r'(?:ya\s+)?(?:compré|tengo)\s+(?:el\s+|la\s+|los\s+|las\s+)?([a-záéíóúñü\s]+)'),
     RegExp(r'\b([a-záéíóúñü]{3,}(?:\s+[a-záéíóúñü]+)*)\b'),
   ];
   
   for (final pattern in patterns) {
     final match = pattern.firstMatch(lowerText);
     if (match != null) {
       final productName = match.group(1)?.trim();
       if (productName != null && productName.length > 2) {
         // Limpiar palabras comunes
         return _cleanProductName(productName);
       }
     }
   }
   
   return null;
 }

 // === FUNCIÓN PARA MANEJAR MÚLTIPLES ACCIONES ===

 Future<ChatMessage> _handleMultipleActions(String userText) async {
   // Detectar si el usuario quiere hacer múltiples cosas
   final lowerText = userText.toLowerCase();
   
   if (lowerText.contains(' y ') || lowerText.contains(', ')) {
     // Dividir las acciones
     final actions = _splitMultipleActions(userText);
     
     if (actions.length > 1) {
       String response = "Entiendo que quieres hacer varias cosas:\n\n";
       
       for (int i = 0; i < actions.length; i++) {
         response += "${i + 1}. ${actions[i]}\n";
       }
       
       response += "\n¿Te gustaría que las haga una por una o prefieres empezar con alguna específica?";
       
       return ChatMessage.createBotMessage(
         response,
         type: MessageType.action,
         metadata: {
           'actionType': 'multiple_actions_detected',
           'actionData': {
             'actions': actions,
             'originalText': userText,
           },
         },
       );
     }
   }
   
   // Si no son múltiples acciones, procesar normalmente
   return await _handleUnknownQuery(userText);
 }

 List<String> _splitMultipleActions(String text) {
   // Dividir por conectores comunes
   final connectors = [' y ', ', ', ' después ', ' luego ', ' también '];
   
   List<String> actions = [text];
   
   for (final connector in connectors) {
     final newActions = <String>[];
     for (final action in actions) {
       if (action.toLowerCase().contains(connector)) {
         newActions.addAll(action.split(connector).map((s) => s.trim()));
       } else {
         newActions.add(action);
       }
     }
     actions = newActions;
   }
   
   // Filtrar acciones vacías o muy cortas
   return actions.where((action) => action.length > 3).toList();
 }

 // === GESTIÓN DE ESTADO Y PERSISTENCIA ===

 Future<void> _saveUserPreferences() async {
   try {
     final userId = _userId;
     if (userId == null) return;
     
     await _firestore
         .collection('users')
         .doc(userId)
         .collection('preferences')
         .doc('chat_preferences')
         .set(_userPreferences);
   } catch (e) {
     print('Error guardando preferencias: $e');
   }
 }

 Future<void> _loadUserPreferences() async {
   try {
     final userId = _userId;
     if (userId == null) return;
     
     final doc = await _firestore
         .collection('users')
         .doc(userId)
         .collection('preferences')
         .doc('chat_preferences')
         .get();
     
     if (doc.exists) {
       _userPreferences = doc.data() ?? {};
     }
   } catch (e) {
     print('Error cargando preferencias: $e');
   }
 }

 // === MÉTODO DE INICIALIZACIÓN ===

 Future<void> initialize() async {
   try {
     await _loadUserPreferences();
     await _updateCache();
     print('EnhancedChatService inicializado correctamente');
   } catch (e) {
     print('Error inicializando EnhancedChatService: $e');
   }
 }

 // === MÉTODO DE LIMPIEZA ===

 void dispose() {
   _conversationContext.clear();
   _recentConversation.clear();
   _userPreferences.clear();
   _cachedInventory.clear();
   _cachedRecipes.clear();
   _cachedShoppingList.clear();
 }

 // === MÉTODOS DE DEBUGGING Y TESTING ===

 Map<String, dynamic> getDebugInfo() {
   return {
     'conversationContext': _conversationContext,
     'recentConversation': _recentConversation,
     'userPreferences': _userPreferences,
     'cacheStatus': {
       'inventoryCache': _cachedInventory.keys.toList(),
       'recipesCache': _cachedRecipes.keys.toList(),
       'shoppingListCache': _cachedShoppingList.keys.toList(),
       'lastCacheUpdate': _lastCacheUpdate.toIso8601String(),
     },
     'lastInteraction': _lastInteraction.toIso8601String(),
   };
 }

 Future<Map<String, dynamic>> runDiagnostics() async {
   final diagnostics = <String, dynamic>{};
   
   try {
     // Test de conectividad con servicios
     diagnostics['inventoryService'] = await _inventoryService.getAllProducts().then((_) => 'OK').catchError((_) => 'ERROR');
     diagnostics['recipeService'] = await _recipeService.getAllRecipes().then((_) => 'OK').catchError((_) => 'ERROR');
     diagnostics['shoppingListService'] = await _shoppingListService.getShoppingList().then((_) => 'OK').catchError((_) => 'ERROR');
     diagnostics['geminiService'] = await _geminiService.testGeminiConnection().then((connected) => connected ? 'OK' : 'DISCONNECTED');
     
     // Test de Firebase
     diagnostics['firebaseAuth'] = _userId != null ? 'OK' : 'NOT_AUTHENTICATED';
     diagnostics['firestore'] = _userMessages != null ? 'OK' : 'ERROR';
     
     // Estado del cache
     diagnostics['cacheHealth'] = {
       'inventoryCache': _cachedInventory.isNotEmpty ? 'LOADED' : 'EMPTY',
       'recipesCache': _cachedRecipes.isNotEmpty ? 'LOADED' : 'EMPTY',
       'shoppingListCache': _cachedShoppingList.isNotEmpty ? 'LOADED' : 'EMPTY',
       'cacheAge': DateTime.now().difference(_lastCacheUpdate).inMinutes,
     };
     
     diagnostics['overallStatus'] = 'HEALTHY';
   } catch (e) {
     diagnostics['overallStatus'] = 'ERROR';
     diagnostics['error'] = e.toString();
   }
   
   return diagnostics;
 }
}