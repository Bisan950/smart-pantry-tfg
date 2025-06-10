// lib/models/meal_plan_model.dart - Versión corregida

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recipe_model.dart';

class MealPlan {
  final String id;
  final DateTime date;
  final String mealTypeId;
  final String recipeId;        // Campo obligatorio ahora
  final Recipe? recipe;         // Ahora es opcional
  final bool isCompleted;

  const MealPlan({
    required this.id,
    required this.date,
    required this.mealTypeId,
    required this.recipeId,     // Ahora es obligatorio
    this.recipe,                // Ahora es opcional
    this.isCompleted = false,
  });

  // Para crear un mapa de comidas por tipo
  static Map<String, List<MealPlan>> groupByMealType(List<MealPlan> meals) {
    final result = <String, List<MealPlan>>{};
    
    for (final meal in meals) {
      if (!result.containsKey(meal.mealTypeId)) {
        result[meal.mealTypeId] = [];
      }
      result[meal.mealTypeId]?.add(meal);
    }
    
    return result;
  }

  // Factory para crear desde un mapa (JSON) - ACTUALIZADO para manejar ambos formatos
  factory MealPlan.fromMap(Map<String, dynamic> map) {
    // Manejar diferentes tipos de fecha (Timestamp o String)
    DateTime date;
    if (map['date'] is Timestamp) {
      date = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      date = DateTime.parse(map['date']);
    } else {
      // Fallback por si la fecha es null o tipo incorrecto
      date = DateTime.now();
    }
    
    // Manejar compatibilidad con formato antiguo y nuevo
    Recipe? recipe;
    String recipeId;
    
    // Formato nuevo: Primero verificar si hay un recipeId
    if (map.containsKey('recipeId') && map['recipeId'] != null) {
      recipeId = map['recipeId'];
      
      // Si también tiene recipe, cargarla
      if (map.containsKey('recipe') && map['recipe'] is Map) {
        final recipeMap = Map<String, dynamic>.from(map['recipe']);
        recipe = Recipe.fromMap(recipeMap);
      }
    } 
    // Formato antiguo: Solo tiene receta embebida
    else if (map.containsKey('recipe') && map['recipe'] is Map) {
      final recipeMap = Map<String, dynamic>.from(map['recipe']);
      recipe = Recipe.fromMap(recipeMap);
      recipeId = recipe.id; // Usar el ID de la receta embebida
    } 
    // Error: No tiene ni recipeId ni recipe
    else {
      // Como ahora recipeId es requerido, proporcionar un valor por defecto
      recipeId = '';
      // Log para diagnóstico
      print('⚠️ Advertencia: MealPlan sin recipeId ni recipe: $map');
    }
    
    return MealPlan(
      id: map['id'] ?? '',
      date: date,
      mealTypeId: map['mealTypeId'] ?? '',
      recipeId: recipeId,
      recipe: recipe,
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  // Convertir a mapa (JSON) - ACTUALIZADO para usar solo ID de receta
  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'date': date.toIso8601String(),
      'mealTypeId': mealTypeId,
      'recipeId': recipeId,    // Guardar solo la referencia
      'isCompleted': isCompleted,
      'userId': FirebaseAuth.instance.currentUser?.uid, // Para redundancia
      'createdAt': FieldValue.serverTimestamp(), // Timestamp de creación
    };
    
    // No incluir la receta completa en el mapa
    // Si se necesita, debe cargarse por separado
    
    return map;
  }

  // Crear una copia con cambios
  MealPlan copyWith({
    String? id,
    DateTime? date,
    String? mealTypeId,
    String? recipeId,
    Recipe? recipe,
    bool? isCompleted,
  }) {
    return MealPlan(
      id: id ?? this.id,
      date: date ?? this.date,
      mealTypeId: mealTypeId ?? this.mealTypeId,
      recipeId: recipeId ?? this.recipeId,
      recipe: recipe ?? this.recipe,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
  
  // Método para actualizar la receta del plan
  MealPlan withRecipe(Recipe newRecipe) {
    return MealPlan(
      id: id,
      date: date,
      mealTypeId: mealTypeId,
      recipeId: newRecipe.id,
      recipe: newRecipe,
      isCompleted: isCompleted,
    );
  }
  
  // Verificar si el plan tiene una receta cargada
  bool get hasLoadedRecipe => recipe != null;
}