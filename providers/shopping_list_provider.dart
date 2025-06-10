// lib/providers/shopping_list_provider.dart - VERSIÓN COMPLETA Y CORREGIDA

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/product_location_model.dart';
import '../services/shopping_list_service.dart';
import '../services/inventory_service.dart';
import 'dart:async';

/// Modelo para los items de la lista de compras
class ShoppingItem {
 final String id;
 final String name;
 final int quantity;
 final int maxQuantity;
 final String unit;
 final String category;
 final bool isPurchased;
 final bool isSuggested;
 final String imageUrl;
 final String location;
 final DateTime? expiryDate;
 final int? priority;
 final String? notes;

 ShoppingItem({
   required this.id,
   required this.name,
   required this.quantity,
   this.maxQuantity = 0,
   required this.unit,
   required this.category,
   this.isPurchased = false,
   this.isSuggested = false,
   this.imageUrl = '',
   this.location = 'Despensa',
   this.expiryDate,
   this.priority,
   this.notes,
 });

 ShoppingItem copyWith({
   String? id,
   String? name,
   int? quantity,
   int? maxQuantity,
   String? unit,
   String? category,
   bool? isPurchased,
   bool? isSuggested,
   String? imageUrl,
   String? location,
   DateTime? expiryDate,
   int? priority,
   String? notes,
 }) {
   return ShoppingItem(
     id: id ?? this.id,
     name: name ?? this.name,
     quantity: quantity ?? this.quantity,
     maxQuantity: maxQuantity ?? this.maxQuantity,
     unit: unit ?? this.unit,
     category: category ?? this.category,
     isPurchased: isPurchased ?? this.isPurchased,
     isSuggested: isSuggested ?? this.isSuggested,
     imageUrl: imageUrl ?? this.imageUrl,
     location: location ?? this.location,
     expiryDate: expiryDate ?? this.expiryDate,
     priority: priority ?? this.priority,
     notes: notes ?? this.notes,
   );
 }

 Map<String, dynamic> toMap() {
   return {
     'id': id,
     'name': name,
     'quantity': quantity,
     'maxQuantity': maxQuantity,
     'unit': unit,
     'category': category,
     'isPurchased': isPurchased,
     'isSuggested': isSuggested,
     'imageUrl': imageUrl,
     'location': location,
     'expiryDate': expiryDate?.toIso8601String(),
     'priority': priority,
     'notes': notes,
   };
 }

 factory ShoppingItem.fromMap(Map<String, dynamic> map) {
   // Conversión segura de quantity
   int quantity = 0;
   if (map['quantity'] != null) {
     if (map['quantity'] is int) {
       quantity = map['quantity'];
     } else if (map['quantity'] is double) {
       quantity = (map['quantity'] as double).toInt();
     } else if (map['quantity'] is String) {
       quantity = int.tryParse(map['quantity']) ?? 0;
     }
   }
   
   // Conversión segura de maxQuantity
   int maxQuantity = 0;
   if (map['maxQuantity'] != null) {
     if (map['maxQuantity'] is int) {
       maxQuantity = map['maxQuantity'];
     } else if (map['maxQuantity'] is double) {
       maxQuantity = (map['maxQuantity'] as double).toInt();
     } else if (map['maxQuantity'] is String) {
       maxQuantity = int.tryParse(map['maxQuantity']) ?? 0;
     }
   }

   // Conversión segura de expiryDate
   DateTime? expiryDate;
   if (map['expiryDate'] != null) {
     try {
       if (map['expiryDate'] is DateTime) {
         expiryDate = map['expiryDate'] as DateTime;
       } else if (map['expiryDate'] is Timestamp) {
         expiryDate = (map['expiryDate'] as Timestamp).toDate();
       } else if (map['expiryDate'] is String) {
         expiryDate = DateTime.parse(map['expiryDate'] as String);
       }
     } catch (e) {
       expiryDate = null;
     }
   }

   return ShoppingItem(
     id: map['id']?.toString() ?? '',
     name: map['name']?.toString() ?? '',
     quantity: quantity,
     maxQuantity: maxQuantity,
     unit: map['unit']?.toString() ?? '',
     category: map['category']?.toString() ?? '',
     isPurchased: map['isPurchased'] == true,
     isSuggested: map['isSuggested'] == true,
     imageUrl: map['imageUrl']?.toString() ?? '',
     location: map['location']?.toString() ?? 'Despensa',
     expiryDate: expiryDate,
     priority: map['priority'] as int?,
     notes: map['notes']?.toString(),
   );
 }
 
 factory ShoppingItem.fromProduct(Product product, {bool isSuggested = false}) {
   return ShoppingItem(
     id: DateTime.now().millisecondsSinceEpoch.toString(),
     name: product.name,
     quantity: 1,
     maxQuantity: product.maxQuantity,
     unit: product.unit,
     category: product.category,
     imageUrl: product.imageUrl,
     location: product.location,
     expiryDate: null,
     isSuggested: isSuggested,
     priority: 2,
     notes: null,
   );
 }
}

/// Provider corregido para evitar problemas de overlay
class ShoppingListProvider with ChangeNotifier {
 final ShoppingListService _shoppingListService = ShoppingListService();
 final InventoryService _inventoryService = InventoryService();
 
 // Streams subscription para manejo correcto
 StreamSubscription<List<ShoppingItem>>? _shoppingItemsSubscription;
 
 // === ESTADO PRINCIPAL ===
 List<ShoppingItem> _shoppingItems = [];
 List<ShoppingItem> _suggestedItems = [];
 List<Product> _favoriteProducts = [];
 
 // === ESTADO DE CARGA ===
 bool _isLoading = false;
 bool _isFavoritesLoading = false;
 bool _isInitialized = false;
 bool _isInventoryLoaded = false; // ✅ AGREGADO: Getter faltante
 String _error = '';
 
 // === SELECCIÓN ===
 final Set<String> _selectedItemIds = {};
 
 // === FILTROS ===
 String _categoryFilter = 'Todas';
 bool _showOnlyPending = false;
 String _sortBy = 'name';

 // === GETTERS SEGUROS ===
 List<ShoppingItem> get items => List.unmodifiable(_shoppingItems);
 List<ShoppingItem> get shoppingItems => List.unmodifiable(_shoppingItems);
 List<ShoppingItem> get suggestedItems => List.unmodifiable(_suggestedItems);
 List<Product> get favoriteProducts => List.unmodifiable(_favoriteProducts);
 
 bool get isLoading => _isLoading;
 bool get isFavoritesLoading => _isFavoritesLoading;
 bool get isInitialized => _isInitialized;
 bool get isInventoryLoaded => _isInventoryLoaded; // ✅ AGREGADO: Getter faltante
 String get error => _error;
 
 Set<String> get selectedItemIds => Set.unmodifiable(_selectedItemIds);
 bool get hasSelection => _selectedItemIds.isNotEmpty;
 
 String get categoryFilter => _categoryFilter;
 bool get showOnlyPending => _showOnlyPending;
 String get sortBy => _sortBy;

 // Getters de utilidad
 int get itemCount => _shoppingItems.length;
 int get purchasedCount => _shoppingItems.where((item) => item.isPurchased).length;
 int get pendingCount => itemCount - purchasedCount;

 // === CONSTRUCTOR SEGURO ===
 ShoppingListProvider() {
   // No inicializar automáticamente para evitar problemas de overlay
   _scheduleInitialization();
 }

 // Programar la inicialización para el siguiente tick del event loop
 void _scheduleInitialization() {
   Future.microtask(() async {
     try {
       await _safeInitialize();
     } catch (e) {
       debugPrint('Error en inicialización programada: $e');
     }
   });
 }

 // === INICIALIZACIÓN SEGURA ===
 Future<void> _safeInitialize() async {
   if (_isInitialized || _isLoading) return;
   
   try {
     _setLoading(true);
     
     // Verificar autenticación antes de continuar
     final user = FirebaseAuth.instance.currentUser;
     if (user == null) {
       _setError('Usuario no autenticado');
       return;
     }

     // Configurar stream de forma segura
     await _setupDataStream();
     
     // Cargar datos iniciales
     await _loadInitialData();
     
     _isInitialized = true;
     _setLoading(false);
     
     debugPrint('✅ ShoppingListProvider inicializado correctamente');
     
   } catch (e) {
     debugPrint('❌ Error en inicialización: $e');
     _setError('Error al inicializar: $e');
     _setLoading(false);
   }
 }

 // ✅ MÉTODO DE INICIALIZACIÓN PÚBLICO REQUERIDO
 Future<void> initialize() async {
   await _safeInitialize();
 }

 // Configuración segura del stream
 Future<void> _setupDataStream() async {
   try {
     // Cancelar stream anterior si existe
     await _shoppingItemsSubscription?.cancel();
     
     // Configurar nuevo stream con manejo de errores
     _shoppingItemsSubscription = _shoppingListService
         .getShoppingItemsStream()
         .handleError((error) {
           debugPrint('❌ Error en stream: $error');
           _setError('Error de conexión: $error');
         })
         .listen(
           (items) {
             _updateShoppingItems(items);
           },
           onError: (error) {
             debugPrint('❌ Error en listener del stream: $error');
             _setError('Error al recibir actualizaciones: $error');
           },
         );
     
     debugPrint('🔄 Stream configurado correctamente');
   } catch (e) {
     debugPrint('❌ Error configurando stream: $e');
     throw e;
   }
 }

 // Actualización segura de items
 void _updateShoppingItems(List<ShoppingItem> newItems) {
   try {
     _shoppingItems = newItems;
     
     // Limpiar selecciones de items que ya no existen
     _selectedItemIds.removeWhere(
       (id) => !_shoppingItems.any((item) => item.id == id)
     );
     
     _applySorting();
     
     // Solo notificar si hay cambios reales
     notifyListeners();
     
   } catch (e) {
     debugPrint('❌ Error actualizando items: $e');
   }
 }

 // Carga inicial de datos - CORREGIDA
 Future<void> _loadInitialData() async {
   try {
     // Cargar datos en paralelo de forma segura
     final futures = <Future<void>>[];
     
     futures.add(_loadItemsSafely());
     futures.add(_loadFavoritesSafely());
     futures.add(_generateSuggestionsSafely());
     
     // Esperar todas las operaciones con timeout - CORREGIDO
     await Future.wait(futures).timeout(
       const Duration(seconds: 30),
       onTimeout: () {
         debugPrint('⚠️ Timeout en carga inicial de datos');
         return <void>[]; // Retornar lista vacía en caso de timeout
       },
     );
     
   } catch (e) {
     debugPrint('❌ Error en carga inicial: $e');
     // No lanzar el error para evitar crash
   }
 }

 // === MÉTODOS DE CARGA SEGUROS ===

 Future<void> _loadItemsSafely() async {
   try {
     final items = await _shoppingListService.getShoppingItems();
     _shoppingItems = items;
     _applySorting();
   } catch (e) {
     debugPrint('❌ Error cargando items: $e');
     // Mantener lista vacía en caso de error
     _shoppingItems = [];
   }
 }

 Future<void> _loadFavoritesSafely() async {
   try {
     _favoriteProducts = await _shoppingListService.getFavoriteProducts();
   } catch (e) {
     debugPrint('❌ Error cargando favoritos: $e');
     _favoriteProducts = [];
   }
 }

 Future<void> _generateSuggestionsSafely() async {
   try {
     _suggestedItems = await _shoppingListService.generateSuggestions();
     debugPrint('🤖 Generadas ${_suggestedItems.length} sugerencias');
   } catch (e) {
     debugPrint('❌ Error generando sugerencias: $e');
     _suggestedItems = [];
   }
 }

 // === MÉTODOS PÚBLICOS SEGUROS ===

 Future<void> refreshData() async {
   if (_isLoading) return;
   
   try {
     debugPrint("🔄 Iniciando actualización de datos");
     _setLoading(true);
     _clearError();
     
     await _loadInitialData();
     
     debugPrint("✅ Actualización completada");
   } catch (e) {
     debugPrint("❌ Error en refreshData: $e");
     _setError('Error al actualizar: $e');
   } finally {
     _setLoading(false);
   }
 }

 // Método para forzar inicialización (llamar desde UI)
 Future<void> ensureInitialized() async {
   if (!_isInitialized && !_isLoading) {
     await _safeInitialize();
   }
 }

 // ✅ MÉTODO REQUERIDO PARA SINCRONIZAR CON INVENTARIO
 void syncWithInventoryProvider(List<Product> inventoryProducts) {
   try {
     debugPrint('🔄 Sincronizando con inventario (${inventoryProducts.length} productos)');
     _isInventoryLoaded = true;
     notifyListeners();
   } catch (e) {
     debugPrint('❌ Error en sincronización con inventario: $e');
   }
 }

 // === MÉTODOS REQUERIDOS POR DASHBOARD ===

 int getItemCount() {
   return _shoppingItems.length;
 }

 // === MÉTODOS DE FAVORITOS REQUERIDOS ===

 Future<void> loadFavorites() async {
   if (_isFavoritesLoading) return;
   
   try {
     _setFavoritesLoading(true);
     _clearError();
     
     _favoriteProducts = await _shoppingListService.getFavoriteProducts();
     notifyListeners();
   } catch (e) {
     debugPrint('❌ Error cargando favoritos: $e');
     _setError('Error al cargar favoritos: $e');
     _favoriteProducts = [];
   } finally {
     _setFavoritesLoading(false);
   }
 }

 Future<bool> addFavoriteToInventory(Product favoriteProduct) async {
   try {
     _clearError();
     
     // Obtener favorito completo con toda la información
     final completeFavorite = await _shoppingListService.getCompleteFavoriteById(favoriteProduct.id) 
         ?? favoriteProduct;
     
     // Crear producto para inventario con TODA la información completa
     final inventoryProduct = completeFavorite.copyWith(
       id: DateTime.now().millisecondsSinceEpoch.toString(),
       productLocation: ProductLocation.inventory,
       createdAt: DateTime.now(),
       isFavorite: false,
     );
     
     // Añadir al inventario con toda la información
     await _inventoryService.addProduct(inventoryProduct);
     
     return true;
   } catch (e) {
     debugPrint('❌ Error añadiendo favorito al inventario: $e');
     _setError('Error al añadir favorito al inventario: $e');
     return false;
   }
 }

 Future<bool> removeFromFavorites(String favoriteId) async {
   try {
     _clearError();
     final success = await _shoppingListService.removeFromFavorites(favoriteId);
     
     if (success) {
       _favoriteProducts.removeWhere((product) => product.id == favoriteId);
       notifyListeners();
       return true;
     }
     return false;
   } catch (e) {
     debugPrint('❌ Error eliminando de favoritos: $e');
     _setError('Error al eliminar de favoritos: $e');
     return false;
   }
 }

 // === MÉTODOS DE ITEMS (VERSIONES SEGURAS) ===

 Future<void> addItem(ShoppingItem item) async {
   try {
     _clearError();
     
     // Verificar si ya existe
     final existingIndex = _shoppingItems.indexWhere(
       (existingItem) => existingItem.name.toLowerCase() == item.name.toLowerCase()
     );
     
     if (existingIndex != -1) {
       // Actualizar cantidad si existe - ACTUALIZACIÓN OPTIMISTA
       final existingItem = _shoppingItems[existingIndex];
       final updatedItem = existingItem.copyWith(
         quantity: existingItem.quantity + item.quantity,
       );
       
       // Actualizar inmediatamente en la UI
       _shoppingItems[existingIndex] = updatedItem;
       notifyListeners();
       
       // Actualizar en segundo plano
       await updateCompleteItem(updatedItem);
     } else {
       // Añadir nuevo item - ACTUALIZACIÓN OPTIMISTA
       final newItem = item.copyWith(
         id: DateTime.now().millisecondsSinceEpoch.toString(),
       );
       
       // Añadir inmediatamente a la UI
       _shoppingItems.add(newItem);
       notifyListeners();
       
       // Guardar en segundo plano
       await _shoppingListService.addShoppingItem(newItem);
     }
   } catch (e) {
     debugPrint('❌ Error añadiendo item: $e');
     _setError('Error al añadir producto: $e');
     // En caso de error, recargar datos para sincronizar
     await refreshData();
   }
 }

 Future<bool> updateItem(
   String itemId, {
   String? name,
   int? quantity,
   int? maxQuantity,
   String? unit,
   String? category,
   bool? isPurchased,
   String? imageUrl,
   String? location,
   DateTime? expiryDate,
   int? priority,
   String? notes,
 }) async {
   try {
     _clearError();
     
     final index = _shoppingItems.indexWhere((item) => item.id == itemId);
     if (index == -1) {
       _setError("Producto no encontrado");
       return false;
     }
     
     final currentItem = _shoppingItems[index];
     final updatedItem = currentItem.copyWith(
       name: name,
       quantity: quantity,
       maxQuantity: maxQuantity,
       unit: unit,
       category: category,
       isPurchased: isPurchased,
       imageUrl: imageUrl,
       location: location,
       expiryDate: expiryDate,
       priority: priority,
       notes: notes,
     );
     
     final success = await _shoppingListService.updateShoppingItem(updatedItem);
     
     if (success) {
       // Actualización local inmediata
       _shoppingItems[index] = updatedItem;
       notifyListeners();
     } else {
       _setError('Error al actualizar el producto');
     }
     
     return success;
   } catch (e) {
     debugPrint('❌ Error actualizando item: $e');
     _setError('Error al actualizar: $e');
     return false;
   }
 }

 

 // Add this method after the updateItem method
 Future<bool> toggleItemPurchased(String itemId) async {
   try {
     _clearError();
     
     final index = _shoppingItems.indexWhere((item) => item.id == itemId);
     if (index == -1) {
       _setError("Producto no encontrado");
       return false;
     }
     
     final currentItem = _shoppingItems[index];
     final updatedItem = currentItem.copyWith(
       isPurchased: !currentItem.isPurchased,
     );
     
     final success = await _shoppingListService.updateShoppingItem(updatedItem);
     
     if (success) {
       // Actualización local inmediata
       _shoppingItems[index] = updatedItem;
       notifyListeners();
     } else {
       _setError('Error al actualizar el estado del producto');
     }
     
     return success;
   } catch (e) {
     debugPrint('❌ Error cambiando estado de compra: $e');
     _setError('Error al actualizar: $e');
     return false;
   }
 }

 Future<bool> removeItem(String itemId) async {
   try {
     _clearError();
     
     // Deseleccionar si está seleccionado
     _selectedItemIds.remove(itemId);
     
     final success = await _shoppingListService.removeShoppingItem(itemId);
     
     if (success) {
       // El stream se encargará de la actualización
       return true;
     } else {
       _setError('Error al eliminar producto');
       return false;
     }
   } catch (e) {
     debugPrint('❌ Error eliminando item: $e');
     _setError('Error al eliminar: $e');
     return false;
   }
 }

 Future<void> clearPurchasedItems() async {
   try {
     final purchasedIds = _shoppingItems
         .where((item) => item.isPurchased)
         .map((item) => item.id)
         .toSet();
     
     _selectedItemIds.removeAll(purchasedIds);
     
     await _shoppingListService.clearPurchasedItems();
   } catch (e) {
     _setError('Error al limpiar items comprados: $e');
   }
 }

 // === MÉTODOS DE SELECCIÓN ===

 void toggleItemSelection(String itemId) {
   if (_selectedItemIds.contains(itemId)) {
     _selectedItemIds.remove(itemId);
   } else {
     _selectedItemIds.add(itemId);
   }
   notifyListeners();
 }

 void clearSelection() {
   if (_selectedItemIds.isNotEmpty) {
     _selectedItemIds.clear();
     notifyListeners();
   }
 }

 // === MÉTODOS DE INVENTARIO ===

 Future<bool> addProductFromInventory(Product product) async {
   try {
     await _shoppingListService.addProductFromInventory(product);
     return true;
   } catch (e) {
     _setError('Error al añadir desde inventario: $e');
     return false;
   }
 }

 Future<bool> addItemToInventoryWithLocation(String itemId, String location) async {
   try {
     final item = _shoppingItems.firstWhere(
       (item) => item.id == itemId,
       orElse: () => throw Exception('Item no encontrado'),
     );
     
     final userId = await _shoppingListService.getCurrentUserId();
     
     final product = Product(
       id: DateTime.now().millisecondsSinceEpoch.toString(),
       name: item.name,
       quantity: item.quantity,
       maxQuantity: item.maxQuantity,
       unit: item.unit,
       category: item.category,
       location: location,
       imageUrl: item.imageUrl,
       expiryDate: item.expiryDate ?? DateTime.now().add(const Duration(days: 7)),
       userId: userId,
     );
     
     await _inventoryService.addProduct(product);
     await updateItem(itemId, isPurchased: true);
     
     return true;
   } catch (e) {
     _setError('Error al añadir al inventario: $e');
     return false;
   }
 }

 Future<bool> addSelectedItemsToInventory({required String location}) async {
   if (_selectedItemIds.isEmpty) return false;
   
   try {
     bool anySuccess = false;
     final itemsToProcess = _selectedItemIds.toList();
     
     for (final itemId in itemsToProcess) {
       try {
         final success = await addItemToInventoryWithLocation(itemId, location);
         if (success) {
           anySuccess = true;
           await removeItem(itemId);
         }
       } catch (e) {
         debugPrint('❌ Error procesando item $itemId: $e');
       }
     }
     
     clearSelection();
     return anySuccess;
   } catch (e) {
     _setError('Error al procesar selección: $e');
     return false;
   }
 }

 // === MÉTODOS DE UTILIDAD ===

 bool hasPurchasedItems() {
   return _shoppingItems.any((item) => item.isPurchased);
 }

 void _applySorting() {
   switch (_sortBy) {
     case 'name':
       _shoppingItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
       break;
     case 'category':
       _shoppingItems.sort((a, b) {
         final categoryComparison = a.category.compareTo(b.category);
         return categoryComparison == 0 
           ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
           : categoryComparison;
       });
       break;
     case 'dateAdded':
       _shoppingItems.sort((a, b) => b.id.compareTo(a.id));
       break;
   }
 }

 // === MÉTODOS DE ESTADO PRIVADOS ===

 void _setLoading(bool loading) {
   if (_isLoading != loading) {
     _isLoading = loading;
     notifyListeners();
   }
 }

 void _setFavoritesLoading(bool loading) {
   if (_isFavoritesLoading != loading) {
     _isFavoritesLoading = loading;
     notifyListeners();
   }
 }

 void _setError(String errorMessage) {
   if (_error != errorMessage) {
     _error = errorMessage;
     notifyListeners();
   }
 }

 void _clearError() {
   if (_error.isNotEmpty) {
     _error = '';
     notifyListeners();
   }
 }

 // === MÉTODOS ADICIONALES ===

 Future<void> updateCompleteItem(ShoppingItem item) async {
   await updateItem(
     item.id,
     name: item.name,
     quantity: item.quantity,
     maxQuantity: item.maxQuantity,
     unit: item.unit,
     category: item.category,
     isPurchased: item.isPurchased,
     imageUrl: item.imageUrl,
     location: item.location,
     expiryDate: item.expiryDate,
     priority: item.priority,
     notes: item.notes,
   );
 }

 // Move silentRefresh method inside the class
 Future<void> silentRefresh() async {
   try {
     debugPrint("🔄 Actualización silenciosa iniciada");
     _clearError();
     
     // Cargar datos sin cambiar el estado de loading
     final items = await _shoppingListService.getShoppingItems();
     _shoppingItems = items;
     
     notifyListeners();
     debugPrint("✅ Actualización silenciosa completada");
   } catch (e) {
     debugPrint("❌ Error en actualización silenciosa: $e");
     // Solo mostrar error, no cambiar loading state
     _setError('Error al sincronizar: $e');
   }
 }

 // === CLEANUP ===

 @override
 void dispose() {
   debugPrint('🧹 Limpiando ShoppingListProvider...');
   _shoppingItemsSubscription?.cancel();
   super.dispose();
 }
}