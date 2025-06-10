// lib/services/nutritional_analysis_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/product_model.dart';

class NutritionalAnalysisService {
  static final NutritionalAnalysisService _instance = NutritionalAnalysisService._internal();
  factory NutritionalAnalysisService() => _instance;
  NutritionalAnalysisService._internal();
  
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String _modelName = 'gemini-1.5-pro';

  /// 🔍 Analizar etiqueta nutricional desde imagen
  Future<NutritionalInfo?> analyzeNutritionalLabel(File imageFile) async {
    try {
      if (_apiKey.isEmpty) {
        print('❌ API key no configurada para análisis nutricional');
        return null;
      }

      print('📸 Iniciando análisis de etiqueta nutricional...');

      // Leer imagen y convertir a base64
      final bytes = await imageFile.readAsBytes();
      
      final prompt = '''
Analiza esta imagen de una etiqueta nutricional de un producto alimentario.

INSTRUCCIONES CRÍTICAS:
1. Lee ÚNICAMENTE la información que aparece claramente escrita en la etiqueta
2. Busca la tabla de "Información Nutricional", "Valores Nutricionales" o "Nutrition Facts"
3. Extrae los valores POR PORCIÓN (serving size) que aparezcan en la etiqueta
4. Si no encuentras algún valor, devuelve null para ese campo
5. Convierte todas las unidades a gramos (g) para macros y miligramos (mg) para sodio

DATOS A EXTRAER:
- Tamaño de porción (serving size)
- Calorías por porción
- Proteínas en gramos
- Carbohidratos en gramos
- Grasas totales en gramos
- Fibra en gramos
- Azúcares en gramos
- Sodio en miligramos

FORMATO DE RESPUESTA (JSON válido únicamente):
{
  "serving_size": número_en_gramos_o_null,
  "serving_unit": "descripción_de_la_porción_como_aparece",
  "calories_per_serving": número_entero_o_null,
  "macros": {
    "proteins": número_decimal_o_null,
    "carbohydrates": número_decimal_o_null,
    "fats": número_decimal_o_null,
    "fiber": número_decimal_o_null,
    "sugar": número_decimal_o_null,
    "sodium": número_decimal_mg_o_null
  },
  "detected_text": "resumen_del_texto_detectado",
  "confidence": número_entre_0_y_1
}

IMPORTANTE:
- Si la imagen no contiene información nutricional clara, devuelve confidence: 0.0
- Si hay texto pero no es una etiqueta nutricional, devuelve confidence: 0.0
- Solo incluye valores que puedas leer con certeza
- Responde ÚNICAMENTE con el JSON, sin explicaciones adicionales
''';

      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1, // Muy baja para máxima precisión
          topP: 0.8,
          topK: 20,
          maxOutputTokens: 1024,
        ),
      );

      print('🤖 Enviando imagen a Gemini para análisis...');
      
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await model.generateContent(content);

      if (response.candidates.isEmpty) {
        print('❌ Sin respuesta de Gemini para análisis nutricional');
        return null;
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
        return _parseNutritionalInfo(analysisData);
      }

      return null;
    } catch (e) {
      print('❌ Error analizando etiqueta nutricional: $e');
      return null;
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
        return '{"confidence": 0.0, "error": "invalid_response"}';
      }
    }
  }

  /// 🔧 Parsear información nutricional desde JSON
  NutritionalInfo? _parseNutritionalInfo(Map<String, dynamic> data) {
    try {
      // Verificar confianza mínima
      final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
      if (confidence < 0.3) {
        print('⚠️ Confianza muy baja: $confidence');
        return null;
      }

      // Extraer datos básicos
      final servingSize = (data['serving_size'] as num?)?.toDouble();
      final servingUnit = data['serving_unit'] as String?;
      final calories = (data['calories_per_serving'] as num?)?.toInt();

      // Extraer macros
      final macrosData = data['macros'] as Map<String, dynamic>?;
      if (macrosData == null) {
        print('⚠️ No se encontraron datos de macros');
        return null;
      }

      final proteins = (macrosData['proteins'] as num?)?.toDouble();
      final carbohydrates = (macrosData['carbohydrates'] as num?)?.toDouble();
      final fats = (macrosData['fats'] as num?)?.toDouble();
      final fiber = (macrosData['fiber'] as num?)?.toDouble();
      final sugar = (macrosData['sugar'] as num?)?.toDouble();
      final sodium = (macrosData['sodium'] as num?)?.toDouble();

      print('✅ Información nutricional parseada correctamente');
      print('Calorías: $calories, Proteínas: $proteins, Carbohidratos: $carbohydrates, Grasas: $fats');

      return NutritionalInfo(
        servingSize: servingSize,
        servingUnit: servingUnit,
        calories: calories,
        proteins: proteins,
        carbohydrates: carbohydrates,
        fats: fats,
        fiber: fiber,
        sugar: sugar,
        sodium: sodium,
      );
    } catch (e) {
      print('❌ Error parseando información nutricional: $e');
      return null;
    }
  }

  /// 🧪 Probar conexión con Gemini Vision
  Future<bool> testConnection() async {
    try {
      print('🔧 Probando conexión con Gemini Vision...');
      
      if (_apiKey.isEmpty) {
        print('❌ API key no configurada');
        return false;
      }
      
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );
      
      final response = await model.generateContent([
        Content.text('Responde únicamente "OK" si puedes procesar imágenes')
      ]);
      
      if (response.candidates.isEmpty) {
        print('❌ Sin respuesta de Gemini');
        return false;
      }
      
      final text = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();
      
      print('✅ Conexión exitosa con Gemini');
      print('Respuesta: $text');
      
      return true;
    } catch (e) {
      print('❌ Error probando conexión: $e');
      return false;
    }
  }

  /// 🔍 Analizar imagen de alimento (para estimación nutricional)
  Future<NutritionalInfo?> estimateNutritionFromFoodImage(File imageFile) async {
    try {
      if (_apiKey.isEmpty) {
        print('❌ API key no configurada');
        return null;
      }

      print('🍎 Estimando nutrición desde imagen de alimento...');

      final bytes = await imageFile.readAsBytes();
      
      final prompt = '''
Analiza esta imagen de alimento y proporciona una estimación nutricional.

INSTRUCCIONES:
1. Identifica el alimento o alimentos en la imagen
2. Estima el tamaño de la porción visible
3. Proporciona valores nutricionales aproximados para esa porción

IMPORTANTE: Esta es una ESTIMACIÓN, no valores exactos.

Responde en JSON:
{
  "identified_food": "descripción_del_alimento",
  "estimated_portion": "estimación_del_tamaño",
  "serving_size": gramos_estimados,
  "calories_per_serving": calorías_estimadas,
  "macros": {
    "proteins": gramos_proteína,
    "carbohydrates": gramos_carbohidratos,
    "fats": gramos_grasas,
    "fiber": gramos_fibra
  },
  "confidence": nivel_confianza_0_a_1,
  "is_estimation": true
}
''';

      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          topP: 0.8,
          maxOutputTokens: 1024,
        ),
      );

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await model.generateContent(content);

      if (response.candidates.isEmpty) {
        return null;
      }

      final responseText = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();

      final jsonStr = _extractJsonFromResponse(responseText);
      final data = jsonDecode(jsonStr);

      if (data is Map<String, dynamic>) {
        return _parseNutritionalInfo(data);
      }

      return null;
    } catch (e) {
      print('❌ Error estimando nutrición de alimento: $e');
      return null;
    }
  }

  /// 🔧 Crear información nutricional manual
  NutritionalInfo createManualNutritionalInfo({
    double? servingSize,
    String? servingUnit,
    int? calories,
    double? proteins,
    double? carbohydrates,
    double? fats,
    double? fiber,
    double? sugar,
    double? sodium,
  }) {
    return NutritionalInfo(
      servingSize: servingSize,
      servingUnit: servingUnit,
      calories: calories,
      proteins: proteins,
      carbohydrates: carbohydrates,
      fats: fats,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
    );
  }
}