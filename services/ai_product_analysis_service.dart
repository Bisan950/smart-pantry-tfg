// lib/services/ai_product_analysis_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/product_model.dart';

class AIProductAnalysisService {
  static final AIProductAnalysisService _instance = AIProductAnalysisService._internal();
  factory AIProductAnalysisService() => _instance;
  AIProductAnalysisService._internal();
  
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String _modelName = 'gemini-1.5-pro';

  /// 🍎 Analizar producto desde imagen y crear producto completo
  Future<Product?> analyzeProductFromImage(File imageFile) async {
    try {
      // Validación 1: API Key
      if (_apiKey.isEmpty) {
        print('❌ API key no configurada para análisis de productos');
        throw Exception('API key de Gemini no configurada. Verifica tu archivo .env');
      }
  
      // Validación 2: Archivo de imagen
      if (!await imageFile.exists()) {
        print('❌ El archivo de imagen no existe');
        throw Exception('El archivo de imagen no existe o no es accesible');
      }
  
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        print('❌ El archivo de imagen está vacío');
        throw Exception('El archivo de imagen está vacío');
      }
  
      if (fileSize > 20 * 1024 * 1024) { // 20MB límite
        print('❌ El archivo de imagen es demasiado grande: ${fileSize} bytes');
        throw Exception('El archivo de imagen es demasiado grande (máximo 20MB)');
      }
  
      print('📸 Iniciando análisis de producto por imagen...');
      print('📊 Tamaño de archivo: ${fileSize} bytes');
  
      final bytes = await imageFile.readAsBytes();
      
      final prompt = '''
Analiza esta imagen de un producto alimentario y crea información completa para añadirlo a un inventario doméstico.

INSTRUCCIONES CRÍTICAS:
1. Identifica el producto principal en la imagen
2. Determina la categoría más apropiada
3. Estima la cantidad y unidad basándote en lo que ves
4. Sugiere una ubicación de almacenamiento lógica
5. Estima valores nutricionales aproximados para una porción típica
6. Sugiere una fecha de caducidad razonable desde hoy

CATEGORÍAS DISPONIBLES:
- Lácteos, Frutas, Verduras, Carnes, Pescados, Granos, Bebidas, Snacks, Congelados, Panadería, Cereales, Condimentos, Conservas, Dulces

UBICACIONES DISPONIBLES:
- Nevera, Despensa, Congelador, Armario, Especias

UNIDADES DISPONIBLES:
- unidades, g, kg, ml, L, paquete, lata, botella

FORMATO DE RESPUESTA (JSON válido únicamente):
{
  "product_info": {
    "name": "nombre_descriptivo_del_producto",
    "category": "categoría_de_la_lista",
    "estimated_quantity": número_estimado,
    "unit": "unidad_apropiada",
    "suggested_location": "ubicación_de_la_lista",
    "estimated_expiry_days": número_días_desde_hoy,
    "confidence": número_entre_0_y_1
  },
  "nutritional_info": {
    "serving_size": gramos_por_porción,
    "serving_unit": "descripción_porción",
    "calories": calorías_estimadas,
    "proteins": gramos_proteína,
    "carbohydrates": gramos_carbohidratos,
    "fats": gramos_grasas,
    "fiber": gramos_fibra_opcional,
    "sugar": gramos_azúcar_opcional,
    "sodium": miligramos_sodio_opcional,
    "is_estimation": true
  },
  "additional_info": {
    "detected_items": ["lista", "de", "elementos", "detectados"],
    "quality_assessment": "descripción_del_estado_aparente",
    "storage_tips": "consejos_de_almacenamiento",
    "usage_suggestions": ["sugerencias", "de", "uso"]
  }
}

IMPORTANTE:
- Si no puedes identificar claramente el producto, devuelve confidence: 0.0
- Sé conservador con las estimaciones nutricionales
- Para productos frescos (frutas/verduras), estima peso individual
- Para productos empaquetados, estima el contenido total
- Responde ÚNICAMENTE con el JSON, sin explicaciones adicionales
''';

      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3, // Balanceado para creatividad y precisión
          topP: 0.8,
          topK: 40,
          maxOutputTokens: 2048,
        ),
      );
  
      print('🤖 Enviando imagen a Gemini para análisis...');
      
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ])
      ];
  
      // Validación 4: Llamada a la API con manejo específico de errores
      GenerateContentResponse response;
      try {
        response = await model.generateContent(content);
        print('✅ Respuesta recibida de Gemini');
      } catch (e) {
        print('❌ Error en la llamada a Gemini API: $e');
        if (e.toString().contains('API_KEY_INVALID')) {
          throw Exception('La API key de Gemini no es válida. Verifica tu configuración.');
        } else if (e.toString().contains('QUOTA_EXCEEDED')) {
          throw Exception('Se ha excedido la cuota de la API de Gemini.');
        } else if (e.toString().contains('PERMISSION_DENIED')) {
          throw Exception('Permisos denegados para la API de Gemini.');
        } else {
          throw Exception('Error de conectividad con Gemini: $e');
        }
      }
  
      if (response.candidates.isEmpty) {
        print('❌ Sin respuesta de Gemini para análisis de producto');
        throw Exception('Gemini no pudo procesar la imagen. Intenta con una imagen más clara.');
      }
  
      final responseText = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();
  
      print('📋 Respuesta recibida de Gemini');
      print('Respuesta: $responseText');
  
      // Extraer y parsear JSON
      final jsonStr = _extractJsonFromResponse(responseText);
      final analysisData = jsonDecode(jsonStr);
  
      if (analysisData is Map<String, dynamic>) {
        return _createProductFromAnalysis(analysisData);
      }
  
      throw Exception('Respuesta de IA en formato inválido');
      
    } catch (e) {
      print('❌ Error analizando producto por imagen: $e');
      // Re-lanzar la excepción para que llegue al UI con el mensaje específico
      rethrow;
    }
  }

  /// 🔧 Extraer JSON de la respuesta de IA
  String _extractJsonFromResponse(String response) {
    try {
      // Intentar decodificar directamente
      jsonDecode(response);
      return response;
    } catch (_) {
      // Buscar JSON en la respuesta
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0);
        if (jsonStr != null) {
          try {
            jsonDecode(jsonStr);
            return jsonStr;
          } catch (_) {}
        }
      }
      
      // Limpiar markdown si existe
      String cleaned = response;
      if (cleaned.contains('```json')) {
        cleaned = cleaned.split('```json').last.split('```').first.trim();
      } else if (cleaned.contains('```')) {
        cleaned = cleaned.split('```').where((part) => part.contains('{') && part.contains('}')).join().trim();
      }
      
      try {
        jsonDecode(cleaned);
        return cleaned;
      } catch (_) {
        print('⚠️ No se pudo extraer JSON válido de la respuesta');
        return '{"product_info": {"confidence": 0.0}, "error": "invalid_response"}';
      }
    }
  }

  /// 🔧 Crear producto desde análisis
  Product? _createProductFromAnalysis(Map<String, dynamic> data) {
    try {
      final productInfo = data['product_info'] as Map<String, dynamic>?;
      if (productInfo == null) {
        print('⚠️ No se encontró información del producto');
        return null;
      }

      // Verificar confianza mínima
      final confidence = (productInfo['confidence'] as num?)?.toDouble() ?? 0.0;
      print('🎯 Confianza del análisis: $confidence');
      if (confidence < 0.2) { // Reducir de 0.4 a 0.2
        print('⚠️ Confianza muy baja: $confidence');
        return null;
      }

      // Extraer información del producto
      final name = productInfo['name'] as String? ?? 'Producto desconocido';
      final category = productInfo['category'] as String? ?? 'Otros';
      final quantity = (productInfo['estimated_quantity'] as num?)?.toInt() ?? 1;
      final unit = productInfo['unit'] as String? ?? 'unidades';
      final location = productInfo['suggested_location'] as String? ?? 'Despensa';
      final expiryDays = (productInfo['estimated_expiry_days'] as num?)?.toInt() ?? 7;

      // Extraer información nutricional
      NutritionalInfo? nutritionalInfo;
      final nutritionalData = data['nutritional_info'] as Map<String, dynamic>?;
      if (nutritionalData != null) {
        nutritionalInfo = NutritionalInfo(
          servingSize: (nutritionalData['serving_size'] as num?)?.toDouble(),
          servingUnit: nutritionalData['serving_unit'] as String?,
          calories: (nutritionalData['calories'] as num?)?.toInt(),
          proteins: (nutritionalData['proteins'] as num?)?.toDouble(),
          carbohydrates: (nutritionalData['carbohydrates'] as num?)?.toDouble(),
          fats: (nutritionalData['fats'] as num?)?.toDouble(),
          fiber: (nutritionalData['fiber'] as num?)?.toDouble(),
          sugar: (nutritionalData['sugar'] as num?)?.toDouble(),
          sodium: (nutritionalData['sodium'] as num?)?.toDouble(),
        );
      }

      // Calcular fecha de caducidad
      final expiryDate = DateTime.now().add(Duration(days: expiryDays));

      print('✅ Producto creado desde análisis de IA');
      print('Nombre: $name, Categoría: $category, Cantidad: $quantity $unit');

      return Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        quantity: quantity,
        unit: unit,
        category: category,
        location: location,
        imageUrl: '', // Se añadirá después si es necesario
        expiryDate: expiryDate,
        userId: '', // Se asignará cuando se guarde
        nutritionalInfo: nutritionalInfo,
        notes: 'Producto identificado automáticamente por IA', // Nota especial
      );
    } catch (e) {
      print('❌ Error creando producto desde análisis: $e');
      return null;
    }
  }

  /// 🍅 Analizar múltiples productos en una imagen
  Future<List<Product>> analyzeMultipleProductsFromImage(File imageFile) async {
    try {
      // Validaciones tempranas
      if (_apiKey.isEmpty) {
        print('❌ API key no configurada');
        throw Exception('API key de Gemini no configurada. Verifica tu archivo .env');
      }
  
      if (!await imageFile.exists()) {
        throw Exception('El archivo de imagen no existe o no es accesible');
      }
  
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        throw Exception('El archivo de imagen está vacío');
      }
  
      print('📸 Analizando múltiples productos en imagen...');
      print('📊 Tamaño de archivo: ${fileSize} bytes');
  
      final bytes = await imageFile.readAsBytes();
      
      final prompt = '''
Analiza esta imagen e identifica TODOS los productos alimentarios visibles.

Crea una lista de productos individuales que se pueden añadir a un inventario doméstico.

Formato JSON:
{
  "products": [
    {
      "name": "producto1",
      "category": "categoría",
      "estimated_quantity": 1,
      "unit": "unidades",
      "suggested_location": "Nevera",
      "estimated_expiry_days": 7,
      "confidence": 0.8
    },
    // ... más productos
  ],
  "scene_description": "descripción_general_de_la_imagen"
}

CATEGORÍAS: Lácteos, Frutas, Verduras, Carnes, Pescados, Granos, Bebidas, Snacks, Congelados, Panadería, Cereales, Condimentos, Conservas, Dulces
UBICACIONES: Nevera, Despensa, Congelador, Armario, Especias
UNIDADES: unidades, g, kg, ml, L, paquete, lata, botella
''';

      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          topP: 0.8,
          maxOutputTokens: 3072,
        ),
      );

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await model.generateContent(content);

      if (response.candidates.isEmpty) return [];

      final responseText = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();

      final jsonStr = _extractJsonFromResponse(responseText);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final products = <Product>[];
      final productsList = data['products'] as List<dynamic>? ?? [];

      for (final productData in productsList) {
        if (productData is Map<String, dynamic>) {
          final confidence = (productData['confidence'] as num?)?.toDouble() ?? 0.0;
          
          if (confidence >= 0.4) {
            final product = Product(
              id: DateTime.now().millisecondsSinceEpoch.toString() + products.length.toString(),
              name: productData['name'] as String? ?? 'Producto',
              quantity: (productData['estimated_quantity'] as num?)?.toInt() ?? 1,
              unit: productData['unit'] as String? ?? 'unidades',
              category: productData['category'] as String? ?? 'Otros',
              location: productData['suggested_location'] as String? ?? 'Despensa',
              imageUrl: '',
              expiryDate: DateTime.now().add(Duration(
                days: (productData['estimated_expiry_days'] as num?)?.toInt() ?? 7,
              )),
              userId: '',
              notes: 'Identificado automáticamente por IA',
            );
            
            products.add(product);
          }
        }
      }

      print('✅ ${products.length} productos identificados en la imagen');
      return products;
    } catch (e) {
      print('❌ Error analizando múltiples productos: $e');
      rethrow; // Re-lanzar para que llegue al UI
    }
  }

  /// 🧪 Probar conexión con Gemini Vision
  Future<bool> testConnection() async {
    try {
      print('🔧 Probando conexión con Gemini Vision para análisis de productos...');
      
      if (_apiKey.isEmpty) {
        print('❌ API key no configurada');
        return false;
      }
      
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );
      
      final response = await model.generateContent([
        Content.text('Responde únicamente "OK" si puedes analizar productos en imágenes')
      ]);
      
      if (response.candidates.isEmpty) {
        print('❌ Sin respuesta de Gemini');
        return false;
      }
      
      final text = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();
      
      print('✅ Conexión exitosa con Gemini para análisis de productos');
      print('Respuesta: $text');
      
      return true;
    } catch (e) {
      print('❌ Error probando conexión: $e');
      return false;
    }
  }

  /// 📊 Obtener estadísticas de productos analizados
  Map<String, dynamic> getAnalysisStats() {
    return {
      'total_analyzed': 0, // Implementar contador si es necesario
      'success_rate': 0.85, // Ejemplo
      'most_common_categories': [
        'Frutas',
        'Verduras',
        'Lácteos',
      ],
      'api_available': _apiKey.isNotEmpty,
    };
  }
}