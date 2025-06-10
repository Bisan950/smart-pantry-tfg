// lib/models/user_model.dart - VERSIÓN ACTUALIZADA con soporte para avatares

import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para representar un usuario en la aplicación SmartPantry
/// 
/// Incluye información básica del usuario y sus preferencias,
/// con métodos para conversión a/desde formato de base de datos
/// ACTUALIZADO: Ahora incluye mejor soporte para avatares
class UserModel {
  final String id;
  final String email;
  final String name;
  final String photoUrl;
  final String? avatarId; // NUEVO: ID del avatar seleccionado
  final List<String> favoriteRecipes;
  final Map<String, dynamic> preferences;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  // Getter para obtener la primera letra del nombre (útil para avatares de respaldo)
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : (email.isNotEmpty ? email[0].toUpperCase() : 'U');
  
  // Getter para obtener el primer nombre
  String get firstName => name.contains(' ') ? name.split(' ')[0] : name;

  // NUEVO: Getter para determinar si está usando un avatar local o una foto externa
  bool get hasLocalAvatar => avatarId != null && avatarId!.isNotEmpty;
  
  // NUEVO: Getter para determinar si tiene una foto externa (URL)
  bool get hasExternalPhoto => photoUrl.isNotEmpty && !hasLocalAvatar;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl = '',
    this.avatarId, // NUEVO: Campo opcional para el ID del avatar
    this.favoriteRecipes = const [],
    this.preferences = const {},
    this.lastLogin,
    this.createdAt,
  });

  // Factory para crear un usuario desde un mapa (JSON/Firestore) con conversión segura de tipos
  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Manejar fechas de Firestore
    DateTime? lastLogin;
    if (map['lastLogin'] != null) {
      if (map['lastLogin'] is Timestamp) {
        lastLogin = (map['lastLogin'] as Timestamp).toDate();
      } else if (map['lastLogin'] is String) {
        try {
          lastLogin = DateTime.parse(map['lastLogin'] as String);
        } catch (_) {
          lastLogin = null;
        }
      }
    }
    
    DateTime? createdAt;
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        createdAt = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        try {
          createdAt = DateTime.parse(map['createdAt'] as String);
        } catch (_) {
          createdAt = null;
        }
      }
    }
    
    // Conversión segura para favoriteRecipes
    List<String> favoriteRecipes = [];
    if (map['favoriteRecipes'] != null) {
      if (map['favoriteRecipes'] is List) {
        favoriteRecipes = List<String>.from(
          (map['favoriteRecipes'] as List).map((item) => item.toString())
        );
      }
    }
    
    // Conversión segura para preferences
    Map<String, dynamic> preferences = {};
    if (map['preferences'] != null) {
      if (map['preferences'] is Map) {
        preferences = Map<String, dynamic>.from(map['preferences'] as Map);
      }
    }
    
    return UserModel(
      id: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      avatarId: map['avatarId'], // NUEVO: Leer el ID del avatar
      favoriteRecipes: favoriteRecipes,
      preferences: preferences,
      lastLogin: lastLogin,
      createdAt: createdAt,
    );
  }

  // Método para convertir a un mapa (para guardar en Firestore)
  Map<String, dynamic> toMap() {
    return {
      'uid': id,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'avatarId': avatarId, // NUEVO: Incluir el ID del avatar
      'favoriteRecipes': favoriteRecipes,
      'preferences': preferences,
      'lastLogin': lastLogin?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // Método para crear una copia con algunos campos modificados y conversión segura de tipos
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    String? avatarId, // NUEVO: Parámetro para actualizar avatar
    List<String>? favoriteRecipes,
    Map<String, dynamic>? preferences,
    DateTime? lastLogin,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarId: avatarId ?? this.avatarId, // NUEVO: Usar el nuevo avatar o mantener el actual
      favoriteRecipes: favoriteRecipes ?? List<String>.from(this.favoriteRecipes),
      preferences: preferences ?? Map<String, dynamic>.from(this.preferences),
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  // NUEVO: Método específico para actualizar el avatar
  UserModel updateAvatar(String newAvatarId) {
    return copyWith(
      avatarId: newAvatarId,
      photoUrl: '', // Limpiar la foto externa cuando se selecciona un avatar local
    );
  }
  
  // NUEVO: Método específico para actualizar la foto externa
  UserModel updatePhotoUrl(String newPhotoUrl) {
    return copyWith(
      photoUrl: newPhotoUrl,
      avatarId: null, // Limpiar el avatar local cuando se selecciona una foto externa
    );
  }
  
  // NUEVO: Método para limpiar tanto avatar como foto
  UserModel clearAvatar() {
    return copyWith(
      avatarId: null,
      photoUrl: '',
    );
  }
  
  // Método para verificar si un usuario existe (tiene ID y email)
  bool get exists => id.isNotEmpty && email.isNotEmpty;
  
  // Método para actualizar timestamp de último login
  UserModel updateLastLogin() {
    return copyWith(lastLogin: DateTime.now());
  }
  
  // Método para añadir una receta a favoritos con conversión segura de tipos
  UserModel addFavoriteRecipe(String recipeId) {
    if (favoriteRecipes.contains(recipeId)) return this;
    
    // Crear una nueva lista con conversión segura
    List<String> updatedFavorites = List<String>.from(favoriteRecipes);
    updatedFavorites.add(recipeId);
    
    return copyWith(
      favoriteRecipes: updatedFavorites,
    );
  }
  
  // Método para quitar una receta de favoritos con conversión segura de tipos
  UserModel removeFavoriteRecipe(String recipeId) {
    if (!favoriteRecipes.contains(recipeId)) return this;
    
    // Crear una nueva lista con conversión segura
    List<String> updatedFavorites = List<String>.from(favoriteRecipes);
    updatedFavorites.removeWhere((id) => id == recipeId);
    
    return copyWith(
      favoriteRecipes: updatedFavorites,
    );
  }
  
  // Método para verificar si una receta está en favoritos
  bool isFavoriteRecipe(String recipeId) {
    return favoriteRecipes.contains(recipeId);
  }
  
  // Método para actualizar preferencias con conversión segura de tipos
  UserModel updatePreference(String key, dynamic value) {
    // Crear un nuevo mapa con conversión segura
    Map<String, dynamic> updatedPreferences = Map<String, dynamic>.from(preferences);
    updatedPreferences[key] = value;
    
    return copyWith(preferences: updatedPreferences);
  }
  
  // Método para obtener una preferencia específica con valor por defecto
  T getPreference<T>(String key, T defaultValue) {
    return preferences.containsKey(key) ? preferences[key] as T : defaultValue;
  }
  
  // Método para crear un usuario anónimo (para uso sin autenticación)
  factory UserModel.anonymous() {
    return UserModel(
      id: 'anonymous',
      email: 'anonymous@example.com',
      name: 'Usuario',
      createdAt: DateTime.now(),
      favoriteRecipes: [], // Lista vacía explícita
      preferences: {}, // Mapa vacío explícito
    );
  }
  
  // Método para comprobar igualdad entre usuarios
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() => 'UserModel(id: $id, name: $name, email: $email, avatarId: $avatarId)';
}