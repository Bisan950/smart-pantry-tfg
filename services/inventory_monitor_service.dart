// lib/services/inventory_monitor_service.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/product_location_model.dart';
import '../services/inventory_service.dart';
import '../services/notification_service.dart';
import '../services/expiry_settings_service.dart';

class InventoryMonitorService {
  // Singleton
  static final InventoryMonitorService _instance = InventoryMonitorService._internal();
  factory InventoryMonitorService() => _instance;
  InventoryMonitorService._internal();

  // Servicios
  final InventoryService _inventoryService = InventoryService();
  final NotificationService _notificationService = NotificationService();
  final ExpirySettingsService _expirySettingsService = ExpirySettingsService();

  // Streams y timers
  StreamSubscription<List<Product>>? _inventorySubscription;
  Timer? _periodicCheckTimer;
  
  // Control de estado
  bool _isMonitoring = false;
  DateTime? _lastExpiryCheck;
  DateTime? _lastStockCheck;
  List<String> _notifiedExpiredProducts = [];
  List<String> _notifiedLowStockProducts = [];

  // Inicializar el servicio de monitoreo
  Future<void> initialize() async {
    if (_isMonitoring) return;
    
    await _notificationService.initialize();
    
    // Cargar productos ya notificados para evitar spam
    await _loadNotifiedProducts();
    
    // Iniciar monitoreo en tiempo real
    _startRealtimeMonitoring();
    
    // Iniciar verificaciones periódicas
    _startPeriodicChecks();
    
    _isMonitoring = true;
    print('✅ InventoryMonitorService inicializado');
  }

  // Detener el servicio de monitoreo
  Future<void> dispose() async {
    await _inventorySubscription?.cancel();
    _periodicCheckTimer?.cancel();
    
    _isMonitoring = false;
    print('🛑 InventoryMonitorService detenido');
  }

  // Iniciar monitoreo en tiempo real del inventario
  void _startRealtimeMonitoring() {
    _inventorySubscription = _inventoryService.getProductsStream().listen(
      (products) => _analyzeInventoryChanges(products),
      onError: (error) => print('Error en monitoreo en tiempo real: $error'),
    );
  }

  // Iniciar verificaciones periódicas (cada 2 horas)
  void _startPeriodicChecks() {
    _periodicCheckTimer = Timer.periodic(
      const Duration(hours: 2),
      (_) => _performPeriodicCheck(),
    );
  }

  // Analizar cambios en el inventario
  Future<void> _analyzeInventoryChanges(List<Product> products) async {
    final now = DateTime.now();
    
    // Filtrar productos del inventario
    final inventoryProducts = products.where((product) =>
      product.productLocation == ProductLocation.inventory ||
      product.productLocation == ProductLocation.both
    ).toList();

    // Verificar caducidad si han pasado más de 4 horas desde la última verificación
    if (_lastExpiryCheck == null || 
        now.difference(_lastExpiryCheck!).inHours >= 4) {
      await _checkExpiryNotifications(inventoryProducts);
      _lastExpiryCheck = now;
    }

    // Verificar stock bajo si han pasado más de 6 horas desde la última verificación
    if (_lastStockCheck == null || 
        now.difference(_lastStockCheck!).inHours >= 6) {
      await _checkLowStockNotifications(inventoryProducts);
      _lastStockCheck = now;
    }

    // Verificar oportunidades de recetas
    await _checkRecipeOpportunities(inventoryProducts);
  }

  // Verificar productos próximos a caducar
  Future<void> _checkExpiryNotifications(List<Product> products) async {
    try {
      final settings = await _expirySettingsService.getSettings();
      
      if (!settings.notificationsEnabled) return;

      final prefs = await SharedPreferences.getInstance();
      final expiryNotifications = prefs.getBool('expiry_notifications') ?? true;
      
      if (!expiryNotifications) return;

      // Productos próximos a caducar
      final expiringProducts = products.where((product) {
        return product.expiryDate != null &&
               product.daysUntilExpiry >= 0 &&
               product.daysUntilExpiry <= settings.warningDays;
      }).toList();

      // Productos críticos (muy próximos a caducar)
      final criticalProducts = expiringProducts.where((product) {
        return product.daysUntilExpiry <= settings.criticalDays &&
               !_notifiedExpiredProducts.contains(product.id);
      }).toList();

      if (criticalProducts.isNotEmpty) {
        await _sendExpiryNotifications(criticalProducts, settings.criticalDays);
        
        // Marcar como notificados
        _notifiedExpiredProducts.addAll(criticalProducts.map((p) => p.id));
        await _saveNotifiedProducts();
      }

      // Limpiar productos notificados que ya no están próximos a caducar
      _cleanupNotifiedExpiredProducts(products);

    } catch (e) {
      print('Error al verificar notificaciones de caducidad: $e');
    }
  }

  // Verificar productos con stock bajo
  Future<void> _checkLowStockNotifications(List<Product> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stockNotifications = prefs.getBool('stock_notifications') ?? true;
      
      if (!stockNotifications) return;

      // Productos con stock crítico que no han sido notificados
      final criticalStockProducts = products.where((product) {
        return product.hasCriticalStock() &&
               !_notifiedLowStockProducts.contains(product.id);
      }).toList();

      if (criticalStockProducts.isNotEmpty) {
        await _sendLowStockNotifications(criticalStockProducts);
        
        // Marcar como notificados
        _notifiedLowStockProducts.addAll(criticalStockProducts.map((p) => p.id));
        await _saveNotifiedProducts();
      }

      // Limpiar productos notificados que ya no tienen stock bajo
      _cleanupNotifiedLowStockProducts(products);

    } catch (e) {
      print('Error al verificar notificaciones de stock bajo: $e');
    }
  }

  // Verificar oportunidades de recetas
  Future<void> _checkRecipeOpportunities(List<Product> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recipeSuggestions = prefs.getBool('recipe_suggestions') ?? false;
      
      if (!recipeSuggestions) return;

      // Solo verificar sugerencias de recetas una vez al día
      final lastRecipeCheck = prefs.getString('last_recipe_suggestion_date');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      if (lastRecipeCheck == today) return;

      // Buscar productos que caducan en 2-3 días (perfectos para usar)
      final productsToUse = products.where((product) {
        return product.expiryDate != null &&
               product.daysUntilExpiry >= 2 &&
               product.daysUntilExpiry <= 3;
      }).toList();

      if (productsToUse.length >= 2) {
        await _sendRecipeSuggestion(productsToUse);
        await prefs.setString('last_recipe_suggestion_date', today);
      }

    } catch (e) {
      print('Error al verificar oportunidades de recetas: $e');
    }
  }

  // Realizar verificación periódica completa
  Future<void> _performPeriodicCheck() async {
    try {
      print('🔍 Realizando verificación periódica del inventario...');
      
      final products = await _inventoryService.getAllProducts();
      await _analyzeInventoryChanges(products);
      
      // Verificar recordatorios programados
      await _checkScheduledReminders();
      
      print('✅ Verificación periódica completada');
    } catch (e) {
      print('Error en verificación periódica: $e');
    }
  }

  // Verificar recordatorios programados
  Future<void> _checkScheduledReminders() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    // Recordatorio de compras (domingos a las 10:00)
    if (now.weekday == 7 && now.hour == 10) {
      final lastShoppingReminder = prefs.getString('last_shopping_reminder_date');
      final today = now.toIso8601String().substring(0, 10);
      
      if (lastShoppingReminder != today) {
        final shoppingReminders = prefs.getBool('shopping_reminders') ?? true;
        if (shoppingReminders) {
          await _sendShoppingReminder();
          await prefs.setString('last_shopping_reminder_date', today);
        }
      }
    }

    // Recordatorio de planificación de comidas (domingos a las 18:00)
    if (now.weekday == 7 && now.hour == 18) {
      final lastMealPlanReminder = prefs.getString('last_meal_plan_reminder_date');
      final today = now.toIso8601String().substring(0, 10);
      
      if (lastMealPlanReminder != today) {
        final mealPlanReminders = prefs.getBool('meal_plan_reminders') ?? true;
        if (mealPlanReminders) {
          await _sendMealPlanReminder();
          await prefs.setString('last_meal_plan_reminder_date', today);
        }
      }
    }
  }

  // MÉTODOS PARA ENVIAR NOTIFICACIONES

  Future<void> _sendExpiryNotifications(List<Product> products, int criticalDays) async {
    if (products.length == 1) {
      final product = products.first;
      await _notificationService.sendCustomReminder(
        '⚠️ Producto por Caducar',
        '${product.name} caduca en ${product.daysUntilExpiry} día${product.daysUntilExpiry == 1 ? '' : 's'}',
        payload: 'expiry_single:${product.id}',
      );
    } else {
      final urgentCount = products.where((p) => p.daysUntilExpiry <= 1).length;
      String message;
      
      if (urgentCount > 0) {
        message = '$urgentCount producto${urgentCount == 1 ? '' : 's'} ${urgentCount == 1 ? 'caduca' : 'caducan'} hoy o mañana';
      } else {
        message = '${products.length} productos caducan en los próximos $criticalDays días';
      }
      
      await _notificationService.sendCustomReminder(
        '⚠️ Varios Productos por Caducar',
        message,
        payload: 'expiry_multiple:${products.length}',
      );
    }
  }

  Future<void> _sendLowStockNotifications(List<Product> products) async {
    if (products.length == 1) {
      final product = products.first;
      await _notificationService.sendCustomReminder(
        '📦 Stock Bajo',
        '${product.name} tiene stock crítico (${product.formattedQuantity()})',
        payload: 'low_stock_single:${product.id}',
      );
    } else {
      await _notificationService.sendCustomReminder(
        '📦 Varios Productos con Stock Bajo',
        '${products.length} productos necesitan reposición',
        payload: 'low_stock_multiple:${products.length}',
      );
    }
  }

  Future<void> _sendRecipeSuggestion(List<Product> products) async {
    final productNames = products.take(3).map((p) => p.name).toList();
    final ingredients = productNames.join(', ');
    
    await _notificationService.sendCustomReminder(
      '👨‍🍳 Sugerencia de Receta',
      'Tienes $ingredients que están por caducar. ¿Qué tal una receta?',
      payload: 'recipe_suggestion:${products.map((p) => p.id).join(',')}',
    );
  }

  Future<void> _sendShoppingReminder() async {
    await _notificationService.sendCustomReminder(
      '🛒 Recordatorio Semanal',
      '¿Ya revisaste tu lista de compras para esta semana?',
      payload: 'shopping_reminder',
    );
  }

  Future<void> _sendMealPlanReminder() async {
    await _notificationService.sendCustomReminder(
      '🍽️ Planifica tus Comidas',
      'Es un buen momento para planificar las comidas de esta semana',
      payload: 'meal_plan_reminder',
    );
  }

  // MÉTODOS DE UTILIDAD

  Future<void> _loadNotifiedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final expiredNotifications = prefs.getStringList('notified_expired_products') ?? [];
      final stockNotifications = prefs.getStringList('notified_low_stock_products') ?? [];
      
      _notifiedExpiredProducts = expiredNotifications;
      _notifiedLowStockProducts = stockNotifications;
      
    } catch (e) {
      print('Error al cargar productos notificados: $e');
    }
  }

  Future<void> _saveNotifiedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setStringList('notified_expired_products', _notifiedExpiredProducts);
      await prefs.setStringList('notified_low_stock_products', _notifiedLowStockProducts);
      
    } catch (e) {
      print('Error al guardar productos notificados: $e');
    }
  }

  void _cleanupNotifiedExpiredProducts(List<Product> currentProducts) {
    final currentProductIds = currentProducts.map((p) => p.id).toSet();
    
    // Remover productos que ya no existen o que ya no están próximos a caducar
    _notifiedExpiredProducts.removeWhere((productId) {
      if (!currentProductIds.contains(productId)) return true;
      
      final product = currentProducts.firstWhere((p) => p.id == productId);
      return product.daysUntilExpiry > 7 || product.daysUntilExpiry < 0;
    });
  }

  void _cleanupNotifiedLowStockProducts(List<Product> currentProducts) {
    final currentProductIds = currentProducts.map((p) => p.id).toSet();
    
    // Remover productos que ya no existen o que ya no tienen stock bajo
    _notifiedLowStockProducts.removeWhere((productId) {
      if (!currentProductIds.contains(productId)) return true;
      
      final product = currentProducts.firstWhere((p) => p.id == productId);
      return !product.hasCriticalStock();
    });
  }

  // MÉTODOS PÚBLICOS PARA CONTROL MANUAL

  // Forzar verificación inmediata
  Future<void> forceCheck() async {
    try {
      print('🔍 Forzando verificación inmediata...');
      
      final products = await _inventoryService.getAllProducts();
      await _analyzeInventoryChanges(products);
      
      print('✅ Verificación forzada completada');
    } catch (e) {
      print('Error en verificación forzada: $e');
    }
  }

  // Limpiar historial de notificaciones
  Future<void> clearNotificationHistory() async {
    _notifiedExpiredProducts.clear();
    _notifiedLowStockProducts.clear();
    await _saveNotifiedProducts();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_recipe_suggestion_date');
    await prefs.remove('last_shopping_reminder_date');
    await prefs.remove('last_meal_plan_reminder_date');
    
    print('🧹 Historial de notificaciones limpiado');
  }

  // Obtener estadísticas del monitor
  Map<String, dynamic> getMonitorStats() {
    return {
      'isMonitoring': _isMonitoring,
      'lastExpiryCheck': _lastExpiryCheck?.toIso8601String(),
      'lastStockCheck': _lastStockCheck?.toIso8601String(),
      'notifiedExpiredProducts': _notifiedExpiredProducts.length,
      'notifiedLowStockProducts': _notifiedLowStockProducts.length,
    };
  }

  // Verificar si un producto específico ha sido notificado
  bool isProductNotified(String productId, {required bool forExpiry}) {
    if (forExpiry) {
      return _notifiedExpiredProducts.contains(productId);
    } else {
      return _notifiedLowStockProducts.contains(productId);
    }
  }

  // Marcar un producto como notificado manualmente
  Future<void> markProductAsNotified(String productId, {required bool forExpiry}) async {
    if (forExpiry) {
      if (!_notifiedExpiredProducts.contains(productId)) {
        _notifiedExpiredProducts.add(productId);
      }
    } else {
      if (!_notifiedLowStockProducts.contains(productId)) {
        _notifiedLowStockProducts.add(productId);
      }
    }
    
    await _saveNotifiedProducts();
  }
}