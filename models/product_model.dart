// lib/models/product_model.dart - ACTUALIZADO CON MACROS

import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_location_model.dart';

// Clase para información nutricional
class NutritionalInfo {
  final double? servingSize; // Tamaño de porción en gramos
  final int? calories; // Calorías por porción
  final double? proteins; // Proteínas en gramos
  final double? carbohydrates; // Carbohidratos en gramos
  final double? fats; // Grasas en gramos
  final double? fiber; // Fibra en gramos
  final double? sugar; // Azúcar en gramos
  final double? sodium; // Sodio en mg
  final String? servingUnit; // Unidad de la porción (ej: "100g", "1 taza")

  const NutritionalInfo({
    this.servingSize,
    this.calories,
    this.proteins,
    this.carbohydrates,
    this.fats,
    this.fiber,
    this.sugar,
    this.sodium,
    this.servingUnit,
  });

  // CopyWith para crear copias con modificaciones
  NutritionalInfo copyWith({
    double? servingSize,
    int? calories,
    double? proteins,
    double? carbohydrates,
    double? fats,
    double? fiber,
    double? sugar,
    double? sodium,
    String? servingUnit,
  }) {
    return NutritionalInfo(
      servingSize: servingSize ?? this.servingSize,
      calories: calories ?? this.calories,
      proteins: proteins ?? this.proteins,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      fats: fats ?? this.fats,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      sodium: sodium ?? this.sodium,
      servingUnit: servingUnit ?? this.servingUnit,
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'servingSize': servingSize,
      'calories': calories,
      'proteins': proteins,
      'carbohydrates': carbohydrates,
      'fats': fats,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
      'servingUnit': servingUnit,
    };
  }

  // Crear desde Map
  factory NutritionalInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NutritionalInfo();
    
    return NutritionalInfo(
      servingSize: (map['servingSize'] as num?)?.toDouble(),
      calories: (map['calories'] as num?)?.toInt(),
      proteins: (map['proteins'] as num?)?.toDouble(),
      carbohydrates: (map['carbohydrates'] as num?)?.toDouble(),
      fats: (map['fats'] as num?)?.toDouble(),
      fiber: (map['fiber'] as num?)?.toDouble(),
      sugar: (map['sugar'] as num?)?.toDouble(),
      sodium: (map['sodium'] as num?)?.toDouble(),
      servingUnit: map['servingUnit'] as String?,
    );
  }

  // Verificar si tiene información nutricional
  bool get hasNutritionalInfo {
    return calories != null || proteins != null || carbohydrates != null || fats != null;
  }

  // Obtener calorías por 100g (normalizado)
  int? get caloriesPer100g {
    if (calories == null || servingSize == null) return calories;
    if (servingSize == 0) return calories;
    return ((calories! / servingSize!) * 100).round();
  }
}

class Product {
  final String id;
  final String name;
  final int quantity;
  final int maxQuantity;
  final String unit;
  final String category;
  final String location;
  final ProductLocation productLocation;
  final String imageUrl;
  final String barcode;
  final String notes;
  final bool isFavorite;
  final bool isPurchased;
  final DateTime? expiryDate;
  final String userId;
  final DateTime? createdAt;
  final NutritionalInfo? nutritionalInfo; // ¡NUEVO CAMPO!
  
  // Calcular días hasta caducidad
  int get daysUntilExpiry {
    if (expiryDate == null) return 999;
    
    final now = DateTime.now();
    return expiryDate!.difference(now).inDays;
  }

  Product({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.userId,
    this.maxQuantity = 0,
    this.location = 'Despensa',
    this.productLocation = ProductLocation.inventory,
    this.imageUrl = '',
    this.barcode = '',
    this.notes = '',
    this.isFavorite = false,
    this.isPurchased = false,
    this.expiryDate,
    this.createdAt,
    this.nutritionalInfo, // ¡NUEVO PARÁMETRO!
  });

  // Método para crear una copia con algunos campos modificados
  Product copyWith({
    String? id,
    String? name,
    int? quantity,
    int? maxQuantity,
    String? unit,
    String? category,
    String? location,
    ProductLocation? productLocation,
    String? imageUrl,
    String? barcode,
    String? notes,
    bool? isFavorite,
    bool? isPurchased,
    DateTime? expiryDate,
    String? userId,
    DateTime? createdAt,
    NutritionalInfo? nutritionalInfo, // ¡NUEVO!
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      location: location ?? this.location,
      productLocation: productLocation ?? this.productLocation,
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: barcode ?? this.barcode,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      isPurchased: isPurchased ?? this.isPurchased,
      expiryDate: expiryDate ?? this.expiryDate,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
    );
  }

  // [RESTO DE MÉTODOS SIN CAMBIOS - moveToLocation, isAvailableIn, etc.]
  Product moveToLocation(ProductLocation newLocation) {
    if (productLocation == newLocation) return this;
    
    if (productLocation == ProductLocation.both) {
      return copyWith(productLocation: newLocation);
    }
    
    if ((productLocation == ProductLocation.inventory && newLocation == ProductLocation.shoppingList) ||
        (productLocation == ProductLocation.shoppingList && newLocation == ProductLocation.inventory)) {
      return copyWith(productLocation: ProductLocation.both);
    }
    
    return copyWith(productLocation: newLocation);
  }

  bool isAvailableIn(ProductLocation location) {
    if (productLocation == ProductLocation.both) return true;
    return productLocation == location;
  }

  Product createShoppingCopy() {
    if (productLocation == ProductLocation.shoppingList || 
        productLocation == ProductLocation.both) {
      return this;
    }
    
    return copyWith(productLocation: ProductLocation.both);
  }

  Product createInventoryCopy() {
    if (productLocation == ProductLocation.inventory || 
        productLocation == ProductLocation.both) {
      return this;
    }
    
    return copyWith(productLocation: ProductLocation.both);
  }

  // Método para convertir a un mapa - ACTUALIZADO
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'maxQuantity': maxQuantity,
      'unit': unit,
      'category': category,
      'location': location,
      'productLocation': productLocation.toString(),
      'imageUrl': imageUrl,
      'barcode': barcode,
      'notes': notes,
      'isFavorite': isFavorite,
      'isPurchased': isPurchased,
      'expiryDate': expiryDate?.toIso8601String(),
      'userId': userId,
      'createdAt': createdAt?.toIso8601String(),
      'nutritionalInfo': nutritionalInfo?.toMap(), // ¡NUEVO!
    };
  }

  // Factory para crear un producto desde un mapa - ACTUALIZADO
  factory Product.fromMap(Map<String, dynamic> map) {
    // [TODA LA LÓGICA EXISTENTE PARA OTROS CAMPOS...]
    
    // Manejar quantity
    int quantity;
    if (map['quantity'] is int) {
      quantity = map['quantity'] ?? 0;
    } else if (map['quantity'] is double) {
      quantity = (map['quantity'] ?? 0).toInt();
    } else if (map['quantity'] is String) {
      quantity = int.tryParse(map['quantity'] ?? '0') ?? 0;
    } else {
      quantity = 0;
    }
    
    // Manejar maxQuantity
    int maxQuantity;
    if (map['maxQuantity'] is int) {
      maxQuantity = map['maxQuantity'] ?? 0;
    } else if (map['maxQuantity'] is double) {
      maxQuantity = (map['maxQuantity'] ?? 0).toInt();
    } else if (map['maxQuantity'] is String) {
      maxQuantity = int.tryParse(map['maxQuantity'] ?? '0') ?? 0;
    } else {
      maxQuantity = 0;
    }
    
    // Manejar expiryDate
    DateTime? expiryDate;
    if (map['expiryDate'] != null) {
      if (map['expiryDate'] is DateTime) {
        expiryDate = map['expiryDate'];
      } else if (map['expiryDate'] is Timestamp) {
        expiryDate = (map['expiryDate'] as Timestamp).toDate();
      } else if (map['expiryDate'] is String) {
        try {
          expiryDate = DateTime.parse(map['expiryDate']);
        } catch (e) {
          expiryDate = null;
        }
      }
    }
    
    // Manejar createdAt
    DateTime? createdAt;
    if (map['createdAt'] != null) {
      if (map['createdAt'] is DateTime) {
        createdAt = map['createdAt'];
      } else if (map['createdAt'] is Timestamp) {
        createdAt = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        try {
          createdAt = DateTime.parse(map['createdAt']);
        } catch (e) {
          createdAt = null;
        }
      }
    }
    
    // Manejar productLocation
    ProductLocation productLocation = ProductLocation.inventory;
    if (map['productLocation'] != null) {
      try {
        productLocation = ProductLocation.fromString(map['productLocation'].toString());
      } catch (e) {
        productLocation = ProductLocation.inventory;
      }
    }

    // ¡NUEVO! Manejar nutritionalInfo
    NutritionalInfo? nutritionalInfo;
    if (map['nutritionalInfo'] != null) {
      nutritionalInfo = NutritionalInfo.fromMap(map['nutritionalInfo'] as Map<String, dynamic>?);
    }

    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      quantity: quantity,
      maxQuantity: maxQuantity,
      unit: map['unit'] ?? '',
      category: map['category'] ?? '',
      location: map['location'] ?? 'Despensa',
      productLocation: productLocation,
      imageUrl: map['imageUrl'] ?? '',
      barcode: map['barcode'] ?? '',
      notes: map['notes'] ?? '',
      isFavorite: map['isFavorite'] ?? false,
      isPurchased: map['isPurchased'] ?? false,
      expiryDate: expiryDate,
      userId: map['userId'] ?? '',
      createdAt: createdAt,
      nutritionalInfo: nutritionalInfo, // ¡NUEVO!
    );
  }

  // [RESTO DE MÉTODOS SIN CAMBIOS - formattedQuantity, hasLowStock, etc.]
  String formattedQuantity() {
    if (unit.toLowerCase() == 'g' && quantity >= 1000) {
      return '${(quantity / 1000).toStringAsFixed(1)} kg';
    } else if (unit.toLowerCase() == 'ml' && quantity >= 1000) {
      return '${(quantity / 1000).toStringAsFixed(1)} L';
    } else {
      return '$quantity $unit';
    }
  }

  bool hasLowStock() {
    if (unit == 'unidades' && quantity <= 2) return true;
    if (unit == 'g' && quantity <= 100) return true;
    if (unit == 'kg' && quantity <= 0.2) return true;
    if (unit == 'ml' && quantity <= 100) return true;
    if (unit == 'L' && quantity <= 0.2) return true;
    return false;
  }

  bool hasCriticalStock() {
    if (unit == 'unidades' && quantity <= 1) return true;
    if (unit == 'g' && quantity <= 50) return true;
    if (unit == 'kg' && quantity <= 0.05) return true;
    if (unit == 'ml' && quantity <= 50) return true;
    if (unit == 'L' && quantity <= 0.05) return true;
    return false;
  }

  double stockPercentage() {
    if (maxQuantity <= 0) return 1.0;
    return quantity / maxQuantity;
  }

  bool isExpired() {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    return expiryDate!.isBefore(now);
  }

  bool isAboutToExpire() {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final daysUntil = expiryDate!.difference(now).inDays;
    return daysUntil >= 0 && daysUntil <= 3;
  }

  // ¡NUEVOS MÉTODOS PARA INFORMACIÓN NUTRICIONAL!
  
  // Verificar si tiene información nutricional
  bool get hasNutritionalInfo {
    return nutritionalInfo?.hasNutritionalInfo ?? false;
  }

  // Obtener información nutricional formateada para mostrar
  String get nutritionalSummary {
    if (!hasNutritionalInfo) return 'Sin información nutricional';
    
    final info = nutritionalInfo!;
    final parts = <String>[];
    
    if (info.calories != null) {
      parts.add('${info.calories} kcal');
    }
    if (info.proteins != null) {
      parts.add('P: ${info.proteins!.toStringAsFixed(1)}g');
    }
    if (info.carbohydrates != null) {
      parts.add('C: ${info.carbohydrates!.toStringAsFixed(1)}g');
    }
    if (info.fats != null) {
      parts.add('G: ${info.fats!.toStringAsFixed(1)}g');
    }
    
    if (parts.isEmpty) return 'Sin macros disponibles';
    
    return parts.join(' • ');
  }
}