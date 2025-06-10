import '../models/chat_message_model.dart';
import '../models/chat_intent.dart';
import 'inventory_service.dart';
import 'recipe_service.dart';
import 'shopping_list_service.dart';
import 'meal_plan_service.dart';
import 'gemini_ai_service.dart';
import 'chat_action_service.dart'; // 🆕 Add this import

class ChatResponseGenerator {
  final InventoryService _inventoryService = InventoryService();
  final RecipeService _recipeService = RecipeService();
  final ShoppingListService _shoppingListService = ShoppingListService();
  final MealPlanService _mealPlanService = MealPlanService();
  final GeminiAIService _geminiService = GeminiAIService();
  final ChatActionService _actionService = ChatActionService();

  // 🆕 Add this initialize method
  Future<void> initialize() async {
    // Initialize any services that need initialization
    // Most services don't need explicit initialization, but we provide this method
    // to satisfy the interface expected by AIChatService
    try {
      // If any of the services need initialization, add them here
      // For now, this is just a placeholder
    } catch (e) {
      rethrow;
    }
  }

  Future<ChatMessage> generateResponse({
    required ChatIntent intent,
    required String userText,
    required Map<String, dynamic> context,
  }) async {
    try {
      switch (intent.type) {
        case 'greeting':
          return _handleGreeting(context);
        case 'help':
          return _handleHelp();
        case 'inventory_query':
          return await _handleInventoryQuery(intent, userText);
        case 'recipe_request':
          return await _handleRecipeRequest(intent, userText, context);
        case 'shopping_list':
          return await _handleShoppingList(intent, userText);
        case 'meal_planning':
          return await _handleMealPlanning(intent, userText);
        // 🆕 Nuevos casos para acciones
        case 'add_to_cart':
        case 'add_to_inventory':
        case 'remove_from_inventory':
          return await _actionService.processActionRequest(
            actionType: intent.type,
            userText: userText,
            context: context,
          );
        default:
          return await _handleUnknown(userText, context);
      }
    } catch (e) {
      return ChatMessage.createBotMessage(
        'Ha ocurrido un error procesando tu solicitud. ¿Podrías intentarlo de otra manera?'
      );
    }
  }

  ChatMessage _handleGreeting(Map<String, dynamic> context) {
    final hour = DateTime.now().hour;
    String greeting;
    
    if (hour < 12) {
      greeting = '¡Buenos días! 🌅';
    } else if (hour < 18) {
      greeting = '¡Buenas tardes! ☀️';
    } else {
      greeting = '¡Buenas noches! 🌙';
    }
    
    return ChatMessage.createBotMessage(
      '$greeting ¿En qué puedo ayudarte hoy con tu cocina inteligente?'
    );
  }

  ChatMessage _handleHelp() {
    return ChatMessage.createBotMessage(
      '''🤖 **Soy tu asistente de cocina inteligente**

**Puedo ayudarte con:**
• 📦 **Inventario**: "¿Qué tengo en mi despensa?"
• 🍳 **Recetas**: "¿Qué puedo cocinar con pollo?"
• 🛒 **Lista de compras**: "Añade leche a mi lista"
• 📅 **Planificación**: "Crea un menú para la semana"
• ⚠️ **Alertas**: "¿Qué productos caducan pronto?"

💬 **Habla conmigo de forma natural** - Entiendo el contexto y puedo mantener conversaciones complejas.

¿Qué te gustaría hacer?'''
    );
  }

  Future<ChatMessage> _handleInventoryQuery(ChatIntent intent, String userText) async {
    try {
      final products = await _inventoryService.getAllProducts();
      
      if (products.isEmpty) {
        return ChatMessage.createBotMessage(
          'Tu inventario está vacío. ¿Te gustaría que te ayude a añadir algunos productos?'
        );
      }

      final response = StringBuffer();
      response.writeln('📦 **Tu inventario actual:**\n');
      
      // Agrupar por categoría
      final byCategory = <String, List<dynamic>>{};
      for (final product in products) {
        byCategory.putIfAbsent(product.category, () => []).add(product);
      }
      
      for (final entry in byCategory.entries) {
        response.writeln('**${entry.key}:**');
        for (final product in entry.value.take(5)) {
          response.writeln('• ${product.name} (${product.quantity} ${product.unit})');
        }
        if (entry.value.length > 5) {
          response.writeln('• ... y ${entry.value.length - 5} más');
        }
        response.writeln();
      }
      
      response.writeln('💡 **¿Qué te gustaría hacer?**');
      response.writeln('• Ver productos que caducan pronto');
      response.writeln('• Buscar recetas con estos ingredientes');
      response.writeln('• Generar lista de compras');
      
      return ChatMessage.createBotMessage(response.toString());
    } catch (e) {
      return ChatMessage.createBotMessage(
        'No pude acceder a tu inventario en este momento. ¿Quieres que lo intente de nuevo?'
      );
    }
  }

  Future<ChatMessage> _handleRecipeRequest(ChatIntent intent, String userText, Map<String, dynamic> context) async {
    try {
      // Obtener ingredientes disponibles
      final availableProducts = await _inventoryService.getAllProducts();
      
      if (availableProducts.isEmpty) {
        return ChatMessage.createBotMessage(
          'No tienes productos en tu inventario. ¿Te gustaría que te sugiera algunas recetas populares?'
        );
      }

      // Generar recetas con IA
      final prompt = '''
Genera 3 recetas creativas y diferentes usando estos ingredientes disponibles:

${availableProducts.map((p) => '- ${p.name} (${p.quantity} ${p.unit})').join('\n')}

Consulta del usuario: "$userText"

Responde en formato markdown con:
- Nombre de la receta
- Tiempo de preparación
- Ingredientes necesarios
- Pasos de preparación
- Consejos adicionales

Sé creativo y práctico.''';

      final aiResponse = await _geminiService.generateText(prompt);
      
      return ChatMessage.createBotMessage(
        '🍳 **Recetas personalizadas para ti:**\n\n$aiResponse\n\n💡 ¿Te gusta alguna? ¡Puedo darte más detalles!'
      );
    } catch (e) {
      return ChatMessage.createBotMessage(
        'No pude generar recetas en este momento. ¿Te gustaría ver algunas recetas populares?'
      );
    }
  }

  Future<ChatMessage> _handleShoppingList(ChatIntent intent, String userText) async {
    try {
      final items = await _shoppingListService.getShoppingList();
      
      if (items.isEmpty) {
        return ChatMessage.createBotMessage(
          'Tu lista de compras está vacía. ¿Te gustaría que genere sugerencias basadas en tu inventario?'
        );
      }

      final response = StringBuffer();
      response.writeln('🛒 **Tu lista de compras:**\n');
      
      final pending = items.where((item) => !item.isPurchased).toList();
      final completed = items.where((item) => item.isPurchased).toList();
      
      if (pending.isNotEmpty) {
        response.writeln('**Pendientes:**');
        for (final item in pending) {
          response.writeln('• ${item.name} (${item.quantity} ${item.unit})');
        }
        response.writeln();
      }
      
      if (completed.isNotEmpty) {
        response.writeln('**Completados:**');
        for (final item in completed.take(3)) {
          response.writeln('✅ ${item.name}');
        }
        if (completed.length > 3) {
          response.writeln('✅ ... y ${completed.length - 3} más');
        }
      }
      
      return ChatMessage.createBotMessage(response.toString());
    } catch (e) {
      return ChatMessage.createBotMessage(
        'No pude acceder a tu lista de compras. ¿Quieres que lo intente de nuevo?'
      );
    }
  }

  Future<ChatMessage> _handleMealPlanning(ChatIntent intent, String userText) async {
    return ChatMessage.createBotMessage(
      '📅 **Planificación de comidas**\n\n¿Te gustaría que:\n• Genere un menú semanal personalizado\n• Cree un plan basado en tus productos actuales\n• Planifique comidas para una ocasión especial\n\n¡Dime qué prefieres!'
    );
  }

  Future<ChatMessage> _handleUnknown(String userText, Map<String, dynamic> context) async {
    // Usar IA para generar respuesta contextual
    final prompt = '''
El usuario dice: "$userText"
Contexto: ${context.toString()}

Genera una respuesta útil y amigable como asistente de cocina inteligente.
Si no entiendes la consulta, ofrece opciones específicas de ayuda.
Mantén un tono conversacional y profesional.''';

    try {
      final aiResponse = await _geminiService.generateText(prompt);
      return ChatMessage.createBotMessage(aiResponse);
    } catch (e) {
      return ChatMessage.createBotMessage(
        'No estoy seguro de cómo ayudarte con eso. ¿Podrías ser más específico?\n\n💡 **Puedo ayudarte con:**\n• Gestión de inventario\n• Recetas personalizadas\n• Lista de compras\n• Planificación de comidas'
      );
    }
  }
}