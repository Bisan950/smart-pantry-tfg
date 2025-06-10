// lib/services/shopping_list_service.dart - VERSIÓN COMPLETA Y CORREGIDA

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../models/product_location_model.dart';
import '../providers/shopping_list_provider.dart'; // Para usar ShoppingItem
import 'firestore_service.dart';
import 'inventory_service.dart';

class ShoppingListService {
  // Singleton para acceso global al servicio
  static final ShoppingListService _instance = ShoppingListService._internal();
  factory ShoppingListService() => _instance;
  ShoppingListService._internal();

  // Instancias de servicios
  final FirestoreService _firestoreService = FirestoreService();
  final InventoryService _inventoryService = InventoryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Referencia al usuario actual
  String? get _userId => _auth.currentUser?.uid;
  
  // Referencias a Firestore
  CollectionReference? get _shoppingListCollection {
    final userId = _userId;
    if (userId == null) return null;
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('shoppingList'); // Cambio de 'shopping_list' a 'shoppingList'
  }
  
  CollectionReference? get _productsCollection {
    final userId = _userId;
    if (userId == null) return null;
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('products');
  }

  CollectionReference? get _favoritesCollection {
    final userId = _userId;
    if (userId == null) return null;
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites');
  }
  
  // Referencia a la colección de lista de compras del usuario (usando FirestoreService)
  CollectionReference? get _userShoppingList {
    final userId = _userId;
    if (userId == null) return null;
    return _firestoreService.getUserShoppingList(userId);
  }

  // ✅ MÉTODO DE INICIALIZACIÓN REQUERIDO
  Future<void> initialize() async {
    try {
      final userId = _userId;
      if (userId == null) {
        print('⚠️ No hay usuario autenticado para inicializar ShoppingListService');
        return;
      }
      
      // Verificar que las colecciones existan
      await _firestoreService.ensureUserCollectionsExist();
      
      print('✅ ShoppingListService inicializado correctamente');
    } catch (e) {
      print('❌ Error al inicializar ShoppingListService: $e');
      rethrow;
    }
  }

  // === MÉTODOS PARA OBTENER LA LISTA DE COMPRAS ===
  
  // Obtener lista completa de compras (MÉTODO CORREGIDO)
  Future<List<ShoppingItem>> getShoppingItems() async {
    try {
      final userId = _userId;
      if (userId == null) return [];
      
      final snapshot = await _shoppingListCollection?.get();
      
      if (snapshot == null) return [];
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ShoppingItem.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
    } catch (e) {
      print('❌ Error al obtener lista de compras: $e');
      return [];
    }
  }

  // Método alternativo (CORREGIDO)
  Future<List<ShoppingItem>> getAllShoppingItems() async {
    try {
      if (_shoppingListCollection == null) return [];
      
      final snapshot = await _shoppingListCollection!.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ShoppingItem.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
    } catch (e) {
      print('❌ Error al obtener items de la lista de compras: $e');
      return [];
    }
  }
  
  // Obtener un stream de items de la lista de compras (CORREGIDO)
  Stream<List<ShoppingItem>> getShoppingItemsStream() {
    try {
      if (_shoppingListCollection == null) return Stream.value([]);
      
      return _shoppingListCollection!.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return ShoppingItem.fromMap({
            'id': doc.id,
            ...data,
          });
        }).toList();
      });
    } catch (e) {
      print('❌ Error al obtener stream de lista de compras: $e');
      return Stream.value([]);
    }
  }

  // === MÉTODOS PARA AÑADIR ITEMS ===
  
  // Método para añadir un item a la lista de compras (MEJORADO)
  Future<String?> addShoppingItem(ShoppingItem item) async {
    try {
      if (_shoppingListCollection == null) throw Exception('Usuario no autenticado');
      
      // Verificar si ya existe un item con el mismo nombre
      final existingItems = await _shoppingListCollection!
          .where('name', isEqualTo: item.name)
          .limit(1) // Optimización: solo necesitamos saber si existe
          .get();
      
      if (existingItems.docs.isNotEmpty) {
        // Si existe, actualizar la cantidad
        final existingDoc = existingItems.docs.first;
        final existingItem = ShoppingItem.fromMap({
          'id': existingDoc.id,
          ...(existingDoc.data() as Map<String, dynamic>),
        });
        
        final updatedQuantity = existingItem.quantity + item.quantity;
        await existingDoc.reference.update({
          'quantity': updatedQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        return existingDoc.id;
      } else {
        // Si no existe, crear nuevo item
        final itemMap = item.toMap();
        itemMap.remove('id');
        itemMap['createdAt'] = FieldValue.serverTimestamp();
        itemMap['updatedAt'] = FieldValue.serverTimestamp();
        
        final docRef = await _shoppingListCollection!.add(itemMap);
        return docRef.id;
      }
    } catch (e) {
      print('❌ Error al añadir item a la lista de compras: $e');
      rethrow; // Propagar el error para manejo en el provider
    }
  }
  
  // Método para añadir múltiples items a la vez
  Future<void> addMultipleItems(List<ShoppingItem> items) async {
    for (final item in items) {
      await addShoppingItem(item);
    }
  }

  // === MÉTODOS PARA ACTUALIZAR ITEMS ===
  
  // Método seguro para actualizar un item (CORREGIDO)
  Future<bool> updateShoppingItem(ShoppingItem updatedItem) async {
    try {
      if (_shoppingListCollection == null) throw Exception('Usuario no autenticado');
      
      print("🔄 Actualizando item: ${updatedItem.id} - ${updatedItem.name}");
      
      if (updatedItem.id.isEmpty) {
        print('❌ ID de item vacío');
        return false;
      }
      
      // Intentar con el ID exacto primero
      final docRef = _shoppingListCollection!.doc(updatedItem.id);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        print("✅ Documento encontrado, actualizando...");
        final data = updatedItem.toMap();
        data.remove('id');
        data['updatedAt'] = FieldValue.serverTimestamp();
        await docRef.update(data);
        return true;
      }
      
      // Si no existe, buscar por nombre
      print("🔍 Buscando por nombre...");
      final querySnapshot = await _shoppingListCollection!
          .where('name', isEqualTo: updatedItem.name)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        print("✅ Encontrado por nombre, actualizando: ${doc.id}");
        final data = updatedItem.toMap();
        data.remove('id');
        data['updatedAt'] = FieldValue.serverTimestamp();
        await doc.reference.update(data);
        return true;
      }
      
      print("❌ No se encontró el item para actualizar");
      return false;
    } catch (e) {
      print('❌ Error al actualizar item: $e');
      return false;
    }
  }
  
  // Método para marcar un item como comprado o no comprado (CORREGIDO)
  Future<bool> toggleItemPurchased(String itemId) async {
    try {
      if (_shoppingListCollection == null) throw Exception('Usuario no autenticado');
      
      print('🔄 Toggling purchase state for item: $itemId');
      
      // Obtener el estado actual
      final doc = await _shoppingListCollection!.doc(itemId).get();
      
      if (!doc.exists) {
        print('❌ Documento no encontrado');
        return false;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final currentState = data['isPurchased'] as bool? ?? false;
      final newState = !currentState;
      
      // Actualizar el estado
      await _shoppingListCollection!.doc(itemId).update({
        'isPurchased': newState,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Estado actualizado de $currentState a $newState');
      return true;
    } catch (e) {
      print('❌ Error al marcar item como comprado: $e');
      return false;
    }
  }

  // === MÉTODOS PARA ELIMINAR ITEMS ===
  
  // Método seguro para eliminar un item (CORREGIDO)
  Future<bool> removeShoppingItem(String itemId) async {
    try {
      if (_shoppingListCollection == null) throw Exception('Usuario no autenticado');
      
      print("🗑️ Eliminando item: $itemId");
      
      // Intentar eliminar directamente por ID
      final docRef = _shoppingListCollection!.doc(itemId);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        await docRef.delete();
        print("✅ Item eliminado exitosamente");
        return true;
      }
      
      print("❌ No se encontró el item para eliminar");
      return false;
    } catch (e) {
      print('❌ Error al eliminar item: $e');
      return false;
    }
  }
  
  // Alias para mantener compatibilidad
  Future<bool> deleteShoppingItem(String id) async {
    return removeShoppingItem(id);
  }
  
  // Método para limpiar items comprados (CORREGIDO)
  Future<int> clearPurchasedItems() async {
    try {
      if (_shoppingListCollection == null) throw Exception('Usuario no autenticado');
      
      // Obtener items comprados
      final purchasedItems = await _shoppingListCollection!
          .where('isPurchased', isEqualTo: true)
          .get();
      
      // Eliminar cada item
      for (final doc in purchasedItems.docs) {
        await doc.reference.delete();
      }
      
      print('🧹 Eliminados ${purchasedItems.docs.length} items comprados');
      return purchasedItems.docs.length;
    } catch (e) {
      print('❌ Error al limpiar items comprados: $e');
      return 0;
    }
  }

  // === MÉTODOS RELACIONADOS CON INVENTARIO ===
  
  // Método para añadir un producto del inventario a la lista de compras (CORREGIDO)
  Future<bool> addProductFromInventory(Product product) async {
    try {
      // Calculate suggested quantity using the helper method
      final suggestedQuantity = _calculateSuggestedQuantity(product);
      
      final shoppingItem = ShoppingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: product.name,
        quantity: suggestedQuantity, // Use calculated quantity
        maxQuantity: product.maxQuantity,
        unit: product.unit,
        category: product.category,
        location: product.location,
        imageUrl: product.imageUrl,
        expiryDate: null,
        isPurchased: false,
        isSuggested: false,
      );
      
      final result = await addShoppingItem(shoppingItem);
      return result != null; // Convert String? to bool
    } catch (e) {
      print('❌ Error al añadir producto desde inventario: $e');
      return false;
    }
  }

  // Método auxiliar para calcular cantidad sugerida (versión simple)
int _calculateSuggestedQuantity(Product product) {
  // Si el producto tiene cantidad actual, usar esa como base
  if (product.quantity > 0) {
    return product.quantity; // Usar la cantidad actual como referencia
  }
  
  // Si no hay cantidad, usar cantidades por defecto según la unidad
  switch (product.unit.toLowerCase()) {
    case 'unidades':
      return 1;
    case 'g':
      return 500;
    case 'kg':
      return 1;
    case 'ml':
      return 500;
    case 'l':
      return 1;
    case 'paquete':
    case 'lata':
    case 'botella':
      return 1;
    default:
      return 1;
  }
}

  // === MÉTODOS DE SUGERENCIAS ===
  
  // Método para generar sugerencias (MEJORADO)
  Future<List<ShoppingItem>> generateSuggestions() async {
    try {
      final result = <ShoppingItem>[];
      
      // Obtener productos con poco stock
      final allProducts = await _inventoryService.getAllProducts();
      final lowStockProducts = allProducts.where((product) {
        return _hasLowStock(product);
      }).toList();
      
      // Obtener productos próximos a caducar
      final expiringProducts = await _inventoryService.getExpiringProducts(3);
      
      // Obtener la lista actual para evitar duplicados
      final currentList = await getShoppingItems();
      final currentProductNames = currentList.map((item) => item.name.toLowerCase()).toSet();
      
      final addedProductNames = <String>{};
      
      // Agregar productos con poco stock
      for (final product in lowStockProducts) {
        final productName = product.name.toLowerCase();
        if (!addedProductNames.contains(productName) && 
            !currentProductNames.contains(productName)) {
          result.add(ShoppingItem(
            id: 'suggestion_${DateTime.now().millisecondsSinceEpoch}_${result.length}',
            name: product.name,
            quantity: 1,
            unit: product.unit,
            category: product.category,
            isPurchased: false,
            isSuggested: true,
            priority: 2,
          ));
          addedProductNames.add(productName);
        }
      }
      
      // Agregar productos próximos a caducar
      for (final product in expiringProducts) {
        final productName = product.name.toLowerCase();
        if (!addedProductNames.contains(productName) && 
            !currentProductNames.contains(productName)) {
          result.add(ShoppingItem(
            id: 'suggestion_${DateTime.now().millisecondsSinceEpoch}_${result.length}',
            name: product.name,
            quantity: 1,
            unit: product.unit,
            category: product.category,
            isPurchased: false,
            isSuggested: true,
            priority: 1, // Alta prioridad para productos que caducan
          ));
          addedProductNames.add(productName);
        }
      }
      
      print('🤖 Generadas ${result.length} sugerencias');
      return result;
    } catch (e) {
      print('❌ Error al generar sugerencias: $e');
      return [];
    }
  }

  bool _hasLowStock(Product product) {
    switch (product.unit.toLowerCase()) {
      case 'unidades':
        return product.quantity <= 2;
      case 'g':
        return product.quantity <= 100;
      case 'kg':
        return product.quantity <= 1;
      case 'ml':
        return product.quantity <= 100;
      case 'l':
        return product.quantity <= 1;
      default:
        return product.quantity <= 2;
    }
  }

  // === MÉTODOS DE FAVORITOS (CORREGIDOS Y COMPLETOS) ===
  
  // Método para añadir un producto a favoritos CON INFORMACIÓN COMPLETA
  Future<bool> addProductToFavorites(Product product) async {
    try {
      final userId = _userId;
      if (userId == null) return false;

      // Verificar si ya existe
      final existingDoc = await _favoritesCollection!
          .where('name', isEqualTo: product.name)
          .get();
      
      if (existingDoc.docs.isNotEmpty) {
        print('⚠️ Producto ya existe en favoritos');
        return true; // Ya existe, consideramos como éxito
      }
      
      // Crear el documento de favorito con TODA la información del producto
      final favoriteData = {
        'name': product.name,
        'category': product.category,
        'unit': product.unit,
        'location': product.location,
        'userId': userId,
        'isFavorite': true,
        'createdAt': FieldValue.serverTimestamp(),
        
        // INFORMACIÓN COMPLETA que se almacena:
        'quantity': product.quantity,
        'maxQuantity': product.maxQuantity,
        'expiryDate': product.expiryDate,
        'imageUrl': product.imageUrl,
        'notes': product.notes,
        'barcode': product.barcode,
        
        // Información nutricional completa
        'nutritionalInfo': product.nutritionalInfo?.toMap(),
        
        // Metadatos adicionales para favoritos
        'savedFromInventory': true,
        'originalProductId': product.id,
        'completeness': {
          'hasQuantity': product.quantity > 0,
          'hasMaxQuantity': product.maxQuantity > 0,
          'hasExpiryDate': product.expiryDate != null,
          'hasNutritionalInfo': product.nutritionalInfo != null,
          'hasImage': product.imageUrl.isNotEmpty,
          'hasNotes': product.notes.isNotEmpty,
        }
      };

      await _favoritesCollection!.add(favoriteData);
      
      print('✅ Producto añadido a favoritos con información completa');
      return true;
    } catch (e) {
      print('❌ Error al guardar favorito: $e');
      return false;
    }
  }
  
  // Método para obtener favoritos (CORREGIDO)
  Future<List<Product>> getFavoriteProducts() async {
    try {
      final userId = _userId;
      if (userId == null) return [];

      final snapshot = await _favoritesCollection!
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Crear producto favorito con información completa
        return Product.fromMap({
          'id': doc.id,
          'userId': userId,
          ...data,
        });
      }).toList();
    } catch (e) {
      print('❌ Error al obtener favoritos: $e');
      return [];
    }
  }

  // Método para obtener favorito completo por ID (NUEVO)
  Future<Product?> getCompleteFavoriteById(String favoriteId) async {
    try {
      final userId = _userId;
      if (userId == null) return null;

      final doc = await _favoritesCollection!.doc(favoriteId).get();

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      
      // Retornar el producto con TODA la información completa
      return Product.fromMap({
        'id': doc.id,
        'userId': userId,
        ...data,
      });
    } catch (e) {
      print('❌ Error al obtener favorito completo: $e');
      return null;
    }
  }

  // Método para eliminar de favoritos (CORREGIDO)
  Future<bool> removeFromFavorites(String favoriteId) async {
    try {
      final userId = _userId;
      if (userId == null) return false;

      await _favoritesCollection!.doc(favoriteId).delete();
      
      print('✅ Favorito eliminado');
      return true;
    } catch (e) {
      print('❌ Error al eliminar favorito: $e');
      return false;
    }
  }

  // Método para añadir un producto favorito al inventario CON INFORMACIÓN COMPLETA (NUEVO)
  Future<bool> addFavoriteToInventory(Product favoriteProduct) async {
    try {
      // Obtener el favorito completo con toda la información
      final completeFavorite = await getCompleteFavoriteById(favoriteProduct.id) 
          ?? favoriteProduct;
      
      // Crear producto para inventario con TODA la información completa
      final inventoryProduct = completeFavorite.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productLocation: ProductLocation.inventory,
        createdAt: DateTime.now(),
        isFavorite: false,
        // MANTENER TODA LA INFORMACIÓN ORIGINAL:
        // quantity, maxQuantity, expiryDate, nutritionalInfo,
        // imageUrl, notes, unit, location, barcode
      );
      
      // Añadir al inventario con toda la información
      await _inventoryService.addProduct(inventoryProduct);
      
      print('✅ Favorito añadido al inventario con información completa');
      return true;
    } catch (e) {
      print('❌ Error al añadir favorito al inventario: $e');
      return false;
    }
  }

  // Método para verificar si un producto ya está en favoritos (NUEVO)
  Future<bool> isProductInFavorites(String productId) async {
    try {
      final userId = _userId;
      if (userId == null) return false;

      final doc = await _favoritesCollection!.doc(productId).get();
      return doc.exists;
    } catch (e) {
      print('❌ Error al verificar favorito: $e');
      return false;
    }
  }

  // Método para obtener estadísticas de completeness de favoritos (NUEVO)
  Future<Map<String, int>> getFavoritesCompletenessStats() async {
    try {
      final userId = _userId;
      if (userId == null) return {};

      final snapshot = await _favoritesCollection!.get();

      int withQuantity = 0;
      int withExpiryDate = 0;
      int withNutritionalInfo = 0;
      int withImage = 0;
      int withNotes = 0;
      int total = snapshot.docs.length;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final completeness = data['completeness'] as Map<String, dynamic>?;
        
        if (completeness != null) {
          if (completeness['hasQuantity'] == true) withQuantity++;
          if (completeness['hasExpiryDate'] == true) withExpiryDate++;
          if (completeness['hasNutritionalInfo'] == true) withNutritionalInfo++;
          if (completeness['hasImage'] == true) withImage++;
          if (completeness['hasNotes'] == true) withNotes++;
        }
      }

      return {
        'total': total,
        'withQuantity': withQuantity,
        'withExpiryDate': withExpiryDate,
        'withNutritionalInfo': withNutritionalInfo,
        'withImage': withImage,
        'withNotes': withNotes,
      };
    } catch (e) {
      print('❌ Error al obtener estadísticas de favoritos: $e');
      return {};
    }
  }

  // === MÉTODOS DE UTILIDAD ===
  
  // Método para verificar si un item existe (CORREGIDO)
  Future<bool> checkIfItemExists(String itemId) async {
    try {
      if (_shoppingListCollection == null) return false;
      
      final doc = await _shoppingListCollection!.doc(itemId).get();
      return doc.exists;
    } catch (e) {
      print('❌ Error al verificar existencia de item: $e');
      return false;
    }
  }
  
  // Método para obtener el ID del usuario actual (CORREGIDO)
  Future<String> getCurrentUserId() async {
    final user = _auth.currentUser;
    
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }
    
    return user.uid;
  }

  // Método para limpiar todos los datos (útil para logout)
  Future<void> clearAllUserData() async {
    try {
      final userId = _userId;
      if (userId == null) return;

      // Limpiar lista de compras
      final shoppingItems = await _shoppingListCollection!.get();
      for (final doc in shoppingItems.docs) {
        await doc.reference.delete();
      }

      // Limpiar favoritos
      final favorites = await _favoritesCollection!.get();
      for (final doc in favorites.docs) {
        await doc.reference.delete();
      }

      print('🧹 Datos de usuario limpiados');
    } catch (e) {
      print('❌ Error al limpiar datos de usuario: $e');
    }
  }

  // === MÉTODO DE COMPATIBILIDAD ===
  
  // ✅ MÉTODO FALTANTE PARA COMPATIBILIDAD CON CHAT_SERVICE
  Future<List<ShoppingItem>> getShoppingList() async {
    return await getShoppingItems();
  }


}