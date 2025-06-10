// Al inicio de barcode_service.dart:
import 'dart:async';
import 'dart:convert';
// Para la simulación aleatoria
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart'; // Añade esta importación para CameraController
// Añade esta importación para XFile
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/product_model.dart';
import '../screens/inventory/barcode_scanner_screen.dart'; // Importa esta pantalla
// Asegúrate de tener esta clase

/// Servicio para gestionar escaneo y procesamiento de códigos de barras
class BarcodeService {
  // Singleton para acceso global al servicio
  static final BarcodeService _instance = BarcodeService._internal();
  factory BarcodeService() => _instance;
  BarcodeService._internal();

  // Base de datos local para productos escaneados
  Database? _database;
  
  // API URL para Open Food Facts
  final String _apiBaseUrl = 'https://world.openfoodfacts.org/api/v0/product/';
  
  // Inicializar la base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  // Crear e inicializar la base de datos
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(documentsDirectory.path, 'barcode_products.db');
    
    return await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products(
            barcode TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  /// Método para verificar y solicitar permisos de cámara
  Future<bool> startBarcodeScannerCamera() async {
    try {
      // Verificar y solicitar permiso de cámara
      final cameraStatus = await Permission.camera.request();
      return cameraStatus.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('Error al solicitar permisos de cámara: $e');
      }
      return false;
    }
  }

  // Implementar métodos de permisos requeridos
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

// Nuevo método en BarcodeService para escanear desde una imagen de la cámara
Future<String?> scanBarcodeFromImage(CameraController cameraController) async {
  try {
    // Captura una imagen de la cámara
    final XFile image = await cameraController.takePicture();
    
    // Aquí deberías implementar el análisis de la imagen para detectar códigos de barras
    // Puedes usar paquetes como 'google_ml_kit' o 'mobile_scanner' para este propósito
    
    // Como este es un código de ejemplo, devolveremos un código de barras simulado
    // En una implementación real, deberías analizar la imagen y devolver el código detectado
    
    // Simular que se detectó un código
    final demoBarcode = [
      '8410188012912', // Zumo Don Simón
     '8480000118127', // Leche Hacendado
     '8410668004672', // Galletas María
     '8480000591470', // Pan de molde
     '8480000503199',  // Agua mineral
   ][DateTime.now().second % 5]; // Usar los segundos actuales para variar el resultado
   
   return demoBarcode;
 } catch (e) {
   print('Error al escanear desde imagen: $e');
   return null;
 }
}

// Modificar el método existente scanBarcode para usar el método directo cuando estamos en la pantalla de escáner
Future<String?> scanBarcode(BuildContext context) async {
 try {
   // Verifica si estamos en la pantalla de BarcodeScannerScreen
   // Si es así, no abrimos otra pantalla
   if (ModalRoute.of(context)?.settings.name == '/barcode_scanner' || 
       context.widget is BarcodeScannerScreen) {
     // Si ya estamos en la pantalla de escaneo, simplemente escaneamos una imagen
     // Para la demostración, devolvemos un código simulado
     final demoBarcode = [
       '8410188012912', // Zumo Don Simón
       '8480000118127', // Leche Hacendado
       '8410668004672', // Galletas María
       '8480000591470', // Pan de molde
       '8480000503199',  // Agua mineral
     ][DateTime.now().second % 5]; // Usar los segundos actuales para variar el resultado
     
     return demoBarcode;
   }
   
   // Si no estamos en la pantalla de escaneo, seguimos con el flujo normal
   // Verificar permisos de cámara primero
   if (!await checkCameraPermission()) {
     final permissionGranted = await requestCameraPermission();
     if (!permissionGranted) {
       // Si no se conceden permisos, mostrar mensaje y salir
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Se necesita acceso a la cámara para escanear códigos'),
           backgroundColor: Colors.red,
           duration: Duration(seconds: 2),
         ),
       );
       return null;
     }
   }
   
   // Navegar a la pantalla de escaneo
   String? barcodeValue;
   try {
     barcodeValue = await Navigator.push<String>(
       context,
       MaterialPageRoute(
         builder: (context) => const BarcodeScannerScreen(),
         settings: const RouteSettings(name: '/barcode_scanner'),
       ),
     );
   } catch (navigationError) {
     print('Error durante la navegación/escaneo: $navigationError');
     return null;
   }
   
   // Si el usuario canceló o no se detectó un código, retornar null
   if (barcodeValue == null || barcodeValue.isEmpty) {
     return null;
   }
   
   return barcodeValue;
 } catch (e) {
   print('Error general al escanear código de barras: $e');
   return null;
 }
}
  /// Método para obtener información de producto desde un código de barras
  /// Intenta primero en la base de datos local, si no existe, consulta la API
  Future<Map<String, dynamic>?> getProductInfoFromBarcode(String barcode) async {
    try {
      // Primero buscar en la base de datos local
      final localProduct = await _getLocalProduct(barcode);
      if (localProduct != null) {
        if (kDebugMode) {
          print('Producto encontrado en base de datos local: $barcode');
        }
        return jsonDecode(localProduct['data']);
      }
      
      // Si no está en la base local, buscar en Open Food Facts
      final apiProduct = await _fetchProductFromAPI(barcode);
      if (apiProduct != null) {
        // Guardar en la base de datos local para futuros accesos
        await _saveLocalProduct(barcode, apiProduct);
        return apiProduct;
      }
      
      // Finalmente, buscar en nuestra base de datos interna
      return _productDatabase[barcode];
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener información del producto: $e');
      }
      return null;
    }
  }
  
  /// Obtener producto de la base de datos local
  Future<Map<String, dynamic>?> _getLocalProduct(String barcode) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    
    if (maps.isNotEmpty) {
      // Verificar si el producto está actualizado (no más de 30 días)
      final timestamp = maps.first['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final thirtyDaysInMillis = 30 * 24 * 60 * 60 * 1000;
      
      if (now - timestamp < thirtyDaysInMillis) {
        return maps.first;
      } else {
        // Si el producto es muy antiguo, eliminarlo
        await db.delete(
          'products',
          where: 'barcode = ?',
          whereArgs: [barcode],
        );
        return null;
      }
    }
    
    return null;
  }
  
  /// Guardar producto en la base de datos local
  Future<void> _saveLocalProduct(String barcode, Map<String, dynamic> productData) async {
    final db = await database;
    await db.insert(
      'products',
      {
        'barcode': barcode,
        'data': jsonEncode(productData),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Obtener información del producto desde la API de Open Food Facts
  Future<Map<String, dynamic>?> _fetchProductFromAPI(String barcode) async {
  try {
    // Añadir un timeout a la petición para evitar esperas largas
    final response = await http.get(Uri.parse('$_apiBaseUrl$barcode.json'))
      .timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      
      // Verificar si el producto existe
      if (jsonData['status'] == 1) {
        final productData = jsonData['product'];
        
        // Extraer información relevante
        final name = productData['product_name'] ?? 
                    productData['product_name_es'] ?? 
                    productData['product_name_en'] ??
                    productData['generic_name'] ??
                    productData['generic_name_es'] ??
                    'Producto ${barcode.substring(0, 4)}';
        
        // Mejora: Asegurarse de que el nombre no esté vacío
        final finalName = name.toString().trim().isEmpty 
          ? 'Producto ${barcode.substring(0, 4)}'
          : name.toString();
        
        // Determinar la categoría
        String category = 'Otros';
        if (productData['categories_tags'] != null && productData['categories_tags'] is List && productData['categories_tags'].isNotEmpty) {
          final categories = productData['categories_tags'] as List;
          // Intentar encontrar una categoría en español
          for (final cat in categories) {
            if (cat.toString().startsWith('es:')) {
              category = cat.toString().substring(3);
              break;
            }
          }
          // Si no hay categoría en español, usar la primera
          if (category == 'Otros' && categories.isNotEmpty) {
            final firstCategory = categories.first.toString();
            if (firstCategory.contains(':')) {
              category = firstCategory.split(':').last;
            } else {
              category = firstCategory;
            }
          }
        }
        
        // Normalizar la categoría
        category = _normalizeCategory(category);
        
        // Determinar cantidad y unidad
        int quantity = 1;
        String unit = 'unidades';
        
        if (productData['quantity'] != null && productData['quantity'].toString().isNotEmpty) {
          final quantityStr = productData['quantity'].toString();
          
          // Extraer número y unidad (ej: "250 g", "1 L", "6 uds")
          final RegExp regExp = RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z]+)?');
          final match = regExp.firstMatch(quantityStr);
          
          if (match != null) {
            quantity = int.tryParse(match.group(1) ?? '1') ?? 1;
            unit = match.group(2)?.toLowerCase() ?? 'unidades';
            
            // Normalizar unidades
            if (unit == 'g' || unit == 'gr' || unit == 'grs' || unit == 'gramos') {
              unit = 'g';
            } else if (unit == 'kg' || unit == 'kgs' || unit == 'kilos' || unit == 'kilogramos') {
              unit = 'kg';
            } else if (unit == 'ml' || unit == 'mililitros') {
              unit = 'ml';
            } else if (unit == 'l' || unit == 'lt' || unit == 'litros') {
              unit = 'L';
            } else if (unit == 'uds' || unit == 'unid' || unit == 'u') {
              unit = 'unidades';
            }
          }
        }
        
        // Estimar días hasta caducidad según la categoría
        final expiryDays = _estimateExpiryDays(category);
        
        // Sugerir ubicación basada en la categoría
        final location = suggestLocationForCategory(category);
        
        // Construir objeto de respuesta
        final processedData = {
          'name': finalName,
          'quantity': quantity,
          'maxQuantity': quantity,
          'unit': unit,
          'category': category,
          'expiryDays': expiryDays,
          'defaultLocation': location,
          'imageUrl': productData['image_url'] ?? '',
          'barcode': barcode,
          'apiSource': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        
        return processedData;
      }
    }
    
    // Si no encontramos nada, buscar en la base de datos interna
    return _productDatabase[barcode];
  } catch (e) {
    if (kDebugMode) {
      print('Error al consultar la API: $e');
    }
    // En caso de error, intentar con la base de datos interna
    return _productDatabase[barcode];
  }
}

// Método para calcular días hasta caducidad
int getDaysUntilExpiry(DateTime expiryDate) {
  final now = DateTime.now();
  final difference = expiryDate.difference(now).inDays;
  return difference;
}

// Método para determinar el color según la proximidad de la caducidad
Color getExpiryIndicatorColor(DateTime expiryDate) {
  final daysUntilExpiry = getDaysUntilExpiry(expiryDate);
  
  if (daysUntilExpiry < 0) {
    return Colors.red; // Caducado
  } else if (daysUntilExpiry <= 3) {
    return Colors.orange; // Próximo a caducar
  } else if (daysUntilExpiry <= 7) {
    return Colors.yellow; // Precaución
  } else {
    return Colors.green; // Bien
  }
}
  
  // Normalizar categoría
  String _normalizeCategory(String category) {
    // Convertir primera letra a mayúscula y eliminar espacios al inicio/final
    category = category.trim();
    if (category.isEmpty) return 'Otros';
    
    // Transformar categorías en inglés comunes
    final Map<String, String> categoryMap = {
      'dairy': 'Lácteos',
      'milk': 'Lácteos',
      'cheese': 'Lácteos',
      'yogurt': 'Lácteos',
      'meat': 'Carnes',
      'beef': 'Carnes',
      'pork': 'Carnes',
      'chicken': 'Carnes',
      'fish': 'Pescados',
      'seafood': 'Pescados',
      'vegetable': 'Verduras',
      'vegetables': 'Verduras',
      'fruit': 'Frutas',
      'fruits': 'Frutas',
      'cereal': 'Cereales',
      'cereals': 'Cereales',
      'grain': 'Cereales',
      'grains': 'Cereales',
      'snack': 'Snacks',
      'snacks': 'Snacks',
      'beverage': 'Bebidas',
      'beverages': 'Bebidas',
      'drink': 'Bebidas',
      'drinks': 'Bebidas',
      'frozen': 'Congelados',
      'bakery': 'Panadería',
      'bread': 'Panadería',
      'sweet': 'Dulces',
      'sweets': 'Dulces',
      'candy': 'Dulces',
      'spice': 'Condimentos',
      'spices': 'Condimentos',
      'sauce': 'Condimentos',
      'sauces': 'Condimentos',
      'oil': 'Condimentos',
      'oils': 'Condimentos',
      'canned': 'Conservas',
      'conserve': 'Conservas',
    };
    
    // Intentar encontrar alguna coincidencia
    final lowercaseCategory = category.toLowerCase();
    for (final entry in categoryMap.entries) {
      if (lowercaseCategory.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Si es una categoría en inglés que no reconocemos, capitalizar la primera letra
    if (category.length > 1) {
      return category[0].toUpperCase() + category.substring(1);
    }
    
    return category;
  }
  
  // Estimar días hasta caducidad según la categoría
  int _estimateExpiryDays(String category) {
    switch (category.toLowerCase()) {
      case 'lácteos':
        return 7;
      case 'frutas':
      case 'verduras':
        return 5;
      case 'carnes':
        return 3;
      case 'pescados':
        return 2;
      case 'panadería':
        return 4;
      case 'congelados':
        return 60;
      case 'conservas':
        return 365;
      case 'cereales':
      case 'snacks':
        return 90;
      case 'condimentos':
        return 180;
      default:
        return 15;
    }
  }

  Future<Product?> createProductFromBarcode(String barcode) async {
  try {
    final productInfo = await getProductInfoFromBarcode(barcode);
    
    if (productInfo == null) {
      return null;
    }
    
    // Calcular fecha de caducidad basada en los días típicos
    final expiryDate = DateTime.now().add(Duration(days: productInfo['expiryDays'] as int));
    
    // Obtener la ubicación recomendada o usar valor por defecto
    final location = productInfo['defaultLocation'] as String? ?? 'Nevera';
    
    // URL de imagen si existe
    final imageUrl = productInfo.containsKey('imageUrl') ? productInfo['imageUrl'] as String : '';
    
    // Generar un ID único para el producto
    final productId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Crear un nuevo producto con la información
    return Product(
      id: productId, 
      name: productInfo['name'] as String,
      quantity: productInfo['quantity'] as int,
      maxQuantity: (productInfo['maxQuantity'] as int?) ?? productInfo['quantity'] as int,
      unit: productInfo['unit'] as String,
      expiryDate: expiryDate,
      imageUrl: imageUrl,
      category: productInfo['category'] as String,
      location: location,
      userId: '', // Se asignará automáticamente al guardar
    );
  } catch (e) {
    print('Error al crear producto desde código de barras: $e');
    return null;
  }
}
  
  /// Método para buscar un producto por nombre en nuestra base de datos
  Future<List<String>> searchBarcodesByProductName(String name) async {
    final normalizedName = name.toLowerCase();
    final db = await database;
    
    // Buscar en la base de datos local
    final List<Map<String, dynamic>> maps = await db.query('products');
    final matchingCodes = <String>[];
    
    // Filtrar por nombre
    for (final product in maps) {
      final data = jsonDecode(product['data']) as Map<String, dynamic>;
      final productName = (data['name'] as String).toLowerCase();
      
      if (productName.contains(normalizedName)) {
        matchingCodes.add(product['barcode'] as String);
      }
    }
    
    // También buscar en la base de datos interna
    for (final entry in _productDatabase.entries) {
      final productName = (entry.value['name'] as String).toLowerCase();
      if (productName.contains(normalizedName)) {
        matchingCodes.add(entry.key);
      }
    }
    
    return matchingCodes;
  }
  
  /// Método para guardar un nuevo código de barras en la base de datos local
  Future<bool> saveProductBarcode(String barcode, Map<String, dynamic> productInfo) async {
    try {
      // Validar información mínima
      if (!productInfo.containsKey('name') || 
          !productInfo.containsKey('quantity') ||
          !productInfo.containsKey('unit') ||
          !productInfo.containsKey('category')) {
        return false;
      }
      
      // Asegurarse de que quantity y maxQuantity sean enteros
      final int quantity = productInfo['quantity'] is int
          ? productInfo['quantity']
          : (productInfo['quantity'] as num).toInt();
      
      final int maxQuantity = productInfo.containsKey('maxQuantity')
          ? (productInfo['maxQuantity'] is int
              ? productInfo['maxQuantity']
              : (productInfo['maxQuantity'] as num).toInt())
          : quantity;
      
      // Crear objeto para guardar
      final dataToSave = {
        'name': productInfo['name'],
        'quantity': quantity,
        'maxQuantity': maxQuantity,
        'unit': productInfo['unit'],
        'category': productInfo['category'],
        'expiryDays': productInfo['expiryDays'] ?? 7,
        'defaultLocation': productInfo['defaultLocation'] ?? 'Nevera',
        'imageUrl': productInfo['imageUrl'] ?? '',
        'userAdded': true,
      };
      
      // Guardar en la base de datos local
      await _saveLocalProduct(barcode, dataToSave);
      
      // También actualizar la base de datos en memoria
      _productDatabase[barcode] = Map<String, dynamic>.from(dataToSave);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar código de barras: $e');
      }
      return false;
    }
  }
  
  /// Método para obtener todas las ubicaciones disponibles
  List<String> getAvailableLocations() {
    return [
      'Nevera',
      'Congelador',
      'Despensa',
      'Armario',
      'Especias',
    ];
  }
  
  /// Método para sugerir una ubicación basada en la categoría del producto
  String suggestLocationForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'lácteos':
      case 'carnes':
      case 'pescados':
      case 'frutas':
      case 'verduras':
        return 'Nevera';
      case 'congelados':
        return 'Congelador';
      case 'condimentos':
        return 'Especias';
      case 'snacks':
      case 'cereales':
        return 'Armario';
      default:
        return 'Despensa';
    }
  }
  
  /// Método para exportar la base de datos a JSON
  Future<String> exportDatabaseToJson() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    
    // Construir mapa de resultados
    final Map<String, dynamic> exportData = {};
    
    // Añadir productos de la base de datos local
    for (final product in maps) {
      exportData[product['barcode'] as String] = jsonDecode(product['data']);
    }
    
    // Añadir productos de la base de datos interna
    exportData.addAll(_productDatabase);
    
    return jsonEncode(exportData);
  }
  
  /// Método para importar base de datos desde JSON
  Future<bool> importDatabaseFromJson(String jsonData) async {
    try {
      final Map<String, dynamic> importedData = jsonDecode(jsonData);
      
      // Limpiar base de datos existente
      final db = await database;
      await db.delete('products');
      
      // Importar cada producto
      for (final entry in importedData.entries) {
        final barcode = entry.key;
        final productData = entry.value;
        
        await _saveLocalProduct(barcode, productData is Map ? 
                              Map<String, dynamic>.from(productData) : 
                              {'data': productData});
      }
      
      // También actualizar la base de datos en memoria
      _productDatabase.clear();
      for (final entry in importedData.entries) {
        if (entry.value is Map) {
          _productDatabase[entry.key] = Map<String, dynamic>.from(entry.value);
        }
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error al importar base de datos: $e');
      }
      return false;
    }
  }
  
  /// Método para eliminar un producto de la base de datos local
  Future<bool> deleteLocalProduct(String barcode) async {
    try {
      final db = await database;
      await db.delete(
        'products',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
      
      // También eliminarlo de la base de datos en memoria
      _productDatabase.remove(barcode);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error al eliminar producto: $e');
      }
      return false;
    }
  }
  
  /// Método para obtener todos los productos de la base de datos local
  Future<List<Map<String, dynamic>>> getAllLocalProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    
    final result = <Map<String, dynamic>>[];
    for (final product in maps) {
      final data = jsonDecode(product['data']);
      if (data is Map) {
        final productWithBarcode = Map<String, dynamic>.from(data);
        productWithBarcode['barcode'] = product['barcode'];
        result.add(productWithBarcode);
      }
    }
    
    return result;
  }
  
  // Base de datos simulada de productos por código de barras
  // Se mantendrá para compatibilidad y como respaldo
  final Map<String, Map<String, dynamic>> _productDatabase = {
    '8480000123456': {
      'name': 'Leche Entera',
      'quantity': 1,
      'maxQuantity': 1,
      'unit': 'L',
      'category': 'Lácteos',
      'expiryDays': 7,
      'defaultLocation': 'Nevera',
    },
    '8410188012349': {
      'name': 'Yogur Natural',
      'quantity': 125,
      'maxQuantity': 125,
      'unit': 'g',
      'category': 'Lácteos',
      'expiryDays': 21,
      'defaultLocation': 'Nevera',
    },
    // Mantener los demás productos que ya tienes en el código original
    // ...
  };
}