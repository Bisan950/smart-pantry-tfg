// lib/app.dart - ACTUALIZADO CON THEME PROVIDER

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'screens/inventory/add_product_screen.dart';
import 'screens/inventory/product_detail_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'screens/meal_planner/add_to_meal_plan_screen.dart'; 
import 'screens/settings/settings_screen.dart';
import 'widgets/common/error_boundary.dart';
import 'models/recipe_model.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart'; // 🆕 NUEVO
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'services/inventory_monitor_service.dart';
import 'services/notification_service.dart';

class MyApp extends StatefulWidget {
  final bool hasSession; // Parámetro para indicar si hay sesión guardada
  
  const MyApp({super.key, this.hasSession = false});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isLoading = true;
  
  // Servicios de notificaciones
  final InventoryMonitorService _monitorService = InventoryMonitorService();
  final NotificationService _notificationService = NotificationService();
  bool _monitorInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monitorService.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
  print('🚀 Iniciando _initializeApp');
  try {
    // Inicializar servicio de notificaciones
    await _notificationService.initialize();
    print('✅ NotificationService inicializado');
    
    // Si hay sesión, esperar a que AuthProvider se inicialice
    if (widget.hasSession) {
      print('🔐 Sesión detectada, inicializando AuthProvider...');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Esperar inicialización con timeout más corto
      int attempts = 0;
      while (attempts < 15 && !authProvider.isInitialized) { // 3 segundos máximo
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
      
      if (authProvider.isInitialized) {
        print('✅ AuthProvider inicializado');
      } else {
        print('⚠️ Timeout en AuthProvider - continuando');
      }
    }
    
    // Configurar listeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAuthListener();
    });
    
  } catch (e) {
    print('❌ Error en inicialización: $e');
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  // Configurar listener para cambios de autenticación
  void _setupAuthListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.addListener(() {
      _handleAuthStateChange(authProvider);
    });
    
    // Verificar estado inicial
    if (authProvider.isAuthenticated && !_monitorInitialized) {
      _startMonitorService();
    }
  }

  // Manejar cambios en el estado de autenticación
  Future<void> _handleAuthStateChange(AuthProvider authProvider) async {
    if (authProvider.isAuthenticated && !_monitorInitialized) {
      await _startMonitorService();
    } else if (!authProvider.isAuthenticated && _monitorInitialized) {
      await _stopMonitorService();
    }
  }

  // Iniciar el servicio de monitoreo
  Future<void> _startMonitorService() async {
    try {
      await _monitorService.initialize();
      _monitorInitialized = true;
      print('✅ Servicio de monitoreo de inventario iniciado');
    } catch (e) {
      print('❌ Error al iniciar servicio de monitoreo: $e');
    }
  }

  // Detener el servicio de monitoreo
  Future<void> _stopMonitorService() async {
    try {
      await _monitorService.dispose();
      _monitorInitialized = false;
      print('🛑 Servicio de monitoreo de inventario detenido');
    } catch (e) {
      print('❌ Error al detener servicio de monitoreo: $e');
    }
  }

  // Manejar cambios en el ciclo de vida de la app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 App en primer plano');
        // Cuando la app vuelve al primer plano, forzar verificación
        if (_monitorInitialized) {
          _monitorService.forceCheck();
        }
        break;
      case AppLifecycleState.paused:
        print('📱 App en segundo plano');
        break;
      case AppLifecycleState.inactive:
        print('📱 App inactiva');
        break;
      case AppLifecycleState.detached:
        print('📱 App desconectada');
        break;
      case AppLifecycleState.hidden:
        print('📱 App oculta');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Decidir la ruta inicial basada en el estado de autenticación
    Widget determineInitialScreen() {
  print('🔍 determineInitialScreen - _isLoading: $_isLoading');
  
  if (_isLoading) {
    print('📱 Mostrando pantalla de carga');
    return _buildLoadingScreen();
  }
  
  return Consumer<AuthProvider>(
    builder: (context, authProvider, _) {
      print('🔍 AuthProvider state:');
      print('  - isInitialized: ${authProvider.isInitialized}');
      print('  - isAuthenticated: ${authProvider.isAuthenticated}');
      print('  - isLoading: ${authProvider.isLoading}');
      
      // Si el proveedor aún está cargando o no inicializado
      if (authProvider.isLoading || !authProvider.isInitialized) {
        print('📱 AuthProvider cargando - mostrando pantalla de carga');
        return _buildLoadingScreen();
      }
      
      // Verificar si el usuario está autenticado
      if (authProvider.isAuthenticated) {
        print('📱 Usuario autenticado - navegando a Dashboard');
        return const DashboardScreen();
      } else {
        print('📱 Usuario no autenticado - navegando a Welcome');
        return const WelcomeScreen();
      }
    },
  );
}

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        if (!themeProvider.isInitialized) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return ErrorBoundary(
          child: MaterialApp(
            title: 'SmartPantry',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode, // Now properly accessed
            
            // Rutas
            initialRoute: '/',
            routes: {
              '/': (context) => determineInitialScreen(),
              Routes.dashboard: (context) => const DashboardScreen(),
              Routes.welcome: (context) => const WelcomeScreen(),
              Routes.settings: (context) => const SettingsScreen(),
            },
            onGenerateRoute: (settings) {
              // Para depuración
              print('📍 Navegando a: ${settings.name}');
              
              try {
                // Manejar casos especiales que necesitan argumentos
                if (settings.name == Routes.productDetail) {
                  final args = settings.arguments as Map<String, dynamic>?;
                  return MaterialPageRoute(
                    builder: (context) => ErrorBoundary(
                      child: ProductDetailScreen(
                        product: args?['product'],
                      ),
                    ),
                    settings: settings,
                  );
                } 
                
                else if (settings.name == Routes.recipeDetail) {
                  final args = settings.arguments as Map<String, dynamic>?;
                  // Mostrar una pantalla placeholder para recetas sin argumentos
                  if (args == null || args['recipe'] == null) {
                    return MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Detalle de Receta'),
                          backgroundColor: AppTheme.coralMain,
                          foregroundColor: AppTheme.pureWhite,
                        ),
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu_outlined,
                                size: 64,
                                color: AppTheme.mediumGrey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Selecciona una receta',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkGrey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Elige una receta para ver sus detalles',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      settings: settings,
                    );
                  }
                  // Si tenemos los argumentos adecuados, navegar a la pantalla de detalles
                  return MaterialPageRoute(
                    builder: (context) => ErrorBoundary(
                      child: RecipeDetailScreen(
                        recipe: args['recipe'],
                      ),
                    ),
                    settings: settings,
                  );
                } 
                
                else if (settings.name == Routes.addProduct) {
                  // Si hay un producto para editar, pasarlo como argumento
                  if (settings.arguments != null) {
                    final args = settings.arguments as Map<String, dynamic>;
                    return MaterialPageRoute(
                      builder: (context) => ErrorBoundary(
                        child: AddProductScreen(
                          productToEdit: args['productToEdit'],
                        ),
                      ),
                      settings: settings,
                    );
                  }
                  // Si no hay argumentos, abrir la pantalla para añadir un nuevo producto
                  return MaterialPageRoute(
                    builder: (context) => ErrorBoundary(
                      child: AddProductScreen(
                        productToEdit: null,
                      ),
                    ),
                    settings: settings,
                  );
                } 
                
                else if (settings.name == Routes.addToMealPlan) {
                  // Manejar la ruta para añadir al plan de comidas
                  final recipe = settings.arguments as Recipe?;
                  return MaterialPageRoute(
                    builder: (context) => ErrorBoundary(
                      child: AddToMealPlanScreen(
                        recipe: recipe,
                      ),
                    ),
                    settings: settings,
                  );
                }
                
                // Para el resto de rutas, usar el generador de rutas definido en Routes
                final route = Routes.generateRoute(settings);
                
                // Si se generó una ruta, usarla directamente
                if (route != null) {
                  return route;
                }
                
              } catch (e) {
                print('❌ Error al generar ruta ${settings.name}: $e');
                return _buildErrorRoute(settings, e.toString());
              }
              
              // Si no se pudo generar la ruta, mostrar error
              return _buildNotFoundRoute(settings);
            },
            
            // Manejar errores de navegación
            onUnknownRoute: (settings) {
              print('❌ Ruta desconocida: ${settings.name}');
              return _buildNotFoundRoute(settings);
            },
            
            // Configuración global de navegación
            navigatorObservers: [
              // Aquí podrías añadir observadores de navegación personalizados
              // Por ejemplo, para analytics o logging de navegación
            ],
            
            // Builder para manejar configuraciones globales
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
                ),
                child: child ?? const SizedBox(),
              );
            },
          ),
        );
      },
    );
  }

  // Pantalla de carga mientras se inicializa la app
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color(0xFFFFF0EB), // Color coral muy suave
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo animado
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.coralMain,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.coralMain.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.kitchen_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Indicador de carga personalizado
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppTheme.coralMain,
                  strokeWidth: 3,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Texto de carga
              Text(
                'Iniciando SmartPantry...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkGrey,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Subtexto
              Text(
                'Configurando notificaciones automáticas',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pantalla de error para rutas no encontradas
  MaterialPageRoute _buildNotFoundRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Página no encontrada'),
          backgroundColor: AppTheme.coralMain,
          foregroundColor: AppTheme.pureWhite,
        ),
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: AppTheme.coralMain.withOpacity(0.7),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Página no encontrada',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'No se pudo encontrar la ruta solicitada:',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.mediumGrey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  settings.name ?? 'Ruta desconocida',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    color: AppTheme.darkGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    Routes.welcome, 
                    (route) => false
                  );
                },
                icon: const Icon(Icons.home_rounded),
                label: const Text('Volver al inicio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coralMain,
                  foregroundColor: AppTheme.pureWhite,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      settings: settings,
    );
  }

  // Pantalla de error para errores en la generación de rutas
  MaterialPageRoute _buildErrorRoute(RouteSettings settings, String error) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Error de Navegación'),
          backgroundColor: AppTheme.errorRed,
          foregroundColor: AppTheme.pureWhite,
        ),
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bug_report_rounded,
                size: 80,
                color: AppTheme.errorRed.withOpacity(0.7),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Error de Navegación',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Ocurrió un error al intentar navegar a:',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.mediumGrey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.errorRed.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Ruta: ${settings.name ?? 'Desconocida'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: $error',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppTheme.errorRed,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Volver'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.coralMain,
                      side: BorderSide(color: AppTheme.coralMain),
                    ),
                  ),
                  
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        Routes.welcome, 
                        (route) => false
                      );
                    },
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Inicio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.coralMain,
                      foregroundColor: AppTheme.pureWhite,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      settings: settings,
    );
  }
}

// Clase auxiliar para manejar notificaciones cuando la app está cerrada
class NotificationHandler {
  static void handleNotificationWhenAppClosed(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'expiry':
        print('📱 Notificación de caducidad recibida con app cerrada');
        break;
      case 'low_stock':
        print('📱 Notificación de stock bajo recibida con app cerrada');
        break;
      case 'shopping_reminder':
        print('📱 Recordatorio de compras recibido con app cerrada');
        break;
      case 'meal_plan_reminder':
        print('📱 Recordatorio de planificación recibido con app cerrada');
        break;
      case 'recipe_suggestion':
        print('📱 Sugerencia de receta recibida con app cerrada');
        break;
      default:
        print('📱 Notificación desconocida recibida con app cerrada: $type');
    }
  }
}