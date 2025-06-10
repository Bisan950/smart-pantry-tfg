// lib/main.dart - ACTUALIZADO CON NOTIFICACIONES Y SHOPPING LIST 2.0 + PREFERENCIAS + THEME PROVIDER
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'app.dart'; // ✅ RESTAURADO: Importar app.dart
import 'firebase_options.dart';

// Providers - SIMPLIFICADOS POST-REFACTORIZACIÓN CON INTEGRACIÓN + PREFERENCIAS + THEME
import 'providers/auth_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/shopping_list_provider.dart'; // ✅ MANTENER - Unificado e Integrado
import 'providers/shopping_list_preferences_provider.dart'; // 🆕 NUEVO - Preferencias persistentes
import 'providers/meal_plan_provider.dart';
import 'providers/ai_chat_provider.dart'; // 🆕 AGREGAR - Nuevo provider de AI chat
import 'providers/theme_provider.dart'; // 🆕 NUEVO - Provider de tema
// import 'providers/chat_provider.dart'; // ❌ COMENTAR - Provider antiguo

// Servicios existentes
import 'services/auth_service.dart';
import 'services/inventory_service.dart';
import 'services/firestore_service.dart';
import 'services/barcode_service.dart';
import 'services/camera_service.dart';
import 'services/storage_service.dart';
import 'services/gemini_recipe_service.dart';
import 'services/meal_plan_service.dart';
import 'services/recipe_service.dart';
import 'services/notification_service.dart';

import 'services/shopping_list_service.dart';
// 🆕 SERVICIOS SHOPPING LIST 2.0 - Solo los que existen

// Utilidades
import 'utils/data_migration_util.dart';

// Handler para notificaciones en background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
  
  // Aquí puedes procesar la notificación en background
  // Por ejemplo, actualizar datos o mostrar una notificación local
}

// Método para inicializar todos los servicios - ACTUALIZADO
Future<void> initializeServices() async {
  // Servicios existentes
  final authService = AuthService();
  final firestoreService = FirestoreService();
  final inventoryService = InventoryService();
  final barcodeService = BarcodeService();
  final cameraService = CameraService();
  final storageService = StorageService();
  final geminiRecipeService = GeminiRecipeService();
  final mealPlanService = MealPlanService();
  final recipeService = RecipeService();
  final notificationService = NotificationService();
  
  // 🆕 SERVICIOS REFACTORIZADOS - Solo los que existen
  final shoppingListService = ShoppingListService(); // ✅ NUEVO - Reemplaza múltiples servicios
  
  // Inicializar servicios existentes
  await notificationService.initialize();
  await inventoryService.initialize();
  
  // 🆕 INICIALIZAR SERVICIOS REFACTORIZADOS
  try {
    print('🔧 Inicializando servicios Shopping List 2.0 refactorizados...');
    
    // Servicio principal unificado
    await shoppingListService.initialize();
    
    print('✅ Servicios Shopping List 2.0 refactorizados inicializados');
  } catch (e) {
    print('⚠️ Error inicializando servicios Shopping refactorizados: $e');
    // Continuar sin fallar la app
  }
  
  // Verificar estructura de datos
  if (authService.currentUser != null) {
    await firestoreService.ensureUserCollectionsExist();
    await _scheduleInitialNotificationCheck();
  }
  
  await Future.delayed(Duration.zero);
  print('✅ Todos los servicios inicializados correctamente');
}

// Programar verificación inicial de notificaciones
Future<void> _scheduleInitialNotificationCheck() async {
  try {
    final notificationService = NotificationService();
    final inventoryService = InventoryService();
    
    final products = await inventoryService.getAllProducts();
    await notificationService.checkAndSendExpiryNotifications(products);
    await notificationService.checkAndSendLowStockNotifications(products);
    
    print('✅ Verificación inicial de notificaciones completada');
  } catch (e) {
    print('Error en verificación inicial de notificaciones: $e');
  }
}

// 🆕 MIGRACIÓN DE DATOS PARA REFACTORIZACIÓN
Future<bool> checkAndExecuteRefactoringMigration() async {
  try {
    print('🔄 Verificando necesidad de migración por refactorización...');
    
    // Aquí podríamos agregar lógica específica para migrar datos
    // de enhanced_shopping_list_provider a shopping_list_provider si fuera necesario
    
    // Por ahora, solo verificar la migración general
    final migrationUtil = DataMigrationUtil();
    final needsMigration = await migrationUtil.needsMigration();
    
    if (needsMigration) {
      print('📦 Ejecutando migración de datos...');
      final success = await migrationUtil.migrateUserDataSilently();
      print('Resultado de migración: ${success ? "Exitoso" : "Fallido"}');
      return success;
    }
    
    print('✅ No se requiere migración');
    return true;
  } catch (e) {
    print('❌ Error en migración de refactorización: $e');
    return false;
  }
}

// Función separada para verificar sesión guardada como en la versión antigua
Future<bool> checkForSavedSession() async {
  try {
    print('🔍 Verificando sesión guardada...');
    final authService = AuthService();
    bool hasSession = await authService.hasActiveSession();
    print('📱 Sesión encontrada: $hasSession');
    return hasSession;
  } catch (e) {
    print('❌ Error verificando sesión: $e');
    return false;
  }
}

// En la función main, cambiar:
Future<void> cleanupCameraCache() async {
  try {
    final cameraService = CameraService();
    await cameraService.cleanupTemporaryFiles();
    print('✅ Limpieza de archivos temporales completada');
  } catch (e) {
    print('Error al limpiar archivos temporales: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar orientación
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Cargar variables de entorno
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Variables de entorno cargadas');
  } catch (e) {
    print('⚠️ Error cargando .env: $e');
  }
  
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Configurar handler de notificaciones en background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Usar la función separada como en la versión antigua
  bool hasSession = await checkForSavedSession();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // Add this line
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => ShoppingListProvider()),
        ChangeNotifierProvider(create: (_) => ShoppingListPreferencesProvider()),
        ChangeNotifierProvider(create: (_) => MealPlanProvider()),
        ChangeNotifierProvider(create: (_) => AIChatProvider()),
      ],
      child: MyApp(hasSession: hasSession),
    ),
  );
}

// 🆕 WRAPPER PARA INTEGRACIÓN DE PROVIDERS CON LA APP PRINCIPAL
class SmartPantryAppWrapper extends StatelessWidget {
  final bool hasSession;

  const SmartPantryAppWrapper({super.key, required this.hasSession});

  @override
  Widget build(BuildContext context) {
    return Consumer4<AuthProvider, InventoryProvider, ShoppingListProvider, ShoppingListPreferencesProvider>(
      builder: (context, authProvider, inventoryProvider, shoppingProvider, preferencesProvider, child) {
        // 🆕 MONITOREAR CAMBIOS EN INVENTARIO PARA SINCRONIZAR
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncProvidersIfNeeded(inventoryProvider, shoppingProvider);
        });

        // 🔧 CORREGIDO: Usar MyApp del archivo app.dart
        return MyApp(hasSession: hasSession);
      },
    );
  }

  /// 🆕 SINCRONIZAR PROVIDERS CUANDO SEA NECESARIO
  void _syncProvidersIfNeeded(InventoryProvider inventoryProvider, ShoppingListProvider shoppingProvider) {
    // Solo sincronizar si:
    // 1. El inventario no está cargando
    // 2. Hay productos en el inventario
    // 3. El shopping provider está inicializado
    if (!inventoryProvider.isLoading && 
        inventoryProvider.allProducts.isNotEmpty && 
        shoppingProvider.isInventoryLoaded == false) {
      
      print('🔄 Sincronización automática detectada - actualizando Shopping List');
      shoppingProvider.syncWithInventoryProvider(inventoryProvider.allProducts);
    }
  }
}

// === PANTALLAS DE MIGRACIÓN ACTUALIZADAS ===

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  _MigrationScreenState createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final DataMigrationUtil _migrationUtil = DataMigrationUtil();
  bool _migrationStarted = false;
  bool _isRefactoringMigration = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_migrationStarted) {
        _startMigration();
      }
    });
  }

  Future<void> _startMigration() async {
    if (_migrationStarted) return;
    
    setState(() {
      _migrationStarted = true;
      _isRefactoringMigration = true;
    });
    
    // Primero migración general
    bool success = await _migrationUtil.migrateUserData();
    
    // Luego migración específica de refactorización
    if (success) {
      success = await checkAndExecuteRefactoringMigration();
    }
    
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRefactoringMigration 
            ? 'Actualizando SmartPantry Shopping 2.0'
            : 'Actualizando SmartPantry'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.shopping_cart_rounded,
                  size: 64,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                _isRefactoringMigration 
                    ? 'Optimizando Sistema de Compras'
                    : 'Actualizando SmartPantry',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                _isRefactoringMigration
                    ? 'Mejorando la experiencia de compras inteligentes...'
                    : 'Migrando datos a la nueva versión...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              
              if (_isRefactoringMigration) ...[
                const Text(
                  '✨ Lista de compras unificada\n🤖 IA mejorada\n📊 Mejor tracking de precios\n🔄 Integración con inventario',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              StreamBuilder<MigrationStatus>(
                stream: _migrationUtil.migrationStatus,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                    );
                  }
                  
                  final status = snapshot.data!;
                  
                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: Colors.grey[200],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: status.progress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        status.statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(status.progress * 100).toInt()}% completado',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              if (!_migrationStarted) ...[
                ElevatedButton.icon(
                  onPressed: _startMigration,
                  icon: const Icon(Icons.upgrade_rounded),
                  label: const Text('Iniciar actualización'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/dashboard');
                  },
                  child: const Text('Saltar (solo para desarrollo)'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Por favor, no cierres la aplicación durante este proceso',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// 🆕 INICIALIZACIÓN POST-AUTENTICACIÓN ACTUALIZADA CON PREFERENCIAS
class PostAuthInitializer extends StatefulWidget {
  final Widget child;

  const PostAuthInitializer({super.key, required this.child});

  @override
  State<PostAuthInitializer> createState() => _PostAuthInitializerState();
}

class _PostAuthInitializerState extends State<PostAuthInitializer> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAfterAuth();
  }

  Future<void> _initializeAfterAuth() async {
    final authProvider = context.read<AuthProvider>();
    
    if (authProvider.isAuthenticated) {
      try {
        print('👤 Usuario autenticado - inicializando providers integrados con preferencias...');
        
        // 1. Inicializar preferencias primero (independiente)
        final preferencesProvider = context.read<ShoppingListPreferencesProvider>();
        // Las preferencias se inicializan automáticamente en el constructor
        
        // 2. Inicializar inventario
        final inventoryProvider = context.read<InventoryProvider>();
        await inventoryProvider.refreshData();
        
        // 3. Luego inicializar shopping list con datos del inventario
        final shoppingProvider = context.read<ShoppingListProvider>();
        await shoppingProvider.initialize();
        
        // 4. Sincronizar datos
        shoppingProvider.syncWithInventoryProvider(inventoryProvider.allProducts);
        
        print('✅ Providers integrados con preferencias inicializados correctamente');
        
        setState(() {
          _initialized = true;
        });
      } catch (e) {
        print('❌ Error inicializando providers integrados: $e');
        setState(() {
          _initialized = true; // Continuar aunque haya errores
        });
      }
    } else {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Consumer<ShoppingListPreferencesProvider>(
        builder: (context, prefsProvider, _) {
          return Scaffold(
            backgroundColor: prefsProvider.isInitialized 
              ? prefsProvider.theme.backgroundColor 
              : Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: prefsProvider.isInitialized 
                      ? prefsProvider.theme.primaryColor 
                      : Colors.teal,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Inicializando SmartPantry...',
                    style: TextStyle(
                      color: prefsProvider.isInitialized 
                        ? prefsProvider.theme.primaryColor 
                        : Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return widget.child;
  }
}