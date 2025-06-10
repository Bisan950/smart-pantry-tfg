// lib/models/avatar_model.dart
/// Modelo para representar un avatar disponible en la aplicación
library;


class AvatarModel {
  final String id;
  final String name;
  final String assetPath;
  final String category;
  final bool isPremium;

  const AvatarModel({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.category,
    this.isPremium = false,
  });

  // Factory para crear un avatar desde un mapa
  factory AvatarModel.fromMap(Map<String, dynamic> map) {
    return AvatarModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      assetPath: map['assetPath'] ?? '',
      category: map['category'] ?? '',
      isPremium: map['isPremium'] ?? false,
    );
  }

  // Método para convertir a mapa
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'assetPath': assetPath,
      'category': category,
      'isPremium': isPremium,
    };
  }

  // Método para crear una copia con algunos campos modificados
  AvatarModel copyWith({
    String? id,
    String? name,
    String? assetPath,
    String? category,
    bool? isPremium,
  }) {
    return AvatarModel(
      id: id ?? this.id,
      name: name ?? this.name,
      assetPath: assetPath ?? this.assetPath,
      category: category ?? this.category,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AvatarModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AvatarModel(id: $id, name: $name, category: $category)';
}