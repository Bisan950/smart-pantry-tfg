// lib/providers/product_provider.dart

import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../models/product_location_model.dart';

class ProductProvider with ChangeNotifier {
  final ProductService _productService = ProductService();
  
  // Estado
  List<Product> _allProducts = [];
  List<Product> _inventoryProducts = [];
  List<Product> _shoppingListProducts = [];
  bool _isLoading = true;
  String _error = '';
  
  // Selección
  final Set<String> _selectedItemIds = {};
  
  // Getters
  List<Product> get allProducts => _allProducts;
  List<Product> get inventoryProducts => _inventoryProducts;
  List<Product> get shoppingListProducts => _shoppingListProducts;
  bool get isLoading => _isLoading;
  String get error => _error;
  Set<String> get selectedItemIds => _selectedItemIds;
  bool get hasSelection => _selectedItemIds.isNotEmpty;
  
  // Constructor
  ProductProvider() {
    _initialize();
  }
  
  // Inicialización
  Future<void> _initialize() async {
    try {
      _setLoading(true);
      
      // Suscribirse a cambios en productos
      _productService.getProductsStream().listen((products) {
        _allProducts = products;
        _inventoryProducts = products.where((p) =>
          p.productLocation == ProductLocation.inventory ||
          p.productLocation == ProductLocation.both
        ).toList();
        _shoppingListProducts = products.where((p) =>
          p.productLocation == ProductLocation.shoppingList ||
          p.productLocation == ProductLocation.both
        ).toList();
        
        // Limpiar IDs seleccionados que ya no existen
        _selectedItemIds.removeWhere(
          (id) => !_allProducts.any((product) => product.id == id)
        );
        
        _setLoading(false);
        notifyListeners();
      }, onError: (e) {
        _setError('Error en stream de productos: $e');
      });
      
    } catch (e) {
      _setError('Error al inicializar: $e');
    }
  }
  
  // Añadir producto
  Future<String?> addProduct(Product product) async {
    try {
      return await _productService.addProduct(product);
    } catch (e) {
      _setError('Error al añadir producto: $e');
      return null;
    }
  }
  
  // Actualizar producto
  Future<bool> updateProduct(Product product) async {
    try {
      return await _productService.updateProduct(product);
    } catch (e) {
      _setError('Error al actualizar producto: $e');
      return false;
    }
  }
  
  // Eliminar producto
  Future<bool> deleteProduct(String productId) async {
    try {
      return await _productService.deleteProduct(productId);
    } catch (e) {
      _setError('Error al eliminar producto: $e');
      return false;
    }
  }
  
  // Corregir el método moveToInventory para incluir el location
Future<bool> moveToInventory(String productId, String location) async {
  try {
    // Asegurarnos de que se pasan los dos argumentos requeridos
    return await _productService.moveToInventory(productId, location);
  } catch (e) {
    _setError('Error al mover producto al inventario: $e');
    return false;
  }
}
  
  // Selección
  void toggleItemSelection(String itemId) {
    if (_selectedItemIds.contains(itemId)) {
      _selectedItemIds.remove(itemId);
    } else {
      _selectedItemIds.add(itemId);
    }
    notifyListeners();
  }
  
  void clearSelection() {
    _selectedItemIds.clear();
    notifyListeners();
  }
  
  // Estado
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String errorMessage) {
    _error = errorMessage;
    _isLoading = false;
    notifyListeners();
  }
  
  void clearError() {
    _error = '';
    notifyListeners();
  }
  
  // Refrescar datos
  Future<void> refreshData() async {
    try {
      _setLoading(true);
      
      _allProducts = await _productService.getAllProducts();
      _inventoryProducts = await _productService.getInventoryProducts();
      _shoppingListProducts = await _productService.getShoppingListProducts();
      
      _setLoading(false);
    } catch (e) {
      _setError('Error al refrescar datos: $e');
    }
  }
}