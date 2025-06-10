// lib/services/recipe_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe_model.dart';
import 'firestore_service.dart';
import 'inventory_service.dart';

class RecipeService {
  // Singleton para acceso fácil al servicio
  static final RecipeService _instance = RecipeService._internal();
  factory RecipeService() => _instance;
  RecipeService._internal();

  // Instancias de servicios
  final FirestoreService _firestoreService = FirestoreService();
  final InventoryService _inventoryService = InventoryService();
  
  // Referencia al usuario actual
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  
  // Referencias a colecciones
  CollectionReference get _globalRecipes => _firestoreService.recipes; // Para backward compatibility
  
  // Colección principal de recetas del usuario
  CollectionReference? get _userRecipes => _firestoreService.getUserRecipes();
  
  // Para recetas favoritas del usuario
  CollectionReference? get _userFavoriteRecipes => _firestoreService.getUserFavoriteRecipes();
  
  // Para recetas personalizadas antiguas (para migración)
  CollectionReference? get _userCustomRecipes => _firestoreService.getUserCustomRecipes();

  Future<List<Recipe>> getAllRecipes() async {
  try {
    if (_userId == null) {
      throw Exception('Usuario no autenticado');
    }

    print('Obteniendo recetas desde Firestore');
    final userRecipesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('recipes');
    
    final userRecipesSnapshot = await userRecipesRef.get();
    
    print('Se encontraron ${userRecipesSnapshot.docs.length} recetas');
    
    final recipes = userRecipesSnapshot.docs.map((doc) {
      final data = doc.data();
      final docId = doc.id;
      
      print('Procesando receta - ID: "$docId", Nombre: "${data['name']}"');
      
      // CRUCIAL: Ignorar cualquier ID que pueda estar dentro de los datos
      // y usar exclusivamente el ID del documento de Firestore
      final Map<String, dynamic> recipeData = {
        ...data,
        'id': docId, // Sobrescribir cualquier 'id' que exista en los datos
      };
      
      if (data.containsKey('id') && data['id'] != docId) {
        print('ADVERTENCIA: ID en datos (${data['id']}) difiere del ID del documento ($docId)');
      }
      
      return Recipe.fromMap(recipeData);
    }).toList();
    
    for (var i = 0; i < recipes.length; i++) {
      print('Receta creada #$i - ID: "${recipes[i].id}", Nombre: "${recipes[i].name}"');
    }
    
    return recipes;
  } catch (e) {
    print('Error al obtener recetas: $e');
    return [];
  }
}

  // Método para obtener recetas en el formato antiguo (para migración)
  Future<List<Recipe>> _getRecipesLegacy() async {
    // Obtener recetas globales
    final globalRecipesSnapshot = await _globalRecipes.get();
    final globalRecipes = globalRecipesSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Recipe.fromMap({
        'id': doc.id,
        ...data,
      });
    }).toList();
    
    // Obtener recetas personalizadas del usuario (si está autenticado)
    if (_userCustomRecipes != null) {
      final userRecipesSnapshot = await _userCustomRecipes!.get();
      final userRecipes = userRecipesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Recipe.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
      
      // Combinar ambas listas
      globalRecipes.addAll(userRecipes);
    }
    
    return globalRecipes;
  }

  // Método para obtener una receta específica por ID
  Future<Recipe?> getRecipeById(String recipeId) async {
    try {
      if (_userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar si existe la nueva colección de recetas
      final hasNewRecipes = await _firestoreService.collectionExists('recipes');
      
      if (hasNewRecipes && _userRecipes != null) {
        // Buscar en la nueva estructura
        final docSnapshot = await _userRecipes!.doc(recipeId).get();
        
        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, dynamic>;
          return Recipe.fromMap({
            'id': docSnapshot.id,
            ...data,
          });
        }
      }
      
      // Si no se encuentra en la nueva estructura o ésta no existe, buscar en el formato antiguo
      // Primero en recetas personalizadas
      if (_userCustomRecipes != null) {
        final customSnapshot = await _userCustomRecipes!.doc(recipeId).get();
        if (customSnapshot.exists) {
          final data = customSnapshot.data() as Map<String, dynamic>;
          return Recipe.fromMap({
            'id': customSnapshot.id,
            ...data,
          });
        }
      }
      
      // Luego en recetas globales
      final globalSnapshot = await _globalRecipes.doc(recipeId).get();
      if (globalSnapshot.exists) {
        final data = globalSnapshot.data() as Map<String, dynamic>;
        return Recipe.fromMap({
          'id': globalSnapshot.id,
          ...data,
        });
      }
      
      return null; // Si no se encuentra en ninguna colección
    } catch (e) {
      print('Error al obtener receta por ID: $e');
      return null;
    }
  }

  // Método para agregar una receta
  Future<String?> addRecipe(Recipe recipe) async {
    try {
      if (_userId == null || _userRecipes == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Asegurar que exista la colección de recetas
      await _firestoreService.ensureUserCollectionsExist();
      
      // Prepare el mapa de datos
      final recipeMap = recipe.toMap();
      
      // Asegurar que la receta tenga el ID del usuario actual
      if (!recipeMap.containsKey('userId')) {
        recipeMap['userId'] = _userId;
      }
      
      // Eliminar ID si está vacío para que Firestore genere uno
      if (recipe.id.isEmpty) {
        recipeMap.remove('id');
      }
      
      // Añadir metadatos de creación
      recipeMap['createdAt'] = FieldValue.serverTimestamp();
      recipeMap['updatedAt'] = FieldValue.serverTimestamp();
      
      // Agregar receta a la colección de recetas del usuario
      final docRef = await _userRecipes!.add(recipeMap);
      return docRef.id;
    } catch (e) {
      print('Error al agregar receta: $e');
      return null;
    }
  }

  // Método para actualizar una receta
  Future<bool> updateRecipe(Recipe recipe) async {
    try {
      if (_userId == null || _userRecipes == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Verificar que la receta existe
      final docSnapshot = await _userRecipes!.doc(recipe.id).get();
      if (!docSnapshot.exists) {
        throw Exception('La receta no existe');
      }
      
      // Preparar el mapa de datos
      final recipeMap = recipe.toMap();
      
      // Eliminar ID del mapa ya que es la referencia del documento
      recipeMap.remove('id');
      
      // Añadir metadatos de actualización
      recipeMap['updatedAt'] = FieldValue.serverTimestamp();
      
      // Actualizar la receta
      await _userRecipes!.doc(recipe.id).update(recipeMap);
      return true;
    } catch (e) {
      print('Error al actualizar receta: $e');
      return false;
    }
  }

  // Método para migrar recetas de ejemplo a Firestore
  Future<void> migrateExampleRecipesToFirestore() async {
    try {
      if (_userId == null || _userRecipes == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Asegurar que exista la colección de recetas
      await _firestoreService.ensureUserCollectionsExist();
      
      // Cargar recetas por defecto
      final defaultRecipes = _loadDefaultRecipes();
      
      // Contador para recetas migradas
      int migratedCount = 0;
      
      // Añadir cada receta por defecto a la colección del usuario
      for (final recipe in defaultRecipes) {
        try {
          // Añadir la receta
          final recipeMap = recipe.copyWith(userId: _userId).toMap();
          
          // Eliminar ID para que Firestore genere uno nuevo
          recipeMap.remove('id');
          
          // Añadir metadatos
          recipeMap['createdAt'] = FieldValue.serverTimestamp();
          recipeMap['updatedAt'] = FieldValue.serverTimestamp();
          recipeMap['isDefault'] = true;
          
          // Guardar en Firestore
          await _userRecipes!.add(recipeMap);
          migratedCount++;
        } catch (e) {
          print('Error al migrar receta de ejemplo: $e');
        }
      }
      
      print('Migradas $migratedCount recetas de ejemplo');
    } catch (e) {
      print('Error al migrar recetas de ejemplo a Firestore: $e');
      rethrow;
    }
  }

Future<bool> deleteRecipe(String recipeId) async {
  if (recipeId.isEmpty) {
    print('Error al eliminar receta: recipeId está vacío');
    return false;
  }
  
  print('====== INICIO ELIMINACIÓN DE RECETA ======');
  print('Intentando eliminar receta con ID: $recipeId');
  
  try {
    // Verificar autenticación
    if (_userId == null) {
      print('Error al eliminar receta: usuario no autenticado');
      return false;
    }
    
    print('Usuario autenticado: $_userId');
    
    // Obtener referencia directa a la receta
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userRecipesRef = firestore.collection('users').doc(_userId).collection('recipes').doc(recipeId);
    
    // Verificar si la receta existe
    final docSnapshot = await userRecipesRef.get();
    if (!docSnapshot.exists) {
      print('La receta no existe en la colección principal: $recipeId');
      
      // Buscar en la colección de documentos de recetas para ver si hay alguna coincidencia
      print('Buscando todas las recetas para verificar inconsistencias...');
      final allRecipesSnapshot = await firestore.collection('users').doc(_userId).collection('recipes').get();
      
      print('Encontradas ${allRecipesSnapshot.docs.length} recetas en Firestore:');
      for (var doc in allRecipesSnapshot.docs) {
        print('ID en Firestore: "${doc.id}" - Nombre: "${doc.data()['name']}"');
      }
      
      return false;
    }
    
    // La receta existe, proceder con la eliminación
    await userRecipesRef.delete();
    print('✓ Receta eliminada correctamente: $recipeId');
    
    // También eliminar de favoritos y planes de comida si es necesario
    // ...
    
    return true;
  } catch (e) {
    print('ERROR al eliminar receta: $e');
    return false;
  }
}

  // Método para marcar/desmarcar una receta como favorita
  Future<bool> toggleFavoriteRecipe(String recipeId) async {
    try {
      if (_userId == null || _userFavoriteRecipes == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Verificar si ya está en favoritos
      final docSnapshot = await _userFavoriteRecipes!.doc(recipeId).get();
      
      if (docSnapshot.exists) {
        // Si existe, eliminarla de favoritos
        await _userFavoriteRecipes!.doc(recipeId).delete();
        return false; // Ya no es favorita
      } else {
        // Si no existe, agregarla a favoritos
        await _userFavoriteRecipes!.doc(recipeId).set({
          'addedAt': FieldValue.serverTimestamp(),
        });
        return true; // Ahora es favorita
      }
    } catch (e) {
      print('Error al marcar/desmarcar receta como favorita: $e');
      rethrow;
    }
  }
  
  // Método para obtener las recetas favoritas del usuario
  Future<List<Recipe>> getFavoriteRecipes() async {
    try {
      if (_userId == null || _userFavoriteRecipes == null) {
        return [];
      }
      
      // Obtener IDs de recetas favoritas
      final favoriteIds = (await _userFavoriteRecipes!.get()).docs.map((doc) => doc.id).toList();
      
      if (favoriteIds.isEmpty) {
        return [];
      }
      
      // Obtener detalles de las recetas favoritas
      final List<Recipe> favoriteRecipes = [];
      
      for (final recipeId in favoriteIds) {
        final recipe = await getRecipeById(recipeId);
        if (recipe != null) {
          favoriteRecipes.add(recipe);
        }
      }
      
      return favoriteRecipes;
    } catch (e) {
      print('Error al obtener recetas favoritas: $e');
      return [];
    }
  }
  
  // Método para verificar si una receta es favorita
  Future<bool> isRecipeFavorite(String recipeId) async {
    try {
      if (_userId == null || _userFavoriteRecipes == null) {
        return false;
      }
      
      final doc = await _userFavoriteRecipes!.doc(recipeId).get();
      return doc.exists;
    } catch (e) {
      print('Error al verificar si la receta es favorita: $e');
      return false;
    }
  }

  // Método para obtener recetas sugeridas basadas en inventario
  Future<List<Recipe>> getSuggestedRecipes() async {
    try {
      // Obtenemos los productos del inventario
      final products = await _inventoryService.getAllProducts();
      final inventoryIngredients = products.map((product) => product.name.toLowerCase()).toSet();
      
      // Obtenemos todas las recetas
      final allRecipes = await getAllRecipes();
      
      // Filtramos recetas que usan ingredientes disponibles
      final recipesWithAvailability = allRecipes.map((recipe) {
        // Crear una copia con ingredientes marcados según disponibilidad
        final ingredientsWithAvailability = recipe.ingredients.map((ingredient) {
          // Verificar disponibilidad
          final isAvailable = inventoryIngredients.contains(ingredient.name.toLowerCase());
          
          // Crear nuevo ingrediente con disponibilidad actualizada
          return RecipeIngredient(
            id: ingredient.id,
            name: ingredient.name,
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            isAvailable: isAvailable,
            isOptional: ingredient.isOptional,
          );
        }).toList();
        
        // Crear nueva receta con los ingredientes actualizados
        return recipe.copyWith(
          ingredients: ingredientsWithAvailability,
        );
      }).toList();
      
      // Filtrar recetas con alto porcentaje de ingredientes disponibles
      return recipesWithAvailability
        .where((recipe) => recipe.availableIngredientsPercentage >= 0.7)
        .toList();
    } catch (e) {
      print('Error al obtener recetas sugeridas: $e');
      return [];
    }
  }
  
  // Método para obtener recetas para ingredientes por caducar (modo S.O.S.)
  Future<List<Recipe>> getRecipesForExpiringProducts() async {
    try {
      // Obtenemos productos cercanos a caducar (menos de 3 días)
      final expiringProducts = await _inventoryService.getExpiringProducts(3);
      final expiringIngredients = expiringProducts.map((p) => p.name.toLowerCase()).toSet();
      
      if (expiringIngredients.isEmpty) {
        return [];
      }
      
      // Obtenemos todas las recetas
      final allRecipes = await getAllRecipes();
      
      // Filtramos recetas que usan al menos un ingrediente por caducar
      return allRecipes.where((recipe) {
        return recipe.ingredients.any((ingredient) => 
          expiringIngredients.contains(ingredient.name.toLowerCase()));
      }).toList();
    } catch (e) {
      print('Error al obtener recetas para productos por caducar: $e');
      return [];
    }
  }

  // Método para buscar recetas por nombre o descripción
  Future<List<Recipe>> searchRecipes(String query) async {
    try {
      final allRecipes = await getAllRecipes();
      final normalizedQuery = query.toLowerCase();
      
      return allRecipes.where((recipe) {
        return recipe.name.toLowerCase().contains(normalizedQuery) ||
               recipe.description.toLowerCase().contains(normalizedQuery) ||
               recipe.ingredients.any((ingredient) => 
                 ingredient.name.toLowerCase().contains(normalizedQuery)) ||
               recipe.categories.any((category) =>
                 category.toLowerCase().contains(normalizedQuery));
      }).toList();
    } catch (e) {
      print('Error al buscar recetas: $e');
      return [];
    }
  }

  // Método para filtrar recetas por categoría
  Future<List<Recipe>> filterRecipesByCategory(String category) async {
    try {
      final allRecipes = await getAllRecipes();
      return allRecipes.where((recipe) => recipe.hasCategory(category)).toList();
    } catch (e) {
      print('Error al filtrar recetas por categoría: $e');
      return [];
    }
  }
  
  // Método para migrar recetas existentes a la nueva estructura
  Future<MigrationResult> migrateExistingRecipes() async {
    try {
      if (_userId == null || _userRecipes == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Asegurar que exista la colección de recetas
      await _firestoreService.ensureUserCollectionsExist();
      
      // Resultados de la migración
      int globalRecipesCount = 0;
      int customRecipesCount = 0;
      int favoriteRecipesCount = 0;
      int failedMigrations = 0;
      
      // Obtener recetas globales
      final globalRecipesSnapshot = await _globalRecipes.get();
      final globalRecipes = globalRecipesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      // Obtener recetas personalizadas existentes
      List<Map<String, dynamic>> customRecipes = [];
      if (_userCustomRecipes != null) {
        final customRecipesSnapshot = await _userCustomRecipes!.get();
        customRecipes = customRecipesSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
      }
      
      // Obtener IDs de recetas favoritas
      Set<String> favoriteIds = {};
      if (_userFavoriteRecipes != null) {
        final favoritesSnapshot = await _userFavoriteRecipes!.get();
        favoriteIds = favoritesSnapshot.docs.map((doc) => doc.id).toSet();
      }
      
      // Migrar recetas personalizadas
      for (final recipeMap in customRecipes) {
        try {
          // Convertir a objeto Recipe
          final recipe = Recipe.fromMap(recipeMap);
          
          // Añadir a la nueva colección
          final newRecipeMap = recipe.copyWith(userId: _userId).toMap();
          newRecipeMap.remove('id'); // Usar el ID del documento
          
          await _userRecipes!.doc(recipe.id).set({
            ...newRecipeMap,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'migratedFrom': 'custom_recipes',
          });
          
          customRecipesCount++;
        } catch (e) {
          print('Error al migrar receta personalizada: $e');
          failedMigrations++;
        }
      }
      
      // Migrar recetas globales favoritas
      for (final recipeId in favoriteIds) {
        try {
          // Buscar la receta en la lista de recetas globales
          final globalRecipeMap = globalRecipes.firstWhere(
            (r) => r['id'] == recipeId,
            orElse: () => <String, dynamic>{},
          );
          
          if (globalRecipeMap.isNotEmpty) {
            // Convertir a objeto Recipe
            final recipe = Recipe.fromMap(globalRecipeMap);
            
            // Añadir a la nueva colección
            final newRecipeMap = recipe.copyWith(userId: _userId).toMap();
            newRecipeMap.remove('id'); // Usar el ID del documento
            
            await _userRecipes!.doc(recipe.id).set({
              ...newRecipeMap,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'migratedFrom': 'global_recipes',
              'isFavorite': true,
            });
            
            favoriteRecipesCount++;
          }
        } catch (e) {
          print('Error al migrar receta favorita: $e');
          failedMigrations++;
        }
      }
      
      // Opcionalmente, migrar algunas recetas globales populares
      final popularGlobalRecipes = globalRecipes.take(10).toList();
      
      for (final recipeMap in popularGlobalRecipes) {
        try {
          // Verificar si ya se migró esta receta (si era favorita)
          if (favoriteIds.contains(recipeMap['id'])) {
            continue; // Saltar si ya fue migrada como favorita
          }
          
          // Convertir a objeto Recipe
          final recipe = Recipe.fromMap(recipeMap);
          
          // Añadir a la nueva colección
          final newRecipeMap = recipe.copyWith(userId: _userId).toMap();
          newRecipeMap.remove('id'); // Usar el ID del documento
          
          await _userRecipes!.doc(recipe.id).set({
            ...newRecipeMap,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'migratedFrom': 'global_recipes',
          });
          
          globalRecipesCount++;
        } catch (e) {
          print('Error al migrar receta global: $e');
          failedMigrations++;
        }
      }
      
      return MigrationResult(
        totalRecipes: globalRecipesCount + customRecipesCount + favoriteRecipesCount,
        globalRecipesMigrated: globalRecipesCount,
        customRecipesMigrated: customRecipesCount,
        favoriteRecipesMigrated: favoriteRecipesCount,
        failedMigrations: failedMigrations,
      );
    } catch (e) {
      print('Error al migrar recetas existentes: $e');
      return MigrationResult(
        totalRecipes: 0,
        globalRecipesMigrated: 0,
        customRecipesMigrated: 0,
        favoriteRecipesMigrated: 0,
        failedMigrations: 1,
        error: e.toString(),
      );
    }
  }
  
  // Método privado para cargar recetas por defecto en caso de error
  List<Recipe> _loadDefaultRecipes() {
    return [
      Recipe(
        id: '1',
        name: 'Ensalada Mediterránea',
        description: 'Una fresca ensalada con ingredientes mediterráneos, ideal para días calurosos.',
        ingredients: [
          RecipeIngredient(id: '101', name: 'Lechuga', quantity: 200, unit: 'g'),
          RecipeIngredient(id: '102', name: 'Tomate', quantity: 2, unit: 'unidades'),
          RecipeIngredient(id: '103', name: 'Pepino', quantity: 1, unit: 'unidad'),
          RecipeIngredient(id: '104', name: 'Aceitunas', quantity: 50, unit: 'g'),
          RecipeIngredient(id: '105', name: 'Queso feta', quantity: 100, unit: 'g'),
          RecipeIngredient(id: '106', name: 'Aceite de oliva', quantity: 2, unit: 'cucharadas'),
        ],
        steps: [
          'Lavar y cortar todos los vegetales.',
          'Mezclar en un bowl grande.',
          'Añadir el queso feta desmenuzado.',
          'Aliñar con aceite de oliva, sal y pimienta al gusto.',
        ],
        imageUrl: 'https://example.com/ensalada.jpg',
        preparationTime: 15,
        cookingTime: 0,
        difficulty: DifficultyLevel.easy,
        categories: ['vegetariana', 'saludable', 'sin cocción'],
        servings: 2,
        calories: 320,
        nutrition: {
          'proteins': 12,
          'carbs': 15,
          'fats': 24,
          'fiber': 6,
        },
      ),
      Recipe(
        id: '2',
        name: 'Pasta con Verduras',
        description: 'Pasta integral con vegetales salteados, una opción rápida y nutritiva.',
        ingredients: [
          RecipeIngredient(id: '201', name: 'Pasta integral', quantity: 200, unit: 'g'),
          RecipeIngredient(id: '202', name: 'Calabacín', quantity: 1, unit: 'unidad'),
          RecipeIngredient(id: '203', name: 'Pimiento', quantity: 1, unit: 'unidad'),
          RecipeIngredient(id: '204', name: 'Cebolla', quantity: 1, unit: 'unidad'),
          RecipeIngredient(id: '205', name: 'Aceite de oliva', quantity: 2, unit: 'cucharadas'),
          RecipeIngredient(id: '206', name: 'Queso parmesano', quantity: 30, unit: 'g', isOptional: true),
        ],
        steps: [
          'Hervir la pasta según las instrucciones del paquete.',
          'Mientras tanto, cortar las verduras en trozos pequeños.',
          'Saltear las verduras en una sartén con aceite.',
          'Escurrir la pasta y mezclar con las verduras.',
          'Servir con queso parmesano rallado por encima.',
        ],
        imageUrl: 'https://example.com/pasta.jpg',
        preparationTime: 10,
        cookingTime: 20,
        difficulty: DifficultyLevel.easy,
        categories: ['vegetariana', 'pasta'],
        servings: 2,
        calories: 450,
        nutrition: {
          'proteins': 15,
          'carbs': 65,
          'fats': 12,
          'fiber': 8,
        },
      ),
      Recipe(
        id: '3',
        name: 'Tortilla Española',
        description: 'Clásica tortilla española de patatas, un plato versátil para cualquier momento.',
        ingredients: [
          RecipeIngredient(id: '301', name: 'Patatas', quantity: 500, unit: 'g'),
          RecipeIngredient(id: '302', name: 'Huevos', quantity: 4, unit: 'unidades'),
          RecipeIngredient(id: '303', name: 'Cebolla', quantity: 1, unit: 'unidad'),
          RecipeIngredient(id: '304', name: 'Aceite de oliva', quantity: 100, unit: 'ml'),
          RecipeIngredient(id: '305', name: 'Sal', quantity: 1, unit: 'cucharadita'),
        ],
        steps: [
          'Pelar y cortar las patatas en rodajas finas.',
          'Picar la cebolla finamente.',
          'Freír las patatas y la cebolla a fuego lento hasta que estén tiernas.',
          'Batir los huevos y mezclar con las patatas.',
          'Cuajar la tortilla en una sartén, dándole la vuelta a mitad de cocción.',
        ],
        imageUrl: 'https://example.com/tortilla.jpg',
        preparationTime: 15,
        cookingTime: 30,
        difficulty: DifficultyLevel.medium,
        categories: ['vegetariana', 'española', 'sin gluten'],
        servings: 4,
        calories: 380,
        nutrition: {
          'proteins': 14,
          'carbs': 30,
          'fats': 22,
          'fiber': 3,
        },
      ),
    ];
  }
}

// Clase para resultados de migración
class MigrationResult {
  final int totalRecipes;
  final int globalRecipesMigrated;
  final int customRecipesMigrated;
  final int favoriteRecipesMigrated;
  final int failedMigrations;
  final String? error;

  MigrationResult({
    required this.totalRecipes,
    required this.globalRecipesMigrated,
    required this.customRecipesMigrated,
    required this.favoriteRecipesMigrated,
    required this.failedMigrations,
    this.error,
  });

  bool get isSuccess => error == null;
  
  @override
  String toString() {
    return 'Migración ${isSuccess ? 'exitosa' : 'fallida'}: Total: $totalRecipes, Globales: $globalRecipesMigrated, Personalizadas: $customRecipesMigrated, Favoritas: $favoriteRecipesMigrated, Fallidas: $failedMigrations${error != null ? ', Error: $error' : ''}';
  }
}