import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../models/product_model.dart';
import 'inventory_service.dart';
import 'shopping_list_service.dart';

class ChatActionService {
  final InventoryService _inventoryService = InventoryService();
  final ShoppingListService _shoppingListService = ShoppingListService();
  
  // Mapa para almacenar acciones pendientes de confirmación
  final Map<String, PendingAction> _pendingActions = {};

  Future<ChatMessage> processActionRequest({
    required String actionType,
    required String userText,
    required Map<String, dynamic> context,
  }) async {
    switch (actionType) {
      case 'add_to_cart':
        return await _handleAddToCartRequest(userText, context);
      case 'add_to_inventory':
        return await _handleAddToInventoryRequest(userText, context);
      case 'remove_from_inventory':
        return await _handleRemoveFromInventoryRequest(userText, context);
      default:
        return ChatMessage.createBotMessage('No entiendo qué acción quieres realizar.');
    }
  }

  Future<ChatMessage> _handleAddToCartRequest(String userText, Map<String, dynamic> context) async {
    // Extraer información del producto del texto
    final productInfo = await _extractProductInfo(userText);
    
    if (productInfo == null) {
      return ChatMessage.createBotMessage(
        '¿Qué producto quieres añadir al carrito? Por ejemplo: "Añadir 2 litros de leche al carrito"'
      );
    }

    // Crear acción pendiente
    final actionId = DateTime.now().millisecondsSinceEpoch.toString();
    _pendingActions[actionId] = PendingAction(
      id: actionId,
      type: 'add_to_cart',
      productInfo: productInfo,
      timestamp: DateTime.now(),
    );

    // Crear mensaje de confirmación
    return ChatMessage.createAction(
      '🛒 **Confirmar acción:**\n\n'
      '**Producto:** ${productInfo['name']}\n'
      '**Cantidad:** ${productInfo['quantity']} ${productInfo['unit'] ?? ''}\n'
      '**Acción:** Añadir al carrito\n\n'
      '¿Confirmas esta acción?',
      actionType: 'confirm_action',
      actionData: {
        'actionId': actionId,
        'preview': {
          'action': 'Añadir al carrito',
          'product': productInfo['name'],
          'quantity': '${productInfo['quantity']} ${productInfo['unit'] ?? ''}',
        }
      },
    );
  }

  Future<ChatMessage> _handleAddToInventoryRequest(String userText, Map<String, dynamic> context) async {
    final productInfo = await _extractProductInfo(userText);
    
    if (productInfo == null) {
      return ChatMessage.createBotMessage(
        '¿Qué producto quieres añadir al inventario? Por ejemplo: "Tengo 3 manzanas en la nevera"'
      );
    }

    final actionId = DateTime.now().millisecondsSinceEpoch.toString();
    _pendingActions[actionId] = PendingAction(
      id: actionId,
      type: 'add_to_inventory',
      productInfo: productInfo,
      timestamp: DateTime.now(),
    );

    return ChatMessage.createAction(
      '📦 **Confirmar acción:**\n\n'
      '**Producto:** ${productInfo['name']}\n'
      '**Cantidad:** ${productInfo['quantity']} ${productInfo['unit'] ?? ''}\n'
      '**Ubicación:** ${productInfo['location'] ?? 'Inventario general'}\n'
      '**Acción:** Añadir al inventario\n\n'
      '¿Confirmas esta acción?',
      actionType: 'confirm_action',
      actionData: {
        'actionId': actionId,
        'preview': {
          'action': 'Añadir al inventario',
          'product': productInfo['name'],
          'quantity': '${productInfo['quantity']} ${productInfo['unit'] ?? ''}',
          'location': productInfo['location'] ?? 'Inventario general',
        }
      },
    );
  }

  Future<ChatMessage> _handleRemoveFromInventoryRequest(String userText, Map<String, dynamic> context) async {
    final productInfo = await _extractProductInfo(userText);
    
    if (productInfo == null) {
      return ChatMessage.createBotMessage(
        '¿Qué producto quieres quitar del inventario? Por ejemplo: "Quitar 2 manzanas del inventario"'
      );
    }

    final actionId = DateTime.now().millisecondsSinceEpoch.toString();
    _pendingActions[actionId] = PendingAction(
      id: actionId,
      type: 'remove_from_inventory',
      productInfo: productInfo,
      timestamp: DateTime.now(),
    );

    return ChatMessage.createAction(
      '🗑️ **Confirmar acción:**\n\n'
      '**Producto:** ${productInfo['name']}\n'
      '**Cantidad:** ${productInfo['quantity']} ${productInfo['unit'] ?? ''}\n'
      '**Acción:** Quitar del inventario\n\n'
      '¿Confirmas esta acción?',
      actionType: 'confirm_action',
      actionData: {
        'actionId': actionId,
        'preview': {
          'action': 'Quitar del inventario',
          'product': productInfo['name'],
          'quantity': '${productInfo['quantity']} ${productInfo['unit'] ?? ''}',
        }
      },
    );
  }

  Future<ChatMessage> confirmAction(String actionId, bool confirmed) async {
    final action = _pendingActions[actionId];
    if (action == null) {
      return ChatMessage.createBotMessage('La acción ha expirado. Por favor, inténtalo de nuevo.');
    }

    if (!confirmed) {
      _pendingActions.remove(actionId);
      return ChatMessage.createBotMessage('Acción cancelada. ¿Hay algo más en lo que pueda ayudarte?');
    }

    // Ejecutar la acción
    try {
      switch (action.type) {
        case 'add_to_cart':
          await _executeAddToCart(action.productInfo);
          break;
        case 'add_to_inventory':
          await _executeAddToInventory(action.productInfo);
          break;
        case 'remove_from_inventory':
          await _executeRemoveFromInventory(action.productInfo);
          break;
      }

      _pendingActions.remove(actionId);
      return ChatMessage.createBotMessage(
        '✅ **Acción completada exitosamente!**\n\n'
        '${_getSuccessMessage(action.type, action.productInfo)}'
      );
    } catch (e) {
      _pendingActions.remove(actionId);
      return ChatMessage.createBotMessage(
        '❌ **Error al ejecutar la acción:**\n\n$e\n\n¿Quieres intentarlo de nuevo?'
      );
    }
  }

  Future<Map<String, dynamic>?> _extractProductInfo(String text) async {
    // Usar IA para extraer información del producto
    // Implementar lógica de extracción de entidades
    // Por ahora, implementación básica
    
    final patterns = [
      RegExp(r'(\d+)\s*(\w+)?\s*(?:de\s+)?(\w+(?:\s+\w+)*)', caseSensitive: false),
      RegExp(r'(\w+(?:\s+\w+)*)\s*(\d+)\s*(\w+)?', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return {
          'name': match.group(3) ?? match.group(1) ?? 'Producto',
          'quantity': int.tryParse(match.group(1) ?? match.group(2) ?? '1') ?? 1,
          'unit': match.group(2) ?? match.group(3) ?? 'unidad',
        };
      }
    }
    
    return null;
  }

  Future<void> _executeAddToCart(Map<String, dynamic> productInfo) async {
    final product = Product(
      id: '',
      name: productInfo['name'],
      quantity: productInfo['quantity'],
      unit: productInfo['unit'] ?? 'unidad',
      category: 'General',
      userId: 'current_user', // 🆕 Add required userId
      createdAt: DateTime.now(),
    );
    
    await _shoppingListService.addProductFromInventory(product);
  }

  Future<void> _executeAddToInventory(Map<String, dynamic> productInfo) async {
    final product = Product(
      id: '',
      name: productInfo['name'],
      quantity: productInfo['quantity'],
      unit: productInfo['unit'] ?? 'unidad',
      category: 'General',
      userId: 'current_user', // 🆕 Add required userId
      location: productInfo['location'] ?? 'Inventario general',
      createdAt: DateTime.now(),
    );
    
    await _inventoryService.addProduct(product);
  }

  Future<void> _executeRemoveFromInventory(Map<String, dynamic> productInfo) async {
    // Buscar producto en inventario y reducir cantidad o eliminar
    final products = await _inventoryService.getAllProducts();
    final matchingProduct = products.firstWhere(
      (p) => p.name.toLowerCase().contains(productInfo['name'].toLowerCase()),
      orElse: () => throw Exception('Producto no encontrado en el inventario'),
    );
    
    final newQuantity = matchingProduct.quantity - (productInfo['quantity'] as int);
    if (newQuantity <= 0) {
      await _inventoryService.deleteProduct(matchingProduct.id);
    } else {
      final updatedProduct = matchingProduct.copyWith(quantity: newQuantity);
      await _inventoryService.updateProduct(updatedProduct);
    }
  }

  String _getSuccessMessage(String actionType, Map<String, dynamic> productInfo) {
    switch (actionType) {
      case 'add_to_cart':
        return 'He añadido **${productInfo['name']}** (${productInfo['quantity']} ${productInfo['unit']}) a tu lista de compras.';
      case 'add_to_inventory':
        return 'He añadido **${productInfo['name']}** (${productInfo['quantity']} ${productInfo['unit']}) a tu inventario.';
      case 'remove_from_inventory':
        return 'He actualizado la cantidad de **${productInfo['name']}** en tu inventario.';
      default:
        return 'Acción completada.';
    }
  }
}

class PendingAction {
  final String id;
  final String type;
  final Map<String, dynamic> productInfo;
  final DateTime timestamp;

  PendingAction({
    required this.id,
    required this.type,
    required this.productInfo,
    required this.timestamp,
  });
}