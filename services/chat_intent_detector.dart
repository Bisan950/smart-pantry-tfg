import 'dart:convert';
import '../models/chat_intent.dart';
import 'gemini_ai_service.dart';

class ChatIntentDetector {
  final GeminiAIService _geminiService = GeminiAIService();
  
  // Patrones de intención predefinidos
  final Map<String, List<RegExp>> _intentPatterns = {
    'greeting': [
      RegExp(r'\b(hola|hey|saludos|buenos días|buenas tardes)\b', caseSensitive: false),
      RegExp(r'\b(hi|hello|good morning)\b', caseSensitive: false),
    ],
    'help': [
      RegExp(r'\b(ayuda|help|ayúdame|qué puedes hacer)\b', caseSensitive: false),
    ],
    'inventory_query': [
      RegExp(r'\b(inventario|stock|productos|qué tengo)\b', caseSensitive: false),
    ],
    'recipe_request': [
      RegExp(r'\b(receta|cocinar|preparar|qué puedo hacer)\b', caseSensitive: false),
    ],
    'shopping_list': [
      RegExp(r'\b(lista de compras|comprar|necesito)\b', caseSensitive: false),
    ],
    'meal_planning': [
      RegExp(r'\b(plan de comidas|planificar|menú semanal)\b', caseSensitive: false),
    ],
    'add_to_cart': [
      RegExp(r'\b(añadir|agregar|meter|poner).*(carrito|lista de compras)\b', caseSensitive: false),
      RegExp(r'\b(comprar|necesito comprar)\b', caseSensitive: false),
    ],
    'add_to_inventory': [
      RegExp(r'\b(añadir|agregar|meter|tengo).*(inventario|despensa|nevera)\b', caseSensitive: false),
      RegExp(r'\b(compré|he comprado|acabo de comprar)\b', caseSensitive: false),
    ],
    'remove_from_inventory': [
      RegExp(r'\b(quitar|eliminar|sacar|consumir).*(inventario|despensa)\b', caseSensitive: false),
      RegExp(r'\b(se acabó|terminé|consumí)\b', caseSensitive: false),
    ],
    'product_action': [
      RegExp(r'\b(producto|item|artículo)\s+\w+', caseSensitive: false),
    ],
  };

  Future<void> initialize() async {
    // Inicialización si es necesaria
  }

  Future<ChatIntent> detectIntent(String text, Map<String, dynamic> context) async {
    try {
      // 1. Detección rápida con patrones
      final quickIntent = _detectWithPatterns(text);
      if (quickIntent.confidence > 0.8) {
        return quickIntent;
      }

      // 2. Detección con IA para casos complejos
      final aiIntent = await _detectWithAI(text, context);
      
      // 3. Combinar resultados
      return _combineIntents(quickIntent, aiIntent);
    } catch (e) {
      // Fallback a detección básica
      return _detectWithPatterns(text);
    }
  }

  ChatIntent _detectWithPatterns(String text) {
    final lowerText = text.toLowerCase();
    
    for (final entry in _intentPatterns.entries) {
      final intentType = entry.key;
      final patterns = entry.value;
      
      for (final pattern in patterns) {
        if (pattern.hasMatch(lowerText)) {
          return ChatIntent(
            type: intentType,
            confidence: 0.9,
            entities: _extractEntities(text, intentType),
          );
        }
      }
    }
    
    return ChatIntent(
      type: 'unknown',
      confidence: 0.1,
      entities: {},
    );
  }

  Future<ChatIntent> _detectWithAI(String text, Map<String, dynamic> context) async {
    final prompt = '''
Analiza la siguiente consulta del usuario y determina su intención:

Texto: "$text"
Contexto previo: ${jsonEncode(context)}

Responde SOLO con un JSON válido:
{
  "intent": "tipo_de_intencion",
  "confidence": 0.95,
  "entities": {
    "key": "value"
  }
}

Tipos de intención válidos:
- greeting, help, inventory_query, recipe_request, shopping_list, meal_planning, product_info, unknown
''';

    try {
      final response = await _geminiService.generateText(prompt);
      final jsonResponse = jsonDecode(response);
      
      return ChatIntent(
        type: jsonResponse['intent'] ?? 'unknown',
        confidence: (jsonResponse['confidence'] ?? 0.5).toDouble(),
        entities: Map<String, dynamic>.from(jsonResponse['entities'] ?? {}),
      );
    } catch (e) {
      return ChatIntent(type: 'unknown', confidence: 0.1, entities: {});
    }
  }

  ChatIntent _combineIntents(ChatIntent pattern, ChatIntent ai) {
    if (pattern.confidence > ai.confidence) {
      return pattern;
    }
    return ai;
  }

  Map<String, dynamic> _extractEntities(String text, String intentType) {
    final entities = <String, dynamic>{};
    
    switch (intentType) {
      case 'recipe_request':
        // Extraer ingredientes mencionados
        final ingredients = _extractIngredients(text);
        if (ingredients.isNotEmpty) {
          entities['ingredients'] = ingredients;
        }
        break;
      case 'inventory_query':
        // Extraer productos específicos
        final products = _extractProducts(text);
        if (products.isNotEmpty) {
          entities['products'] = products;
        }
        break;
    }
    
    return entities;
  }

  List<String> _extractIngredients(String text) {
    // Implementar extracción de ingredientes
    return [];
  }

  List<String> _extractProducts(String text) {
    // Implementar extracción de productos
    return [];
  }
}