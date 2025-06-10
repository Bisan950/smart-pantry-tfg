// lib/services/notification_service.dart - CON SOLICITUD AUTOMÁTICA DE PERMISOS

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; // NUEVO
import '../models/product_model.dart';
import '../models/product_location_model.dart';
import '../services/inventory_service.dart';
import '../services/expiry_settings_service.dart';

// Handler para tareas en background (SIN CAMBIOS)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case "checkExpiryNotifications":
        await _checkExpiryInBackground();
        break;
      case "checkLowStockNotifications":
        await _checkLowStockInBackground();
        break;
      case "sendShoppingReminder":
        await _sendShoppingReminderInBackground();
        break;
      case "sendMealPlanReminder":
        await _sendMealPlanReminderInBackground();
        break;
    }
    return Future.value(true);
  });
}

// Funciones auxiliares para background tasks (SIN CAMBIOS)
Future<void> _checkExpiryInBackground() async {
  try {
    final inventoryService = InventoryService();
    final expirySettingsService = ExpirySettingsService();
    final settings = await expirySettingsService.getSettings();
    
    if (!settings.notificationsEnabled) return;
    
    final products = await inventoryService.getExpiringProducts(settings.warningDays);
    final criticalProducts = products.where((p) => p.daysUntilExpiry <= settings.criticalDays).toList();
    
    if (criticalProducts.isNotEmpty) {
      await NotificationService()._showExpiryNotification(
        criticalProducts.length,
        criticalProducts.first.name,
        settings.criticalDays,
      );
    }
  } catch (e) {
    print('Error en verificación de caducidad en background: $e');
  }
}

Future<void> _checkLowStockInBackground() async {
  try {
    final inventoryService = InventoryService();
    final products = await inventoryService.getAllProducts();
    final lowStockProducts = products.where((p) => 
      (p.productLocation == ProductLocation.inventory || 
       p.productLocation == ProductLocation.both) && 
      p.hasLowStock()
    ).toList();
    
    if (lowStockProducts.isNotEmpty) {
      await NotificationService()._showLowStockNotification(lowStockProducts);
    }
  } catch (e) {
    print('Error en verificación de stock bajo en background: $e');
  }
}

Future<void> _sendShoppingReminderInBackground() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final shouldSendReminder = prefs.getBool('shopping_reminder_enabled') ?? true;
    
    if (shouldSendReminder) {
      await NotificationService()._showShoppingReminderNotification();
    }
  } catch (e) {
    print('Error en recordatorio de compras en background: $e');
  }
}

Future<void> _sendMealPlanReminderInBackground() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final shouldSendReminder = prefs.getBool('meal_plan_reminder_enabled') ?? true;
    
    if (shouldSendReminder) {
      await NotificationService()._showMealPlanReminderNotification();
    }
  } catch (e) {
    print('Error en recordatorio de planificación de comidas en background: $e');
  }
}

class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Plugins
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  bool _isInitialized = false;
  bool _permissionsRequested = false; // NUEVO: Control de permisos

  // Canales de notificación
  static const String _expiryChannelId = 'expiry_notifications';
  static const String _stockChannelId = 'stock_notifications';
  static const String _shoppingChannelId = 'shopping_reminders';
  static const String _mealPlanChannelId = 'meal_plan_reminders';
  static const String _recipeChannelId = 'recipe_suggestions';

  // NUEVO: Estados de permisos
  Map<String, bool> _permissionStatus = {
    'notifications': false,
    'battery_optimization': false,
    'exact_alarms': false,
    'ignore_battery': false,
  };

  // Inicialización completa del servicio
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🔄 Inicializando NotificationService...');

    // NUEVO: Solicitar permisos primero
    await _requestAllPermissions();
    
    // Configurar notificaciones locales
    await _initializeLocalNotifications();
    
    // Configurar Firebase Messaging
    await _initializeFirebaseMessaging();
    
    // Configurar WorkManager para tareas en background
    await _initializeBackgroundTasks();
    
    _isInitialized = true;
    print('✅ NotificationService inicializado completamente');
    
    // NUEVO: Mostrar resumen de permisos
    _logPermissionStatus();
  }

  // NUEVO: Solicitar todos los permisos necesarios
  Future<void> _requestAllPermissions() async {
    if (_permissionsRequested) return;
    
    print('🔐 Solicitando permisos para notificaciones...');
    
    try {
      // 1. Permisos básicos de notificaciones
      await _requestNotificationPermissions();
      
      // 2. Permisos específicos de Android
      if (Platform.isAndroid) {
        await _requestAndroidSpecificPermissions();
      }
      
      _permissionsRequested = true;
      print('✅ Solicitud de permisos completada');
      
    } catch (e) {
      print('❌ Error al solicitar permisos: $e');
    }
  }

  // NUEVO: Solicitar permisos básicos de notificaciones
  Future<void> _requestNotificationPermissions() async {
    try {
      // Permisos de notificaciones estándar
      final notificationStatus = await Permission.notification.request();
      _permissionStatus['notifications'] = notificationStatus.isGranted;
      
      print('📱 Permisos de notificación: ${notificationStatus.isGranted ? "✅ Concedido" : "❌ Denegado"}');
      
      if (notificationStatus.isDenied) {
        print('⚠️ Las notificaciones están deshabilitadas. Ve a Configuración para activarlas.');
      }
      
    } catch (e) {
      print('❌ Error al solicitar permisos de notificación: $e');
    }
  }

  // NUEVO: Solicitar permisos específicos de Android
  Future<void> _requestAndroidSpecificPermissions() async {
    try {
      // 1. Solicitar ignorar optimización de batería
      await _requestBatteryOptimizationPermission();
      
      // 2. Solicitar alarmas exactas (Android 12+)
      await _requestExactAlarmPermission();
      
      // 3. Verificar estado de optimización de batería
      await _checkBatteryOptimizationStatus();
      
    } catch (e) {
      print('❌ Error al solicitar permisos específicos de Android: $e');
    }
  }

  // NUEVO: Solicitar permiso para ignorar optimización de batería
  Future<void> _requestBatteryOptimizationPermission() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      
      if (status.isDenied) {
        print('🔋 Solicitando permiso para ignorar optimización de batería...');
        
        final result = await Permission.ignoreBatteryOptimizations.request();
        _permissionStatus['ignore_battery'] = result.isGranted;
        
        if (result.isGranted) {
          print('✅ Permiso de optimización de batería concedido');
        } else {
          print('⚠️ Permiso de optimización de batería denegado - las notificaciones pueden no funcionar con la app cerrada');
        }
      } else {
        _permissionStatus['ignore_battery'] = status.isGranted;
        print('✅ Optimización de batería ya configurada');
      }
      
    } catch (e) {
      print('❌ Error con optimización de batería: $e');
    }
  }

  // NUEVO: Solicitar permiso para alarmas exactas
  Future<void> _requestExactAlarmPermission() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.scheduleExactAlarm.status;
        
        if (status.isDenied) {
          print('⏰ Solicitando permiso para alarmas exactas...');
          
          final result = await Permission.scheduleExactAlarm.request();
          _permissionStatus['exact_alarms'] = result.isGranted;
          
          if (result.isGranted) {
            print('✅ Permiso de alarmas exactas concedido');
          } else {
            print('⚠️ Permiso de alarmas exactas denegado - los horarios pueden ser inexactos');
          }
        } else {
          _permissionStatus['exact_alarms'] = status.isGranted;
          print('✅ Alarmas exactas ya configuradas');
        }
      }
      
    } catch (e) {
      print('❌ Error con alarmas exactas: $e');
    }
  }

  // NUEVO: Verificar estado de optimización de batería
  Future<void> _checkBatteryOptimizationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt('last_battery_check') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Verificar cada 24 horas
      if (now - lastCheck > 86400000) {
        final isOptimized = await Permission.ignoreBatteryOptimizations.isGranted;
        _permissionStatus['battery_optimization'] = isOptimized;
        
        if (!isOptimized) {
          print('⚠️ La app está sujeta a optimización de batería');
          print('💡 Para mejores notificaciones, desactiva la optimización de batería para SmartPantry');
        } else {
          print('✅ Optimización de batería desactivada correctamente');
        }
        
        await prefs.setInt('last_battery_check', now);
      }
      
    } catch (e) {
      print('❌ Error al verificar optimización de batería: $e');
    }
  }

  // NUEVO: Mostrar resumen de permisos
  void _logPermissionStatus() {
    print('\n📊 RESUMEN DE PERMISOS:');
    print('├─ Notificaciones: ${_permissionStatus['notifications']! ? "✅" : "❌"}');
    print('├─ Optimización Batería: ${_permissionStatus['battery_optimization']! ? "✅" : "❌"}');
    print('├─ Alarmas Exactas: ${_permissionStatus['exact_alarms']! ? "✅" : "❌"}');
    print('└─ Ignorar Batería: ${_permissionStatus['ignore_battery']! ? "✅" : "❌"}');
    
    final allGranted = _permissionStatus.values.every((granted) => granted);
    if (allGranted) {
      print('🎉 TODOS LOS PERMISOS CONCEDIDOS - Notificaciones funcionarán óptimamente');
    } else {
      print('⚠️ ALGUNOS PERMISOS FALTANTES - Las notificaciones pueden no funcionar con la app cerrada');
    }
    print('');
  }

  // NUEVO: Método público para obtener estado de permisos
  Map<String, bool> getPermissionStatus() {
    return Map.from(_permissionStatus);
  }

  // NUEVO: Método público para solicitar permisos manualmente
  Future<void> requestPermissionsManually() async {
    _permissionsRequested = false; // Resetear para forzar nueva solicitud
    await _requestAllPermissions();
  }

  // NUEVO: Abrir configuración del sistema para permisos
  Future<void> openAppSettings() async {
    try {
      await openAppSettings();
      print('📱 Abriendo configuración de la app...');
    } catch (e) {
      print('❌ Error al abrir configuración: $e');
    }
  }

  // Inicializar notificaciones locales (SIN CAMBIOS IMPORTANTES)
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@android:drawable/ic_dialog_info');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannels();
  }

  // Crear canales de notificación (SIN CAMBIOS)
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      const List<AndroidNotificationChannel> channels = [
        AndroidNotificationChannel(
          _expiryChannelId,
          'Notificaciones de Caducidad',
          description: 'Alertas sobre productos próximos a caducar',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          _stockChannelId,
          'Notificaciones de Stock',
          description: 'Alertas sobre productos con stock bajo',
          importance: Importance.defaultImportance,
        ),
        AndroidNotificationChannel(
          _shoppingChannelId,
          'Recordatorios de Compras',
          description: 'Recordatorios para revisar la lista de compras',
          importance: Importance.defaultImportance,
        ),
        AndroidNotificationChannel(
          _mealPlanChannelId,
          'Recordatorios de Planificación',
          description: 'Recordatorios para planificar las comidas',
          importance: Importance.defaultImportance,
        ),
        AndroidNotificationChannel(
          _recipeChannelId,
          'Sugerencias de Recetas',
          description: 'Sugerencias de recetas basadas en tu inventario',
          importance: Importance.low,
        ),
      ];

      for (final channel in channels) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }
    }
  }

  // Inicializar Firebase Messaging (CON MEJORAS DE PERMISOS)
  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Solicitar permisos de Firebase
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Permisos de Firebase concedidos');
        
        // Obtener token FCM
        String? token = await _messaging.getToken();
        print('🔑 FCM Token: ${token?.substring(0, 20)}...');
        
        // Guardar token para uso futuro
        final prefs = await SharedPreferences.getInstance();
        if (token != null) {
          await prefs.setString('fcm_token', token);
        }
        
        // Manejar notificaciones
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
        
        // Verificar si la app se abrió desde una notificación
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }
      } else {
        print('❌ Permisos de Firebase denegados');
      }
    } catch (e) {
      print('❌ Error al inicializar Firebase Messaging: $e');
    }
  }

  // Inicializar WorkManager (CON VERIFICACIÓN DE PERMISOS)
  Future<void> _initializeBackgroundTasks() async {
    try {
      // Verificar si tenemos permisos para tareas en background
      if (!_permissionStatus['ignore_battery']!) {
        print('⚠️ Sin permisos de batería - las tareas en background pueden no funcionar correctamente');
      }
      
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      await _scheduleBackgroundTasks();
      print('✅ WorkManager inicializado');
    } catch (e) {
      print('❌ Error al inicializar WorkManager: $e');
    }
  }

  // Programar tareas en background (CON LOGGING MEJORADO)
  Future<void> _scheduleBackgroundTasks() async {
    try {
      print('📅 Programando tareas en background...');
      
      // Verificar caducidad cada 6 horas
      await Workmanager().registerPeriodicTask(
        "checkExpiryNotifications",
        "checkExpiryNotifications",
        frequency: const Duration(hours: 6),
        initialDelay: const Duration(minutes: 5),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
      print('✅ Tarea de caducidad programada (cada 6 horas)');

      // Verificar stock bajo cada 12 horas
      await Workmanager().registerPeriodicTask(
        "checkLowStockNotifications",
        "checkLowStockNotifications",
        frequency: const Duration(hours: 12),
        initialDelay: const Duration(minutes: 10),
      );
      print('✅ Tarea de stock bajo programada (cada 12 horas)');

      // Recordatorio de compras cada domingo
      await Workmanager().registerPeriodicTask(
        "sendShoppingReminder",
        "sendShoppingReminder",
        frequency: const Duration(days: 7),
        initialDelay: _getDelayUntilNextSunday(),
      );
      print('✅ Recordatorio de compras programado (domingos 10:00)');

      // Recordatorio de planificación cada domingo
      await Workmanager().registerPeriodicTask(
        "sendMealPlanReminder",
        "sendMealPlanReminder",
        frequency: const Duration(days: 7),
        initialDelay: _getDelayUntilNextSundayEvening(),
      );
      print('✅ Recordatorio de planificación programado (domingos 18:00)');
      
    } catch (e) {
      print('❌ Error al programar tareas: $e');
    }
  }

  // Métodos auxiliares para calcular delays (SIN CAMBIOS)
  Duration _getDelayUntilNextSunday() {
    final now = DateTime.now();
    final nextSunday = now.add(Duration(days: 7 - now.weekday));
    final sundayAt10 = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 10, 0);
    return sundayAt10.difference(now);
  }

  Duration _getDelayUntilNextSundayEvening() {
    final now = DateTime.now();
    final nextSunday = now.add(Duration(days: 7 - now.weekday));
    final sundayAt18 = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 18, 0);
    return sundayAt18.difference(now);
  }

  // Handlers de notificaciones (SIN CAMBIOS)
  void _handleForegroundMessage(RemoteMessage message) {
    print('📱 Notificación recibida en foreground: ${message.notification?.title}');
    _showLocalNotification(
      message.notification?.title ?? 'SmartPantry',
      message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('👆 Notificación Firebase tapped: ${message.data}');
    _navigateBasedOnNotificationType(message.data);
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Notificación local tapped: ${response.payload}');
    if (response.payload != null) {
      _navigateBasedOnPayload(response.payload!);
    }
  }

  void _navigateBasedOnNotificationType(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'expiry':
        // Navegar a pantalla de control de caducidad
        break;
      case 'low_stock':
        // Navegar a pantalla de inventario
        break;
      case 'shopping_reminder':
        // Navegar a lista de compras
        break;
      case 'meal_plan_reminder':
        // Navegar a planificador de comidas
        break;
    }
  }

  void _navigateBasedOnPayload(String payload) {
    print('🧭 Navigating based on payload: $payload');
  }

  // MÉTODOS PÚBLICOS PARA ENVIAR NOTIFICACIONES (SIN CAMBIOS IMPORTANTES)

  Future<void> checkAndSendExpiryNotifications(List<Product> products) async {
    await initialize();

    final expirySettingsService = ExpirySettingsService();
    final settings = await expirySettingsService.getSettings();

    if (!settings.notificationsEnabled) return;

    final criticalProducts = products.where(
      (product) => (product.productLocation == ProductLocation.inventory ||
                    product.productLocation == ProductLocation.both) &&
                   product.daysUntilExpiry >= 0 &&
                   product.daysUntilExpiry <= settings.criticalDays
    ).toList();

    if (criticalProducts.isNotEmpty) {
      await _showExpiryNotification(
        criticalProducts.length,
        criticalProducts.first.name,
        settings.criticalDays,
      );
    }
  }

  Future<void> checkAndSendLowStockNotifications(List<Product> products) async {
    await initialize();

    final lowStockProducts = products.where((product) =>
      (product.productLocation == ProductLocation.inventory ||
       product.productLocation == ProductLocation.both) &&
      product.hasLowStock()
    ).toList();

    if (lowStockProducts.isNotEmpty) {
      await _showLowStockNotification(lowStockProducts);
    }
  }

  Future<void> sendRecipeSuggestion(String recipeName, List<String> ingredients) async {
    await initialize();
    await _showRecipeSuggestionNotification(recipeName, ingredients);
  }

  Future<void> sendCustomReminder(String title, String message, {String? payload}) async {
    await initialize();
    await _showLocalNotification(title, message, payload: payload);
  }

  // MÉTODOS PRIVADOS PARA MOSTRAR NOTIFICACIONES (SIN CAMBIOS)

  Future<void> _showExpiryNotification(int productCount, String firstProductName, int days) async {
    String message;
    if (productCount == 1) {
      message = "$firstProductName caduca en $days días.";
    } else {
      message = "$firstProductName y ${productCount - 1} productos más están por caducar.";
    }

    await _showLocalNotification(
      '⚠️ Alerta de Caducidad',
      message,
      channelId: _expiryChannelId,
      payload: 'expiry_alert',
    );
  }

  Future<void> _showLowStockNotification(List<Product> products) async {
    String message;
    if (products.length == 1) {
      message = "${products.first.name} tiene stock bajo.";
    } else {
      message = "${products.length} productos tienen stock bajo.";
    }

    await _showLocalNotification(
      '📦 Stock Bajo',
      message,
      channelId: _stockChannelId,
      payload: 'low_stock_alert',
    );
  }

  Future<void> _showShoppingReminderNotification() async {
    await _showLocalNotification(
      '🛒 Recordatorio de Compras',
      '¿Ya revisaste tu lista de compras para esta semana?',
      channelId: _shoppingChannelId,
      payload: 'shopping_reminder',
    );
  }

  Future<void> _showMealPlanReminderNotification() async {
    await _showLocalNotification(
      '🍽️ Planifica tus Comidas',
      '¿Qué tal si planificas las comidas de esta semana?',
      channelId: _mealPlanChannelId,
      payload: 'meal_plan_reminder',
    );
  }

  Future<void> _showRecipeSuggestionNotification(String recipeName, List<String> ingredients) async {
    final ingredientsList = ingredients.take(3).join(', ');
    final moreIngredients = ingredients.length > 3 ? ' y más' : '';
    
    await _showLocalNotification(
      '👨‍🍳 Sugerencia de Receta',
      'Puedes hacer $recipeName con $ingredientsList$moreIngredients',
      channelId: _recipeChannelId,
      payload: 'recipe_suggestion:$recipeName',
    );
  }

  // Método genérico para mostrar notificaciones locales (SIN CAMBIOS)
  Future<void> _showLocalNotification(
    String title,
    String body, {
    String? channelId,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId ?? _expiryChannelId,
      channelId == _expiryChannelId ? 'Notificaciones de Caducidad' :
      channelId == _stockChannelId ? 'Notificaciones de Stock' :
      channelId == _shoppingChannelId ? 'Recordatorios de Compras' :
      channelId == _mealPlanChannelId ? 'Recordatorios de Planificación' :
      'Sugerencias de Recetas',
      importance: channelId == _expiryChannelId ? Importance.high : Importance.defaultImportance,
      priority: channelId == _expiryChannelId ? Priority.high : Priority.defaultPriority,
      styleInformation: const BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Métodos de control (MEJORADOS)
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    print('🗑️ Todas las notificaciones canceladas');
  }

  Future<void> enableNotifications(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enable);
    
    if (enable) {
      await _scheduleBackgroundTasks();
      print('✅ Notificaciones habilitadas y tareas programadas');
    } else {
      await Workmanager().cancelAll();
      print('❌ Notificaciones deshabilitadas y tareas canceladas');
    }
  }

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  // NUEVO: Método para verificar si todos los permisos están concedidos
  bool get hasAllPermissions {
    return _permissionStatus.values.every((granted) => granted);
  }

  // NUEVO: Método para obtener recomendaciones de configuración
  List<String> getConfigurationRecommendations() {
    final recommendations = <String>[];
    
    if (!_permissionStatus['notifications']!) {
      recommendations.add('Activar notificaciones en Configuración > Apps > SmartPantry');
    }
    
    if (!_permissionStatus['ignore_battery']!) {
      recommendations.add('Desactivar optimización de batería para SmartPantry');
    }
    
    if (!_permissionStatus['exact_alarms']!) {
      recommendations.add('Permitir alarmas exactas para horarios precisos');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('✅ Configuración óptima - las notificaciones funcionarán correctamente');
    }
    
    return recommendations;
  }
}