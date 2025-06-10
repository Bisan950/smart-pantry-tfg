// lib/services/improved_barcode_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/product_model.dart';
import '../utils/barcode_validator.dart';
import 'barcode_apis.dart'; // Usar las APIs actualizadas

/// Información del producto obtenida de APIs de códigos de barras
class ProductInfo {
  final String name;
  final String category;
  final String brand;
  final String barcode;
  final int quantity;
  final int maxQuantity;
  final String unit;
  final String imageUrl;
  final List<String> ingredients;
  final Map<String, dynamic> nutritionalInfo;
  final String defaultLocation;
  final String source;
  final double confidence;

  ProductInfo({
    required this.name,
    required this.category,
    required this.barcode,
    this.brand = '',
    this.quantity = 1,
    this.maxQuantity = 0,
    this.unit = 'unidades',
    this.imageUrl = '',
    this.ingredients = const [],
    this.nutritionalInfo = const {},
    this.defaultLocation = 'Despensa',
    this.source = 'unknown',
    this.confidence = 0.5,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      name: json['name'] ?? '',
      category: json['category'] ?? 'Otros',
      brand: json['brand'] ?? '',
      barcode: json['barcode'] ?? '',
      quantity: json['quantity'] ?? 1,
      maxQuantity: json['maxQuantity'] ?? 0,
      unit: json['unit'] ?? 'unidades',
      imageUrl: json['imageUrl'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      nutritionalInfo: Map<String, dynamic>.from(json['nutritionalInfo'] ?? {}),
      defaultLocation: json['defaultLocation'] ?? 'Despensa',
      source: json['source'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.5).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'brand': brand,
      'barcode': barcode,
      'quantity': quantity,
      'maxQuantity': maxQuantity,
      'unit': unit,
      'imageUrl': imageUrl,
      'ingredients': ingredients,
      'nutritionalInfo': nutritionalInfo,
      'defaultLocation': defaultLocation,
      'source': source,
      'confidence': confidence,
    };
  }
}

/// Resultado de consulta a API
class APIResult {
  final String api;
  final ProductInfo productInfo;
  final int responseTime;
  final double confidence;

  APIResult({
    required this.api,
    required this.productInfo,
    required this.responseTime,
    required this.confidence,
  });
}

/// Datos del producto almacenados localmente
class LocalProductData {
  final ProductInfo productInfo;
  final int timestamp;
  final String source;
  final double confidence;

  LocalProductData({
    required this.productInfo,
    required this.timestamp,
    required this.source,
    required this.confidence,
  });
}

/// Estadísticas de uso de APIs
class APIStats {
  int successCount;
  int failureCount;
  double avgResponseTime;
  int lastUsed;

  APIStats({
    this.successCount = 0,
    this.failureCount = 0,
    this.avgResponseTime = 0.0,
    this.lastUsed = 0,
  });

  double get successRate {
    final total = successCount + failureCount;
    return total > 0 ? successCount / total : 0.0;
  }

  int get totalCalls => successCount + failureCount;
}

/// Servicio mejorado para gestionar códigos de barras con múltiples APIs españolas
class ImprovedBarcodeService {
  static final ImprovedBarcodeService _instance = ImprovedBarcodeService._internal();
  factory ImprovedBarcodeService() => _instance;
  ImprovedBarcodeService._internal();

  Database? _database;
  
  // Configuración de APIs múltiples optimizada para España
  late List<BarcodeAPI> _apis;
  String _currentRegion = 'ES'; // Por defecto España
  
  // Estadísticas de uso de APIs
  final Map<String, APIStats> _apiStats = {};
  
  // Cache en memoria para sesión actual
  final Map<String, ProductInfo> _sessionCache = {};
  
  // Validador de códigos de barras
  final BarcodeValidator _validator = BarcodeValidator();

  /// Inicializar el servicio con región específica
  Future<void> initialize({String region = 'ES'}) async {
  try {
    print('🚀 Inicializando servicio de códigos de barras...');
    
    _currentRegion = region;
    _setupAPIs();
    
    // Cargar configuración y estadísticas
    await Future.wait([
      _loadAPIStats(),
      loadSavedSettings(),
    ]);
    
    print('✅ Servicio inicializado correctamente:');
    print('   - Región: $_currentRegion');
    print('   - APIs activas: ${_apis.length}');
    print('   - Estadísticas cargadas: ${_apiStats.length} APIs');
    
    // Verificar que OpenFoodFacts funciona
    await _testMainAPI();
    
  } catch (e) {
    print('💥 Error inicializando servicio: $e');
    // Fallback mínimo
    _apis = [FallbackProductGeneratorAPI()];
  }
}

// NUEVO MÉTODO: Probar API principal
Future<void> _testMainAPI() async {
  try {
    print('🧪 Probando API principal con código de prueba...');
    
    // Código de prueba conocido (Coca-Cola)
    const testBarcode = '8410076472049';
    
    final mainAPI = _apis.firstWhere(
      (api) => api is OpenFoodFactsAPI,
      orElse: () => _apis.first,
    );
    
    final testResult = await mainAPI.getProductInfo(testBarcode)
        .timeout(Duration(seconds: 15));
    
    if (testResult != null) {
      print('✅ API principal funciona correctamente');
      print('   Producto de prueba: ${testResult.name}');
    } else {
      print('⚠️  API principal no encontró producto de prueba');
    }
    
  } catch (e) {
    print('⚠️  Error probando API principal: $e');
  }
}

  void _setupAPIs() {
  print('🔧 Configurando APIs para región: $_currentRegion');
  
  // USAR SOLO APIs que funcionan realmente
  _apis = BarcodeAPIFactory.getAPIsByRegion(_currentRegion);
  
  print('✅ Configuradas ${_apis.length} APIs funcionales:');
  for (var api in _apis) {
    print('   - ${api.name} (Prioridad: ${api.priority}, Región: ${api.region})');
  }
  
  // VERIFICAR que tenemos al menos una API
  if (_apis.isEmpty) {
    print('⚠️  Sin APIs configuradas, añadiendo fallback...');
    _apis = [FallbackProductGeneratorAPI()];
  }
}

  /// Cargar estadísticas de APIs desde la base de datos
  Future<void> _loadAPIStats() async {
    final db = await database;
    
    try {
      final results = await db.query('api_stats');
      
      for (final row in results) {
        final apiName = row['api_name'] as String;
        _apiStats[apiName] = APIStats(
          successCount: row['success_count'] as int,
          failureCount: row['failure_count'] as int,
          avgResponseTime: (row['avg_response_time'] as num).toDouble(),
          lastUsed: row['last_used'] as int,
        );
      }
      
      print('Cargadas estadísticas de ${_apiStats.length} APIs');
    } catch (e) {
      print('Error cargando estadísticas de APIs: $e');
    }
  }

  /// Inicializar base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(documentsDirectory.path, 'enhanced_barcode_products.db');
    
    return await openDatabase(
      databasePath,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products(
            barcode TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            source TEXT NOT NULL,
            confidence REAL NOT NULL,
            timestamp INTEGER NOT NULL,
            access_count INTEGER DEFAULT 1
          )
        ''');
        
        await db.execute('''
          CREATE TABLE api_stats(
            api_name TEXT PRIMARY KEY,
            success_count INTEGER DEFAULT 0,
            failure_count INTEGER DEFAULT 0,
            avg_response_time REAL DEFAULT 0,
            last_used INTEGER
          )
        ''');
        
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE products ADD COLUMN source TEXT DEFAULT "unknown"');
            await db.execute('ALTER TABLE products ADD COLUMN confidence REAL DEFAULT 0.5');
            await db.execute('ALTER TABLE products ADD COLUMN access_count INTEGER DEFAULT 1');
          } catch (e) {
            print('Error en migración v2: $e');
          }
        }
        
        if (oldVersion < 3) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS api_stats(
                api_name TEXT PRIMARY KEY,
                success_count INTEGER DEFAULT 0,
                failure_count INTEGER DEFAULT 0,
                avg_response_time REAL DEFAULT 0,
                last_used INTEGER
              )
            ''');
          } catch (e) {
            print('Error en migración v3: $e');
          }
        }
        
        if (oldVersion < 4) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS settings(
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )
            ''');
          } catch (e) {
            print('Error en migración v4: $e');
          }
        }
      },
    );
  }

  Future<ProductInfo?> getEnhancedProductInfo(String barcode) async {
  try {
    print('🔍 === INICIANDO CONSULTA PARA $barcode ===');
    
    // 1. VERIFICAR que el servicio esté listo
    if (_apis.isEmpty) {
      print('⚠️  APIs no configuradas, inicializando...');
      await initialize();
    }
    
    print('📊 Estado actual:');
    print('   - APIs disponibles: ${_apis.length}');
    print('   - Caché de sesión: ${_sessionCache.length} productos');
    
    // 2. Validar código de barras
    if (!_validator.isValid(barcode)) {
      print('❌ Código inválido: $barcode');
      return null;
    }
    
    print('✅ Código válido, continuando...');

    // 3. Buscar en caché de sesión
    if (_sessionCache.containsKey(barcode)) {
      print('📱 ¡Encontrado en caché de sesión!');
      return _sessionCache[barcode];
    }

    // 4. Buscar en base de datos local
    final localResult = await _getLocalProduct(barcode);
    if (localResult != null && _isDataFresh(localResult)) {
      _sessionCache[barcode] = localResult.productInfo;
      await _updateAccessCount(barcode);
      print('💾 ¡Encontrado en BD local! (${localResult.source})');
      return localResult.productInfo;
    }

    // 5. Consultar APIs en orden de prioridad
    print('🌐 Consultando ${_apis.length} APIs...');
    
    ProductInfo? bestResult;
    
    // Probar APIs una por una hasta encontrar resultado
    for (int i = 0; i < _apis.length; i++) {
      final api = _apis[i];
      print('   🔍 Probando ${api.name} (${i+1}/${_apis.length})...');
      
      try {
        final result = await api.getProductInfo(barcode)
            .timeout(Duration(seconds: api.priority >= 8 ? 15 : 10));
        
        if (result != null) {
          print('   ✅ ¡Éxito con ${api.name}!');
          print('      - Producto: ${result.name}');
          print('      - Confianza: ${result.confidence}');
          
          // Calcular confianza mejorada
          final enhancedConfidence = _calculateConfidence(result, api);
          final enhancedResult = ProductInfo(
            name: result.name,
            category: result.category,
            brand: result.brand,
            barcode: result.barcode,
            quantity: result.quantity,
            maxQuantity: result.maxQuantity,
            unit: result.unit,
            imageUrl: result.imageUrl,
            ingredients: result.ingredients,
            nutritionalInfo: result.nutritionalInfo,
            defaultLocation: result.defaultLocation,
            source: result.source,
            confidence: enhancedConfidence,
          );
          
          bestResult = enhancedResult;
          
          // Si la confianza es alta, parar aquí
          if (enhancedConfidence > 0.8) {
            print('   🎯 Alta confianza alcanzada, parando búsqueda');
            break;
          }
        } else {
          print('   ❌ No encontrado en ${api.name}');
        }
        
        // Actualizar estadísticas
        await _updateAPIStats(api.name, result != null, 0);
        
      } catch (e) {
        print('   💥 Error en ${api.name}: $e');
        await _updateAPIStats(api.name, false, 0);
      }
    }

    // 6. Guardar resultado si se encontró
    if (bestResult != null) {
      await _saveLocalProduct(barcode, bestResult);
      _sessionCache[barcode] = bestResult;
      
      print('✅ === PRODUCTO ENCONTRADO ===');
      print('   Nombre: ${bestResult.name}');
      print('   Fuente: ${bestResult.source}');
      print('   Confianza: ${bestResult.confidence}');
      
      return bestResult;
    }

    print('❌ === NO SE ENCONTRÓ EL PRODUCTO ===');
    return null;

  } catch (e) {
    print('💥 === ERROR CRÍTICO ===');
    print('Error: $e');
    print('StackTrace: ${StackTrace.current}');
    return null;
  }
}

  /// Consultar múltiples APIs de forma inteligente
  Future<List<APIResult>> _queryMultipleAPIs(String barcode) async {
    final results = <APIResult>[];
    final futures = <Future<APIResult?>>[];

    // Usar APIs ordenadas por prioridad y rendimiento
    final sortedAPIs = _getSortedAPIsByPerformance();
    
    // Estrategia: probar APIs de alta prioridad primero, luego paralelo con las demás
    final highPriorityAPIs = sortedAPIs.where((api) => api.priority >= 8).toList();
    final mediumPriorityAPIs = sortedAPIs.where((api) => api.priority >= 5 && api.priority < 8).toList();
    final lowPriorityAPIs = sortedAPIs.where((api) => api.priority < 5).toList();
    
    // 1. Probar APIs de alta prioridad secuencialmente (más rápido para productos españoles)
    for (final api in highPriorityAPIs) {
      print('Probando API de alta prioridad: ${api.name}');
      final result = await _queryAPIWithStats(api, barcode, const Duration(seconds: 8));
      if (result != null) {
        results.add(result);
        // Si obtenemos un resultado con alta confianza, no necesitamos más APIs
        if (result.confidence > 0.8) {
          print('Resultado de alta confianza obtenido de ${api.name}, omitiendo otras APIs');
          return results;
        }
      }
    }

    // 2. Si no hay resultados buenos, probar APIs de prioridad media en paralelo
    if (results.isEmpty || results.first.confidence < 0.7) {
      print('Probando APIs de prioridad media en paralelo...');
      for (final api in mediumPriorityAPIs) {
        futures.add(_queryAPIWithStats(api, barcode, const Duration(seconds: 6)));
      }
    }

    // 3. APIs de baja prioridad solo si no hay nada más
    if (results.isEmpty) {
      print('Probando APIs de baja prioridad...');
      for (final api in lowPriorityAPIs) {
        futures.add(_queryAPIWithStats(api, barcode, const Duration(seconds: 4)));
      }
    }

    // Esperar resultados paralelos
    if (futures.isNotEmpty) {
      try {
        final parallelResults = await Future.wait(futures).timeout(
          const Duration(seconds: 15),
        );

        for (final result in parallelResults) {
          if (result != null) {
            results.add(result);
          }
        }
      } catch (e) {
        print('Error en consultas paralelas: $e');
      }
    }

    print('Obtenidos ${results.length} resultados de APIs');
    return results;
  }

  /// Consultar API individual con estadísticas
  Future<APIResult?> _queryAPIWithStats(BarcodeAPI api, String barcode, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await api.getProductInfo(barcode).timeout(timeout);
      stopwatch.stop();
      
      if (result != null) {
        await _updateAPIStats(api.name, true, stopwatch.elapsedMilliseconds);
        return APIResult(
          api: api.name,
          productInfo: result,
          responseTime: stopwatch.elapsedMilliseconds,
          confidence: _calculateConfidence(result, api),
        );
      } else {
        await _updateAPIStats(api.name, false, stopwatch.elapsedMilliseconds);
      }
    } catch (e) {
      stopwatch.stop();
      await _updateAPIStats(api.name, false, stopwatch.elapsedMilliseconds);
      print('Error en API ${api.name}: $e');
    }
    
    return null;
  }

  /// Seleccionar el mejor resultado usando múltiples criterios
  ProductInfo _selectBestResult(List<APIResult> results) {
    if (results.isEmpty) throw Exception('No hay resultados para seleccionar');
    
    results.sort((a, b) {
      // Peso para diferentes factores:
      // - Confianza: 50%
      // - Completitud de datos: 30% 
      // - Velocidad: 10%
      // - Prioridad de API: 10%
      
      final scoreA = (a.confidence * 0.5) + 
                    (_calculateCompleteness(a.productInfo) * 0.3) +
                    (_calculateSpeedScore(a.responseTime) * 0.1) +
                    (_getAPIPriorityScore(a.api) * 0.1);
      
      final scoreB = (b.confidence * 0.5) + 
                    (_calculateCompleteness(b.productInfo) * 0.3) +
                    (_calculateSpeedScore(b.responseTime) * 0.1) +
                    (_getAPIPriorityScore(b.api) * 0.1);
      
      return scoreB.compareTo(scoreA);
    });

    final bestResult = results.first;
    print('Mejor resultado seleccionado: ${bestResult.api} (puntuación: ${(bestResult.confidence * 0.5 + _calculateCompleteness(bestResult.productInfo) * 0.3).toStringAsFixed(2)})');
    
    return bestResult.productInfo;
  }

  /// Calcular confianza del resultado
  double _calculateConfidence(ProductInfo info, BarcodeAPI api) {
    double confidence = info.confidence;
    
    // Bonus por API de alta prioridad
    confidence += _getAPIReliabilityScore(api.name);
    
    // Bonus por completitud de datos
    if (info.name.isNotEmpty && info.name != 'Producto desconocido') confidence += 0.1;
    if (info.imageUrl.isNotEmpty) confidence += 0.05;
    if (info.ingredients.isNotEmpty) confidence += 0.05;
    if (info.nutritionalInfo.isNotEmpty) confidence += 0.05;
    if (info.brand.isNotEmpty) confidence += 0.05;
    
    // Bonus por APIs específicas de España
    if (api.region == 'ES') confidence += 0.1;
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Calcular completitud de los datos
  double _calculateCompleteness(ProductInfo info) {
    int totalFields = 9;
    int filledFields = 0;
    
    if (info.name.isNotEmpty && info.name != 'Producto desconocido') filledFields++;
    if (info.category.isNotEmpty && info.category != 'Otros') filledFields++;
    if (info.brand.isNotEmpty) filledFields++;
    if (info.imageUrl.isNotEmpty) filledFields++;
    if (info.ingredients.isNotEmpty) filledFields++;
    if (info.nutritionalInfo.isNotEmpty) filledFields++;
    if (info.quantity > 0) filledFields++;
    if (info.unit.isNotEmpty) filledFields++;
    if (info.defaultLocation.isNotEmpty) filledFields++;
    
    return filledFields / totalFields;
  }

  /// Calcular puntaje de velocidad
  double _calculateSpeedScore(int responseTimeMs) {
    if (responseTimeMs < 1000) return 1.0;
    if (responseTimeMs < 2000) return 0.9;
    if (responseTimeMs < 3000) return 0.8;
    if (responseTimeMs < 5000) return 0.6;
    if (responseTimeMs < 8000) return 0.4;
    return 0.2;
  }

  /// Obtener puntaje de prioridad de API
  double _getAPIPriorityScore(String apiName) {
    final api = _apis.firstWhere((a) => a.name == apiName, orElse: () => _apis.first);
    return api.priority / 10.0; // Normalizar a 0-1
  }

  /// Crear información básica del producto mejorada
  ProductInfo _createBasicProductInfo(String barcode) {
    final category = _detectCategoryFromBarcode(barcode);
    final isSpanish = _isSpanishBarcode(barcode);
    final brandInfo = isSpanish ? _detectSpanishBrand(barcode) : null;
    
    String productName;
    if (isSpanish) {
      productName = _generateSpanishProductName(barcode, category);
    } else {
      productName = 'Producto ${barcode.substring(0, min(6, barcode.length))}';
    }
    
    return ProductInfo(
      name: productName,
      category: category,
      brand: brandInfo?['brand'] ?? '',
      barcode: barcode,
      quantity: 1,
      unit: 'unidades',
      defaultLocation: _suggestLocationForCategory(category),
      confidence: isSpanish ? 0.3 : 0.1, // Más confianza para productos españoles
      source: 'generated',
    );
  }

  /// Detectar si es un código de barras español
  bool _isSpanishBarcode(String barcode) {
    if (barcode.length < 3) return false;
    final spanishPrefixes = ['840', '841', '842', '843', '844', '845', '846', '847', '848', '849'];
    return spanishPrefixes.contains(barcode.substring(0, 3));
  }

  /// Detectar marca española por código de barras
  Map<String, String>? _detectSpanishBrand(String barcode) {
    if (barcode.length < 5) return null;
    
    final brandPrefixes = {
      '84000': {'brand': 'Mercadona', 'confidence': '0.7'},
      '84001': {'brand': 'Carrefour', 'confidence': '0.6'},
      '84002': {'brand': 'DIA', 'confidence': '0.6'},
      '84003': {'brand': 'Eroski', 'confidence': '0.6'},
      '84004': {'brand': 'El Corte Inglés', 'confidence': '0.6'},
      '84005': {'brand': 'Alcampo', 'confidence': '0.5'},
      '84006': {'brand': 'Hipercor', 'confidence': '0.5'},
      '84007': {'brand': 'Consum', 'confidence': '0.5'},
    };
    
    final prefix5 = barcode.substring(0, 5);
    return brandPrefixes[prefix5];
  }

  /// Generar nombre de producto español
  String _generateSpanishProductName(String barcode, String category) {
    final categoryNames = {
      'Lácteos': 'Producto Lácteo',
      'Carnes': 'Producto Cárnico',
      'Pescados': 'Producto Pesquero',
      'Frutas': 'Fruta',
      'Verduras': 'Verdura',
      'Panadería': 'Producto de Panadería',
      'Bebidas': 'Bebida',
      'Congelados': 'Producto Congelado',
      'Conservas': 'Conserva',
      'Snacks': 'Snack',
      'Limpieza': 'Producto de Limpieza',
      'Higiene': 'Producto de Higiene',
    };
    
    final baseName = categoryNames[category] ?? 'Producto';
    return '$baseName ${barcode.substring(0, min(6, barcode.length))}';
  }

  /// Detectar categoría por código de barras
  String _detectCategoryFromBarcode(String barcode) {
    if (barcode.length < 3) return 'Otros';
    
    final prefix = barcode.substring(0, min(4, barcode.length));
    
    final categoryMap = {
      '841': 'Alimentación',
      '840': 'Alimentación', 
      '8400': 'Lácteos',
      '8401': 'Carnes',
      '8402': 'Pescados',
      '8403': 'Frutas',
      '8404': 'Verduras',
      '8405': 'Panadería',
      '8406': 'Bebidas',
      '8407': 'Congelados',
      '8408': 'Conservas',
      '8409': 'Snacks',
      '8410': 'Limpieza',
      '8411': 'Higiene',
      '848': 'Bebidas',
      '750': 'Bebidas',
      '300': 'Farmacia',
      '978': 'Libros',
      '979': 'Libros',
      '020': 'Alimentación',
      '021': 'Alimentación',
    };
    
    // Probar primero prefijos de 4 dígitos, luego 3
    return categoryMap[prefix] ?? categoryMap[prefix.substring(0, 3)] ?? 'Otros';
  }

  Future<Product?> createEnhancedProductFromBarcode(String barcode) async {
  try {
    print('🏗️  Creando producto desde código: $barcode');
    
    final productInfo = await getEnhancedProductInfo(barcode);
    
    if (productInfo == null) {
      print('❌ No se pudo obtener información del producto');
      return null;
    }
    
    final expiryDate = DateTime.now().add(
      Duration(days: _estimateExpiryDays(productInfo.category))
    );
    
    // Convertir la información nutricional del ProductInfo a NutritionalInfo
    NutritionalInfo? nutritionalInfo;
    if (productInfo.nutritionalInfo.isNotEmpty) {
      nutritionalInfo = NutritionalInfo.fromMap(productInfo.nutritionalInfo);
    }
    
    final product = Product(
      id: '', // Se llenará después
      name: productInfo.name,
      quantity: productInfo.quantity,
      maxQuantity: productInfo.maxQuantity > 0 ? productInfo.maxQuantity : productInfo.quantity * 2,
      unit: productInfo.unit,
      category: productInfo.category,
      location: productInfo.defaultLocation,
      barcode: barcode,
      imageUrl: productInfo.imageUrl,
      expiryDate: expiryDate,
      userId: '', // Se llenará después
      nutritionalInfo: nutritionalInfo, // ✅ AGREGAR ESTA LÍNEA
    );
    
    print('✅ Producto creado exitosamente: ${product.name}');
    return product;
    
  } catch (e) {
    print('💥 Error creando producto: $e');
    return null;
  }
}

// NUEVO: Método para limpiar y reiniciar el servicio
Future<void> resetService() async {
  try {
    print('🔄 Reiniciando servicio...');
    
    // Limpiar cachés
    _sessionCache.clear();
    _apiStats.clear();
    
    // Reinicializar
    await initialize();
    
    print('✅ Servicio reiniciado correctamente');
    
  } catch (e) {
    print('💥 Error reiniciando servicio: $e');
  }
}

// NUEVO: Método para diagnóstico rápido
Future<Map<String, dynamic>> quickDiagnosis() async {
  return {
    'service_initialized': _apis.isNotEmpty,
    'total_apis': _apis.length,
    'working_apis': _apis.map((api) => api.name).toList(),
    'session_cache_size': _sessionCache.length,
    'database_ready': _database != null,
    'current_region': _currentRegion,
    'api_stats_loaded': _apiStats.isNotEmpty,
  };
}

  /// Método alternativo que solo devuelve información del producto sin crear Product
  Future<ProductInfo?> getProductInfoFromBarcode(String barcode) async {
    try {
      return await getEnhancedProductInfo(barcode);
    } catch (e) {
      print('Error al obtener información del código de barras: $e');
      return null;
    }
  }

  /// Obtener estadísticas del servicio
  Future<Map<String, dynamic>> getServiceStats() async {
    final db = await database;
    
    final productCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products')
    ) ?? 0;
    
    final apiStatsQuery = await db.query('api_stats');
    final apiStats = <String, Map<String, dynamic>>{};
    
    for (final row in apiStatsQuery) {
      final stats = _apiStats[row['api_name'] as String] ?? APIStats();
      apiStats[row['api_name'] as String] = {
        'success_count': row['success_count'],
        'failure_count': row['failure_count'],
        'avg_response_time': row['avg_response_time'],
        'success_rate': stats.successRate,
        'total_calls': stats.totalCalls,
      };
    }
    
    return {
      'product_count': productCount,
      'session_cache_size': _sessionCache.length,
      'current_region': _currentRegion,
      'configured_apis': _apis.length,
      'api_stats': apiStats,
      'spanish_products': await _getSpanishProductCount(),
      'api_factory_stats': BarcodeAPIFactory.getAPIStats(),
    };
  }

  /// Obtener cantidad de productos españoles
  Future<int> _getSpanishProductCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM products WHERE barcode LIKE '84%'"
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ============= MÉTODOS PRIVADOS DE UTILIDAD =============
  
  /// Obtener producto de la base de datos local
  Future<LocalProductData?> _getLocalProduct(String barcode) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    
    if (results.isNotEmpty) {
      final data = results.first;
      try {
        return LocalProductData(
          productInfo: ProductInfo.fromJson(jsonDecode(data['data'] as String)),
          timestamp: data['timestamp'] as int,
          source: data['source'] as String,
          confidence: (data['confidence'] as num).toDouble(),
        );
      } catch (e) {
        print('Error al parsear producto local: $e');
        return null;
      }
    }
    
    return null;
  }
  
  /// Verificar si los datos locales están frescos
  bool _isDataFresh(LocalProductData data) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ageInDays = (now - data.timestamp) / (1000 * 60 * 60 * 24);
    
    // Datos de alta confianza duran una semana
    if (data.confidence > 0.8 && ageInDays < 7) return true;
    
    // Datos de confianza media duran un día
    if (data.confidence > 0.5 && ageInDays < 1) return true;
    
    // Datos de baja confianza duran solo unas horas
    if (data.confidence > 0.3 && ageInDays < 0.5) return true;
    
    return false;
  }
  
  /// Obtener APIs ordenadas por rendimiento
  List<BarcodeAPI> _getSortedAPIsByPerformance() {
    final sortedApis = List<BarcodeAPI>.from(_apis);
    sortedApis.sort((a, b) {
      final scoreA = _getAPIPerformanceScore(a.name);
      final scoreB = _getAPIPerformanceScore(b.name);
      return scoreB.compareTo(scoreA);
    });
    return sortedApis;
  }
  
  /// Calcular puntaje de rendimiento de API
  double _getAPIPerformanceScore(String apiName) {
    final stats = _apiStats[apiName];
    if (stats == null) return 0.5;
    
    final total = stats.totalCalls;
    if (total == 0) return 0.5;
    
    final successRate = stats.successRate;
    final speedScore = 1.0 / (1.0 + (stats.avgResponseTime / 1000));
    
    return (successRate * 0.7) + (speedScore * 0.3);
  }
  
  /// Obtener puntaje de confiabilidad de API
  double _getAPIReliabilityScore(String apiName) {
    final stats = _apiStats[apiName];
    if (stats == null) return 0.0;
    
    final total = stats.totalCalls;
    if (total == 0) return 0.0;
    
    return stats.successRate * 0.2;
  }
  
  /// Guardar producto en base de datos local
  Future<void> _saveLocalProduct(String barcode, ProductInfo productInfo) async {
    final db = await database;
    await db.insert(
      'products',
      {
        'barcode': barcode,
        'data': jsonEncode(productInfo.toJson()),
        'source': productInfo.source,
        'confidence': productInfo.confidence,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'access_count': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Actualizar contador de acceso
  Future<void> _updateAccessCount(String barcode) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE products SET access_count = access_count + 1 WHERE barcode = ?',
      [barcode],
    );
  }
  
  /// Actualizar estadísticas de API
  Future<void> _updateAPIStats(String apiName, bool success, int responseTime) async {
    final db = await database;
    
    // Actualizar estadísticas en memoria
    final currentStats = _apiStats[apiName] ?? APIStats();
    if (success) {
      currentStats.successCount++;
    } else {
      currentStats.failureCount++;
    }
    
    // Calcular nuevo promedio de tiempo de respuesta
    final totalCalls = currentStats.totalCalls;
    if (totalCalls > 0) {
      currentStats.avgResponseTime = 
          ((currentStats.avgResponseTime * (totalCalls - 1)) + responseTime) / totalCalls;
    } else {
      currentStats.avgResponseTime = responseTime.toDouble();
    }
    currentStats.lastUsed = DateTime.now().millisecondsSinceEpoch;
    
    _apiStats[apiName] = currentStats;
    
    // Actualizar en base de datos
    await db.insert(
      'api_stats',
      {
        'api_name': apiName,
        'success_count': currentStats.successCount,
        'failure_count': currentStats.failureCount,
        'avg_response_time': currentStats.avgResponseTime,
        'last_used': currentStats.lastUsed,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Sugerir ubicación para una categoría
  String _suggestLocationForCategory(String category) {
    final locationMap = {
      'lácteos': 'Nevera',
      'carnes': 'Nevera',
      'pescados': 'Nevera',
      'frutas': 'Nevera',
      'verduras': 'Nevera',
      'bebidas': 'Nevera',
      'congelados': 'Congelador',
      'condimentos': 'Especias',
      'especias': 'Especias',
      'snacks': 'Armario',
      'cereales': 'Armario',
      'panadería': 'Armario',
      'conservas': 'Despensa',
      'dulces': 'Despensa',
      'alimentación': 'Despensa',
      'limpieza': 'Limpieza',
      'higiene': 'Baño',
      'perfumeria': 'Baño',
      'hogar': 'Hogar',
      'mascotas': 'Despensa',
      'bebe': 'Bebé',
    };
    
    return locationMap[category.toLowerCase()] ?? 'Despensa';
  }
  
  /// Estimar días de caducidad por categoría
  int _estimateExpiryDays(String category) {
    final expiryMap = {
      'lácteos': 7,
      'frutas': 5,
      'verduras': 5,
      'carnes': 3,
      'pescados': 2,
      'panadería': 4,
      'congelados': 60,
      'conservas': 365,
      'cereales': 90,
      'snacks': 90,
      'condimentos': 180,
      'especias': 365,
      'bebidas': 30,
      'dulces': 120,
      'alimentación': 30,
      'limpieza': 730, // 2 años
      'higiene': 365,
      'perfumeria': 365,
      'hogar': 1095, // 3 años
      'mascotas': 180,
      'bebe': 365,
    };
    
    return expiryMap[category.toLowerCase()] ?? 15;
  }
  
  /// Método para limpiar datos antiguos
  Future<void> cleanupOldData() async {
    final db = await database;
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch;
    
    // Eliminar productos antiguos con baja confianza y pocos accesos
    final deletedCount = await db.delete(
      'products',
      where: 'timestamp < ? AND confidence < ? AND access_count < ?',
      whereArgs: [thirtyDaysAgo, 0.5, 2],
    );
    
    print('Limpieza completada: $deletedCount productos eliminados');
  }
  
  /// Método para obtener permisos de cámara
  Future<bool> checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('Error al comprobar permisos de cámara: $e');
      }
      return false;
    }
  }

  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('Error al solicitar permisos de cámara: $e');
      }
      return false;
    }
  }
  
  /// Método para exportar estadísticas completas
  Future<Map<String, dynamic>> exportStats() async {
    final stats = await getServiceStats();
    final db = await database;
    
    // Productos más populares
    final popularProducts = await db.query(
      'products',
      orderBy: 'access_count DESC',
      limit: 10,
    );
    
    // Productos españoles vs internacionales
    final spanishCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM products WHERE barcode LIKE '84%'"
    );
    final internationalCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM products WHERE barcode NOT LIKE '84%'"
    );
    
    // Distribución por categorías
    final categoryDistribution = await db.rawQuery('''
      SELECT 
        JSON_EXTRACT(data, '\$.category') as category,
        COUNT(*) as count
      FROM products 
      GROUP BY JSON_EXTRACT(data, '\$.category')
      ORDER BY count DESC
      LIMIT 10
    ''');
    
    return {
      ...stats,
      'popular_products': popularProducts.map((p) => {
        'barcode': p['barcode'],
        'access_count': p['access_count'],
        'confidence': p['confidence'],
        'source': p['source'],
      }).toList(),
      'distribution': {
        'spanish_products': Sqflite.firstIntValue(spanishCount) ?? 0,
        'international_products': Sqflite.firstIntValue(internationalCount) ?? 0,
        'categories': categoryDistribution,
      },
      'export_timestamp': DateTime.now().toIso8601String(),
      'version': '4.0',
    };
  }
  
  /// Método para búsqueda inteligente de productos
  Future<List<ProductInfo>> searchProducts(String query) async {
    final db = await database;
    final results = <ProductInfo>[];
    
    // Si la consulta parece un código de barras, buscar directamente
    if (_validator.isValid(query)) {
      final product = await getEnhancedProductInfo(query);
      if (product != null) {
        results.add(product);
        return results;
      }
    }
    
    // Búsqueda por texto en base de datos local
    try {
      final localResults = await db.rawQuery('''
        SELECT * FROM products 
        WHERE LOWER(JSON_EXTRACT(data, '\$.name')) LIKE LOWER(?) 
           OR LOWER(JSON_EXTRACT(data, '\$.brand')) LIKE LOWER(?)
           OR LOWER(JSON_EXTRACT(data, '\$.category')) LIKE LOWER(?)
           OR barcode LIKE ?
        ORDER BY confidence DESC, access_count DESC
        LIMIT 20
      ''', ['%$query%', '%$query%', '%$query%', '%$query%']);
      
      for (final row in localResults) {
        try {
          final productInfo = ProductInfo.fromJson(
            jsonDecode(row['data'] as String)
          );
          results.add(productInfo);
        } catch (e) {
          print('Error al parsear producto en búsqueda: $e');
        }
      }
    } catch (e) {
      print('Error en búsqueda de productos: $e');
    }
    
    return results;
  }
  
  /// Obtener productos por categoría
  Future<List<ProductInfo>> getProductsByCategory(String category) async {
    final db = await database;
    final results = <ProductInfo>[];
    
    try {
      final localResults = await db.rawQuery('''
        SELECT * FROM products 
        WHERE LOWER(JSON_EXTRACT(data, '\$.category')) = LOWER(?)
        ORDER BY confidence DESC, access_count DESC
        LIMIT 50
      ''', [category]);
      
      for (final row in localResults) {
        try {
          final productInfo = ProductInfo.fromJson(
            jsonDecode(row['data'] as String)
          );
          results.add(productInfo);
        } catch (e) {
          print('Error al parsear producto por categoría: $e');
        }
      }
    } catch (e) {
      print('Error obteniendo productos por categoría: $e');
    }
    
    return results;
  }
  
  /// Obtener productos por marca
  Future<List<ProductInfo>> getProductsByBrand(String brand) async {
    final db = await database;
    final results = <ProductInfo>[];
    
    try {
      final localResults = await db.rawQuery('''
        SELECT * FROM products 
        WHERE LOWER(JSON_EXTRACT(data, '\$.brand')) = LOWER(?)
        ORDER BY confidence DESC, access_count DESC
        LIMIT 50
      ''', [brand]);
      
      for (final row in localResults) {
        try {
          final productInfo = ProductInfo.fromJson(
            jsonDecode(row['data'] as String)
          );
          results.add(productInfo);
        } catch (e) {
          print('Error al parsear producto por marca: $e');
        }
      }
    } catch (e) {
      print('Error obteniendo productos por marca: $e');
    }
    
    return results;
  }
  
  /// Actualizar información de producto existente
  Future<bool> updateProductInfo(String barcode, ProductInfo updatedInfo) async {
    try {
      final db = await database;
      
      // Incrementar la confianza al ser actualizado manualmente
      final finalInfo = ProductInfo(
        name: updatedInfo.name,
        category: updatedInfo.category,
        brand: updatedInfo.brand,
        barcode: updatedInfo.barcode,
        quantity: updatedInfo.quantity,
        maxQuantity: updatedInfo.maxQuantity,
        unit: updatedInfo.unit,
        imageUrl: updatedInfo.imageUrl,
        ingredients: updatedInfo.ingredients,
        nutritionalInfo: updatedInfo.nutritionalInfo,
        defaultLocation: updatedInfo.defaultLocation,
        source: 'user_updated',
        confidence: 1.0, // Máxima confianza para actualizaciones manuales
      );
      
      await _saveLocalProduct(barcode, finalInfo);
      
      // Actualizar caché de sesión
      _sessionCache[barcode] = finalInfo;
      
      return true;
    } catch (e) {
      print('Error actualizando información del producto: $e');
      return false;
    }
  }
  
  /// Eliminar producto de la base de datos
  Future<bool> deleteProduct(String barcode) async {
    try {
      final db = await database;
      
      final deletedRows = await db.delete(
        'products',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
      
      // Eliminar del caché de sesión
      _sessionCache.remove(barcode);
      
      return deletedRows > 0;
    } catch (e) {
      print('Error eliminando producto: $e');
      return false;
    }
  }
  
  /// Obtener todas las categorías disponibles
  Future<List<String>> getAvailableCategories() async {
    final db = await database;
    
    try {
      final results = await db.rawQuery('''
        SELECT DISTINCT JSON_EXTRACT(data, '\$.category') as category
        FROM products 
        WHERE JSON_EXTRACT(data, '\$.category') IS NOT NULL
        ORDER BY category
      ''');
      
      return results.map((row) => row['category'] as String).toList();
    } catch (e) {
      print('Error obteniendo categorías: $e');
      return [];
    }
  }
  
  /// Obtener todas las marcas disponibles
  Future<List<String>> getAvailableBrands() async {
    final db = await database;
    
    try {
      final results = await db.rawQuery('''
        SELECT DISTINCT JSON_EXTRACT(data, '\$.brand') as brand
        FROM products 
        WHERE JSON_EXTRACT(data, '\$.brand') IS NOT NULL 
          AND JSON_EXTRACT(data, '\$.brand') != ''
        ORDER BY brand
      ''');
      
      return results.map((row) => row['brand'] as String).toList();
    } catch (e) {
      print('Error obteniendo marcas: $e');
      return [];
    }
  }
  
  /// Cambiar región del servicio
  Future<void> changeRegion(String newRegion) async {
    if (_currentRegion != newRegion) {
      _currentRegion = newRegion;
      _setupAPIs();
      
      // Guardar configuración
      final db = await database;
      await db.insert(
        'settings',
        {
          'key': 'current_region',
          'value': newRegion,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('Región cambiada a: $newRegion');
      print('APIs reconfiguradas: ${_apis.length} disponibles');
    }
  }
  
  /// Cargar configuración guardada
  Future<void> loadSavedSettings() async {
    final db = await database;
    
    try {
      final results = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['current_region'],
      );
      
      if (results.isNotEmpty) {
        final savedRegion = results.first['value'] as String;
        await changeRegion(savedRegion);
      }
    } catch (e) {
      print('Error cargando configuración: $e');
    }
  }
  
  /// Método para optimizar base de datos
  Future<void> optimizeDatabase() async {
    final db = await database;
    
    try {
      // Ejecutar VACUUM para optimizar el archivo de base de datos
      await db.execute('VACUUM');
      
      // Actualizar estadísticas de la base de datos
      await db.execute('ANALYZE');
      
      print('Base de datos optimizada');
    } catch (e) {
      print('Error optimizando base de datos: $e');
    }
  }
  
  /// Método para resetear estadísticas de APIs
  Future<void> resetAPIStats() async {
    final db = await database;
    
    try {
      await db.delete('api_stats');
      _apiStats.clear();
      
      print('Estadísticas de APIs reseteadas');
    } catch (e) {
      print('Error reseteando estadísticas: $e');
    }
  }
  
  /// Dispose del servicio
  Future<void> dispose() async {
    try {
      await _database?.close();
      _database = null;
      _sessionCache.clear();
      _apiStats.clear();
      
      print('Servicio de códigos de barras cerrado correctamente');
    } catch (e) {
      print('Error cerrando servicio: $e');
    }
  }
}