// lib/services/gemini_recipe_service.dart - VERSIÓN COMPLETA Y ACTUALIZADA CON MACROS

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/product_model.dart';
import '../models/recipe_model.dart';
import '../models/product_location_model.dart';

class GeminiRecipeService {
  static final GeminiRecipeService _instance = GeminiRecipeService._internal();
  factory GeminiRecipeService() => _instance;
  GeminiRecipeService._internal();
  
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String _modelName = 'gemini-1.5-pro';

  /// 🤖 NUEVO: Método mejorado para generar recetas con análisis nutricional y condiciones específicas
  Future<List<Recipe>> generateEnhancedRecipesFromIngredients({
    required List<Product> availableIngredients,
    List<Product>? priorityIngredients,
    List<Product>? productsWithNutrition,
    String? cuisine,
    String? dietaryPreferences,
    String? userConditions,
    bool includeNutritionalAnalysis = false,
    int numberOfRecipes = 3,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        throw Exception('API key no configurada. Añade GEMINI_API_KEY en tu archivo .env');
      }

      print('🔬 Generando recetas MEJORADAS con Gemini AI:');
      print('- Ingredientes disponibles: ${availableIngredients.length}');
      print('- Productos prioritarios: ${priorityIngredients?.length ?? 0}');
      print('- Productos con nutrición: ${productsWithNutrition?.length ?? 0}');
      print('- Análisis nutricional: $includeNutritionalAnalysis');
      print('- Condiciones del usuario: ${userConditions ?? "ninguna"}');
      
      final prompt = _buildEnhancedPrompt(
        availableIngredients: availableIngredients,
        priorityIngredients: priorityIngredients,
        productsWithNutrition: productsWithNutrition,
        cuisine: cuisine,
        dietaryPreferences: dietaryPreferences,
        userConditions: userConditions,
        includeNutritionalAnalysis: includeNutritionalAnalysis,
        numberOfRecipes: numberOfRecipes,
      );
      
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.9, // Más creatividad para recetas personalizadas
          topP: 0.95,
          topK: 40,
          maxOutputTokens: 6144, // Más tokens para análisis nutricional detallado
        ),
      );
      
      print('📤 Enviando prompt mejorado a Gemini...');
      final response = await model.generateContent([Content.text(prompt)]);
      
      if (response.candidates.isEmpty) {
        print('❌ Sin respuesta de Gemini.');
        throw Exception('No se recibió respuesta del modelo.');
      }
      
      final responseText = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();
      
      print('📥 Respuesta mejorada recibida de Gemini.');
      
      String jsonStr = _extractJsonFromResponse(responseText);
      
      return _parseEnhancedRecipesFromResponse(jsonStr, availableIngredients);
    } catch (e) {
      print('❌ Error al generar recetas mejoradas con Gemini: $e');
      // Fallback a método original si falla
      return generateRecipesFromIngredients(
        availableIngredients: availableIngredients,
        expiringIngredients: priorityIngredients,
        cuisine: cuisine,
        mealType: dietaryPreferences,
        numberOfRecipes: numberOfRecipes,
      );
    }
  }

  /// 🛠️ Construye el prompt mejorado para generación de recetas
  String _buildEnhancedPrompt({
    required List<Product> availableIngredients,
    List<Product>? priorityIngredients,
    List<Product>? productsWithNutrition,
    String? cuisine,
    String? dietaryPreferences,
    String? userConditions,
    bool includeNutritionalAnalysis = false,
    int numberOfRecipes = 3,
  }) {
    final prompt = StringBuffer();
    
    prompt.writeln('Actúa como un chef experto especializado en nutrición y creatividad culinaria.');
    prompt.writeln('Genera exactamente $numberOfRecipes recetas COMPLETAMENTE DIFERENTES entre sí.');
    prompt.writeln('');
    
    // Información básica de ingredientes
    prompt.writeln('INGREDIENTES DISPONIBLES:');
    for (final product in availableIngredients) {
      prompt.write('- ${product.name} (${product.quantity} ${product.unit})');
      
      // ¡NUEVO! Añadir información nutricional si está disponible
      if (includeNutritionalAnalysis && product.hasNutritionalInfo) {
        final nutrition = product.nutritionalInfo!;
        prompt.write(' [NUTRICIÓN: ');
        
        if (nutrition.calories != null) {
          prompt.write('${nutrition.calories} kcal');
        }
        if (nutrition.proteins != null) {
          prompt.write(', P:${nutrition.proteins!.toStringAsFixed(1)}g');
        }
        if (nutrition.carbohydrates != null) {
          prompt.write(', C:${nutrition.carbohydrates!.toStringAsFixed(1)}g');
        }
        if (nutrition.fats != null) {
          prompt.write(', G:${nutrition.fats!.toStringAsFixed(1)}g');
        }
        if (nutrition.fiber != null) {
          prompt.write(', Fibra:${nutrition.fiber!.toStringAsFixed(1)}g');
        }
        
        prompt.write(']');
      }
      
      prompt.writeln();
    }
    
    // Productos prioritarios
    if (priorityIngredients != null && priorityIngredients.isNotEmpty) {
      prompt.writeln('');
      prompt.writeln('INGREDIENTES PRIORITARIOS (usar preferentemente):');
      for (final product in priorityIngredients) {
        prompt.writeln('- ${product.name} (${product.quantity} ${product.unit}) - PRIORIDAD ALTA');
      }
    }
    
    // ¡NUEVO! Productos con información nutricional destacada
    if (includeNutritionalAnalysis && productsWithNutrition != null && productsWithNutrition.isNotEmpty) {
      prompt.writeln('');
      prompt.writeln('PRODUCTOS CON ANÁLISIS NUTRICIONAL COMPLETO:');
      for (final product in productsWithNutrition) {
        if (product.hasNutritionalInfo) {
          final nutrition = product.nutritionalInfo!;
          prompt.writeln('- ${product.name}: ${product.nutritionalSummary}');
        }
      }
      prompt.writeln('IMPORTANTE: Optimiza las recetas para maximizar el valor nutricional usando estos productos.');
    }
    
    prompt.writeln('');
    
    // Preferencias culinarias
    if (cuisine != null && cuisine != 'Cualquiera') {
      prompt.writeln('ESTILO CULINARIO: Las recetas deben ser de cocina $cuisine.');
    } else {
      prompt.writeln('DIVERSIDAD: Genera recetas de diferentes estilos culinarios (italiana, mexicana, asiática, etc.)');
    }
    
    if (dietaryPreferences != null && dietaryPreferences != 'Cualquiera') {
      prompt.writeln('PREFERENCIAS DIETÉTICAS: Las recetas deben ser $dietaryPreferences.');
    }
    
    // ¡NUEVO! Condiciones específicas del usuario
    if (userConditions != null && userConditions.isNotEmpty) {
      prompt.writeln('');
      prompt.writeln('CONDICIONES ESPECÍFICAS DEL USUARIO:');
      prompt.writeln('$userConditions');
      prompt.writeln('IMPORTANTE: Estas condiciones son OBLIGATORIAS y deben cumplirse en todas las recetas.');
    }
    
    prompt.writeln('');
    prompt.writeln('REGLAS ESTRICTAS:');
    prompt.writeln('1. Cada receta DEBE ser COMPLETAMENTE DIFERENTE de las demás.');
    prompt.writeln('2. NO generes más de una variante del mismo tipo de plato.');
    prompt.writeln('3. NO repitas la misma base de ingredientes principales entre recetas.');
    prompt.writeln('4. Prioriza la creatividad y variedad de platos.');
    prompt.writeln('5. Las cantidades DEBEN ser números enteros (1, 2, 3, etc.), NO decimales.');
    prompt.writeln('6. Usa unidades apropiadas: g, kg, ml, l, cucharadas, cucharaditas, tazas, unidades, piezas, dientes, ramitas, hojas, pizca.');
    
    // ¡NUEVO! Reglas nutricionales si se incluye análisis
    if (includeNutritionalAnalysis) {
      prompt.writeln('7. OBLIGATORIO: Calcula información nutricional PRECISA por porción.');
      prompt.writeln('8. Optimiza el balance de macronutrientes (proteínas, carbohidratos, grasas).');
      prompt.writeln('9. Menciona beneficios nutricionales específicos en la descripción.');
      prompt.writeln('10. Prioriza ingredientes con mejor perfil nutricional cuando sea posible.');
    }
    
    prompt.writeln('');
    
    // Estructura de respuesta
    if (includeNutritionalAnalysis) {
      prompt.writeln('Responde ÚNICAMENTE con JSON válido (sin texto adicional):');
      prompt.writeln('''{
  "recipes": [
    {
      "name": "Nombre creativo y descriptivo de la receta",
      "description": "Descripción atractiva incluyendo beneficios nutricionales",
      "preparationTime": tiempo_preparación_minutos,
      "cookingTime": tiempo_cocción_minutos,
      "servings": número_porciones,
      "difficulty": "easy", "medium" o "hard",
      "categories": ["categoría1", "categoría2"],
      "ingredients": [
        {"name": "Ingrediente", "quantity": cantidad_entera, "unit": "unidad", "isOptional": false}
      ],
      "steps": ["Paso 1 detallado", "Paso 2 detallado", ...],
      "calories": calorías_por_porción,
      "nutrition": {
        "protein": gramos_proteína_por_porción,
        "carbs": gramos_carbohidratos_por_porción,
        "fats": gramos_grasas_por_porción,
        "fiber": gramos_fibra_por_porción,
        "sugar": gramos_azúcar_por_porción,
        "sodium": miligramos_sodio_por_porción
      },
      "nutritional_highlights": ["Beneficio nutricional 1", "Beneficio 2"],
      "macro_balance": "descripción_del_balance_nutricional"
    }
  ]
}''');
    } else {
      prompt.writeln('Responde ÚNICAMENTE con JSON válido (sin texto adicional):');
      prompt.writeln('''{
  "recipes": [
    {
      "name": "Nombre de la receta",
      "description": "Breve descripción de la receta",
      "preparationTime": tiempo_preparación_minutos,
      "cookingTime": tiempo_cocción_minutos,
      "servings": número_porciones,
      "difficulty": "easy", "medium" o "hard",
      "categories": ["categoría1", "categoría2"],
      "ingredients": [
        {"name": "Ingrediente", "quantity": cantidad_entera, "unit": "unidad", "isOptional": false}
      ],
      "steps": ["Paso 1", "Paso 2", ...],
      "calories": calorías_estimadas_por_porción,
      "nutrition": {
        "protein": gramos_proteína_estimados,
        "carbs": gramos_carbohidratos_estimados,
        "fats": gramos_grasas_estimados,
        "fiber": gramos_fibra_estimados
      }
    }
  ]
}''');
    }
    
    return prompt.toString();
  }

  /// 🔄 Parsea las recetas mejoradas de la respuesta de IA
  List<Recipe> _parseEnhancedRecipesFromResponse(String response, List<Product> inventory) {
    try {
      print('📋 Parseando respuesta mejorada...');
      final jsonData = jsonDecode(response);
      
      if (!jsonData.containsKey('recipes')) {
        print('❌ El formato de respuesta no tiene una clave "recipes"');
        throw Exception('Formato de respuesta inválido');
      }
      
      final List<dynamic> recipesJson = jsonData['recipes'];
      print('✅ Encontradas ${recipesJson.length} recetas en la respuesta');
      
      if (recipesJson.isEmpty) {
        throw Exception('No se encontraron recetas en la respuesta');
      }
      
      final recipes = <Recipe>[];
      
      for (var json in recipesJson) {
        try {
          if (!json.containsKey('name') || !json.containsKey('ingredients') || !json.containsKey('steps')) {
            print('⚠️ Receta con campos incompletos: $json');
            continue;
          }
          
          final ingredients = <RecipeIngredient>[];
          
          if (json['ingredients'] is List) {
            for (var ing in json['ingredients']) {
              if (ing is Map) {
                try {
                  final String ingredientName = ing['name'] ?? 'Ingrediente sin nombre';
                  
                  // Convertir cantidad a entero
                  dynamic quantity = ing['quantity'];
                  int intQuantity = 1;
                  
                  if (quantity is int) {
                    intQuantity = quantity;
                  } else if (quantity is double) {
                    intQuantity = quantity.round();
                  } else if (quantity is String) {
                    try {
                      final parsed = double.parse(quantity);
                      intQuantity = parsed.round();
                    } catch (_) {
                      intQuantity = 1;
                    }
                  }
                  
                  if (intQuantity <= 0) intQuantity = 1;
                  
                  final String unit = ing['unit']?.toString() ?? 'unidades';
                  final bool isOptional = ing['isOptional'] == true;
                  
                  final bool isAvailable = _isIngredientAvailableInInventory(
                    ingredientName, 
                    intQuantity.toDouble(),
                    unit,
                    inventory
                  );
                  
                  ingredients.add(RecipeIngredient(
                    name: ingredientName,
                    quantity: intQuantity.toDouble(),
                    unit: unit,
                    isAvailable: isAvailable,
                    isOptional: isOptional,
                  ));
                } catch (ingError) {
                  print('❌ Error al procesar ingrediente: $ingError');
                }
              }
            }
          }
          
          List<String> steps = [];
          if (json['steps'] is List) {
            steps = (json['steps'] as List).map((step) => step.toString()).toList();
          }
          
          List<String> categories = [];
          if (json['categories'] is List) {
            categories = (json['categories'] as List).map((cat) => cat.toString()).toList();
          }
          
          final difficulty = _parseDifficulty(json['difficulty']?.toString());
          
          // Parsear tiempos como enteros
          int preparationTime = _parseIntValue(json['preparationTime'], 15);
          int cookingTime = _parseIntValue(json['cookingTime'], 30);
          int servings = _parseIntValue(json['servings'], 4);
          int calories = _parseIntValue(json['calories'], 300);
          
          // ¡NUEVO! Parsear información nutricional mejorada
          Map<String, dynamic> nutrition = {};
          if (json['nutrition'] is Map) {
            try {
              final Map<String, dynamic> nutMap = {};
              (json['nutrition'] as Map).forEach((key, value) {
                // Para macros principales, mantener decimales para mayor precisión
                if (['protein', 'carbs', 'fats', 'fiber'].contains(key)) {
                  if (value is num) {
                    nutMap[key.toString()] = value.toDouble();
                  } else if (value is String) {
                    final numValue = double.tryParse(value);
                    if (numValue != null) {
                      nutMap[key.toString()] = numValue;
                    }
                  }
                } else {
                  // Para otros valores (como sodio), usar enteros
                  nutMap[key.toString()] = _parseIntValue(value, 0);
                }
              });
              nutrition = nutMap;
            } catch (e) {
              print('❌ Error procesando información nutricional: $e');
            }
          }
          
          // ¡NUEVO! Procesar destacados nutricionales si están disponibles
          List<String> nutritionalHighlights = [];
          if (json['nutritional_highlights'] is List) {
            nutritionalHighlights = (json['nutritional_highlights'] as List)
                .map((highlight) => highlight.toString())
                .toList();
          }
          
          // ¡NUEVO! Incluir destacados en la descripción si existen
          String enhancedDescription = json['description']?.toString() ?? 'Receta generada con inteligencia artificial';
          if (nutritionalHighlights.isNotEmpty) {
            enhancedDescription += '\n\n✨ Beneficios nutricionales: ${nutritionalHighlights.join(', ')}.';
          }
          
          final String recipeId = '${DateTime.now().millisecondsSinceEpoch}_${recipes.length}';
          final recipe = Recipe(
            id: recipeId,
            name: json['name']?.toString().isNotEmpty == true ? 
                json['name'].toString() : 'Receta generada con IA ${recipeId.substring(0, 5)}',
            description: enhancedDescription,
            imageUrl: '',
            preparationTime: preparationTime,
            cookingTime: cookingTime,
            servings: servings,
            difficulty: difficulty,
            categories: categories,
            ingredients: ingredients,
            steps: steps,
            calories: calories,
            nutrition: nutrition,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          recipes.add(recipe);
          print('✅ Receta mejorada añadida: ${recipe.name}');
          print('   - ${ingredients.length} ingredientes, ${steps.length} pasos');
          print('   - Calorías: ${recipe.calories}, Macros: P:${nutrition['protein'] ?? 0}g C:${nutrition['carbs'] ?? 0}g G:${nutrition['fats'] ?? 0}g');
          
        } catch (recipeError) {
          print('❌ Error al procesar receta individual: $recipeError');
        }
      }
      
      print('🎉 Parseadas correctamente ${recipes.length} recetas mejoradas');
      
      if (recipes.isEmpty) {
        throw Exception('No se pudieron procesar recetas válidas');
      }
      
      return recipes;
    } catch (e) {
      print('❌ Error al parsear recetas mejoradas: $e');
      print('📄 Respuesta recibida: $response');
      throw Exception('Error al procesar las recetas generadas: $e');
    }
  }

  /// 🤖 MÉTODO ORIGINAL: Análizar disponibilidad de ingredientes
  Future<Map<String, dynamic>?> analyzeIngredientAvailability({
    required List<RecipeIngredient> ingredients,
    required List<Product> availableProducts,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        print('API key no configurada para análisis de ingredientes');
        return null;
      }

      final ingredientsList = ingredients.map((ing) => 
        '- ${ing.name} (${ing.quantity} ${ing.unit})'
      ).join('\n');
      
      final productsList = availableProducts.map((prod) => 
        '- ${prod.name} (${prod.quantity} ${prod.unit}, categoría: ${prod.category})'
      ).join('\n');

      final prompt = '''
Analiza la disponibilidad de ingredientes para una receta comparando con el inventario disponible.

INGREDIENTES NECESARIOS:
$ingredientsList

PRODUCTOS DISPONIBLES EN INVENTARIO:
$productsList

Por favor, analiza y clasifica cada ingrediente en:
1. DISPONIBLE: El producto exacto o equivalente está disponible
2. FALTANTE: No hay producto similar disponible
3. OPCIONAL: Ingrediente que se puede omitir sin afectar significativamente la receta
4. SIMILAR: Hay un producto parecido que podría servir como sustituto

Considera sinónimos, variaciones de nombres, y equivalencias culinarias.
Por ejemplo: "tomates" y "tomate", "aceite de oliva" y "aceite", etc.

Responde ÚNICAMENTE en formato JSON válido:
{
  "available": [{"ingredient": "nombre", "matched_product": "producto_encontrado", "confidence": 0.95}],
  "missing": [{"ingredient": "nombre", "reason": "no_encontrado"}],
  "optional": [{"ingredient": "nombre", "reason": "puede_omitirse"}],
  "similar": [{"ingredient": "nombre", "similar_product": "producto_similar", "confidence": 0.75}]
}
''';

      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          topP: 0.8,
          topK: 20,
          maxOutputTokens: 2048,
        ),
      );

      print('🔍 Enviando análisis de ingredientes a Gemini...');
      final response = await model.generateContent([Content.text(prompt)]);

      if (response.candidates.isEmpty) {
        print('Sin respuesta para análisis de ingredientes');
        return null;
      }

      final responseText = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();

      print('📋 Respuesta de análisis recibida');

      // Extraer y parsear JSON
      final jsonStr = _extractJsonFromResponse(responseText);
      final analysisData = jsonDecode(jsonStr);

      if (analysisData is Map<String, dynamic>) {
        print('✅ Análisis de ingredientes procesado correctamente');
        return analysisData;
      }

      return null;
    } catch (e) {
      print('❌ Error analizando disponibilidad de ingredientes: $e');
      return null;
    }
  }

  /// 🤖 MÉTODO ORIGINAL: Conversión de ingredientes a productos de supermercado
  Future<Map<String, dynamic>?> convertIngredientsToShoppingProducts({
    required List<RecipeIngredient> ingredients,
    int servings = 4,
  }) async {
    try {
      final ingredientsList = ingredients.map((ing) => 
        '${ing.name}: ${ing.quantity} ${ing.unit}'
      ).join('\n');

      final prompt = '''
Actúa como un experto en compras de supermercado español. Convierte estos ingredientes de receta a cantidades prácticas de supermercado.

INGREDIENTES DE RECETA (para $servings personas):
$ingredientsList

INSTRUCCIONES IMPORTANTES:
1. Convierte cada ingrediente a la cantidad mínima práctica que se compra en un supermercado español típico.
2. Ejemplos de conversión:
   - "1 cucharadita de sal" → "Sal fina" 1 paquete
   - "2 dientes de ajo" → "Ajos" 1 cabeza  
   - "100ml de leche" → "Leche entera" 1 litro
   - "50g de queso rallado" → "Queso rallado" 1 bolsa
   - "1 tomate" → "Tomates" 1 kg
   - "2 cucharadas de aceite" → "Aceite de oliva" 1 botella
3. Usa nombres de productos como aparecen en supermercados españoles.
4. Asigna la categoría EXACTA de la lista proporcionada.
5. Cantidades siempre números enteros positivos.

CATEGORÍAS DISPONIBLES (usar EXACTAMENTE estos nombres):
- Frutas y Verduras
- Carnes y Pescados  
- Lácteos y Huevos
- Panadería
- Conservas
- Congelados
- Bebidas
- Condimentos y Especias
- Cereales y Legumbres
- Dulces y Snacks
- Productos de Limpieza
- Cuidado Personal
- Otros

REGLAS ESTRICTAS:
- Cantidades SIEMPRE números enteros (1, 2, 3, nunca decimales)
- Unidades estándar: kg, g, l, ml, unidades, paquetes, botes, latas, botellas
- Ser práctico: mejor comprar un poco más que quedarse corto
- NO crear ingredientes duplicados o similares

Responde ÚNICAMENTE con JSON válido (sin explicaciones ni texto adicional):
{
  "products": [
    {
      "name": "Nombre exacto como en supermercado",
      "quantity": número_entero,
      "unit": "unidad_estándar", 
      "category": "Categoría_exacta_de_la_lista"
    }
  ]
}
''';

      print('📤 Enviando conversión de ingredientes a Gemini...');
      return await generateNutritionalInfo(prompt);
      
    } catch (e) {
      print('❌ Error en convertIngredientsToShoppingProducts: $e');
      return null;
    }
  }

  /// 🤖 MÉTODO ORIGINAL: Generar recetas desde ingredientes disponibles
  Future<List<Recipe>> generateRecipesFromIngredients({
    required List<Product> availableIngredients,
    List<Product>? expiringIngredients,
    String? cuisine,
    String? mealType,
    int numberOfRecipes = 3,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        throw Exception('API key no configurada. Añade GEMINI_API_KEY en tu archivo .env');
      }

      print('Generando recetas con Gemini AI:');
      print('Ingredientes disponibles: ${availableIngredients.map((p) => p.name).join(', ')}');
      print('Cocina seleccionada: ${cuisine ?? "Cualquiera"}');
      print('Tipo de comida: ${mealType ?? "Cualquiera"}');
      
      final prompt = _buildPrompt(
        availableIngredients: availableIngredients,
        expiringIngredients: expiringIngredients,
        cuisine: cuisine,
        mealType: mealType,
        numberOfRecipes: numberOfRecipes,
      );
      
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 1.0,
          topP: 0.95,
          topK: 40,
          maxOutputTokens: 4096,
        ),
      );
      
      print('Enviando solicitud a Gemini...');
      final response = await model.generateContent([Content.text(prompt)]);
      
      if (response.candidates.isEmpty) {
        print('Sin respuesta de Gemini.');
        throw Exception('No se recibió respuesta del modelo.');
      }
      
      final responseText = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();
      
      print('Respuesta recibida de Gemini.');
      
      String jsonStr = _extractJsonFromResponse(responseText);
      
      return _parseRecipesFromResponse(jsonStr, availableIngredients);
    } catch (e) {
      print('Error al generar recetas con Gemini: $e');
      return _generateSampleRecipes(
        availableIngredients: availableIngredients,
        expiringIngredients: expiringIngredients,
        cuisine: cuisine,
        mealType: mealType,
      );
    }
  }

  /// 🤖 MÉTODO ORIGINAL: Generar recetas priorizando productos que caducan pronto
  Future<List<Recipe>> generateRecipesFromExpiringProducts({
    required List<Product> expiringProducts,
    List<Product>? additionalProducts,
    String? cuisine,
    String? mealType,
    int numberOfRecipes = 3,
  }) async {
    final List<Product> allProducts = [
      ...expiringProducts,
      ...(additionalProducts ?? []),
    ];
    
    return generateRecipesFromIngredients(
      availableIngredients: allProducts,
      expiringIngredients: expiringProducts,
      cuisine: cuisine,
      mealType: mealType,
      numberOfRecipes: numberOfRecipes,
    );
  }

  /// 🛠️ MÉTODO ORIGINAL: Construye el prompt para generación de recetas
  String _buildPrompt({
    required List<Product> availableIngredients,
    List<Product>? expiringIngredients,
    String? cuisine,
    String? mealType,
    int numberOfRecipes = 3,
  }) {
    return '''
    Actúa como un chef creativo y experto. Necesito recetas completamente diferentes entre sí.
    
    Genera exactamente $numberOfRecipes recetas diferentes utilizando algunos de estos ingredientes disponibles:
    ${availableIngredients.map((p) => '${p.name} (${p.quantity.round()} ${p.unit})').join('\n')}
    
    ${expiringIngredients != null && expiringIngredients.isNotEmpty 
      ? 'IMPORTANTE: Prioriza estos ingredientes que caducan pronto: ${expiringIngredients.map((p) => p.name).join(', ')}' 
      : ''}
    
    ${cuisine != null && cuisine != 'Cualquiera' ? 'Las recetas deben ser de cocina $cuisine.' : 'IMPORTANTE: Genera recetas de cocinas variadas (italiana, mexicana, asiática, etc.)'}
    ${mealType != null ? 'Las recetas deben ser adecuadas para $mealType.' : ''}
    
    REGLAS ESTRICTAS:
    1. Cada receta DEBE ser COMPLETAMENTE DIFERENTE de las demás.
    2. NO generes más de una variante del mismo tipo de plato.
    3. NO repitas la misma base de ingredientes principales entre recetas.
    4. Prioriza la creatividad y variedad de platos.
    5. Genera recetas prácticas y realistas con los ingredientes disponibles.
    6. IMPORTANTE: Las cantidades de ingredientes DEBEN ser números enteros (1, 2, 3, etc.), NO decimales.
    7. Usa unidades apropiadas: g, kg, ml, l, cucharadas, cucharaditas, tazas, unidades, piezas, dientes, ramitas, hojas, pizca, paquete.
    8. Asegúrate de incluir todos los campos requeridos: preparationTime, cookingTime, servings, difficulty, categories, ingredients, steps, calories, nutrition.
    
    Devuelve SOLAMENTE un objeto JSON con esta estructura exacta (sin texto adicional antes o después):
    {
      "recipes": [
        {
          "name": "Nombre de la receta",
          "description": "Breve descripción de la receta",
          "preparationTime": tiempo de preparación en minutos (número entero),
          "cookingTime": tiempo de cocción en minutos (número entero),
          "servings": número de porciones (número entero),
          "difficulty": "easy", "medium" o "hard",
          "categories": ["categoría1", "categoría2"],
          "ingredients": [
            {"name": "Ingrediente 1", "quantity": cantidad (número entero), "unit": "unidad", "isOptional": false},
            ...
          ],
          "steps": ["Paso 1", "Paso 2", ...],
          "calories": calorías estimadas por porción (número entero),
          "nutrition": {
            "protein": gramos de proteína (número entero),
            "carbs": gramos de carbohidratos (número entero),
            "fats": gramos de grasas (número entero),
            "fiber": gramos de fibra (número entero)
          }
        },
        ... más recetas hasta completar $numberOfRecipes
      ]
    }
    
    IMPORTANTE: 
    - Responde SOLO con el JSON, sin explicaciones, introducciones ni textos adicionales.
    - Las cantidades DEBEN ser números enteros, no decimales.
    - Incluye SIEMPRE preparationTime, cookingTime, servings, difficulty, categories, ingredients, steps, calories y nutrition.
    ''';
  }

  /// 🔧 MÉTODO ORIGINAL: Extrae JSON de la respuesta de Gemini
  String _extractJsonFromResponse(String response) {
    try {
      jsonDecode(response);
      return response;
    } catch (_) {
      final jsonMatch = RegExp(r'{[\s\S]*}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0);
        if (jsonStr != null) {
          try {
            jsonDecode(jsonStr);
            return jsonStr;
          } catch (_) {}
        }
      }
      
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
        print('No se pudo extraer JSON válido de la respuesta: $response');
        return '{"recipes":[]}';
      }
    }
  }

  /// 🔧 MÉTODO ORIGINAL: Genera información nutricional con IA
  Future<Map<String, dynamic>?> generateNutritionalInfo(String prompt) async {
    try {
      if (_apiKey.isEmpty) {
        print('API key no configurada para información nutricional');
        return null;
      }

      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3, // Menor temperatura para mayor precisión
          topP: 0.8,
          topK: 20,
          maxOutputTokens: 1024,
        ),
      );

      print('Generando información nutricional...');
      final response = await model.generateContent([Content.text(prompt)]);

      if (response.candidates.isEmpty) {
        print('Sin respuesta para información nutricional');
        return null;
      }

      final responseText = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();

      print('Respuesta nutricional recibida: $responseText');

      // Extraer y parsear JSON
      final jsonStr = _extractJsonFromResponse(responseText);
      final nutritionData = jsonDecode(jsonStr);

      // Validar que tenga la estructura esperada
      if (nutritionData is Map<String, dynamic>) {
        // Convertir todos los valores a enteros
        final Map<String, dynamic> cleanedData = {};
        nutritionData.forEach((key, value) {
          if (value is num) {
            cleanedData[key] = value.round();
          } else if (value is String) {
            final numValue = int.tryParse(value);
            if (numValue != null) {
              cleanedData[key] = numValue;
            }
          }
        });
        
        print('Información nutricional procesada: $cleanedData');
        return cleanedData;
      }

      return null;
    } catch (e) {
      print('Error generando información nutricional: $e');
      return null;
    }
  }

  /// 🧪 MÉTODO ORIGINAL: Prueba la conexión con Gemini
  Future<bool> testGeminiConnection() async {
    try {
      print('Iniciando prueba de conexión a Gemini...');
      
      if (_apiKey.isEmpty) {
        print('❌ API key no configurada. Agrega GEMINI_API_KEY en tu archivo .env');
        return false;
      }
      
      print('✓ API key configurada');
      
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );
      
      print('Enviando solicitud de prueba a Gemini...');
      final response = await model.generateContent(
        [Content.text('Genera una receta de pasta simple en formato JSON con cantidades enteras')]
      );
      
      if (response.candidates.isEmpty) {
        print('❌ Sin respuesta de Gemini');
        return false;
      }
      
      final text = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();
      
      print('✓ Conexión exitosa a Gemini');
      print('Respuesta de prueba:');
      print(text);
      
      return true;
    } catch (e) {
      print('❌ Error durante la prueba de conexión: $e');
      return false;
    }
  }

  /// 🔄 MÉTODO ORIGINAL: Parsea las recetas de la respuesta de IA
  List<Recipe> _parseRecipesFromResponse(String response, List<Product> inventory) {
    try {
      print('Parseando respuesta...');
      final jsonData = jsonDecode(response);
      
      if (!jsonData.containsKey('recipes')) {
        print('El formato de respuesta no tiene una clave "recipes"');
        print('Respuesta recibida: $response');
        throw Exception('Formato de respuesta inválido');
      }
      
      final List<dynamic> recipesJson = jsonData['recipes'];
      print('Encontradas ${recipesJson.length} recetas en la respuesta');
      
      if (recipesJson.isEmpty) {
        throw Exception('No se encontraron recetas en la respuesta');
      }
      
      final recipes = <Recipe>[];
      
      for (var json in recipesJson) {
        try {
          if (!json.containsKey('name') || !json.containsKey('ingredients') || !json.containsKey('steps')) {
            print('Receta con campos incompletos: $json');
            continue;
          }
          
          final ingredients = <RecipeIngredient>[];
          
          if (json['ingredients'] is List) {
            for (var ing in json['ingredients']) {
              if (ing is Map) {
                try {
                  final String ingredientName = ing['name'] ?? 'Ingrediente sin nombre';
                  
                  // Convertir cantidad a entero
                  dynamic quantity = ing['quantity'];
                  int intQuantity = 1; // Valor por defecto
                  
                  if (quantity is int) {
                    intQuantity = quantity;
                  } else if (quantity is double) {
                    intQuantity = quantity.round();
                  } else if (quantity is String) {
                    try {
                      final parsed = double.parse(quantity);
                      intQuantity = parsed.round();
                    } catch (_) {
                      intQuantity = 1;
                    }
                  }
                  
                  // Asegurar que la cantidad sea al menos 1
                  if (intQuantity <= 0) intQuantity = 1;
                  
                  final String unit = ing['unit']?.toString() ?? 'unidades';
                  final bool isOptional = ing['isOptional'] == true;
                  
                  final bool isAvailable = _isIngredientAvailableInInventory(
                    ingredientName, 
                    intQuantity.toDouble(),
                    unit,
                    inventory
                  );
                  
                  ingredients.add(RecipeIngredient(
                    name: ingredientName,
                    quantity: intQuantity.toDouble(),
                    unit: unit,
                    isAvailable: isAvailable,
                    isOptional: isOptional,
                  ));
                } catch (ingError) {
                  print('Error al procesar ingrediente: $ingError');
                }
              }
            }
          }
          
          List<String> steps = [];
          if (json['steps'] is List) {
            steps = (json['steps'] as List).map((step) => step.toString()).toList();
          }
          
          List<String> categories = [];
          if (json['categories'] is List) {
            categories = (json['categories'] as List).map((cat) => cat.toString()).toList();
          }
          
          final difficulty = _parseDifficulty(json['difficulty']?.toString());
          
          // Parsear tiempos como enteros
          int preparationTime = _parseIntValue(json['preparationTime'], 15);
          int cookingTime = _parseIntValue(json['cookingTime'], 30);
          int servings = _parseIntValue(json['servings'], 4);
          int calories = _parseIntValue(json['calories'], 300);
          
          // Parsear información nutricional como enteros
          Map<String, dynamic> nutrition = {};
          if (json['nutrition'] is Map) {
            try {
              final Map<String, dynamic> nutMap = {};
              (json['nutrition'] as Map).forEach((key, value) {
                nutMap[key.toString()] = _parseIntValue(value, 0);
              });
              nutrition = nutMap;
            } catch (e) {
              print('Error procesando información nutricional: $e');
            }
          }
          
          final String recipeId = '${DateTime.now().millisecondsSinceEpoch}_${recipes.length}';
          final recipe = Recipe(
            id: recipeId,
            name: json['name']?.toString().isNotEmpty == true ? 
                json['name'].toString() : 'Receta generada con IA ${recipeId.substring(0, 5)}',
            description: json['description']?.toString() ?? 'Receta generada con inteligencia artificial',
            imageUrl: '',
            preparationTime: preparationTime,
            cookingTime: cookingTime,
            servings: servings,
            difficulty: difficulty,
            categories: categories,
            ingredients: ingredients,
            steps: steps,
            calories: calories,
            nutrition: nutrition,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          recipes.add(recipe);
          print('Receta añadida: ${recipe.name} (${ingredients.length} ingredientes, ${steps.length} pasos)');
        } catch (recipeError) {
          print('Error al procesar receta individual: $recipeError');
        }
      }
      
      print('Parseadas correctamente ${recipes.length} recetas');
      
      if (recipes.isEmpty) {
        throw Exception('No se pudieron procesar recetas válidas');
      }
      
      return recipes;
    } catch (e) {
      print('Error al parsear recetas: $e');
      print('Respuesta recibida: $response');
      throw Exception('Error al procesar las recetas generadas: $e');
    }
  }

  /// 🔧 MÉTODOS AUXILIARES MEJORADOS

  /// Método auxiliar mejorado para parsear valores enteros de forma segura
  int _parseIntValue(dynamic value, int defaultValue) {
    if (value is int) {
      return value;
    } else if (value is double) {
      return value.round();
    } else if (value is String) {
      try {
        final parsed = double.parse(value);
        return parsed.round();
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  /// Método auxiliar para parsear valores decimales de forma segura
  double _parseDoubleValue(dynamic value, double defaultValue) {
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  /// 🍳 MÉTODO ORIGINAL: Genera recetas de muestra cuando falla la IA
  List<Recipe> _generateSampleRecipes({
    required List<Product> availableIngredients,
    List<Product>? expiringIngredients,
    String? cuisine,
    String? mealType,
  }) {
    final ingredientNames = availableIngredients.map((p) => p.name.toLowerCase()).toList();
    final expiringNames = expiringIngredients?.map((p) => p.name.toLowerCase()).toList() ?? [];
    
    List<Recipe> sampleRecipes = [];
    
    bool hasProtein = _hasIngredientType(ingredientNames, ['pollo', 'carne', 'pescado', 'tofu', 'huevos', 'lentejas', 'garbanzos']);
    bool hasVegetables = _hasIngredientType(ingredientNames, ['tomate', 'lechuga', 'zanahoria', 'calabacín', 'pimiento', 'cebolla', 'ajo']);
    bool hasDairy = _hasIngredientType(ingredientNames, ['leche', 'queso', 'yogur', 'crema']);
    bool hasGrains = _hasIngredientType(ingredientNames, ['arroz', 'pasta', 'quinoa', 'avena', 'pan']);
    
    if (hasGrains && hasVegetables) {
      List<RecipeIngredient> pastaIngredients = [];
      
      pastaIngredients.add(RecipeIngredient(
        name: 'Pasta',
        quantity: 200,
        unit: 'g',
        isAvailable: true,
      ));
      
      if (_containsAny(ingredientNames, ['tomate'])) {
        pastaIngredients.add(RecipeIngredient(
          name: 'Tomate',
          quantity: 3,
          unit: 'unidades',
          isAvailable: true,
        ));
      }
      
      if (_containsAny(ingredientNames, ['cebolla'])) {
        pastaIngredients.add(RecipeIngredient(
          name: 'Cebolla',
          quantity: 1,
          unit: 'unidad',
          isAvailable: true,
        ));
      }
      
      if (_containsAny(ingredientNames, ['ajo'])) {
        pastaIngredients.add(RecipeIngredient(
          name: 'Ajo',
          quantity: 2,
          unit: 'dientes',
          isAvailable: true,
        ));
      }
      
      if (hasProtein) {
        if (_containsAny(ingredientNames, ['pollo'])) {
          pastaIngredients.add(RecipeIngredient(
            name: 'Pechuga de pollo',
            quantity: 200,
            unit: 'g',
            isAvailable: true,
          ));
        } else if (_containsAny(ingredientNames, ['carne'])) {
          pastaIngredients.add(RecipeIngredient(
            name: 'Carne picada',
            quantity: 200,
            unit: 'g',
            isAvailable: true,
          ));
        }
      }
      
      pastaIngredients.add(RecipeIngredient(
        name: 'Aceite de oliva',
        quantity: 2,
        unit: 'cucharadas',
        isAvailable: false,
        isOptional: true,
      ));
      
      pastaIngredients.add(RecipeIngredient(
        name: 'Sal',
        quantity: 1,
        unit: 'cucharadita',
        isAvailable: false,
        isOptional: true,
      ));
      
      pastaIngredients.add(RecipeIngredient(
        name: 'Pimienta',
        quantity: 1,
        unit: 'pizca',
        isAvailable: false,
        isOptional: true,
      ));
      
      sampleRecipes.add(Recipe(
        id: '1',
        name: 'Pasta con tomate y verduras',
        description: 'Una pasta clásica con salsa de tomate casera y vegetales frescos.',
        imageUrl: '',
        preparationTime: 15,
        cookingTime: 25,
        servings: 2,
        difficulty: DifficultyLevel.easy,
        categories: ['pasta', 'italiano', 'rápido'],
        ingredients: pastaIngredients,
        steps: [
          'Cocer la pasta en agua con sal según las instrucciones del paquete.',
          'Mientras tanto, picar la cebolla y el ajo y sofreírlos en aceite de oliva.',
          'Añadir los tomates picados y cocinar hasta que se forme una salsa.',
          'Si usas pollo o carne, córtalo en trozos y añádelo a la salsa.',
          'Mezclar la pasta escurrida con la salsa y servir caliente.',
        ],
        calories: 450,
        nutrition: {
          'protein': 15,
          'carbs': 60,
          'fats': 12,
          'fiber': 5,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    
    if (hasVegetables) {
      List<RecipeIngredient> saladIngredients = [];
      
      if (_containsAny(ingredientNames, ['lechuga'])) {
        saladIngredients.add(RecipeIngredient(
          name: 'Lechuga',
          quantity: 1,
          unit: 'unidad',
          isAvailable: true,
        ));
      }
      
      if (_containsAny(ingredientNames, ['tomate'])) {
        saladIngredients.add(RecipeIngredient(
          name: 'Tomate',
          quantity: 2,
          unit: 'unidades',
          isAvailable: true,
        ));
      }
      
      if (_containsAny(ingredientNames, ['pepino'])) {
        saladIngredients.add(RecipeIngredient(
          name: 'Pepino',
          quantity: 1,
          unit: 'unidad',
          isAvailable: true,
        ));
      }
      
      if (_containsAny(ingredientNames, ['cebolla'])) {
        saladIngredients.add(RecipeIngredient(
          name: 'Cebolla',
          quantity: 1,
          unit: 'unidad',
          isAvailable: true,
        ));
      }
      
      if (hasProtein) {
        if (_containsAny(ingredientNames, ['pollo'])) {
          saladIngredients.add(RecipeIngredient(
            name: 'Pechuga de pollo',
            quantity: 150,
            unit: 'g',
            isAvailable: true,
          ));
        } else if (_containsAny(ingredientNames, ['huevos'])) {
          saladIngredients.add(RecipeIngredient(
            name: 'Huevos',
            quantity: 2,
            unit: 'unidades',
            isAvailable: true,
          ));
        }
      }
      
      saladIngredients.add(RecipeIngredient(
        name: 'Aceite de oliva',
        quantity: 2,
        unit: 'cucharadas',
        isAvailable: false,
        isOptional: true,
      ));
      
      saladIngredients.add(RecipeIngredient(
        name: 'Vinagre',
        quantity: 1,
        unit: 'cucharada',
        isAvailable: false,
        isOptional: true,
      ));
      
      saladIngredients.add(RecipeIngredient(
        name: 'Sal',
        quantity: 1,
        unit: 'cucharadita',
        isAvailable: false,
        isOptional: true,
      ));
      
      sampleRecipes.add(Recipe(
        id: '2',
        name: 'Ensalada fresca con vegetales',
        description: 'Una ensalada ligera y nutritiva con vegetales frescos.',
        imageUrl: '',
        preparationTime: 10,
        cookingTime: 5,
        servings: 2,
        difficulty: DifficultyLevel.easy,
        categories: ['ensalada', 'saludable', 'vegetales'],
        ingredients: saladIngredients,
        steps: [
          'Lavar y cortar todos los vegetales.',
          'Si usas pollo, cocinarlo y cortarlo en tiras.',
          'Si usas huevos, hervirlos y cortarlos en cuartos.',
          'Mezclar todos los ingredientes en un bol grande.',
          'Aliñar con aceite de oliva, vinagre y sal al gusto.',
        ],
        calories: 250,
        nutrition: {
          'protein': 12,
          'carbs': 15,
          'fats': 16,
          'fiber': 4,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    
    if (_containsAny(ingredientNames, ['arroz'])) {
      List<RecipeIngredient> riceIngredients = [];
      
      riceIngredients.add(RecipeIngredient(
        name: 'Arroz',
        quantity: 200,
        unit: 'g',
        isAvailable: true,
      ));
      
      if (_containsAny(ingredientNames, ['pimiento'])) {
        riceIngredients.add(RecipeIngredient(
          name: 'Pimiento',
          quantity: 1,
          unit: 'unidad',
          isAvailable: true,
        ));
      }
      
      if (_containsAny(ingredientNames, ['cebolla'])) {
        riceIngredients.add(RecipeIngredient(
          name: 'Cebolla',
          quantity: 1,
          unit: 'unidad',
          isAvailable: true,
        ));
      }
      
      if (_containsAny(ingredientNames, ['tomate'])) {
        riceIngredients.add(RecipeIngredient(
          name: 'Tomate',
          quantity: 2,
          unit: 'unidades',
          isAvailable: true,
        ));
      }
      
      if (hasProtein) {
        if (_containsAny(ingredientNames, ['pollo'])) {
          riceIngredients.add(RecipeIngredient(
            name: 'Pollo',
            quantity: 200,
            unit: 'g',
            isAvailable: true,
          ));
        } else if (_containsAny(ingredientNames, ['carne'])) {
          riceIngredients.add(RecipeIngredient(
            name: 'Carne',
            quantity: 200,
            unit: 'g',
            isAvailable: true,
          ));
        }
      }
      
      sampleRecipes.add(Recipe(
        id: '3',
        name: 'Arroz con verduras',
        description: 'Un plato sencillo y sabroso de arroz con verduras.',
        imageUrl: '',
        preparationTime: 10,
        cookingTime: 25,
        servings: 2,
        difficulty: DifficultyLevel.easy,
        categories: ['arroz', 'sencillo'],
        ingredients: riceIngredients,
        steps: [
          'Picar las verduras en trozos pequeños.',
          'Sofreír la cebolla hasta que esté transparente.',
          'Añadir el resto de verduras y cocinar unos minutos.',
          'Incorporar el arroz y remover para que se impregne de los sabores.',
          'Añadir el doble de agua que de arroz, sal al gusto y cocinar a fuego medio hasta que el arroz esté tierno.',
        ],
        calories: 350,
        nutrition: {
          'protein': 10,
          'carbs': 60,
          'fats': 5,
          'fiber': 3,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    
    if (sampleRecipes.isEmpty) {
      List<RecipeIngredient> genericIngredients = [];
      
      genericIngredients.add(RecipeIngredient(
        name: 'Ingrediente principal',
        quantity: 300,
        unit: 'g',
        isAvailable: true,
      ));
      
      genericIngredients.add(RecipeIngredient(
        name: 'Verduras variadas',
        quantity: 200,
        unit: 'g',
        isAvailable: true,
      ));
      
      genericIngredients.add(RecipeIngredient(
        name: 'Especias al gusto',
        quantity: 1,
        unit: 'cucharadita',
        isAvailable: false,
        isOptional: true,
      ));
      
      sampleRecipes.add(Recipe(
        id: '4',
        name: 'Plato combinado personalizado',
        description: 'Un plato versátil que se adapta a los ingredientes disponibles.',
        imageUrl: '',
        preparationTime: 15,
        cookingTime: 25,
        servings: 2,
        difficulty: DifficultyLevel.easy,
        categories: ['versátil', 'personalizable'],
        ingredients: genericIngredients,
        steps: [
          'Preparar todos los ingredientes cortándolos en trozos del tamaño deseado.',
          'Cocinar el ingrediente principal según corresponda.',
          'Añadir las verduras y saltear todo junto.',
          'Sazonar al gusto y servir caliente.',
        ],
        calories: 400,
        nutrition: {
          'protein': 15,
          'carbs': 45,
          'fats': 15,
          'fiber': 5,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    
    return sampleRecipes;
  }
  
  // Verificar si alguno de los ingredientes es del tipo especificado
  bool _hasIngredientType(List<String> ingredients, List<String> types) {
    return ingredients.any((ingredient) => 
      types.any((type) => ingredient.contains(type))
    );
  }
  
  // Verificar si la lista contiene alguno de los elementos
  bool _containsAny(List<String> items, List<String> targets) {
    return items.any((item) => 
      targets.any((target) => item.contains(target))
    );
  }

  // Verificar si un ingrediente está disponible en el inventario
  bool _isIngredientAvailableInInventory(
    String ingredientName, 
    double quantity, 
    String unit, 
    List<Product> inventory
  ) {
    // Lista de productos que coinciden con el nombre del ingrediente
    // Buscar de forma flexible comparando subcadenas
    final matchingProducts = inventory.where((product) => 
      product.name.toLowerCase().contains(ingredientName.toLowerCase()) ||
      ingredientName.toLowerCase().contains(product.name.toLowerCase())
    ).toList();
    
    if (matchingProducts.isEmpty) {
      return false;
    }
    
    // Usar el primer producto que coincida
    final product = matchingProducts.first;
    
    // Solo verificar si está disponible, no comprobar cantidades exactas
    // ya que la conversión de unidades es compleja
    return product.productLocation == ProductLocation.inventory ||
           product.productLocation == ProductLocation.both;
  }

  // Convertir texto de dificultad a enum
  DifficultyLevel _parseDifficulty(String? difficulty) {
    if (difficulty == null) return DifficultyLevel.medium;
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
      case 'fácil':
      case 'facil':
        return DifficultyLevel.easy;
      case 'medium':
      case 'media':
        return DifficultyLevel.medium;
      case 'hard':
      case 'difícil':
      case 'dificil':
        return DifficultyLevel.hard;
      default:
        return DifficultyLevel.medium;
    }
  }
}