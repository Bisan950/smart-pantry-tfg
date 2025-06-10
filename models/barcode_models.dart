// lib/models/barcode_models.dart

/// Información del producto obtenida de APIs de códigos de barras
class ProductInfo {
  final String name;
  final String category;
  final String brand;
  final String barcode;
  final int quantity;
  final int maxQuantity;
  final String unit;
  final String imageUrl;
  final List<String> ingredients;
  final Map<String, dynamic> nutritionalInfo;
  final String defaultLocation;
  final String source;
  final double confidence;

  ProductInfo({
    required this.name,
    required this.category,
    required this.barcode,
    this.brand = '',
    this.quantity = 1,
    this.maxQuantity = 0,
    this.unit = 'unidades',
    this.imageUrl = '',
    this.ingredients = const [],
    this.nutritionalInfo = const {},
    this.defaultLocation = 'Despensa',
    this.source = 'unknown',
    this.confidence = 0.5,
  });

  /// Crear desde JSON
  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      name: json['name'] ?? '',
      category: json['category'] ?? 'Otros',
      brand: json['brand'] ?? '',
      barcode: json['barcode'] ?? '',
      quantity: json['quantity'] ?? 1,
      maxQuantity: json['maxQuantity'] ?? 0,
      unit: json['unit'] ?? 'unidades',
      imageUrl: json['imageUrl'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      nutritionalInfo: Map<String, dynamic>.from(json['nutritionalInfo'] ?? {}),
      defaultLocation: json['defaultLocation'] ?? 'Despensa',
      source: json['source'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.5).toDouble(),
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'brand': brand,
      'barcode': barcode,
      'quantity': quantity,
      'maxQuantity': maxQuantity,
      'unit': unit,
      'imageUrl': imageUrl,
      'ingredients': ingredients,
      'nutritionalInfo': nutritionalInfo,
      'defaultLocation': defaultLocation,
      'source': source,
      'confidence': confidence,
    };
  }

  /// Crear copia con modificaciones
  ProductInfo copyWith({
    String? name,
    String? category,
    String? brand,
    String? barcode,
    int? quantity,
    int? maxQuantity,
    String? unit,
    String? imageUrl,
    List<String>? ingredients,
    Map<String, dynamic>? nutritionalInfo,
    String? defaultLocation,
    String? source,
    double? confidence,
  }) {
    return ProductInfo(
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredients: ingredients ?? this.ingredients,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      defaultLocation: defaultLocation ?? this.defaultLocation,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// Resultado de consulta a API
class APIResult {
  final String api;
  final ProductInfo productInfo;
  final int responseTime;
  final double confidence;

  APIResult({
    required this.api,
    required this.productInfo,
    required this.responseTime,
    required this.confidence,
  });
}

/// Datos del producto almacenados localmente
class LocalProductData {
  final ProductInfo productInfo;
  final int timestamp;
  final String source;
  final double confidence;

  LocalProductData({
    required this.productInfo,
    required this.timestamp,
    required this.source,
    required this.confidence,
  });
}

/// Estadísticas de uso de APIs
class APIStats {
  int successCount;
  int failureCount;
  double avgResponseTime;
  int lastUsed;

  APIStats({
    this.successCount = 0,
    this.failureCount = 0,
    this.avgResponseTime = 0.0,
    this.lastUsed = 0,
  });

  /// Tasa de éxito
  double get successRate {
    final total = successCount + failureCount;
    return total > 0 ? successCount / total : 0.0;
  }

  /// Número total de llamadas
  int get totalCalls => successCount + failureCount;
}