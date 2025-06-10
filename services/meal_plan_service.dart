// lib/services/meal_plan_service.dart - VERSIÓN COMPLETA CON IA

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_plan_model.dart';
import '../models/recipe_model.dart';
import '../models/product_model.dart';
import '../models/product_location_model.dart';
import '../providers/shopping_list_provider.dart';
import 'inventory_service.dart';
import 'gemini_recipe_service.dart';
import 'recipe_service.dart';
import 'firestore_service.dart';
import 'smart_ingredient_analyzer.dart';
import '../config/theme.dart';
import '../config/routes.dart';

// Clase para resultados de migración de planes de comida
class MealPlanMigrationResult {
  final int totalMigrated;
  final int failedMigrations;
  final String message;

  MealPlanMigrationResult({
    required this.totalMigrated,
    required this.failedMigrations,
    required this.message,
  });

  bool get isSuccess => failedMigrations == 0;
  
  @override
  String toString() {
    return message;
  }
}

/// Resultado de verificación de duplicados
class DuplicateCheckResult {
  final List<RecipeIngredient> duplicates;
  final List<RecipeIngredient> uniqueIngredients;

  DuplicateCheckResult({
    required this.duplicates,
    required this.uniqueIngredients,
  });

  bool get hasDuplicates => duplicates.isNotEmpty;
}

/// Tipos de SnackBar
enum SnackBarType {
  success,
  error,
  warning,
  info,
}

/// Colores para SnackBar
class SnackBarColors {
  final Color backgroundColor;
  final Color iconColor;

  SnackBarColors({
    required this.backgroundColor,
    required this.iconColor,
  });
}

class MealPlanService {
  // Singleton para acceso global al servicio
  static final MealPlanService _instance = MealPlanService._internal();
  factory MealPlanService() => _instance;
  MealPlanService._internal();

  // Referencias a servicios
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final RecipeService _recipeService = RecipeService();
  final InventoryService _inventoryService = InventoryService();
  final GeminiRecipeService _recipeAIService = GeminiRecipeService();
  final SmartIngredientAnalyzerService _ingredientAnalyzer = SmartIngredientAnalyzerService();

  // Usuario actual
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Obtener referencia a la colección de planes de comida
  CollectionReference? get _userMealPlans {
    final userId = _userId;
    if (userId == null) return null;
    return _firestoreService.getUserMealPlans(userId);
  }

  // ================== MÉTODOS PRINCIPALES EXISTENTES ==================

  // Obtener todos los planes de comida
  Future<List<MealPlan>> getMealPlans() async {
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) return [];

      final snapshot = await _userMealPlans!.get();
      final mealPlans = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MealPlan.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
      
      // Cargar recetas para cada plan
      return _populateMealPlansWithRecipes(mealPlans);
    } catch (e) {
      print('Error al obtener planes de comida: $e');
      return [];
    }
  }

  // Método más robusto para cargar recetas en planes de comida
  Future<List<MealPlan>> _populateMealPlansWithRecipes(List<MealPlan> mealPlans) async {
    try {
      // Si no hay planes, retornar lista vacía
      if (mealPlans.isEmpty) return [];
      
      List<MealPlan> populatedPlans = [];
      
      for (final plan in mealPlans) {
        // Si el plan ya tiene una receta cargada con nombre válido, no hacer nada
        if (plan.recipe != null && plan.recipe!.name.isNotEmpty) {
          populatedPlans.add(plan);
          continue;
        }
        
        // Si no tiene receta pero tiene ID de receta, cargar la receta
        if (plan.recipeId.isNotEmpty) {
          try {
            final recipe = await _recipeService.getRecipeById(plan.recipeId);
            
            if (recipe != null) {
              // Añadir el plan con la receta cargada
              populatedPlans.add(MealPlan(
                id: plan.id,
                date: plan.date,
                mealTypeId: plan.mealTypeId,
                recipeId: plan.recipeId,
                recipe: recipe,
                isCompleted: plan.isCompleted,
              ));
              print('Receta cargada para plan ${plan.id}: ${recipe.name}');
            } else {
              // Si no se encontró la receta, intentar crear una receta temporal
              final tempRecipe = Recipe(
                id: plan.recipeId,
                name: 'Receta no encontrada',
                description: 'No se pudo cargar la información de esta receta',
                imageUrl: '',
                cookingTime: 0,
                servings: 0,
                difficulty: DifficultyLevel.easy,
                categories: [],
                ingredients: [],
                steps: [],
                calories: 0,
                nutrition: {},
              );
              
              populatedPlans.add(MealPlan(
                id: plan.id,
                date: plan.date,
                mealTypeId: plan.mealTypeId,
                recipeId: plan.recipeId,
                recipe: tempRecipe,
                isCompleted: plan.isCompleted,
              ));
              print('Receta no encontrada para plan ${plan.id}, usando temporal');
            }
          } catch (recipeError) {
            print('Error al cargar receta para plan ${plan.id}: $recipeError');
            populatedPlans.add(plan); // Mantener el plan original
          }
        } else {
          // Si no tiene receta ni ID, mantener el plan original
          populatedPlans.add(plan);
        }
      }
      
      return populatedPlans;
    } catch (e) {
      print('Error al cargar recetas para planes de comida: $e');
      return mealPlans; // En caso de error general, devolver los planes originales
    }
  }

  // Obtener planes de comida para una fecha específica
  Future<List<MealPlan>> getMealPlansForDate(DateTime date) async {
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) return [];

      // Crear fechas para comparar sólo día, mes y año
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      print('Buscando planes para la fecha: ${startOfDay.toIso8601String()} hasta ${endOfDay.toIso8601String()}');

      // Consultar planes de comida para la fecha específica
      final snapshot = await _userMealPlans!
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .get();

      final mealPlans = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        print('Plan encontrado - ID: ${doc.id}, RecipeID: ${data['recipeId'] ?? 'no recipeId'}');
        return MealPlan.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
      
      // Cargar recetas para cada plan
      final populatedPlans = await _populateMealPlansWithRecipes(mealPlans);
      
      print('Total de planes encontrados: ${populatedPlans.length}');
      
      return populatedPlans;
    } catch (e) {
      print('Error al obtener planes de comida por fecha: $e');
      return [];
    }
  }

  // Obtener planes de comida para un rango de fechas
  Future<List<MealPlan>> getMealPlansForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) return [];

      // Normalizar fechas para que incluyan todo el día
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      // Consultar planes de comida para el rango de fechas
      final snapshot = await _userMealPlans!
          .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('date', isLessThanOrEqualTo: end.toIso8601String())
          .get();

      final mealPlans = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MealPlan.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
      
      // Cargar recetas para cada plan
      return _populateMealPlansWithRecipes(mealPlans);
    } catch (e) {
      print('Error al obtener planes de comida por rango de fechas: $e');
      return [];
    }
  }

  // Obtener planes de comida por tipo de comida
  Future<List<MealPlan>> getMealPlansByMealType(String mealTypeId) async {
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) return [];

      final snapshot = await _userMealPlans!
          .where('mealTypeId', isEqualTo: mealTypeId)
          .get();

      final mealPlans = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MealPlan.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
      
      // Cargar recetas para cada plan
      return _populateMealPlansWithRecipes(mealPlans);
    } catch (e) {
      print('Error al obtener planes de comida por tipo: $e');
      return [];
    }
  }

  // Método para añadir un plan de comida - MEJORADO para asegurar que las recetas se guarden correctamente
  Future<String?> addMealPlan(MealPlan mealPlan) async {
    try {
      final userId = _userId;
      if (userId == null) {
        print('Error: No hay usuario autenticado');
        return null;
      }
      
      if (_userMealPlans == null) {
        print('Error: No se pudo acceder a la colección de planes de comida');
        return null;
      }
      
      // Verificar que tengamos una receta válida
      if (mealPlan.recipeId.isEmpty && mealPlan.recipe == null) {
        throw Exception('Se requiere una receta o ID de receta para crear un plan de comida');
      }
      
      String recipeId = mealPlan.recipeId;
      
      // Si se proporcionó una receta completa pero no ID, verificar si ya existe
      if (mealPlan.recipe != null) {
        Recipe recipe = mealPlan.recipe!;
        
        // Si la receta ya tiene ID, usarlo
        if (recipe.id.isNotEmpty) {
          recipeId = recipe.id;
          
          // Verificar si la receta existe en Firestore
          final existingRecipe = await _recipeService.getRecipeById(recipeId);
          if (existingRecipe == null) {
            // Si no existe, guardarla
            print('Receta con ID ${recipe.id} no encontrada, guardándola...');
            final savedId = await _recipeService.addRecipe(recipe);
            if (savedId != null) {
              recipeId = savedId;
            }
          }
        } else {
          // Si no tiene ID, guardarla como nueva
          print('Guardando nueva receta...');
          final savedId = await _recipeService.addRecipe(recipe);
          if (savedId == null) {
            throw Exception('No se pudo guardar la receta');
          }
          recipeId = savedId;
        }
      }
      
      // Verificar que ahora tengamos un ID de receta válido
      if (recipeId.isEmpty) {
        throw Exception('No se pudo obtener un ID válido para la receta');
      }
      
      // Preparar el mapa para guardar
      final Map<String, dynamic> mealPlanMap = {
        'date': mealPlan.date.toIso8601String(),
        'mealTypeId': mealPlan.mealTypeId,
        'recipeId': recipeId,
        'isCompleted': mealPlan.isCompleted,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      print('Añadiendo plan de comida para ${mealPlan.mealTypeId} con receta ID: $recipeId');
      
      // Añadir el documento a Firestore
      final docRef = await _userMealPlans!.add(mealPlanMap);
      print('Plan de comida añadido con ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error al añadir plan de comida: $e');
      return null;
    }
  }

  // Actualizar un plan de comida - ACTUALIZADO para referencias a recetas
  Future<bool> updateMealPlan(MealPlan mealPlan) async {
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) return false;
      
      // Verificar si el plan existe
      final docSnapshot = await _userMealPlans!.doc(mealPlan.id).get();
      if (!docSnapshot.exists) {
        throw Exception('El plan de comida no existe');
      }
      
      // Preparar el mapa para actualizar
      final Map<String, dynamic> mealPlanMap = {
        'date': mealPlan.date.toIso8601String(),
        'mealTypeId': mealPlan.mealTypeId,
        'recipeId': mealPlan.recipeId,
        'isCompleted': mealPlan.isCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Actualizar el documento en Firestore
      await _userMealPlans!.doc(mealPlan.id).update(mealPlanMap);
      return true;
    } catch (e) {
      print('Error al actualizar plan de comida: $e');
      return false;
    }
  }

  // Eliminar un plan de comida
  Future<bool> deleteMealPlan(String mealPlanId) async {
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) return false;

      // Eliminar el documento en Firestore
      await _userMealPlans!.doc(mealPlanId).delete();
      return true;
    } catch (e) {
      print('Error al eliminar plan de comida: $e');
      return false;
    }
  }

  // Marcar un plan de comida como completado
  Future<bool> toggleMealPlanCompleted(String mealPlanId, bool isCompleted) async {
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) return false;

      // Actualizar sólo el campo isCompleted
      await _userMealPlans!.doc(mealPlanId).update({
        'isCompleted': isCompleted,
      });
      
      // Si se marca como completado, actualizar inventario
      if (isCompleted) {
        await _updateInventoryAfterMealCompleted(mealPlanId);
      }
      
      return true;
    } catch (e) {
      print('Error al actualizar estado del plan de comida: $e');
      return false;
    }
  }

  // ================== MÉTODOS CON IA MEJORADOS ==================

  /// 🤖 Añade ingredientes faltantes a la lista de compras con análisis inteligente
  /// Incluye detección de duplicados y manejo de ingredientes opcionales
  Future<bool> addMissingIngredientsToShoppingList(
    Recipe recipe, {
    required ShoppingListProvider shoppingProvider,
    required BuildContext context,
  }) async {
    try {
      print('🔍 Analizando ingredientes de "${recipe.name}" con IA...');
      
      // Análisis inteligente de disponibilidad
      final availabilityResult = await _ingredientAnalyzer.analyzeIngredientAvailability(
        ingredients: recipe.ingredients,
        forceRefresh: true,
      );

      // Verificar si hay ingredientes que añadir
      if (availabilityResult.missingIngredients.isEmpty) {
        // Mostrar mensaje informativo si no faltan ingredientes
        _showEnhancedSnackBar(
          context: context,
          type: SnackBarType.info,
          title: 'Ingredientes completos',
          message: 'Ya tienes todos los ingredientes necesarios para "${recipe.name}"',
          icon: Icons.check_circle_outline_rounded,
        );
        return false;
      }

      // Si hay ingredientes opcionales, preguntar al usuario
      bool includeOptional = false;
      if (availabilityResult.hasOptionalIngredients) {
        includeOptional = await _showOptionalIngredientsDialog(
          context, 
          availabilityResult.optionalIngredients,
          recipe.name,
        );
      }

      // Preparar lista de ingredientes a añadir
      List<RecipeIngredient> ingredientsToAdd = [...availabilityResult.missingIngredients];
      if (includeOptional) {
        ingredientsToAdd.addAll(availabilityResult.optionalIngredients);
      }

      // Verificar duplicados en la lista de compras
      final duplicateCheckResult = await _checkForDuplicates(
        ingredientsToAdd,
        shoppingProvider.items,
      );

      if (duplicateCheckResult.hasDuplicates) {
        final shouldContinue = await _showDuplicatesDialog(
          context,
          duplicateCheckResult.duplicates,
          recipe.name,
        );
        
        if (!shouldContinue) {
          return false;
        }
        
        // Filtrar duplicados si el usuario decidió no añadirlos
        ingredientsToAdd = duplicateCheckResult.uniqueIngredients;
      }

      // Añadir ingredientes a la lista de compras
      int addedCount = 0;
      for (final ingredient in ingredientsToAdd) {
        final shoppingItem = ShoppingItem(
          id: DateTime.now().millisecondsSinceEpoch.toString() + addedCount.toString(),
          name: ingredient.name,
          quantity: ingredient.quantity is num ? (ingredient.quantity as num).toInt() : 1,
          unit: ingredient.unit,
          category: _getCategoryFromIngredient(ingredient.name),
          isPurchased: false,
        );
        
        await shoppingProvider.addItem(shoppingItem);
        addedCount++;
      }

      // Mostrar resultado
      if (addedCount > 0) {
        _showEnhancedSnackBar(
          context: context,
          type: SnackBarType.success,
          title: '¡Ingredientes añadidos!',
          message: 'Se añadieron $addedCount productos a tu lista de compras',
          icon: Icons.auto_awesome_rounded,
          action: SnackBarAction(
            label: 'VER LISTA',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, Routes.shoppingList);
            },
          ),
        );
        return true;
      } else {
        _showEnhancedSnackBar(
          context: context,
          type: SnackBarType.warning,
          title: 'Sin cambios',
          message: 'No se pudieron añadir ingredientes a la lista',
          icon: Icons.info_outline_rounded,
        );
        return false;
      }
    } catch (e) {
      print('❌ Error al añadir ingredientes: $e');
      _showEnhancedSnackBar(
        context: context,
        type: SnackBarType.error,
        title: 'Error',
        message: 'No se pudieron procesar los ingredientes: ${e.toString()}',
        icon: Icons.error_outline_rounded,
      );
      return false;
    }
  }

  // Método auxiliar para obtener categoría de un ingrediente
  String _getCategoryFromIngredient(String ingredientName) {
    final name = ingredientName.toLowerCase();
    
    if (name.contains('carne') || name.contains('pollo') || name.contains('cerdo') || name.contains('ternera')) {
      return 'Carnes';
    } else if (name.contains('pescado') || name.contains('salmón') || name.contains('atún')) {
      return 'Pescados';
    } else if (name.contains('leche') || name.contains('queso') || name.contains('yogur')) {
      return 'Lácteos';
    } else if (name.contains('tomate') || name.contains('cebolla') || name.contains('pimiento')) {
      return 'Verduras';
    } else if (name.contains('manzana') || name.contains('plátano') || name.contains('naranja')) {
      return 'Frutas';
    } else if (name.contains('arroz') || name.contains('pasta') || name.contains('pan')) {
      return 'Granos';
    } else {
      return 'Otros';
    }
  }

  /// Verifica duplicados en la lista de compras
  Future<DuplicateCheckResult> _checkForDuplicates(
    List<RecipeIngredient> ingredients,
    List<ShoppingItem> existingItems,
  ) async {
    final duplicates = <RecipeIngredient>[];
    final unique = <RecipeIngredient>[];

    for (final ingredient in ingredients) {
      bool isDuplicate = false;
      
      for (final existingItem in existingItems) {
        if (_isIngredientDuplicate(ingredient.name, existingItem.name)) {
          duplicates.add(ingredient);
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        unique.add(ingredient);
      }
    }

    return DuplicateCheckResult(
      duplicates: duplicates,
      uniqueIngredients: unique,
    );
  }

  /// Verifica si un ingrediente es duplicado
  bool _isIngredientDuplicate(String ingredientName, String itemName) {
    final ingredient = ingredientName.toLowerCase().trim();
    final item = itemName.toLowerCase().trim();
    
    // Coincidencia exacta
    if (ingredient == item) return true;
    
    // Coincidencia parcial (85% similar)
    return _calculateSimilarity(ingredient, item) > 0.85;
  }

  /// Calcula similitud entre dos strings
  double _calculateSimilarity(String str1, String str2) {
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;
    
    final longer = str1.length > str2.length ? str1 : str2;
    final shorter = str1.length > str2.length ? str2 : str1;
    
    final editDistance = _levenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }

  /// Calcula distancia de Levenshtein
  int _levenshteinDistance(String str1, String str2) {
    final matrix = List.generate(
      str2.length + 1,
      (i) => List.generate(str1.length + 1, (j) => 0),
    );
    
    for (int i = 0; i <= str2.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= str1.length; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= str2.length; i++) {
      for (int j = 1; j <= str1.length; j++) {
        final cost = str1[j - 1] == str2[i - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[str2.length][str1.length];
  }

  /// Muestra diálogo para ingredientes opcionales
  Future<bool> _showOptionalIngredientsDialog(
    BuildContext context,
    List<RecipeIngredient> optionalIngredients,
    String recipeName,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF2C2C2C) 
            : AppTheme.pureWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.yellowAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: AppTheme.yellowAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Ingredientes opcionales',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hemos detectado ingredientes opcionales para "$recipeName". ¿Deseas incluirlos en tu lista de compras?',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.peachLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingredientes opcionales:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...optionalIngredients.map((ingredient) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 6,
                          color: AppTheme.coralMain,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${ingredient.name} (${ingredient.quantity} ${ingredient.unit})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
                vertical: AppTheme.spacingMedium,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
            child: const Text(
              'Solo esenciales',
              style: TextStyle(color: AppTheme.mediumGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralMain,
              foregroundColor: AppTheme.pureWhite,
              elevation: AppTheme.elevationSmall,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
                vertical: AppTheme.spacingMedium,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
            child: const Text(
              'Incluir todos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.all(AppTheme.spacingMedium),
      ),
    ) ?? false;
  }

  /// Muestra diálogo para duplicados
  Future<bool> _showDuplicatesDialog(
    BuildContext context,
    List<RecipeIngredient> duplicates,
    String recipeName,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF2C2C2C) 
            : AppTheme.pureWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.yellowAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.yellowAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Productos duplicados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Algunos ingredientes de "$recipeName" ya están en tu lista de compras:',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            
              Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.yellowAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                border: Border.all(
                  color: AppTheme.yellowAccent.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ya en tu lista:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...duplicates.map((ingredient) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppTheme.successGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ingredient.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '¿Qué deseas hacer?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
                vertical: AppTheme.spacingMedium,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.mediumGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralMain,
              foregroundColor: AppTheme.pureWhite,
              elevation: AppTheme.elevationSmall,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
                vertical: AppTheme.spacingMedium,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
            child: const Text(
              'Solo nuevos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.all(AppTheme.spacingMedium),
      ),
    ) ?? false;
  }

  /// Muestra SnackBar mejorado con diferentes tipos
  void _showEnhancedSnackBar({
    required BuildContext context,
    required SnackBarType type,
    required String title,
    required String message,
    required IconData icon,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    final colors = _getSnackBarColors(type);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        backgroundColor: colors.backgroundColor,
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppTheme.spacingMedium),
        elevation: AppTheme.elevationMedium,
        duration: duration,
        action: action,
      ),
    );
  }

  /// Obtiene colores según el tipo de SnackBar
  SnackBarColors _getSnackBarColors(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return SnackBarColors(
          backgroundColor: AppTheme.successGreen,
          iconColor: Colors.white,
        );
      case SnackBarType.error:
        return SnackBarColors(
          backgroundColor: AppTheme.errorRed,
          iconColor: Colors.white,
        );
      case SnackBarType.warning:
        return SnackBarColors(
          backgroundColor: AppTheme.yellowAccent,
          iconColor: Colors.white,
        );
      case SnackBarType.info:
        return SnackBarColors(
          backgroundColor: AppTheme.darkGrey,
          iconColor: Colors.white,
        );
    }
  }

  // ================== FUNCIONES PARA INTEGRACIÓN CON INVENTARIO ==================

  // Actualizar inventario después de completar una comida
  Future<void> _updateInventoryAfterMealCompleted(String mealPlanId) async {
    try {
      // Obtener el plan de comida completo con su receta
      final planSnapshot = await _userMealPlans?.doc(mealPlanId).get();
      if (planSnapshot == null || !planSnapshot.exists) return;
      
      final data = planSnapshot.data() as Map<String, dynamic>;
      final mealPlan = MealPlan.fromMap({
        'id': planSnapshot.id,
        ...data,
      });
      
      // No actualizar si el plan no está marcado como completado
      if (!mealPlan.isCompleted) return;
      
      // Verificar si necesitamos cargar la receta
      Recipe? recipe;
      if (mealPlan.recipe != null) {
        recipe = mealPlan.recipe;
      } else if (mealPlan.recipeId.isNotEmpty) {
        recipe = await _recipeService.getRecipeById(mealPlan.recipeId);
      }
      
      if (recipe == null) return;
      
      // Obtener productos del inventario
      final inventory = await _inventoryService.getAllProducts();
      
      // Por cada ingrediente de la receta, actualizar inventario
      for (final ingredient in recipe.ingredients) {
        final matchingProducts = inventory.where((product) => 
          _isProductMatchingIngredient(product, ingredient)
        ).toList();
        
        if (matchingProducts.isNotEmpty) {
          final product = matchingProducts.first;
          
          // Calcular nueva cantidad
          int newQuantity = product.quantity;
          
          // Si el ingrediente tiene una cantidad numérica, restarla
          if (ingredient.quantity is int) {
            newQuantity -= (ingredient.quantity as int);
          } else if (ingredient.quantity is double) {
            newQuantity -= (ingredient.quantity as double).toInt();
          } else if (ingredient.quantity is num) {
            // Esto manejará cualquier tipo numérico
            newQuantity -= (ingredient.quantity as num).toInt();
          } else {
            // Si no es numérico, restar 1 unidad
            newQuantity -= 1;
          }
          
          // Asegurar que la cantidad no sea negativa
          newQuantity = newQuantity < 0 ? 0 : newQuantity;
          
          // Actualizar cantidad del producto
          await _inventoryService.updateProductQuantity(product.id, newQuantity);
        }
      }
    } catch (e) {
      print('Error al actualizar inventario después de completar comida: $e');
    }
  }
  
  // Verificar si un producto coincide con un ingrediente
  bool _isProductMatchingIngredient(Product product, RecipeIngredient ingredient) {
    // Comparar nombres sin distinguir entre mayúsculas y minúsculas
    final productName = product.name.toLowerCase();
    final ingredientName = ingredient.name.toLowerCase();
    
    // Verificar si el nombre del producto contiene el nombre del ingrediente o viceversa
    return productName.contains(ingredientName) || ingredientName.contains(productName);
  }

  // ================== FUNCIONES DE IA Y RECOMENDACIÓN ==================

  // Generar un plan de comidas con IA a partir de ingredientes disponibles
  Future<List<MealPlan>> generateMealPlanWithAI({
    required DateTime date,
    required List<String> mealTypeIds,
    String? cuisine,
  }) async {
    try {
      // Obtener productos del inventario
      final inventory = await _inventoryService.getAllProducts();
      
      // Obtener solo los productos que están en el inventario
      final availableProducts = inventory.where((product) => 
        product.productLocation == ProductLocation.inventory || 
        product.productLocation == ProductLocation.both
      ).toList();
      
      if (availableProducts.isEmpty) {
        throw Exception('No hay productos disponibles en el inventario');
      }
      
      // Generar recetas usando el servicio de IA
      final recipes = await _recipeAIService.generateRecipesFromIngredients(
        availableIngredients: availableProducts,
        cuisine: cuisine,
        numberOfRecipes: mealTypeIds.length, // Generar una receta por tipo de comida
      );
      
      if (recipes.isEmpty) {
        throw Exception('No se pudieron generar recetas');
      }
      
      // Guardar las recetas generadas en la colección del usuario
      final recipeIds = <String>[];
      for (final recipe in recipes) {
        final recipeId = await _recipeService.addRecipe(recipe);
        if (recipeId != null) {
          recipeIds.add(recipeId);
        }
      }
      
      if (recipeIds.isEmpty) {
        throw Exception('No se pudieron guardar las recetas generadas');
      }
      
      // Crear planes de comida para cada tipo de comida
      final List<MealPlan> mealPlans = [];
      
      // Asignar recetas a los tipos de comida
      for (int i = 0; i < mealTypeIds.length; i++) {
        // Si hay menos recetas que tipos de comida, usar el índice circular
        final recipeIndex = i % recipeIds.length;
        
        mealPlans.add(MealPlan(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(), // ID temporal
          date: date,
          mealTypeId: mealTypeIds[i],
          recipeId: recipeIds[recipeIndex],
          isCompleted: false,
        ));
      }
      
      return mealPlans;
    } catch (e) {
      print('Error al generar plan de comidas con IA: $e');
      return [];
    }
  }

  // Generar plan de comida para productos que están por caducar
  Future<List<MealPlan>> generateMealPlanForExpiringProducts({
    required DateTime date,
    required List<String> mealTypeIds,
    int daysThreshold = 5, // Productos que caduquen en 5 días o menos
    String? cuisine,
  }) async {
    try {
      // Obtener productos que están por caducar
      final expiringProducts = await _inventoryService.getExpiringProducts(daysThreshold);
      
      if (expiringProducts.isEmpty) {
        throw Exception('No hay productos por caducar en los próximos $daysThreshold días');
      }
      
      // Obtener todos los productos disponibles para complementar
      final allProducts = await _inventoryService.getAllProducts();
      final availableProducts = allProducts.where((product) => 
        product.productLocation == ProductLocation.inventory || 
        product.productLocation == ProductLocation.both
      ).toList();
      
      // Generar recetas priorizando los productos que caducan pronto
      final recipes = await _recipeAIService.generateRecipesFromExpiringProducts(
        expiringProducts: expiringProducts,
        additionalProducts: availableProducts,
        cuisine: cuisine,
        numberOfRecipes: mealTypeIds.length,
      );
      
      if (recipes.isEmpty) {
        throw Exception('No se pudieron generar recetas para los productos que caducan pronto');
      }
      
      // Guardar las recetas generadas en la colección del usuario
      final recipeIds = <String>[];
      for (final recipe in recipes) {
        final recipeId = await _recipeService.addRecipe(recipe);
        if (recipeId != null) {
          recipeIds.add(recipeId);
        }
      }
      
      if (recipeIds.isEmpty) {
        throw Exception('No se pudieron guardar las recetas generadas');
      }
      
      // Crear planes de comida para cada tipo de comida
      final List<MealPlan> mealPlans = [];
      
      // Asignar recetas a los tipos de comida
      for (int i = 0; i < mealTypeIds.length; i++) {
        // Si hay menos recetas que tipos de comida, usar el índice circular
        final recipeIndex = i % recipeIds.length;
        
        mealPlans.add(MealPlan(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          date: date,
          mealTypeId: mealTypeIds[i],
          recipeId: recipeIds[recipeIndex],
          isCompleted: false,
        ));
      }
      
      return mealPlans;
    } catch (e) {
      print('Error al generar plan para productos que caducan: $e');
      return [];
    }
  }

  // Guardar múltiples planes de comida
  Future<List<String>> saveMealPlans(List<MealPlan> mealPlans) async {
    final List<String> savedIds = [];
    
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) return [];

      // Registro de depuración
      print('Guardando ${mealPlans.length} planes de comida');
      
      for (final mealPlan in mealPlans) {
        // Convertir a mapa con formato correcto para Firestore (solo referencia a receta)
        final Map<String, dynamic> mealPlanMap = {
          'date': mealPlan.date.toIso8601String(),
          'mealTypeId': mealPlan.mealTypeId,
          'recipeId': mealPlan.recipeId,
          'isCompleted': mealPlan.isCompleted,
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        print('Guardando plan para ${mealPlan.mealTypeId}');
        
        // Añadir el documento a Firestore
        try {
          final docRef = await _userMealPlans!.add(mealPlanMap);
          savedIds.add(docRef.id);
          print('Plan guardado con ID: ${docRef.id}');
        } catch (e) {
          print('Error al guardar plan individual: $e');
          continue; // Continuar con el siguiente plan si este falla
        }
      }
      
      print('Guardados ${savedIds.length} de ${mealPlans.length} planes');
      return savedIds;
    } catch (e) {
      print('Error al guardar planes de comida: $e');
      return [];
    }
  }

  // ================== MÉTODOS DE COMPATIBILIDAD Y ESTADÍSTICAS ==================

  // Validar que los planes de comida existan para el usuario actual
  Future<bool> validateUserMealPlans() async {
    try {
      final userId = _userId;
      if (userId == null) return false;
      
      // Verificar si la colección de planes de comida existe
      final collection = _userMealPlans;
      if (collection == null) return false;
      
      // Intentar leer la colección
      final snapshot = await collection.limit(1).get();
      
      // Si llegamos aquí, la colección existe y es accesible
      return true;
    } catch (e) {
      print('Error validando planes de comida del usuario: $e');
      return false;
    }
  }

  // Método para depurar planes de comida
  Future<Map<String, dynamic>> debugMealPlanState() async {
    try {
      final userId = _userId;
      if (userId == null) {
        return {'error': 'No hay usuario autenticado'};
      }
      
      // Verificar colección
      final collectionPath = 'users/$userId/mealPlans';
      final collectionExists = await _firestore.collection(collectionPath).limit(1).get()
        .then((snapshot) => snapshot.docs.isNotEmpty)
        .catchError((_) => false);
      
      // Contar documentos
      final docCount = await _firestore.collection(collectionPath).count().get()
        .then((snapshot) => snapshot.count)
        .catchError((_) => -1);
      
      // Obtener ejemplo de documento si existe
      Map<String, dynamic>? sampleDoc;
      if (collectionExists) {
        sampleDoc = await _firestore.collection(collectionPath).limit(1).get()
          .then((snapshot) => snapshot.docs.isNotEmpty ? 
                snapshot.docs.first.data() : null)
          .catchError((_) => null);
      }
      
      // Verificar la nueva colección de recetas
      final recipeCollectionPath = 'users/$userId/recipes';
      final recipeCollectionExists = await _firestore.collection(recipeCollectionPath).limit(1).get()
        .then((snapshot) => snapshot.docs.isNotEmpty)
        .catchError((_) => false);
      
      final recipeCount = await _firestore.collection(recipeCollectionPath).count().get()
        .then((snapshot) => snapshot.count)
        .catchError((_) => -1);
      
      return {
        'userId': userId,
        'mealPlansCollectionPath': collectionPath,
        'mealPlansCollectionExists': collectionExists,
        'mealPlanDocumentCount': docCount,
        'sampleMealPlanDocument': sampleDoc,
        'recipesCollectionPath': recipeCollectionPath,
        'recipesCollectionExists': recipeCollectionExists,
        'recipeDocumentCount': recipeCount,
      };
    } catch (e) {
      return {'error': 'Error en depuración: $e'};
    }
  }

  // Recomendación inteligente de recetas basada en historial
  Future<List<Recipe>> getRecommendedRecipes({
    int limit = 5,
    String? mealTypeId,
  }) async {
    try {
      // Obtener historial de planes de comida
      final allMealPlans = await getMealPlans();
      
      // Identificar recetas más populares por tipo de comida
      final Map<String, Map<String, int>> recipeCountByMealType = {};
      
      for (final plan in allMealPlans) {
        if (!recipeCountByMealType.containsKey(plan.mealTypeId)) {
          recipeCountByMealType[plan.mealTypeId] = {};
        }
        
        final recipeId = plan.recipeId;
        recipeCountByMealType[plan.mealTypeId]![recipeId] = 
            (recipeCountByMealType[plan.mealTypeId]![recipeId] ?? 0) + 1;
      }
      
      // Filtrar por tipo de comida si se especifica
      if (mealTypeId != null && recipeCountByMealType.containsKey(mealTypeId)) {
        // Ordenar recetas por popularidad
        final recipeEntries = recipeCountByMealType[mealTypeId]!.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        // Obtener IDs de las recetas más populares
        final popularRecipeIds = recipeEntries.take(limit).map((e) => e.key).toList();
        
        // Obtener detalles completos de las recetas
        final List<Recipe> popularRecipes = [];
        
        for (final recipeId in popularRecipeIds) {
          final recipe = await _recipeService.getRecipeById(recipeId);
          if (recipe != null) {
            popularRecipes.add(recipe);
          }
        }
        
        return popularRecipes;
      } else {
        // Si no se especifica tipo de comida o no hay historial, obtener recetas aleatorias
        final allRecipes = await _recipeService.getAllRecipes();
        
        if (allRecipes.isEmpty) {
          return [];
        }
        
        // Ordenar aleatoriamente
        allRecipes.shuffle();
        
        // Limitar el número de resultados
        return allRecipes.take(limit).toList();
      }
    } catch (e) {
      print('Error al obtener recetas recomendadas: $e');
      return [];
    }
  }

  // Obtener recetas que utilizan un producto específico
  Future<List<Recipe>> getRecipesUsingProduct(String productName) async {
    try {
      // Obtener todas las recetas
      final allRecipes = await _recipeService.getAllRecipes();
      
      // Filtrar recetas que utilizan el producto
      return allRecipes.where((recipe) {
        return recipe.ingredients.any((ingredient) => 
          ingredient.name.toLowerCase().contains(productName.toLowerCase())
        );
      }).toList();
    } catch (e) {
      print('Error al buscar recetas con el producto: $e');
      return [];
    }
  }

  // Obtener estadísticas del plan de comidas
  Future<Map<String, dynamic>> getMealPlanStats() async {
    try {
      // Obtener todos los planes de comida
      final allMealPlans = await getMealPlans();
      
      // Si no hay planes, devolver estadísticas vacías
      if (allMealPlans.isEmpty) {
        return {
          'totalMealPlans': 0,
          'completedMealPlans': 0,
          'completionRate': 0.0,
          'topMealTypes': [],
          'topRecipes': [],
        };
      }
      
      // Calcular estadísticas básicas
      final totalMealPlans = allMealPlans.length;
      final completedMealPlans = allMealPlans.where((plan) => plan.isCompleted).length;
      final completionRate = totalMealPlans > 0 
        ? completedMealPlans / totalMealPlans 
        : 0.0;
      
      // Contar tipos de comida
      final Map<String, int> mealTypeCounts = {};
      for (final plan in allMealPlans) {
        mealTypeCounts[plan.mealTypeId] = (mealTypeCounts[plan.mealTypeId] ?? 0) + 1;
      }
      
      // Ordenar tipos de comida por frecuencia
      final topMealTypes = mealTypeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      // Contar recetas
      final Map<String, Map<String, dynamic>> recipeCounts = {};
      for (final plan in allMealPlans) {
        final recipeId = plan.recipeId;
        final recipeName = plan.recipe?.name ?? recipeId;
        
        if (!recipeCounts.containsKey(recipeId)) {
          recipeCounts[recipeId] = {
            'name': recipeName,
            'count': 0,
          };
        }
        
        recipeCounts[recipeId]!['count'] = recipeCounts[recipeId]!['count'] + 1;
      }
      
      // Ordenar recetas por frecuencia
      final topRecipes = recipeCounts.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return {
        'totalMealPlans': totalMealPlans,
        'completedMealPlans': completedMealPlans,
        'completionRate': completionRate,
        'topMealTypes': topMealTypes.take(5).map((e) => {
          'mealTypeId': e.key,
          'count': e.value,
        }).toList(),
        'topRecipes': topRecipes.take(5).toList(),
      };
    } catch (e) {
      print('Error al obtener estadísticas del plan de comidas: $e');
      return {
        'error': 'No se pudieron obtener las estadísticas',
      };
    }
  }

  // ================== STREAMS PARA ACTUALIZACIONES EN TIEMPO REAL ==================

  // Stream de planes de comida para actualizaciones en tiempo real
  Stream<List<MealPlan>> getMealPlansStream() {
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) return Stream.value([]);
      
      return _userMealPlans!.snapshots().asyncMap((snapshot) async {
        final mealPlans = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return MealPlan.fromMap({
            'id': doc.id,
            ...data,
          });
        }).toList();
        
        // Cargar recetas para cada plan
        return _populateMealPlansWithRecipes(mealPlans);
      });
    } catch (e) {
      print('Error al obtener stream de planes de comida: $e');
      return Stream.value([]);
    }
  }

  // Stream de planes de comida para una fecha específica
  Stream<List<MealPlan>> getMealPlansForDateStream(DateTime date) {
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) return Stream.value([]);
      
      // Crear fechas para comparar sólo día, mes y año
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      return _userMealPlans!
        .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('date', isLessThanOrEqualTo: endOfDay.toIso8601String())
        .snapshots()
        .asyncMap((snapshot) async {
          final mealPlans = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return MealPlan.fromMap({
              'id': doc.id,
              ...data,
            });
          }).toList();
          
          // Cargar recetas para cada plan
          return _populateMealPlansWithRecipes(mealPlans);
        });
    } catch (e) {
      print('Error al obtener stream de planes de comida por fecha: $e');
      return Stream.value([]);
    }
  }

  // ================== MÉTODOS DE MIGRACIÓN ==================

  // Método para migrar planes de comida existentes al nuevo formato
  Future<MealPlanMigrationResult> migrateMealPlans() async {
    try {
      final userId = _userId;
      if (userId == null || _userMealPlans == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Resultados de migración
      int totalPlansMigrated = 0;
      int failedMigrations = 0;
      
      // Obtener todos los planes de comida actuales
      final snapshot = await _userMealPlans!.get();
      
      // Verificar si ya están en el nuevo formato
      bool hasOldFormat = false;
      
      // Primera pasada: verificar si hay planes en formato antiguo
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Si tiene receta embebida pero no recipeId, está en formato antiguo
        if ((data['recipe'] is Map) && (!data.containsKey('recipeId') || data['recipeId'] == null)) {
          hasOldFormat = true;
          break;
        }
      }
      
      if (!hasOldFormat) {
        return MealPlanMigrationResult(
          totalMigrated: 0,
          failedMigrations: 0,
          message: 'No hay planes de comida en formato antiguo que migrar',
        );
      }
      
      // Segunda pasada: migrar los planes en formato antiguo
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // Verificar si el plan tiene receta embebida pero no recipeId
          if ((data['recipe'] is Map) && (!data.containsKey('recipeId') || data['recipeId'] == null)) {
            // Extraer los datos de la receta embebida
            final recipeData = data['recipe'] as Map<String, dynamic>;
            
            // Crear un objeto Recipe a partir de los datos embebidos
            final recipe = Recipe.fromMap({
              'id': recipeData['id'] ?? '',
              ...recipeData,
            });
            
            // Guardar la receta en la nueva colección de recetas del usuario
            String? recipeId = recipe.id;
            
            if (recipeId.isEmpty) {
              // Si la receta no tiene ID, guardarla como nueva
              recipeId = await _recipeService.addRecipe(recipe);
            } else {
              // Si ya tiene ID, verificar si existe en la nueva colección
              final existingRecipe = await _recipeService.getRecipeById(recipeId);
              
              if (existingRecipe == null) {
                // La receta no existe, guardarla
                print('Receta con ID ${recipe.id} no encontrada, guardándola...');
                final savedId = await _recipeService.addRecipe(recipe);
                if (savedId != null) {
                  recipeId = savedId;
                }
              }
            }
            
            if (recipeId != null && recipeId.isNotEmpty) {
              // Actualizar el plan de comida para usar solo la referencia
              final Map<String, dynamic> updateData = {
                'recipeId': recipeId,
                'updatedAt': FieldValue.serverTimestamp(),
                'migratedAt': FieldValue.serverTimestamp(),
              };
              
              // Opcionalmente, eliminar la receta embebida para ahorrar espacio
              updateData['recipe'] = FieldValue.delete();
              
              await doc.reference.update(updateData);
              totalPlansMigrated++;
            } else {
              throw Exception('No se pudo obtener un ID válido para la receta');
            }
          }
        } catch (e) {
          print('Error al migrar plan de comida ${doc.id}: $e');
          failedMigrations++;
        }
      }
      
      return MealPlanMigrationResult(
        totalMigrated: totalPlansMigrated,
        failedMigrations: failedMigrations,
        message: 'Migración completada: $totalPlansMigrated planes migrados, $failedMigrations fallos',
      );
    } catch (e) {
      print('Error general al migrar planes de comida: $e');
      return MealPlanMigrationResult(
        totalMigrated: 0,
        failedMigrations: 1,
        message: 'Error durante la migración: ${e.toString()}',
      );
    }
  }
}