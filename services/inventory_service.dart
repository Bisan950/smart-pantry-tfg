// lib/services/inventory_service.dart - CORREGIDO

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../models/product_location_model.dart';
import 'firestore_service.dart';
import 'expiry_settings_service.dart';
import '../models/recipe_model.dart';

class InventoryService {
  // Singleton para acceso global al servicio
  static final InventoryService _instance = InventoryService._internal();
  factory InventoryService() => _instance;
  InventoryService._internal();

  // Instancia de FirestoreService
  final FirestoreService _firestoreService = FirestoreService();
  
  // ✅ CORREGIDO: Referencia a FirebaseAuth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Referencia al usuario actual
  String? get _userId => _auth.currentUser?.uid;
  
  // Obtener referencia a la colección de productos del usuario
  CollectionReference? get _userProducts {
    final userId = _userId;
    if (userId == null) return null;
    return _firestoreService.getUserProducts(userId);
  }

  // Inicializar el servicio
  Future<void> initialize() async {
    // Esta función se mantiene para compatibilidad con código existente
    // pero no necesita hacer nada especial en la implementación de Firestore
  }

  // ✅ MÉTODO ÚNICO getCurrentUserId (combinado y corregido)
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Método para obtener todos los productos
  Future<List<Product>> getAllProducts() async {
    try {
      final userId = _userId;
      if (userId == null) return [];
      
      final products = await _userProducts?.get();
      
      if (products == null) return [];
      
      return products.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromMap({
          'id': doc.id,
          'userId': userId, // Asegurar que se incluya el ID del usuario
          ...data,
        });
      }).toList();
    } catch (e) {
      print('Error al obtener productos: $e');
      return [];
    }
  }

  // Método para obtener los productos más recientes
  Future<List<Product>> getRecentProducts(int limit) async {
    try {
      final userId = _userId;
      if (userId == null) return [];
      
      // Si no hay colección de productos, retornar lista vacía
      if (_userProducts == null) return [];
      
      // Consultar los productos ordenados por fecha de actualización
      final query = await _userProducts!
          .orderBy('lastUpdated', descending: true)
          .limit(limit)
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromMap({
          'id': doc.id,
          'userId': userId,
          ...data,
        });
      }).toList();
    } catch (e) {
      print('Error al obtener productos recientes: $e');
      return [];
    }
  }

  // Método para obtener productos por ubicación
  Future<List<Product>> getProductsByLocation(String location) async {
    try {
      final userId = _userId;
      if (userId == null) return [];
      
      final query = await _userProducts?.where('location', isEqualTo: location).get();
      
      if (query == null) return [];
      
      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromMap({
          'id': doc.id,
          'userId': userId, // Asegurar que se incluya el ID del usuario
          ...data,
        });
      }).toList();
    } catch (e) {
      print('Error al obtener productos por ubicación: $e');
      return [];
    }
  }

  /// Método para unir productos duplicados por nombre
  Future<List<Product>> mergeDuplicateProducts() async {
    try {
      final userId = _userId;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      // Obtener todos los productos del inventario
      final allProducts = await getAllProducts();
      final inventoryProducts = allProducts.where((p) => 
        p.productLocation == ProductLocation.inventory || 
        p.productLocation == ProductLocation.both
      ).toList();
      
      // Agrupar productos por nombre (case insensitive)
      final Map<String, List<Product>> productGroups = {};
      
      for (final product in inventoryProducts) {
        final normalizedName = product.name.toLowerCase().trim();
        if (!productGroups.containsKey(normalizedName)) {
          productGroups[normalizedName] = [];
        }
        productGroups[normalizedName]!.add(product);
      }
      
      // Lista de productos procesados
      final List<Product> mergedProducts = [];
      
      // Procesar cada grupo
      for (final entry in productGroups.entries) {
        final products = entry.value;
        
        if (products.length == 1) {
          // No hay duplicados, mantener el producto original
          mergedProducts.add(products.first);
          continue;
        }
        
        // Hay duplicados, unir productos
        final mergedProduct = _mergeProductGroup(products);
        mergedProducts.add(mergedProduct);
        
        // Eliminar productos duplicados (excepto el que mantenemos)
        for (int i = 1; i < products.length; i++) {
          await deleteProduct(products[i].id);
        }
        
        // CAMBIO CRÍTICO: Usar updateProductQuantity en lugar de updateProduct
        // para asegurar que tanto quantity como maxQuantity se actualicen
        await updateProductQuantity(
          mergedProduct.id, 
          mergedProduct.quantity,
          maxQuantity: mergedProduct.maxQuantity
        );
        
        print('✅ Producto ${mergedProduct.name} actualizado: cantidad=${mergedProduct.quantity}, máximo=${mergedProduct.maxQuantity}');
      }
      
      print('Productos unidos correctamente. Total: ${mergedProducts.length}');
      return mergedProducts;
      
    } catch (e) {
      print('Error al unir productos duplicados: $e');
      rethrow;
    }
  }

  /// Método auxiliar para unir un grupo de productos duplicados
  Product _mergeProductGroup(List<Product> products) {
    if (products.isEmpty) {
      throw Exception('No se pueden unir productos vacíos');
    }
    
    if (products.length == 1) {
      return products.first;
    }
    
    // Usar el primer producto como base
    final baseProduct = products.first;
    
    // Sumar cantidades
    int totalQuantity = 0;
    int maxQuantitySum = 0;
    String unit = baseProduct.unit;
    
    // Debug: Mostrar productos antes de unir
    print('🔄 Uniendo ${products.length} productos:');
    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      print('  Producto $i: ${product.name} - Cantidad: ${product.quantity}, Máximo: ${product.maxQuantity}, Unidad: ${product.unit}');
    }
    
    // Recopilar información adicional
    final Set<String> allNotes = {};
    bool isFavorite = false;
    DateTime? earliestExpiry;
    
    for (final product in products) {
      // Sumar cantidades solo si tienen la misma unidad
      if (product.unit.toLowerCase() == unit.toLowerCase()) {
        totalQuantity += product.quantity;
        maxQuantitySum += product.maxQuantity;
        print('  ✅ Sumando: cantidad ${product.quantity} (total: $totalQuantity), máximo ${product.maxQuantity} (total: $maxQuantitySum)');
      } else {
        print('  ⚠️ Unidad diferente: ${product.unit} vs $unit - No se suma');
      }
      
      // Recopilar notas
      if (product.notes.isNotEmpty) {
        allNotes.add(product.notes);
      }
      
      // Si alguno es favorito, el resultado será favorito
      if (product.isFavorite) {
        isFavorite = true;
      }
      
      // Mantener la fecha de caducidad más próxima
      if (product.expiryDate != null) {
        if (earliestExpiry == null || product.expiryDate!.isBefore(earliestExpiry)) {
          earliestExpiry = product.expiryDate;
        }
      }
    }
    
    // Crear producto unificado
    final mergedProduct = baseProduct.copyWith(
      quantity: totalQuantity,
      maxQuantity: maxQuantitySum > 0 ? maxQuantitySum : totalQuantity,
      notes: allNotes.join(' | '),
      isFavorite: isFavorite,
      expiryDate: earliestExpiry,
    );
    
    print('✅ Producto unificado: ${mergedProduct.name} - Cantidad: ${mergedProduct.quantity}, Máximo: ${mergedProduct.maxQuantity}');
    
    return mergedProduct;
  }

  /// Obtener vista previa de productos que se pueden unir
  Future<Map<String, List<Product>>> getProductsThatCanBeMerged() async {
    try {
      final allProducts = await getAllProducts();
      final inventoryProducts = allProducts.where((p) => 
        p.productLocation == ProductLocation.inventory || 
        p.productLocation == ProductLocation.both
      ).toList();
      
      // Agrupar por nombre
      final Map<String, List<Product>> duplicateGroups = {};
      
      for (final product in inventoryProducts) {
        final normalizedName = product.name.toLowerCase().trim();
        if (!duplicateGroups.containsKey(normalizedName)) {
          duplicateGroups[normalizedName] = [];
        }
        duplicateGroups[normalizedName]!.add(product);
      }
      
      // Filtrar solo grupos con más de un producto
      duplicateGroups.removeWhere((key, value) => value.length <= 1);
      
      return duplicateGroups;
    } catch (e) {
      print('Error al obtener productos duplicados: $e');
      return {};
    }
  }

  // Método para obtener productos por categoría
  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final userId = _userId;
      if (userId == null) return [];
      
      final query = await _userProducts?.where('category', isEqualTo: category).get();
      
      if (query == null) return [];
      
      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromMap({
          'id': doc.id,
          'userId': userId, // Asegurar que se incluya el ID del usuario
          ...data,
        });
      }).toList();
    } catch (e) {
      print('Error al obtener productos por categoría: $e');
      return [];
    }
  }

  // Método para obtener productos próximos a caducar
  Future<List<Product>> getExpiringProducts(int days) async {
    try {
      // Obtener todos los productos (no podemos filtrar por fecha directamente en Firestore en este caso)
      final products = await getAllProducts();
      
      // Filtrar productos que caducan en los próximos 'days' días
      final now = DateTime.now();
      final limit = now.add(Duration(days: days));
      
      return products.where((product) {
        // Solo incluir productos que estén en el inventario o en ambos lugares
        if (product.productLocation != ProductLocation.inventory && 
            product.productLocation != ProductLocation.both) {
          return false;
        }
        
        if (product.expiryDate == null) return false;
        return product.expiryDate!.isAfter(now) && product.expiryDate!.isBefore(limit);
      }).toList();
    } catch (e) {
      print('Error al obtener productos por caducar: $e');
      return [];
    }
  }

  // Método para obtener productos caducados
  Future<List<Product>> getExpiredProducts() async {
    try {
      // Obtener todos los productos
      final products = await getAllProducts();
      
      // Filtrar productos caducados
      final now = DateTime.now();
      
      return products.where((product) {
        // Solo incluir productos que estén en el inventario o en ambos lugares
        if (product.productLocation != ProductLocation.inventory && 
            product.productLocation != ProductLocation.both) {
          return false;
        }
        
        if (product.expiryDate == null) return false;
        return product.expiryDate!.isBefore(now);
      }).toList();
    } catch (e) {
      print('Error al obtener productos caducados: $e');
      return [];
    }
  }

  // Método addProduct corregido
  Future<void> addProduct(Product product) async {
    try {
      // Obtener usuario actual
      final userId = _userId;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      // Referencia a la base de datos
      final firestore = FirebaseFirestore.instance;
      
      // Asegurarse de que el producto tenga el ID de usuario correcto y productLocation
      final productWithLocation = product.copyWith(
        userId: userId, 
        productLocation: product.productLocation ?? ProductLocation.inventory,
        createdAt: product.createdAt ?? DateTime.now(),
        isPurchased: product.isPurchased // Incluir el campo isPurchased
      );
      
      final productMap = productWithLocation.toMap();
      
      // Eliminar el ID si está vacío para que Firestore genere uno nuevo
      if (product.id.isEmpty) {
        productMap.remove('id');
      }
      
      // Si hay fecha de caducidad, formatearla correctamente
      if (product.expiryDate != null) {
        productMap['expiryDate'] = product.expiryDate!.toIso8601String();
      }
      
      // Agregar timestamp para ordenamiento
      productMap['lastUpdated'] = FieldValue.serverTimestamp();
      
      // Imprimir información para depuración
      print('Añadiendo producto al inventario:');
      print('- Nombre: ${product.name}');
      print('- Cantidad: ${product.quantity}');
      print('- Unidad: ${product.unit}');
      print('- Categoría: ${product.category}');
      print('- Ubicación: ${product.location}');
      print('- ProductLocation: ${product.productLocation.toString()}');
      print('- ¿Comprado?: ${product.isPurchased}');
      
      // Guardar el producto en Firestore - colección de primer nivel
      if (product.id.isEmpty) {
        // Añadir un nuevo documento
        final docRef = await firestore
          .collection('users')
          .doc(userId)
          .collection('products')
          .add(productMap);
        
        print('Producto añadido con éxito al inventario, ID: ${docRef.id}');
      } else {
        // Actualizar documento existente
        await firestore
          .collection('users')
          .doc(userId)
          .collection('products')
          .doc(product.id)
          .set(productMap);
        
        print('Producto actualizado con éxito en el inventario, ID: ${product.id}');
      }
    } catch (e) {
      print('Error al añadir producto al inventario: $e');
      rethrow;
    }
  }

  // Método para mover un producto entre ubicaciones
  Future<bool> moveProductLocation(String productId, ProductLocation newLocation) async {
    try {
      if (_userProducts == null) throw Exception('Usuario no autenticado');
      
      // Obtener el producto actual
      final product = await getProductById(productId);
      if (product == null) {
        throw Exception('Producto no encontrado');
      }
      
      // Crear copia con nueva ubicación
      final updatedProduct = product.moveToLocation(newLocation);
      
      // Si no hay cambios, retornar éxito sin hacer nada
      if (updatedProduct.productLocation == product.productLocation) {
        return true;
      }
      
      // Actualizar en Firestore
      await updateProduct(updatedProduct);
      
      print('Producto movido a: ${updatedProduct.productLocation}');
      return true;
    } catch (e) {
      print('Error al mover producto: $e');
      return false;
    }
  }

  // Método para mover un producto del inventario al carrito
  Future<bool> moveProductToShoppingList(String productId) async {
    try {
      if (_userProducts == null) throw Exception('Usuario no autenticado');
      
      // Obtener el producto actual
      final product = await getProductById(productId);
      if (product == null) {
        throw Exception('Producto no encontrado');
      }
      
      // Verificar que el producto está en el inventario
      if (product.productLocation != ProductLocation.inventory && 
          product.productLocation != ProductLocation.both) {
        throw Exception('El producto no está en el inventario');
      }
      
      // Actualizar ubicación
      Product updatedProduct;
      if (product.productLocation == ProductLocation.inventory) {
        updatedProduct = product.copyWith(productLocation: ProductLocation.both);
      } else {
        // Ya está en ambos lugares, no hacer nada
        return true;
      }
      
      // Actualizar en Firestore
      await updateProduct(updatedProduct);
      
      print('Producto añadido al carrito: ${product.name}');
      return true;
    } catch (e) {
      print('Error al mover producto al carrito: $e');
      return false;
    }
  }

  // Método para obtener un producto específico por ID
  Future<Product?> getProductById(String id) async {
    try {
      final userId = _userId;
      if (userId == null) return null;
      
      if (_userProducts == null) return null;
      
      final doc = await _userProducts!.doc(id).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromMap({
          'id': doc.id,
          'userId': userId,
          ...data,
        });
      }
      
      return null;
    } catch (e) {
      print('Error al obtener producto por ID: $e');
      return null;
    }
  }

  // Método para agregar ingredientes de recetas
  Future<bool> addMissingIngredientsToShoppingList(Recipe recipe) async {
    try {
      // Obtener ingredientes que faltan
      final missingIngredients = recipe.ingredients
          .where((ingredient) => !ingredient.isAvailable && !ingredient.isOptional)
          .toList();
      
      if (missingIngredients.isEmpty) {
        return false; // No hay ingredientes que añadir
      }
      
      // Añadir cada ingrediente a la lista de compras
      int successCount = 0;
      
      for (final ingredient in missingIngredients) {
        try {
          final productId = await addIngredientToShoppingList(ingredient);
          
          if (productId != null) {
            successCount++;
          }
        } catch (e) {
          print('Error al añadir ingrediente ${ingredient.name} a la lista: $e');
        }
      }
      
      return successCount > 0;
    } catch (e) {
      print('Error al añadir ingredientes a la lista de compras: $e');
      return false;
    }
  }

  /// Añade un ingrediente de una receta a la lista de compras
  Future<String?> addIngredientToShoppingList(RecipeIngredient ingredient) async {
    try {
      // Verificar si el usuario está autenticado
      final userId = _userId;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Verificar que la referencia a la colección de productos existe
      if (_userProducts == null) {
        throw Exception('No se pudo acceder a la colección de productos');
      }
      
      // Convertir cantidad a int si es posible
      int quantity = 1; // Por defecto
      
      if (ingredient.quantity is int) {
        quantity = ingredient.quantity;
      } else if (ingredient.quantity is double) {
        quantity = (ingredient.quantity as double).toInt();
      } else if (ingredient.quantity is String && ingredient.quantity.toString().isNotEmpty) {
        quantity = int.tryParse(ingredient.quantity.toString()) ?? 1;
      }
      
      // Crear un nuevo producto a partir del ingrediente
      final product = Product(
        id: '', // Vacío para que Firestore genere uno
        name: ingredient.name,
        quantity: quantity,
        unit: ingredient.unit,
        category: 'Varios', // Categoría por defecto
        productLocation: ProductLocation.shoppingList,
        userId: userId,
        location: '',  // Campo obligatorio
        maxQuantity: quantity, // Usar la misma cantidad como máxima por defecto
        createdAt: DateTime.now(),
        expiryDate: null,
        imageUrl: '',
        isPurchased: false,
      );
      
      // Usar el método addProduct existente que ya tiene la lógica correcta
      await addProduct(product);
      
      // Buscar el producto recién añadido para obtener su ID
      final products = await searchProducts(ingredient.name);
      String? newProductId = products.isNotEmpty 
          ? products.firstWhere(
              (p) => p.name == ingredient.name && 
                    p.productLocation == ProductLocation.shoppingList,
              orElse: () => Product(
                  id: '', 
                  name: '', 
                  quantity: 0, 
                  unit: '', 
                  category: '', 
                  location: '', 
                  userId: '')
            ).id 
          : null;
      
      if (newProductId != null && newProductId.isNotEmpty) {
        print('Ingrediente añadido a la lista de compras: ${ingredient.name}, ID: $newProductId');
        return newProductId;
      } else {
        print('Ingrediente añadido a la lista de compras, pero no se pudo recuperar el ID');
        return null;
      }
    } catch (e) {
      print('Error al añadir ingrediente a la lista de compras: $e');
      return null;
    }
  }

  // Método para mover un producto del carrito al inventario
  Future<bool> moveProductToInventory(String productId) async {
    try {
      if (_userProducts == null) throw Exception('Usuario no autenticado');
      
      // Obtener el producto actual
      final product = await getProductById(productId);
      if (product == null) {
        throw Exception('Producto no encontrado');
      }
      
      // Verificar que el producto está en la lista de compras
      if (product.productLocation != ProductLocation.shoppingList && 
          product.productLocation != ProductLocation.both) {
        throw Exception('El producto no está en la lista de compras');
      }
      
      // Actualizar ubicación
      Product updatedProduct;
      if (product.productLocation == ProductLocation.shoppingList) {
        updatedProduct = product.copyWith(productLocation: ProductLocation.both);
      } else {
        // Ya está en ambos lugares, no hacer nada
        return true;
      }
      
      // Actualizar en Firestore
      await updateProduct(updatedProduct);
      
      print('Producto añadido al inventario: ${product.name}');
      return true;
    } catch (e) {
      print('Error al mover producto al inventario: $e');
      return false;
    }
  }

  // Método para eliminar un producto de una ubicación específica
  Future<bool> removeProductFromLocation(String productId, ProductLocation location) async {
    try {
      if (_userProducts == null) throw Exception('Usuario no autenticado');
      
      // Obtener el producto actual
      final product = await getProductById(productId);
      if (product == null) {
        throw Exception('Producto no encontrado');
      }
      
      // Verificar que el producto está en la ubicación indicada
      if (!product.isAvailableIn(location)) {
        throw Exception('El producto no está en la ubicación indicada');
      }
      
      // Actualizar ubicación o eliminar según corresponda
      if (product.productLocation == ProductLocation.both) {
        // Si está en ambos lugares, quitar solo de la ubicación indicada
        ProductLocation newLocation = location == ProductLocation.inventory 
            ? ProductLocation.shoppingList 
            : ProductLocation.inventory;
        
        final updatedProduct = product.copyWith(productLocation: newLocation);
        await updateProduct(updatedProduct);
        
        print('Producto eliminado de ${location.toString()}: ${product.name}');
      } else {
        // Si solo está en la ubicación indicada, eliminar completamente
        await deleteProduct(productId);
        print('Producto eliminado completamente: ${product.name}');
      }
      
      return true;
    } catch (e) {
      print('Error al eliminar producto de ubicación: $e');
      return false;
    }
  }

  // Método para obtener productos próximos a caducar con configuración personalizada
  Future<List<Product>> getExpiringProductsWithSettings() async {
    try {
      // Obtener configuraciones de caducidad
      final expirySettingsService = ExpirySettingsService();
      final settings = await expirySettingsService.getSettings();
      
      // Usar esas configuraciones para obtener productos
      return getExpiringProducts(settings.warningDays);
    } catch (e) {
      print('Error al obtener productos por caducar con configuraciones: $e');
      // Usar valor por defecto si hay un error
      return getExpiringProducts(7);
    }
  }

  // Método para actualizar un producto
  Future<void> updateProduct(Product product) async {
    try {
      if (_userProducts == null) throw Exception('Usuario no autenticado');
      
      final userId = _userId;
      if (userId == null) throw Exception('Usuario no autenticado');
      
      // Verificar que el producto pertenezca al usuario actual
      if (product.userId != userId) {
        throw Exception('No tienes permiso para modificar este producto');
      }
      
      final productMap = product.toMap();
      
      // Si hay fecha de caducidad, asegurarse que esté en formato ISO
      if (product.expiryDate != null) {
        productMap['expiryDate'] = product.expiryDate!.toIso8601String();
      }
      
      // Eliminar ID del mapa ya que es la referencia del documento
      productMap.remove('id');
      
      await _userProducts!.doc(product.id).update(productMap);
    } catch (e) {
      print('Error al actualizar producto: $e');
      rethrow;
    }
  }

  // Método para eliminar un producto
  Future<void> deleteProduct(String id) async {
    try {
      if (_userProducts == null) throw Exception('Usuario no autenticado');
      await _userProducts!.doc(id).delete();
    } catch (e) {
      print('Error al eliminar producto: $e');
      rethrow;
    }
  }

  // Método para actualizar la cantidad de un producto
  Future<void> updateProductQuantity(String id, int newQuantity, {int? maxQuantity}) async {
    try {
      if (_userProducts == null) throw Exception('Usuario no autenticado');
      
      if (newQuantity <= 0) {
        // Si la cantidad es 0 o menos, eliminar el producto
        await deleteProduct(id);
      } else {
        // Preparar los datos a actualizar
        final Map<String, dynamic> updateData = {'quantity': newQuantity};
        
        // Añadir maxQuantity si se proporciona
        if (maxQuantity != null) {
          updateData['maxQuantity'] = maxQuantity;
        }
        
        // Actualizar solo los campos especificados
        await _userProducts!.doc(id).update(updateData);
      }
    } catch (e) {
      print('Error al actualizar cantidad: $e');
      rethrow;
    }
  }

  // Método para buscar productos
  Future<List<Product>> searchProducts(String query) async {
    try {
      final userId = _userId;
      if (userId == null) return [];
      
      // Obtener todos los productos (no podemos hacer búsqueda de texto completo en Firestore sin configuración adicional)
      final products = await getAllProducts();
      
      // Filtrar por nombre o categoría que contenga la query
      final normalizedQuery = query.toLowerCase();
      
      return products.where((product) {
        return product.name.toLowerCase().contains(normalizedQuery) ||
               product.category.toLowerCase().contains(normalizedQuery);
      }).toList();
    } catch (e) {
      print('Error en la búsqueda: $e');
      return [];
    }
  }

  // Método para obtener un stream de productos (para actualización en tiempo real)
  Stream<List<Product>> getProductsStream() {
    try {
      final userId = _userId;
      if (userId == null || _userProducts == null) return Stream.value([]);
      
      return _userProducts!.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Product.fromMap({
            'id': doc.id,
            'userId': userId, // Asegurar que se incluya el ID del usuario
            ...data,
          });
        }).toList();
      });
    } catch (e) {
      print('Error al obtener stream de productos: $e');
      return Stream.value([]);
    }
  }

  // Obtener datos para estadísticas del inventario
  Stream<Map<String, dynamic>> getInventoryStatsStream() {
    return getProductsStream().map((products) {
      // Filtrar solo productos que están en el inventario
      final inventoryProducts = products.where((product) =>
        product.productLocation == ProductLocation.inventory || 
        product.productLocation == ProductLocation.both
      ).toList();
      
      final locationCounts = <String, int>{};
      
      // Contar productos por ubicación
      for (final product in inventoryProducts) {
        locationCounts[product.location] = (locationCounts[product.location] ?? 0) + 1;
      }
      
      // Obtener productos por caducar
      final now = DateTime.now();
      final expiringThreshold = now.add(const Duration(days: 7));
      
      final expiringProducts = inventoryProducts.where((product) {
        if (product.expiryDate == null) return false;
        return product.expiryDate!.isAfter(now) && product.expiryDate!.isBefore(expiringThreshold);
      }).toList();
      
      // Obtener productos caducados
      final expiredProducts = inventoryProducts.where((product) {
        if (product.expiryDate == null) return false;
        return product.expiryDate!.isBefore(now);
      }).toList();
      
      // Contar categorías
      final categoryCount = <String, int>{};
      for (final product in inventoryProducts) {
        categoryCount[product.category] = (categoryCount[product.category] ?? 0) + 1;
      }
      
      // Ordenar categorías por cantidad
      final sortedCategories = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return {
        'totalItems': inventoryProducts.length,
        'locationCounts': locationCounts,
        'expiringItems': expiringProducts.length,
        'expiredItems': expiredProducts.length,
        'topCategories': sortedCategories.take(3).map((e) => {'name': e.key, 'count': e.value}).toList(),
      };
    });
  }

  // Método para obtener productos por ubicación en la aplicación (inventory/shoppingList/both)
  Future<List<Product>> getProductsByAppLocation(ProductLocation appLocation) async {
    try {
      final userId = _userId;
      if (userId == null) return [];
      
      // Obtener todos los productos
      final allProducts = await getAllProducts();
      
      // Filtrar por ubicación en la aplicación
      return allProducts.where((product) => 
        product.productLocation == appLocation
      ).toList();
    } catch (e) {
      print('Error al obtener productos por ubicación en la app: $e');
      return [];
    }
  }

  // Método para migrar datos de ejemplo a Firestore (útil para la primera vez)
  Future<void> migrateExampleDataToFirestore() async {
    if (_userProducts == null) return;
    
    final userId = _userId;
    if (userId == null) return;
    
    // Verificar si el usuario ya tiene productos
    final existingProducts = await _userProducts!.get();
    if (existingProducts.docs.isNotEmpty) return; // Ya tiene productos, no migrar
    
    // Datos de ejemplo con valores enteros
    final exampleProducts = [
      Product(
        id: '1',
        name: 'Leche',
        quantity: 1,
        maxQuantity: 2, // Ejemplo: 2 botellas/litros
        unit: 'L',
        expiryDate: DateTime.now().add(const Duration(days: 3)),
        imageUrl: '',
        category: 'Lácteos',
        location: 'Nevera',
        userId: userId,
        productLocation: ProductLocation.inventory, // Especificar que está en el inventario
      ),
      Product(
        id: '2',
        name: 'Huevos',
        quantity: 8,
        maxQuantity: 12, // Ejemplo: cartón de 12 huevos
        unit: 'unidades',
        expiryDate: DateTime.now().add(const Duration(days: 15)),
        imageUrl: '',
        category: 'Lácteos',
        location: 'Nevera',
        userId: userId,
        productLocation: ProductLocation.inventory,
      ),
      Product(
        id: '3',
        name: 'Arroz',
        quantity: 800,
        maxQuantity: 1000,
        unit: 'g',
        expiryDate: DateTime.now().add(const Duration(days: 180)),
        imageUrl: '',
        category: 'Granos',
        location: 'Despensa',
        userId: userId,
        productLocation: ProductLocation.inventory,
      ),
      Product(
        id: '4',
        name: 'Pasta congelada',
        quantity: 250,
        maxQuantity: 500,
        unit: 'g',
        expiryDate: DateTime.now().add(const Duration(days: 90)),
        imageUrl: '',
        category: 'Congelados',
        location: 'Congelador',
        userId: userId,
        productLocation: ProductLocation.inventory,
      ),
      Product(
        id: '5',
        name: 'Albahaca',
        quantity: 15,
        maxQuantity: 30,
        unit: 'g',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        imageUrl: '',
        category: 'Condimentos',
        location: 'Especias',
        userId: userId,
        productLocation: ProductLocation.inventory,
      ),
      Product(
        id: '6',
        name: 'Cereales',
        quantity: 300,
        maxQuantity: 500,
        unit: 'g',
        expiryDate: DateTime.now().add(const Duration(days: 120)),
        imageUrl: '',
        category: 'Cereales',
        location: 'Armario',
        userId: userId,
        productLocation: ProductLocation.inventory,
      ),
    ];
    
    // Agregar cada producto a Firestore
    for (final product in exampleProducts) {
      await addProduct(product);
    }
  }
  
  // Método para migrar productos existentes y añadir campo productLocation
  Future<void> migrateExistingProductsAddProductLocation() async {
    try {
      final userId = _userId;
      if (userId == null) return;
      
      if (_userProducts == null) return;
      
      // Obtener todos los productos
      final querySnapshot = await _userProducts!.get();
      
      // Para cada producto, añadir campo productLocation si no existe
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Verificar si ya tiene productLocation
        if (!data.containsKey('productLocation')) {
          // Actualizar documento con el nuevo campo
          await doc.reference.update({
            'productLocation': ProductLocation.inventory.toString()
          });
          print('Migrado producto ${data['name']} - añadido productLocation');
        }
      }
      
      print('Migración de productLocation completada');
    } catch (e) {
      print('Error al migrar productos: $e');
    }
  }
}