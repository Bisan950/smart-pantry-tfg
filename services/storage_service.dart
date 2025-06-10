// lib/services/storage_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:path/path.dart' as path;

/// Servicio para gestionar el almacenamiento de archivos (imágenes, etc.)
class StorageService {
  // Singleton para acceso global al servicio
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal() {
    _initializeCloudinary();
  }
  
  // Cloudinary client con tus credenciales
  late CloudinaryPublic cloudinary;
  
  void _initializeCloudinary() {
    cloudinary = CloudinaryPublic(
      'dnvg0ldby',    // Tu cloud name
      'SmartPantry',   // Tu upload preset
    );
    
    if (kDebugMode) {
      print('Cloudinary inicializado con cloud name: SmartPantry');
    }
  }

  // Método para subir una imagen de receta a Cloudinary
Future<String?> uploadRecipeImage(File imageFile, String recipeId) async {
  try {
    final userId = _userId;
    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }
    
    // Crear un identificador único para la imagen
    final fileName = 'recipe_${recipeId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
    
    if (kDebugMode) {
      print('Intentando subir imagen de receta a Cloudinary: $fileName');
    }
    
    // Subir la imagen a Cloudinary
    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        imageFile.path,
        folder: 'smart_pantry/users/$userId/recipes', // Organizar por usuario y tipo
        publicId: fileName,               // Nombre del archivo
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    
    if (kDebugMode) {
      print('Imagen de receta subida exitosamente: ${response.secureUrl}');
    }
    
    // Retornar la URL segura de la imagen
    return response.secureUrl;
  } catch (e) {
    if (kDebugMode) {
      print('Error al subir imagen de receta a Cloudinary: $e');
    }
    return null;
  }
}

// Método para eliminar una imagen de receta
Future<bool> deleteRecipeImage(String imageUrl) async {
  try {
    if (imageUrl.isEmpty || !imageUrl.contains('cloudinary.com')) {
      return true;
    }
    
    // Nota: La eliminación de imágenes en Cloudinary requiere la API firmada
    // que no está disponible en la versión gratuita de cloudinary_public
    // Para implementar borrado, necesitaríamos un backend o usar cloudinary_sdk
    
    if (kDebugMode) {
      print('Nota: La imagen seguirá en Cloudinary, pero se desvinculará de la receta');
    }
    
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('Error al eliminar imagen de receta: $e');
    }
    return false;
  }
}
  
  // Referencia al usuario actual
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  
  /// Método para subir una imagen de producto a Cloudinary
  Future<String?> uploadProductImage(File imageFile, String productId) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Crear un identificador único para la imagen
      final fileName = 'product_${productId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      
      if (kDebugMode) {
        print('Intentando subir imagen a Cloudinary: $fileName');
      }
      
      // Subir la imagen a Cloudinary
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'smart_pantry/users/$userId/products', // Organizar por usuario y tipo
          publicId: fileName,               // Nombre del archivo
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      
      if (kDebugMode) {
        print('Imagen subida exitosamente: ${response.secureUrl}');
      }
      
      // Retornar la URL segura de la imagen
      return response.secureUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error al subir imagen a Cloudinary: $e');
      }
      return null;
    }
  }
  
  /// Método para eliminar una imagen de producto
  Future<bool> deleteProductImage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty || !imageUrl.contains('cloudinary.com')) {
        return true;
      }
      
      // Nota: La eliminación de imágenes en Cloudinary requiere la API firmada
      // que no está disponible en la versión gratuita de cloudinary_public
      // Para implementar borrado, necesitaríamos un backend o usar cloudinary_sdk
      
      if (kDebugMode) {
        print('Nota: La imagen seguirá en Cloudinary, pero se desvinculará del producto');
      }
      
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
    // Nota: Cloudinary Public no ofrece listado de recursos
    // Esto requeriría usar la API Admin de Cloudinary
    return [];
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
      final fileName = 'category_${normalizedName}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Subir la imagen a Cloudinary
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'smart_pantry/users/$userId/categories',
          publicId: fileName,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      
      return response.secureUrl;
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
      final fileName = 'location_${normalizedName}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Subir la imagen a Cloudinary
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'smart_pantry/users/$userId/locations',
          publicId: fileName,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      
      return response.secureUrl;
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
      
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}';
      
      // Subir la imagen a Cloudinary
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'smart_pantry/users/$userId/profile',
          publicId: fileName,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      
      return response.secureUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error al subir imagen de perfil: $e');
      }
      return null;
    }
  }
  
  // Método para eliminar imágenes asociadas a un producto
  Future<void> deleteAllProductImages(String productId) async {
    // Nota: Requeriría la API Admin de Cloudinary
    if (kDebugMode) {
      print('Nota: Las imágenes seguirán en Cloudinary, pero se desvincularán del producto');
    }
  }
  
  /// Método para limpiar el almacenamiento de un usuario
  Future<bool> clearUserStorage() async {
    // Nota: Requeriría la API Admin de Cloudinary
    if (kDebugMode) {
      print('Nota: Función no disponible con Cloudinary Public');
    }
    return true;
  }
}