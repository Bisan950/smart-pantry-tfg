import 'package:flutter/material.dart';

class MealType {
  final String id;
  final String name;
  final IconData icon;

  const MealType({
    required this.id,
    required this.name,
    required this.icon,
  });

  // Lista de tipos de comida predefinidos
  static List<MealType> getPredefinedTypes() {
    return [
      const MealType(id: 'breakfast', name: 'Desayuno', icon: Icons.free_breakfast),
      const MealType(id: 'lunch', name: 'Almuerzo', icon: Icons.lunch_dining),
      const MealType(id: 'dinner', name: 'Cena', icon: Icons.dinner_dining),
      const MealType(id: 'snack', name: 'Merienda', icon: Icons.cookie),
    ];
  }

  // Factory para crear desde un mapa (JSON)
  factory MealType.fromMap(Map<String, dynamic> map) {
    return MealType(
      id: map['id'],
      name: map['name'],
      icon: IconData(
        map['iconCodePoint'],
        fontFamily: 'MaterialIcons',
      ),
    );
  }

  // Convertir a mapa (JSON)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
    };
  }
}