// lib/tools/db_migration.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_location_model.dart';
import '../services/inventory_service.dart';

class DBMigration {
  // Singleton para acceso global
  static final DBMigration _instance = DBMigration._internal();
  factory DBMigration() => _instance;
  DBMigration._internal();
  
  // Variable para rastrear si la migración ya se ejecutó
  bool _migrationRun = false;
  
  // Referencia a Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Referencia al servicio de inventario
  final InventoryService _inventoryService = InventoryService();
  
  // Método para ejecutar todas las migraciones necesarias
  Future<void> runMigrations() async {
    if (_migrationRun) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    print('Iniciando migraciones de base de datos...');
    
    // 1. Migrar campo productLocation a productos existentes
    await migrateProductLocation(user.uid);
    
    // 2. Establecer productLocation a shoppingList para items de compra
    await migrateShoppingListItems(user.uid);
    
    _migrationRun = true;
    print('Migraciones completadas con éxito');
  }
  
  // Migrar campo productLocation a productos existentes
  Future<void> migrateProductLocation(String userId) async {
    try {
      print('Migrando campo productLocation en productos...');
      
      // Referencia a la colección de productos
      final productsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('products');
      
      // Obtener todos los productos
      final querySnapshot = await productsRef.get();
      
      // Contador para productos actualizados
      int updatedCount = 0;
      
      // Para cada producto, añadir campo productLocation si no existe
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Verificar si ya tiene el campo productLocation
        if (!data.containsKey('productLocation')) {
          // Añadir el campo productLocation con el valor por defecto
          await doc.reference.update({
            'productLocation': ProductLocation.inventory.toString()
          });
          updatedCount++;
        }
      }
      
      print('Campo productLocation actualizado en $updatedCount productos');
    } catch (e) {
      print('Error en migración de productLocation: $e');
    }
  }
  
  // Migrar items de la lista de compras para que tengan productLocation
  Future<void> migrateShoppingListItems(String userId) async {
    try {
      print('Migrando items de lista de compras...');
      
      // Referencia a la colección de lista de compras
      final shoppingListRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('shoppingList');
      
      // Referencia a la colección de productos
      final productsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('products');
      
      // Obtener todos los items de compra
      final querySnapshot = await shoppingListRef.get();
      
      // Contador para items procesados
      int processedCount = 0;
      
      // Para cada item de compra, verificar si ya existe en productos
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final itemName = data['name'] as String? ?? '';
        
        if (itemName.isEmpty) continue;
        
        // Buscar un producto con el mismo nombre
        final matchingProductsQuery = await productsRef
            .where('name', isEqualTo: itemName)
            .limit(1)
            .get();
        
        if (matchingProductsQuery.docs.isNotEmpty) {
          // Si existe, actualizar su productLocation a both
          final productDoc = matchingProductsQuery.docs.first;
          
          await productDoc.reference.update({
            'productLocation': ProductLocation.both.toString()
          });
          
          print('Actualizado producto "$itemName" a estado both');
        } else {
          // Si no existe, crear un nuevo producto con los datos del item de compra
          final newProductData = {
            'name': itemName,
            'quantity': data['quantity'] ?? 1,
            'unit': data['unit'] ?? '',
            'category': data['category'] ?? '',
            'location': data['location'] ?? 'Despensa',
            'imageUrl': data['imageUrl'] ?? '',
            'barcode': '',
            'notes': '',
            'isFavorite': false,
            'productLocation': ProductLocation.shoppingList.toString(),
            'userId': userId,
            'lastUpdated': FieldValue.serverTimestamp(),
          };
          
          // Si hay fecha de caducidad, añadirla
          if (data.containsKey('expiryDate') && data['expiryDate'] != null) {
            newProductData['expiryDate'] = data['expiryDate'];
          }
          
          await productsRef.add(newProductData);
          print('Creado nuevo producto para "$itemName" con estado shoppingList');
        }
        
        processedCount++;
      }
      
      print('Procesados $processedCount items de lista de compras');
    } catch (e) {
      print('Error en migración de lista de compras: $e');
    }
  }
  
  // Método para verificar y migrar la estructura de la base de datos
  Future<void> checkAndMigrateDBSchema() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Llamar al método del servicio de inventario para migrar productos
      await _inventoryService.migrateExistingProductsAddProductLocation();
      
      print('Esquema de base de datos verificado y actualizado');
    } catch (e) {
      print('Error al verificar esquema de DB: $e');
    }
  }
}