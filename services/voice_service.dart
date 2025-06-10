// lib/services/storage_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio para gestionar el almacenamiento de archivos (imágenes, etc.)
class StorageService {
  // Singleton para acceso global al servicio
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
  
  // Instancia de Firebase Storage
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Referencia al usuario actual
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  
  /// Método para subir una imagen de producto a Firebase Storage
  Future<String?> uploadProductImage(File imageFile, String productId) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Crear una referencia en Firebase Storage
      final fileName = 'product_${productId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final storageRef = _storage.ref().child('users/$userId/products/$fileName');
      
      // Subir el archivo
      final uploadTask = storageRef.putFile(imageFile);
      
      // Esperar a que termine la subida
      final snapshot = await uploadTask.whenComplete(() => null);
      
      // Obtener la URL de descarga
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error al subir imagen: $e');
      }
      return null;
    }
  }
  
  /// Método para eliminar una imagen de producto
  Future<bool> deleteProductImage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) {
        return true;
      }
      
      // Obtener referencia desde la URL
      final ref = _storage.refFromURL(imageUrl);
      
      // Eliminar la imagen
      await ref.delete();
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error al eliminar imagen: $e');
      }
      return false;
    }
  }
  
  /// Método para obtener todas las imágenes de productos de un usuario
  Future<List<String>> getUserProductImages() async {
    try {
      final userId = _userId;
      if (userId == null) {
        return [];
      }
      
      // Obtener todas las referencias de imágenes
      final result = await _storage.ref().child('users/$userId/products').listAll();
      
      // Obtener las URLs de descarga
      final urls = <String>[];
      for (var item in result.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
      }
      
      return urls;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener imágenes: $e');
      }
      return [];
    }
  }
  
  /// Método para guardar una imagen de categoría personalizada
  Future<String?> uploadCategoryImage(File imageFile, String categoryName) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Normalizar el nombre de la categoría
      final normalizedName = categoryName.toLowerCase().replaceAll(' ', '_');
      
      // Crear una referencia en Firebase Storage
      final fileName = 'category_${normalizedName}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final storageRef = _storage.ref().child('users/$userId/categories/$fileName');
      
      // Subir el archivo
      final uploadTask = storageRef.putFile(imageFile);
      
      // Esperar a que termine la subida
      final snapshot = await uploadTask.whenComplete(() => null);
      
      // Obtener la URL de descarga
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error al subir imagen de categoría: $e');
      }
      return null;
    }
  }
  
  /// Método para guardar una imagen de ubicación personalizada
  Future<String?> uploadLocationImage(File imageFile, String locationName) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Normalizar el nombre de la ubicación
      final normalizedName = locationName.toLowerCase().replaceAll(' ', '_');
      
      // Crear una referencia en Firebase Storage
      final fileName = 'location_${normalizedName}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final storageRef = _storage.ref().child('users/$userId/locations/$fileName');
      
      // Subir el archivo
      final uploadTask = storageRef.putFile(imageFile);
      
      // Esperar a que termine la subida
      final snapshot = await uploadTask.whenComplete(() => null);
      
      // Obtener la URL de descarga
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error al subir imagen de ubicación: $e');
      }
      return null;
    }
  }
  
  /// Método para guardar una imagen de perfil de usuario
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Crear una referencia en Firebase Storage
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final storageRef = _storage.ref().child('users/$userId/profile/$fileName');
      
      // Subir el archivo
      final uploadTask = storageRef.putFile(imageFile);
      
      // Esperar a que termine la subida
      final snapshot = await uploadTask.whenComplete(() => null);
      
      // Obtener la URL de descarga
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error al subir imagen de perfil: $e');
      }
      return null;
    }
  }
  
  /// Método para eliminar todas las imágenes asociadas a un producto
Future<void> deleteAllProductImages(String productId) async {
  try {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    
    // Obtener todas las imágenes asociadas al producto
    // Utilizando el método correcto de listAll() sin parámetros de prefijo
    final result = await _storage.ref().child('users/$userId/products').listAll();
    
    // Filtrar los elementos que contienen el ID del producto
    final itemsToDelete = result.items.where(
      (item) => item.name.contains('product_$productId')
    );
    
    // Eliminar cada imagen filtrada
    for (var item in itemsToDelete) {
      await item.delete();
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error al eliminar imágenes del producto: $e');
    }
  }
}
  
  /// Método para limpiar el almacenamiento de un usuario (eliminar todas sus imágenes)
  Future<bool> clearUserStorage() async {
    try {
      final userId = _userId;
      if (userId == null) {
        return false;
      }
      
      // Obtener todas las referencias
      final result = await _storage.ref().child('users/$userId').listAll();
      
      // Eliminar cada elemento
      for (var item in result.items) {
        await item.delete();
      }
      
      // Eliminar subdirectorios recursivamente
      for (var prefix in result.prefixes) {
        await _deleteStorageFolder(prefix);
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error al limpiar almacenamiento: $e');
      }
      return false;
    }
  }
  
  /// Método auxiliar para eliminar una carpeta recursivamente
  Future<void> _deleteStorageFolder(Reference folderRef) async {
    // Obtener todas las referencias dentro de la carpeta
    final result = await folderRef.listAll();
    
    // Eliminar cada elemento
    for (var item in result.items) {
      await item.delete();
    }
    
    // Eliminar subdirectorios recursivamente
    for (var prefix in result.prefixes) {
      await _deleteStorageFolder(prefix);
    }
  }
}