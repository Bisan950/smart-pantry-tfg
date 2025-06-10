// lib/services/smart_ingredient_analyzer.dart

import 'dart:async';
import '../models/recipe_model.dart';
import '../models/product_model.dart';
import '../models/product_location_model.dart';
import 'gemini_recipe_service.dart';
import 'inventory_service.dart';

/// Resultado del análisis de disponibilidad de ingredientes
class IngredientAvailabilityResult {
  final List<RecipeIngredient> availableIngredients;
  final List<RecipeIngredient> missingIngredients;
  final List<RecipeIngredient> optionalIngredients;
  final List<RecipeIngredient> almostAvailableIngredients; // Productos similares
  final double availabilityPercentage;
  final Map<String, Product> matchedProducts; // Mapeo ingrediente -> producto encontrado

  IngredientAvailabilityResult({
    required this.availableIngredients,
    required this.missingIngredients,
    required this.optionalIngredients,
    required this.almostAvailableIngredients,
    required this.availabilityPercentage,
    required this.matchedProducts,
  });

  bool get canCookRecipe => availabilityPercentage >= 80.0;
  bool get hasOptionalIngredients => optionalIngredients.isNotEmpty;
  bool get hasSimilarIngredients => almostAvailableIngredients.isNotEmpty;
}

/// Servicio para análisis inteligente de disponibilidad de ingredientes
class SmartIngredientAnalyzerService {
  static final SmartIngredientAnalyzerService _instance = SmartIngredientAnalyzerService._internal();
  factory SmartIngredientAnalyzerService() => _instance;
  SmartIngredientAnalyzerService._internal();

  final GeminiRecipeService _geminiService = GeminiRecipeService();
  final InventoryService _inventoryService = InventoryService();
  
  // Cache para evitar análisis repetitivos
  final Map<String, IngredientAvailabilityResult> _analysisCache = {};
  
  /// Analiza la disponibilidad de ingredientes en tiempo real con IA
  Future<IngredientAvailabilityResult> analyzeIngredientAvailability({
    required List<RecipeIngredient> ingredients,
    bool forceRefresh = false,
  }) async {
    try {
      // Crear clave de cache basada en los ingredientes
      final cacheKey = _generateCacheKey(ingredients);
      
      // Verificar cache si no es refresh forzado
      if (!forceRefresh && _analysisCache.containsKey(cacheKey)) {
        return _analysisCache[cacheKey]!;
      }

      print('🔍 Analizando disponibilidad de ${ingredients.length} ingredientes con IA...');
      
      // Obtener productos actuales del inventario
      final inventoryProducts = await _inventoryService.getAllProducts();
      final availableProducts = inventoryProducts.where((product) =>
        product.productLocation == ProductLocation.inventory || 
        product.productLocation == ProductLocation.both
      ).toList();

      if (availableProducts.isEmpty) {
        // Si no hay productos, todos los ingredientes faltan
        return IngredientAvailabilityResult(
          availableIngredients: [],
          missingIngredients: ingredients,
          optionalIngredients: [],
          almostAvailableIngredients: [],
          availabilityPercentage: 0.0,
          matchedProducts: {},
        );
      }

      // Usar IA para análisis inteligente
      final aiAnalysis = await _performAIAnalysis(ingredients, availableProducts);
      
      // Guardar en cache
      _analysisCache[cacheKey] = aiAnalysis;
      
      return aiAnalysis;
    } catch (e) {
      print('❌ Error en análisis de ingredientes: $e');
      // Fallback a análisis básico
      return await _performBasicAnalysis(ingredients);
    }
  }

  /// Análisis con IA usando Gemini
  Future<IngredientAvailabilityResult> _performAIAnalysis(
    List<RecipeIngredient> ingredients,
    List<Product> availableProducts,
  ) async {
    try {
      // Preparar prompt para la IA
      final prompt = _buildAnalysisPrompt(ingredients, availableProducts);
      
      // Llamar a la IA
      final response = await _geminiService.analyzeIngredientAvailability(
        ingredients: ingredients,
        availableProducts: availableProducts,
      );

      if (response != null) {
        return _parseAIResponse(response, ingredients, availableProducts);
      } else {
        return await _performBasicAnalysis(ingredients);
      }
    } catch (e) {
      print('❌ Error en análisis con IA: $e');
      return await _performBasicAnalysis(ingredients);
    }
  }

  /// Construye el prompt para el análisis de IA
  String _buildAnalysisPrompt(List<RecipeIngredient> ingredients, List<Product> products) {
    final ingredientsList = ingredients.map((ing) => 
      '- ${ing.name} (${ing.quantity} ${ing.unit})'
    ).join('\n');
    
    final productsList = products.map((prod) => 
      '- ${prod.name} (${prod.quantity} ${prod.unit}, categoría: ${prod.category})'
    ).join('\n');

    return '''
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

Responde en formato JSON con esta estructura:
{
  "available": [{"ingredient": "nombre", "matched_product": "producto_encontrado", "confidence": 0.95}],
  "missing": [{"ingredient": "nombre", "reason": "no_encontrado"}],
  "optional": [{"ingredient": "nombre", "reason": "puede_omitirse"}],
  "similar": [{"ingredient": "nombre", "similar_product": "producto_similar", "confidence": 0.75}]
}
''';
  }

  /// Parsea la respuesta de la IA
  IngredientAvailabilityResult _parseAIResponse(
    Map<String, dynamic> response,
    List<RecipeIngredient> ingredients,
    List<Product> availableProducts,
  ) {
    final available = <RecipeIngredient>[];
    final missing = <RecipeIngredient>[];
    final optional = <RecipeIngredient>[];
    final almostAvailable = <RecipeIngredient>[];
    final matchedProducts = <String, Product>{};

    try {
      // Procesar ingredientes disponibles
      if (response.containsKey('available')) {
        final availableList = response['available'] as List;
        for (var item in availableList) {
          final ingredientName = item['ingredient'] as String;
          final matchedProductName = item['matched_product'] as String;
          
          final ingredient = _findIngredientByName(ingredients, ingredientName);
          final product = _findProductByName(availableProducts, matchedProductName);
          
          if (ingredient != null) {
            available.add(ingredient.copyWith(isAvailable: true));
            if (product != null) {
              matchedProducts[ingredientName] = product;
            }
          }
        }
      }

      // Procesar ingredientes faltantes
      if (response.containsKey('missing')) {
        final missingList = response['missing'] as List;
        for (var item in missingList) {
          final ingredientName = item['ingredient'] as String;
          final ingredient = _findIngredientByName(ingredients, ingredientName);
          if (ingredient != null) {
            missing.add(ingredient.copyWith(isAvailable: false));
          }
        }
      }

      // Procesar ingredientes opcionales
      if (response.containsKey('optional')) {
        final optionalList = response['optional'] as List;
        for (var item in optionalList) {
          final ingredientName = item['ingredient'] as String;
          final ingredient = _findIngredientByName(ingredients, ingredientName);
          if (ingredient != null) {
            optional.add(ingredient.copyWith(isOptional: true));
          }
        }
      }

      // Procesar ingredientes similares
      if (response.containsKey('similar')) {
        final similarList = response['similar'] as List;
        for (var item in similarList) {
          final ingredientName = item['ingredient'] as String;
          final ingredient = _findIngredientByName(ingredients, ingredientName);
          if (ingredient != null) {
            almostAvailable.add(ingredient);
          }
        }
      }

      // Calcular porcentaje de disponibilidad
      final totalRequired = ingredients.length - optional.length;
      final availableCount = available.length;
      final availabilityPercentage = totalRequired > 0 
          ? (availableCount / totalRequired) * 100 
          : 100.0;

      return IngredientAvailabilityResult(
        availableIngredients: available,
        missingIngredients: missing,
        optionalIngredients: optional,
        almostAvailableIngredients: almostAvailable,
        availabilityPercentage: availabilityPercentage,
        matchedProducts: matchedProducts,
      );
    } catch (e) {
      print('❌ Error parseando respuesta de IA: $e');
      // Return a basic fallback result instead of calling async method
      return IngredientAvailabilityResult(
        availableIngredients: [],
        missingIngredients: ingredients,
        optionalIngredients: [],
        almostAvailableIngredients: [],
        availabilityPercentage: 0.0,
        matchedProducts: {},
      );
    }
  }

  /// Análisis básico sin IA (fallback)
  Future<IngredientAvailabilityResult> _performBasicAnalysis(List<RecipeIngredient> ingredients) async {
    try {
      final inventoryProducts = await _inventoryService.getAllProducts();
      final availableProducts = inventoryProducts.where((product) =>
        product.productLocation == ProductLocation.inventory || 
        product.productLocation == ProductLocation.both
      ).toList();

      final available = <RecipeIngredient>[];
      final missing = <RecipeIngredient>[];
      final matchedProducts = <String, Product>{};

      for (final ingredient in ingredients) {
        bool found = false;
        
        for (final product in availableProducts) {
          if (_basicNameMatch(ingredient.name, product.name)) {
            available.add(ingredient.copyWith(isAvailable: true));
            matchedProducts[ingredient.name] = product;
            found = true;
            break;
          }
        }
        
        if (!found) {
          missing.add(ingredient.copyWith(isAvailable: false));
        }
      }

      final availabilityPercentage = ingredients.isNotEmpty 
          ? (available.length / ingredients.length) * 100 
          : 100.0;

      return IngredientAvailabilityResult(
        availableIngredients: available,
        missingIngredients: missing,
        optionalIngredients: [],
        almostAvailableIngredients: [],
        availabilityPercentage: availabilityPercentage,
        matchedProducts: matchedProducts,
      );
    } catch (e) {
      print('❌ Error en análisis básico: $e');
      return IngredientAvailabilityResult(
        availableIngredients: [],
        missingIngredients: ingredients,
        optionalIngredients: [],
        almostAvailableIngredients: [],
        availabilityPercentage: 0.0,
        matchedProducts: {},
      );
    }
  }

  /// Coincidencia básica de nombres
  bool _basicNameMatch(String ingredientName, String productName) {
    final ingredient = ingredientName.toLowerCase().trim();
    final product = productName.toLowerCase().trim();
    
    // Coincidencia exacta
    if (ingredient == product) return true;
    
    // Coincidencia parcial
    if (ingredient.contains(product) || product.contains(ingredient)) return true;
    
    // Coincidencias específicas comunes
    final commonMatches = {
      'huevo': ['huevos'],
      'tomate': ['tomates', 'tomate frito'],
      'cebolla': ['cebollas'],
      'ajo': ['ajos', 'dientes de ajo'],
      'leche': ['leche entera', 'leche desnatada'],
      'aceite': ['aceite de oliva', 'aceite vegetal'],
    };
    
    for (var entry in commonMatches.entries) {
      if (ingredient.contains(entry.key)) {
        for (var match in entry.value) {
          if (product.contains(match)) return true;
        }
      }
    }
    
    return false;
  }

  /// Encuentra ingrediente por nombre
  RecipeIngredient? _findIngredientByName(List<RecipeIngredient> ingredients, String name) {
    try {
      return ingredients.firstWhere(
        (ing) => ing.name.toLowerCase().trim() == name.toLowerCase().trim(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Encuentra producto por nombre
  Product? _findProductByName(List<Product> products, String name) {
    try {
      return products.firstWhere(
        (prod) => prod.name.toLowerCase().trim() == name.toLowerCase().trim(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Genera clave para cache
  String _generateCacheKey(List<RecipeIngredient> ingredients) {
    final names = ingredients.map((ing) => ing.name.toLowerCase()).toList()..sort();
    return names.join('|');
  }

  /// Limpia el cache
  void clearCache() {
    _analysisCache.clear();
  }

  /// Stream para análisis en tiempo real
  Stream<IngredientAvailabilityResult> getIngredientAvailabilityStream(
    List<RecipeIngredient> ingredients,
  ) async* {
    // Análisis inicial
    yield await analyzeIngredientAvailability(ingredients: ingredients);
    
    // Escuchar cambios en el inventario
    await for (final _ in _inventoryService.getProductsStream()) {
      // Reanalizar cuando cambie el inventario
      yield await analyzeIngredientAvailability(
        ingredients: ingredients,
        forceRefresh: true,
      );
    }
  }
}