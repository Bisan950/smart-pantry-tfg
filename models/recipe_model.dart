// lib/models/recipe_model.dart

import 'dart:developer' as developer;

// Enum for difficulty levels - used in the DifficultyIndicator
enum DifficultyLevel {
  easy,
  medium,
  hard,
}

class Recipe {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int preparationTime;
  final int cookingTime;
  final int servings;
  final DifficultyLevel difficulty;
  final List<String> categories;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final int calories;
  final Map<String, dynamic> nutrition;
  final NutritionalInfo? nutritionalInfo; // Added for backward compatibility
  final String? userId; // Nuevo campo para identificar al propietario de la receta
  final DateTime? createdAt; // Añadido para seguimiento temporal
  final DateTime? updatedAt; // Añadido para seguimiento temporal
  final bool isFavorite; // Nueva propiedad para marcar recetas favoritas

  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.cookingTime,
    this.preparationTime = 0,
    required this.servings,
    required this.difficulty,
    required this.categories,
    required this.ingredients,
    required this.steps,
    required this.calories,
    required this.nutrition,
    this.nutritionalInfo,
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.isFavorite = false, // Por defecto, las recetas no son favoritas
  });

  // Get total time (preparation + cooking)
  int get totalTime => preparationTime + cookingTime;

  // Check if recipe has a specific category
  bool hasCategory(String category) {
    return categories.map((c) => c.toLowerCase()).contains(category.toLowerCase());
  }

  // Get the percentage of available ingredients
  double get availableIngredientsPercentage {
    if (ingredients.isEmpty) return 0;
    final available = ingredients.where((i) => i.isAvailable).length;
    return available / ingredients.length;
  }

  // Check if all ingredients are available
  bool get hasAllIngredients {
    return ingredients.every((i) => i.isAvailable);
  }

  // Get missing ingredients
  List<RecipeIngredient> get missingIngredients {
    return ingredients.where((i) => !i.isAvailable).toList();
  }

  // Get difficulty as Spanish string for display
  String get difficultyDisplayName {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return 'Fácil';
      case DifficultyLevel.medium:
        return 'Intermedio';
      case DifficultyLevel.hard:
        return 'Difícil';
    }
  }

  // Get formatted time string
  String get formattedTime {
    if (totalTime < 60) {
      return '${totalTime}min';
    } else {
      final hours = totalTime ~/ 60;
      final minutes = totalTime % 60;
      if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${minutes}min';
      }
    }
  }

  // Factory constructor to create a Recipe from a map (JSON)
  factory Recipe.fromMap(Map<String, dynamic> map) {
    // Log para depuración
    developer.log("Creando receta desde mapa con ID: \"${map['id']}\"", name: "RecipeModel");
    
    // IMPORTANTE: Usar el ID exactamente como viene, sin modificarlo
    final id = map['id']?.toString() ?? '';
    
    if (id.isEmpty) {
      developer.log("ADVERTENCIA: Creando receta sin ID o con ID vacío", name: "RecipeModel");
    }
    
    // Convertir datos de timestamp a DateTime si existen
    DateTime? parseTimestamp(dynamic timestamp) {
      if (timestamp == null) return null;
      
      // Manejar distintos tipos de datos para timestamps
      if (timestamp is DateTime) return timestamp;
      if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (timestamp is String) {
        // Intentar parsear como int (timestamp)
        try {
          return DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
        } catch (e) {
          // Intentar parsear como DateTime ISO
          try {
            return DateTime.parse(timestamp);
          } catch (e) {
            return null;
          }
        }
      }
      return null;
    }

    // Convert string difficulty to enum
    DifficultyLevel getDifficultyLevel(String? difficulty) {
      if (difficulty == null) return DifficultyLevel.medium;
      
      switch (difficulty.toLowerCase()) {
        case 'fácil':
        case 'facil':
        case 'easy':
          return DifficultyLevel.easy;
        case 'media':
        case 'medio':
        case 'intermedio':
        case 'medium':
          return DifficultyLevel.medium;
        case 'difícil':
        case 'dificil':
        case 'hard':
          return DifficultyLevel.hard;
        default:
          return DifficultyLevel.medium;
      }
    }

    // Manejar diferentes formatos de ingredientes
    List<RecipeIngredient> parseIngredients(dynamic ingredientsData) {
      if (ingredientsData is List) {
        return ingredientsData.map((x) {
          if (x is Map<String, dynamic>) {
            return RecipeIngredient.fromMap(x);
          }
          return RecipeIngredient(
            name: 'Ingrediente desconocido',
            quantity: 0,
            unit: '',
          );
        }).toList();
      }
      return [];
    }

    // Crear la receta a partir del mapa
    final recipe = Recipe(
      id: id, // Usar el ID sin modificarlo
      name: map['name'] ?? 'Receta sin nombre',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      preparationTime: map['preparationTime'] ?? 0,
      cookingTime: map['cookingTime'] ?? 0,
      servings: map['servings'] ?? 2,
      difficulty: getDifficultyLevel(map['difficulty']),
      categories: map['categories'] != null 
          ? List<String>.from(map['categories']) 
          : [],
      ingredients: map['ingredients'] != null 
          ? parseIngredients(map['ingredients'])
          : [],
      steps: map['steps'] != null 
          ? List<String>.from(map['steps']) 
          : [],
      calories: map['calories'] ?? 0,
      nutrition: map['nutrition'] != null 
          ? Map<String, dynamic>.from(map['nutrition']) 
          : {},
      nutritionalInfo: map['nutritionalInfo'] != null 
          ? NutritionalInfo.fromMap(map['nutritionalInfo']) 
          : null,
      userId: map['userId'],
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
      isFavorite: map['isFavorite'] ?? false, // Parsear el estado de favorito
    );
    
    // Log para confirmar la creación
    developer.log(
      "Receta creada: ID=\"${recipe.id}\", Nombre=\"${recipe.name}\", Favorita: ${recipe.isFavorite}", 
      name: "RecipeModel"
    );
    
    return recipe;
  }

  // Convert to a map (JSON)
  Map<String, dynamic> toMap() {
    // Log para depuración
    developer.log("Convirtiendo receta a mapa con ID: \"$id\"", name: "RecipeModel");
    
    String difficultyToString() {
      switch (difficulty) {
        case DifficultyLevel.easy:
          return 'easy';
        case DifficultyLevel.medium:
          return 'medium';
        case DifficultyLevel.hard:
          return 'hard';
        default:
          return 'medium';
      }
    }

    final Map<String, dynamic> result = {
      // IMPORTANTE: Siempre incluir el ID exactamente como es
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'preparationTime': preparationTime,
      'cookingTime': cookingTime,
      'servings': servings,
      'difficulty': difficultyToString(),
      'categories': categories,
      'ingredients': ingredients.map((x) => x.toMap()).toList(),
      'steps': steps,
      'calories': calories,
      'nutrition': nutrition,
      'isFavorite': isFavorite, // Incluir el estado de favorito
    };
    
    // Solo incluir userId si está definido
    if (userId != null) {
      result['userId'] = userId;
    }
    
    // Solo incluir nutritionalInfo si está definido
    if (nutritionalInfo != null) {
      result['nutritionalInfo'] = nutritionalInfo!.toMap();
    }
    
    // Solo incluir timestamps si están definidos
    if (createdAt != null) {
      result['createdAt'] = createdAt!.toIso8601String();
    }
    
    if (updatedAt != null) {
      result['updatedAt'] = updatedAt!.toIso8601String();
    }
    
    // Log para confirmar el resultado
    developer.log(
      "Mapa creado con ${result.length} campos. ID=\"${result['id']}\", Favorita: ${result['isFavorite']}", 
      name: "RecipeModel"
    );
    
    return result;
  }
  
  // Crear una copia con cambios
  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    int? preparationTime,
    int? cookingTime,
    int? servings,
    DifficultyLevel? difficulty,
    List<String>? categories,
    List<RecipeIngredient>? ingredients,
    List<String>? steps,
    int? calories,
    Map<String, dynamic>? nutrition,
    NutritionalInfo? nutritionalInfo,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite, // Añadir isFavorite al copyWith
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      preparationTime: preparationTime ?? this.preparationTime,
      cookingTime: cookingTime ?? this.cookingTime,
      servings: servings ?? this.servings,
      difficulty: difficulty ?? this.difficulty,
      categories: categories ?? this.categories,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      calories: calories ?? this.calories,
      nutrition: nutrition ?? this.nutrition,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // Método de conveniencia para alternar el estado de favorito
  Recipe toggleFavorite() {
    return copyWith(
      isFavorite: !isFavorite,
      updatedAt: DateTime.now(),
    );
  }
  
  @override
  String toString() {
    return 'Recipe(id: "$id", name: "$name", categories: $categories, ingredients: ${ingredients.length}, isFavorite: $isFavorite)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Recipe && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// RecipeIngredient class - extended from Ingredient with additional fields needed
class RecipeIngredient {
  final String id; // Added for compatibility with previous code
  final String name;
  final dynamic quantity; // Can be int or double
  final String unit;
  final bool isAvailable;
  final bool isOptional; // Added for compatibility with previous code

  const RecipeIngredient({
    this.id = '', // Default value
    required this.name,
    required this.quantity,
    required this.unit,
    this.isAvailable = false,
    this.isOptional = false,
  });

  // Get formatted quantity string
  String get formattedQuantity {
    if (quantity is double) {
      final doubleQuantity = quantity as double;
      if (doubleQuantity == doubleQuantity.roundToDouble()) {
        return '${doubleQuantity.round()}';
      } else {
        return doubleQuantity.toString();
      }
    }
    return quantity.toString();
  }

  // Get full description (quantity + unit + name)
  String get fullDescription {
    final quantityStr = formattedQuantity;
    if (unit.isEmpty) {
      return '$quantityStr $name';
    } else {
      return '$quantityStr $unit de $name';
    }
  }

  // Factory constructor to create an Ingredient from a map (JSON)
  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    // Asegurarse que el id sea siempre un string
    String extractId(dynamic id) {
      if (id == null) return '';
      return id.toString();
    }
    
    return RecipeIngredient(
      id: extractId(map['id']),
      name: map['name'] ?? 'Ingrediente sin nombre',
      quantity: map['quantity'] ?? 0,
      unit: map['unit'] ?? '',
      isAvailable: map['isAvailable'] ?? false,
      isOptional: map['isOptional'] ?? false,
    );
  }

  // Convert to a map (JSON)
  Map<String, dynamic> toMap() {
    return {
      // Solo incluir ID si no está vacío
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isAvailable': isAvailable,
      'isOptional': isOptional,
    };
  }
  
  // Crear una copia con cambios
  RecipeIngredient copyWith({
    String? id,
    String? name,
    dynamic quantity,
    String? unit,
    bool? isAvailable,
    bool? isOptional,
  }) {
    return RecipeIngredient(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isAvailable: isAvailable ?? this.isAvailable,
      isOptional: isOptional ?? this.isOptional,
    );
  }
  
  @override
  String toString() {
    return 'RecipeIngredient(id: "$id", name: "$name", quantity: $quantity $unit, available: $isAvailable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipeIngredient && other.id == id && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

// For backwards compatibility with older code
class Ingredient extends RecipeIngredient {
  const Ingredient({
    required super.name,
    required super.quantity,
    required super.unit,
    super.isAvailable,
  });

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      name: map['name'] ?? 'Ingrediente sin nombre',
      quantity: map['quantity'] ?? 0,
      unit: map['unit'] ?? '',
      isAvailable: map['isAvailable'] ?? false,
    );
  }
}

// NutritionalInfo class for storing detailed nutritional information
class NutritionalInfo {
  final double calories;
  final double proteins;
  final double carbs;
  final double fats;
  final double fiber;

  const NutritionalInfo({
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    required this.fiber,
  });

  // Get total macronutrients (excluding fiber)
  double get totalMacros => proteins + carbs + fats;

  // Get percentage of calories from each macronutrient
  Map<String, double> get macroPercentages {
    if (totalMacros == 0) {
      return {'proteins': 0, 'carbs': 0, 'fats': 0};
    }
    
    return {
      'proteins': (proteins / totalMacros) * 100,
      'carbs': (carbs / totalMacros) * 100,
      'fats': (fats / totalMacros) * 100,
    };
  }

  // Factory to create from a map
  factory NutritionalInfo.fromMap(Map<String, dynamic> map) {
    return NutritionalInfo(
      calories: (map['calories'] ?? 0).toDouble(),
      proteins: (map['proteins'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fats: (map['fats'] ?? 0).toDouble(),
      fiber: (map['fiber'] ?? 0).toDouble(),
    );
  }

  // Convert to map
  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'proteins': proteins,
      'carbs': carbs,
      'fats': fats,
      'fiber': fiber,
    };
  }
  
  // Crear una copia con cambios
  NutritionalInfo copyWith({
    double? calories,
    double? proteins,
    double? carbs,
    double? fats,
    double? fiber,
  }) {
    return NutritionalInfo(
      calories: calories ?? this.calories,
      proteins: proteins ?? this.proteins,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      fiber: fiber ?? this.fiber,
    );
  }
  
  @override
  String toString() {
    return 'NutritionalInfo(calories: $calories, proteins: ${proteins}g, carbs: ${carbs}g, fats: ${fats}g, fiber: ${fiber}g)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NutritionalInfo &&
        other.calories == calories &&
        other.proteins == proteins &&
        other.carbs == carbs &&
        other.fats == fats &&
        other.fiber == fiber;
  }

  @override
  int get hashCode {
    return calories.hashCode ^
        proteins.hashCode ^
        carbs.hashCode ^
        fats.hashCode ^
        fiber.hashCode;
  }
}