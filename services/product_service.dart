// lib/services/product_service.dart - NUEVO SERVICIO UNIFICADO

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../models/product_location_model.dart';

class ProductService {
  // Singleton
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();
  
  // Referencia al usuario actual
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  
  // Referencia a la colección de productos
  CollectionReference? get _userProducts {
    final userId = _userId;
    if (userId == null) return null;
    return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('products');
  }
  
  // Inicializar el servicio
  Future<void> initialize() async {
    // Esta función se mantiene para compatibilidad con código existente
  }
  
  // Obtener todos los productos
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
          ...data,
        });
      }).toList();
    } catch (e) {
      print('Error al obtener productos: $e');
      return [];
    }
  }
  
  // Obtener productos del inventario
  Future<List<Product>> getInventoryProducts() async {
    try {
      final allProducts = await getAllProducts();
      return allProducts.where((p) => 
        p.productLocation == ProductLocation.inventory || 
        p.productLocation == ProductLocation.both
      ).toList();
    } catch (e) {
      print('Error al obtener productos del inventario: $e');
      return [];
    }
  }
  
  // Obtener productos de la lista de compras
  Future<List<Product>> getShoppingListProducts() async {
    try {
      final allProducts = await getAllProducts();
      return allProducts.where((p) => 
        p.productLocation == ProductLocation.shoppingList || 
        p.productLocation == ProductLocation.both
      ).toList();
    } catch (e) {
      print('Error al obtener productos de la lista de compras: $e');
      return [];
    }
  }
  
  // Añadir un nuevo producto
  Future<String?> addProduct(Product product) async {
    try {
      final userId = _userId;
      if (userId == null) return null;
      
      if (_userProducts == null) return null;
      
      // Crear un mapa del producto
      final productMap = product.toMap();
      
      // Añadir a Firestore
      final docRef = await _userProducts!.add(productMap);
      
      print('Producto añadido con ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error al añadir producto: $e');
      return null;
    }
  }
  
  // Actualizar un producto existente
  Future<bool> updateProduct(Product product) async {
    try {
      if (_userProducts == null) return false;
      
      // Actualizar en Firestore
      await _userProducts!.doc(product.id).update(product.toMap());
      return true;
    } catch (e) {
      print('Error al actualizar producto: $e');
      return false;
    }
  }
  
  // Eliminar un producto
  Future<bool> deleteProduct(String productId) async {
    try {
      if (_userProducts == null) return false;
      
      await _userProducts!.doc(productId).delete();
      return true;
    } catch (e) {
      print('Error al eliminar producto: $e');
      return false;
    }
  }
  
  // Mover un producto de la lista de compras al inventario
  Future<bool> moveToInventory(String productId, String location) async {
    try {
      if (_userProducts == null) return false;
      
      // Obtener el producto actual
      final docSnapshot = await _userProducts!.doc(productId).get();
      if (!docSnapshot.exists) return false;
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      final product = Product.fromMap({
        'id': productId,
        ...data,
      });
      
      // Actualizar la ubicación del producto y su ubicación física
      final updatedProduct = product.copyWith(
        productLocation: ProductLocation.inventory,
        location: location,
        isPurchased: true,
      );
      
      // Guardar cambios
      await _userProducts!.doc(productId).update(updatedProduct.toMap());
      return true;
    } catch (e) {
      print('Error al mover producto al inventario: $e');
      return false;
    }
  }
  
  // Stream para obtener actualizaciones en tiempo real
  Stream<List<Product>> getProductsStream({ProductLocation? filterLocation}) {
    try {
      if (_userProducts == null) return Stream.value([]);
      
      return _userProducts!.snapshots().map((snapshot) {
        final products = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Product.fromMap({
            'id': doc.id,
            ...data,
          });
        }).toList();
        
        // Filtrar por ubicación si se especifica
        if (filterLocation != null) {
          return products.where((p) => 
            p.productLocation == filterLocation || 
            p.productLocation == ProductLocation.both
          ).toList();
        }
        
        return products;
      });
    } catch (e) {
      print('Error al obtener stream de productos: $e');
      return Stream.value([]);
    }
  }
  
  // Obtener productos por ubicación
  Future<List<Product>> getProductsByLocation(String location) async {
    try {
      final allProducts = await getInventoryProducts();
      return allProducts.where((p) => p.location == location).toList();
    } catch (e) {
      print('Error al obtener productos por ubicación: $e');
      return [];
    }
  }
  
  // Obtener productos próximos a caducar
  Future<List<Product>> getExpiringProducts(int days) async {
    try {
      // Obtener productos del inventario
      final products = await getInventoryProducts();
      
      // Filtrar productos que caducan en los próximos 'days' días
      final now = DateTime.now();
      final limit = now.add(Duration(days: days));
      
      return products.where((product) {
        if (product.expiryDate == null) return false;
        return product.expiryDate!.isAfter(now) && product.expiryDate!.isBefore(limit);
      }).toList();
    } catch (e) {
      print('Error al obtener productos por caducar: $e');
      return [];
    }
  }
  
  // Obtener productos caducados
  Future<List<Product>> getExpiredProducts() async {
    try {
      // Obtener productos del inventario
      final products = await getInventoryProducts();
      
      // Filtrar productos caducados
      final now = DateTime.now();
      
      return products.where((product) {
        if (product.expiryDate == null) return false;
        return product.expiryDate!.isBefore(now);
      }).toList();
    } catch (e) {
      print('Error al obtener productos caducados: $e');
      return [];
    }
  }
  
  // Actualizar cantidad de un producto
  Future<bool> updateProductQuantity(String id, int newQuantity, {int? maxQuantity}) async {
    try {
      if (_userProducts == null) return false;
      
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
      return true;
    } catch (e) {
      print('Error al actualizar cantidad: $e');
      return false;
    }
  }
  
  // Buscar productos
  Future<List<Product>> searchProducts(String query, {ProductLocation? filterLocation}) async {
    try {
      // Obtener todos los productos o filtrados por ubicación
      final List<Product> baseProducts;
      if (filterLocation != null) {
        if (filterLocation == ProductLocation.inventory) {
          baseProducts = await getInventoryProducts();
        } else {
          baseProducts = await getShoppingListProducts();
        }
      } else {
        baseProducts = await getAllProducts();
      }
      
      // Filtrar por nombre o categoría
      final normalizedQuery = query.toLowerCase();
      
      return baseProducts.where((product) {
        return product.name.toLowerCase().contains(normalizedQuery) ||
               product.category.toLowerCase().contains(normalizedQuery);
      }).toList();
    } catch (e) {
      print('Error en la búsqueda: $e');
      return [];
    }
  }
  
  // Añadir a ProductService en lugar de crear una nueva clase
Future<void> migrateExistingData() async {
  try {
    final userId = _userId;
    if (userId == null) return;
    
    final firestore = FirebaseFirestore.instance;
    
    // Referencia a las colecciones antiguas
    final oldInventoryRef = firestore.collection('users').doc(userId).collection('products');
    final oldShoppingListRef = firestore.collection('users').doc(userId).collection('shoppingList');
    
    // Verificar si ya existen productos con el nuevo modelo
    final existingProducts = await _userProducts?.where('productLocation', isNull: false).get();
    if (existingProducts != null && existingProducts.docs.isNotEmpty) {
      // Ya hay datos migrados, no hacer nada
      print('Los datos ya han sido migrados');
      return;
    }
    
    // 1. Migrar inventario
    final inventorySnapshot = await oldInventoryRef.get();
    for (final doc in inventorySnapshot.docs) {
      final data = doc.data();
      
      // Añadir campo de ubicación
      data['productLocation'] = ProductLocation.inventory.toString();
      data['userId'] = userId;
      
      // Crear documento en la colección products
      await _userProducts?.add(data);
    }
    
    // 2. Migrar lista de compras
    final shoppingListSnapshot = await oldShoppingListRef.get();
    for (final doc in shoppingListSnapshot.docs) {
      final data = doc.data();
      
      // Añadir campo de ubicación
      data['productLocation'] = ProductLocation.shoppingList.toString();
      data['userId'] = userId;
      
      // Crear documento en la colección products
      await _userProducts?.add(data);
    }
    
    print('Migración completada con éxito');
  } catch (e) {
    print('Error durante la migración: $e');
  }
}

  
  
  // Obtener productos recientes
  Future<List<Product>> getRecentProducts(int limit) async {
    try {
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
          ...data,
        });
      }).toList();
    } catch (e) {
      print('Error al obtener productos recientes: $e');
      return [];
    }
  }
}