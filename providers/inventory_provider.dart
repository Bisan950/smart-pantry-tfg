// lib/providers/inventory_provider.dart - Corregido

import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/inventory_service.dart';

/// Provider para gestionar el estado del inventario en toda la aplicación
class InventoryProvider with ChangeNotifier {
  final InventoryService inventoryService = InventoryService();
  
  // Estado interno
  List<Product> _allProducts = [];
  List<Product> _fridgeProducts = [];
  List<Product> _pantryProducts = [];
  List<Product> _expiringProducts = [];
  List<Product> _expiredProducts = [];
  bool _isLoading = true;
  String _error = '';
  
  // Getters
  List<Product> get allProducts => _allProducts;
  List<Product> get fridgeProducts => _fridgeProducts;
  List<Product> get pantryProducts => _pantryProducts;
  List<Product> get expiringProducts => _expiringProducts;
  List<Product> get expiredProducts => _expiredProducts;
  bool get isLoading => _isLoading;
  String get error => _error;
  
  // Constructor
  InventoryProvider() {
    _initialize();
  }
  
  // Inicialización
  Future<void> _initialize() async {
    try {
      _setLoading(true);
      await inventoryService.initialize();
      
      // Suscribirse al stream de productos para actualizaciones en tiempo real
      inventoryService.getProductsStream().listen((products) {
        _allProducts = products;
        _fridgeProducts = products.where((p) => p.location == 'Nevera').toList();
        _pantryProducts = products.where((p) => p.location == 'Despensa').toList();
        
        // Actualizar productos por caducar
        final now = DateTime.now();
        final expiryThreshold = now.add(const Duration(days: 7));
        
        _expiringProducts = products.where((product) {
          if (product.expiryDate == null) return false;
          return product.expiryDate!.isAfter(now) && 
                 product.expiryDate!.isBefore(expiryThreshold);
        }).toList();
        
        // Actualizar productos caducados
        _expiredProducts = products.where((product) {
          if (product.expiryDate == null) return false;
          return product.expiryDate!.isBefore(now);
        }).toList();
        
        _setLoading(false);
        notifyListeners();
      }, onError: (e) {
        _setError('Error en stream de productos: $e');
      });
      
      // Realizar una carga inicial para no depender solo del stream
      await _refreshAllData();
      
      // Migrar datos de ejemplo solo si es necesario
      await inventoryService.migrateExampleDataToFirestore();
      
    } catch (e) {
      _setError('Error al inicializar: $e');
    }
  }
  
  // Refrescar todos los datos de forma manual
  Future<void> _refreshAllData() async {
    try {
      _allProducts = await inventoryService.getAllProducts();
      _fridgeProducts = await inventoryService.getProductsByLocation('Nevera');
      _pantryProducts = await inventoryService.getProductsByLocation('Despensa');
      _expiringProducts = await inventoryService.getExpiringProducts(7);
      _expiredProducts = await inventoryService.getExpiredProducts();
      notifyListeners();
    } catch (e) {
      _setError('Error al actualizar datos: $e');
    }
  }

  // Unir productos duplicados
Future<void> mergeDuplicateProducts() async {
  try {
    _setLoading(true);
    await inventoryService.mergeDuplicateProducts();
    await _refreshAllData();
  } catch (e) {
    _setError('Error al unir productos: $e');
  }
}

// Obtener productos duplicados
Future<Map<String, List<Product>>> getProductsThatCanBeMerged() async {
  try {
    return await inventoryService.getProductsThatCanBeMerged();
  } catch (e) {
    _setError('Error al obtener productos duplicados: $e');
    return {};
  }
}
  
  // Métodos para modificar el inventario
  
  // Añadir producto
  Future<void> addProduct(Product product) async {
    try {
      await inventoryService.addProduct(product);
      await _refreshAllData();
    } catch (e) {
      _setError('Error al añadir producto: $e');
    }
  }
  
  // Actualizar producto
  Future<void> updateProduct(Product product) async {
    try {
      await inventoryService.updateProduct(product);
      await _refreshAllData();
    } catch (e) {
      _setError('Error al actualizar producto: $e');
    }
  }
  
  // Eliminar producto
  Future<void> deleteProduct(String productId) async {
    try {
      await inventoryService.deleteProduct(productId);
      await _refreshAllData();
    } catch (e) {
      _setError('Error al eliminar producto: $e');
    }
  }
  
  // Actualizar cantidad de producto - MODIFICADO: ahora usa int en lugar de double
  Future<void> updateProductQuantity(String productId, int newQuantity, {int? maxQuantity}) async {
    try {
      await inventoryService.updateProductQuantity(productId, newQuantity, maxQuantity: maxQuantity);
      await _refreshAllData();
    } catch (e) {
      _setError('Error al actualizar cantidad: $e');
    }
  }
  
  // Buscar productos
  Future<List<Product>> searchProducts(String query) async {
    try {
      return await inventoryService.searchProducts(query);
    } catch (e) {
      _setError('Error en la búsqueda: $e');
      return [];
    }
  }
  
  // Filtrar productos por categoría
  List<Product> filterByCategory(String category, {String? location}) {
    if (category == 'todos') {
      return location == null 
          ? _allProducts 
          : _allProducts.where((p) => p.location == location).toList();
    }
    
    return _allProducts.where((product) => 
      product.category == category && 
      (location == null || product.location == location)
    ).toList();
  }
  
  // Obtener productos por caducar dentro de N días
  Future<List<Product>> getProductsExpiringWithinDays(int days) async {
    try {
      return await inventoryService.getExpiringProducts(days);
    } catch (e) {
      _setError('Error al obtener productos por caducar: $e');
      return [];
    }
  }
  
  // Obtener estadísticas del inventario
  Map<String, dynamic> getInventoryStats() {
    final totalItems = _allProducts.length;
    final fridgeItems = _fridgeProducts.length;
    final pantryItems = _pantryProducts.length;
    final expiringItems = _expiringProducts.length;
    final expiredItems = _expiredProducts.length;
    
    // Categorías más populares
    final categoryCount = <String, int>{};
    for (final product in _allProducts) {
      categoryCount[product.category] = (categoryCount[product.category] ?? 0) + 1;
    }
    
    // Ordenar categorías por cantidad
    final sortedCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return {
      'totalItems': totalItems,
      'fridgeItems': fridgeItems,
      'pantryItems': pantryItems,
      'expiringItems': expiringItems,
      'expiredItems': expiredItems,
      'topCategories': sortedCategories.take(3).map((e) => {'name': e.key, 'count': e.value}).toList(),
    };
  }
  
  // Stream para obtener estadísticas en tiempo real
  Stream<Map<String, dynamic>> getInventoryStatsStream() {
    return inventoryService.getInventoryStatsStream();
  }
  
  // Control de estado
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String errorMessage) {
    _error = errorMessage;
    _isLoading = false;
    notifyListeners();
  }
  
  // Limpiar errores
  void clearError() {
    _error = '';
    notifyListeners();
  }
  
  // Refrescar datos manualmente
  Future<void> refreshData() async {
    _setLoading(true);
    await _refreshAllData();
    _setLoading(false);
  }
}