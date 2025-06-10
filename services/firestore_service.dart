// lib/services/firestore_service.dart - Actualizado con compatibilidad

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  // Singleton para acceso global al servicio
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();
  
  // Instancia de Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Getter para acceder a Firestore
  FirebaseFirestore get firestore => _firestore;
  
  // Usuario actual
  String? get userId => FirebaseAuth.instance.currentUser?.uid;
  
  // Referencias a colecciones comunes - Mantenidas para compatibilidad
  CollectionReference get users => _firestore.collection('users');
  CollectionReference get products => _firestore.collection('products');
  CollectionReference get recipes => _firestore.collection('recipes');
  CollectionReference get mealPlans => _firestore.collection('meal_plans');
  
  // Método para obtener productos de un usuario específico
  CollectionReference getUserProducts(String userId) {
    return users.doc(userId).collection('products');
  }
  
  // Método para obtener la lista de compra de un usuario específico
  CollectionReference getUserShoppingList(String userId) {
    return users.doc(userId).collection('shopping_list');
  }
  
  // Método para obtener el plan de comidas de un usuario específico
  CollectionReference getUserMealPlans([String? uid]) {
    final userId = uid ?? this.userId;
    if (userId == null) return mealPlans; // Fallback a colección global
    return users.doc(userId).collection('mealPlans');
  }
  
  // NUEVOS MÉTODOS para las recetas del usuario
  CollectionReference? getUserRecipes([String? uid]) {
    final userId = uid ?? this.userId;
    if (userId == null) return null;
    return users.doc(userId).collection('recipes');
  }
  
  // Para recetas favoritas del usuario
  CollectionReference? getUserFavoriteRecipes([String? uid]) {
    final userId = uid ?? this.userId;
    if (userId == null) return null;
    return users.doc(userId).collection('favorite_recipes');
  }
  
  // Para recetas personalizadas del usuario (para compatibilidad con versiones anteriores)
  CollectionReference? getUserCustomRecipes([String? uid]) {
    final userId = uid ?? this.userId;
    if (userId == null) return null;
    return users.doc(userId).collection('custom_recipes');
  }
  
  // Método para verificar si una colección existe para un usuario
  Future<bool> collectionExists(String collectionPath, [String? uid]) async {
    final userId = uid ?? this.userId;
    if (userId == null) return false;

    final path = 'users/$userId/$collectionPath';
    
    try {
      final snapshot = await _firestore.collection(path).limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error al verificar colección $path: $e');
      return false;
    }
  }

  // Método auxiliar para crear colecciones necesarias si no existen
  Future<void> ensureUserCollectionsExist([String? uid]) async {
    final userId = uid ?? this.userId;
    if (userId == null) return;

    // Lista de colecciones que cada usuario debería tener
    final requiredCollections = [
      'recipes',
      'mealPlans',
      'favorite_recipes',
      'products',
      'shopping_list',
    ];

    // Verificar y crear documento de usuario si no existe
    final userDoc = users.doc(userId);
    final userSnapshot = await userDoc.get();
    
    if (!userSnapshot.exists) {
      await userDoc.set({
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
    }

    // No es necesario crear colecciones explícitamente en Firestore,
    // pues se crean automáticamente al añadir documentos.
    // Este método se mantiene para posibles validaciones futuras.
  }
  
  // Método genérico para agregar un documento - Mantenido para compatibilidad
  Future<DocumentReference> addDocument(
    CollectionReference collection, 
    Map<String, dynamic> data
  ) async {
    return await collection.add(data);
  }
  
  // Método genérico para actualizar un documento - Mantenido para compatibilidad
  Future<void> updateDocument(
    DocumentReference document, 
    Map<String, dynamic> data
  ) async {
    await document.update(data);
  }
  
  // Método genérico para eliminar un documento - Mantenido para compatibilidad
  Future<void> deleteDocument(DocumentReference document) async {
    await document.delete();
  }
  
  // Método genérico para obtener un documento por ID - Mantenido para compatibilidad
  Future<DocumentSnapshot> getDocument(
    CollectionReference collection, 
    String documentId
  ) async {
    return await collection.doc(documentId).get();
  }
  
  // Método genérico para obtener una colección completa - Mantenido para compatibilidad
  Future<QuerySnapshot> getCollection(CollectionReference collection) async {
    return await collection.get();
  }
  
  // Método para obtener documentos con una condición - Mantenido para compatibilidad
  Future<QuerySnapshot> getDocumentsWhere(
    CollectionReference collection,
    String field,
    dynamic value
  ) async {
    return await collection.where(field, isEqualTo: value).get();
  }
  
  // Método para realizar transacciones
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionFunction
  ) {
    return _firestore.runTransaction(transactionFunction);
  }
}