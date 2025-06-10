// lib/models/product_location_model.dart

/// Enumeración para representar las posibles ubicaciones de un producto
/// en la aplicación: inventario, lista de compras, o ambos.
enum ProductLocation {
  inventory, // El producto está en el inventario
  shoppingList, // El producto está en la lista de compras
  both; // El producto está en ambos lugares

  /// Método para convertir la ubicación a texto para mostrar en la UI
  String toDisplayString() {
    switch (this) {
      case ProductLocation.inventory:
        return 'Inventario';
      case ProductLocation.shoppingList:
        return 'Lista de compras';
      case ProductLocation.both:
        return 'Ambos';
    }
  }

  /// Getter para obtener el nombre de visualización (compatible con el AddProductScreen)
  String get displayName {
    switch (this) {
      case ProductLocation.inventory:
        return 'Inventario';
      case ProductLocation.shoppingList:
        return 'Lista de Compras';
      case ProductLocation.both:
        return 'Ambos';
    }
  }

  /// Método para obtener un ícono representativo de cada ubicación
  String get iconName {
    switch (this) {
      case ProductLocation.inventory:
        return 'inventory';
      case ProductLocation.shoppingList:
        return 'shopping_cart';
      case ProductLocation.both:
        return 'swap_horiz';
    }
  }

  /// Método para obtener una descripción más detallada
  String get description {
    switch (this) {
      case ProductLocation.inventory:
        return 'El producto está disponible en tu inventario';
      case ProductLocation.shoppingList:
        return 'El producto está en tu lista de compras';
      case ProductLocation.both:
        return 'El producto está tanto en inventario como en lista de compras';
    }
  }

  /// Método para verificar si está en el inventario
  bool get isInInventory {
    return this == ProductLocation.inventory || this == ProductLocation.both;
  }

  /// Método para verificar si está en la lista de compras
  bool get isInShoppingList {
    return this == ProductLocation.shoppingList || this == ProductLocation.both;
  }

  /// Método para convertir a String para almacenamiento en base de datos
  @override
  String toString() {
    switch (this) {
      case ProductLocation.inventory:
        return 'inventory';
      case ProductLocation.shoppingList:
        return 'shoppingList';
      case ProductLocation.both:
        return 'both';
    }
  }

  /// Método para crear una ubicación desde una cadena de texto
  static ProductLocation fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'inventory':
        return ProductLocation.inventory;
      case 'shoppinglist':
      case 'shopping_list':
        return ProductLocation.shoppingList;
      case 'both':
        return ProductLocation.both;
      default:
        return ProductLocation.inventory; // Valor por defecto si no coincide
    }
  }

  /// Método para obtener todas las ubicaciones disponibles
  static List<ProductLocation> get allLocations => ProductLocation.values;

  /// Método para obtener ubicaciones de inventario (inventory y both)
  static List<ProductLocation> get inventoryLocations => [
    ProductLocation.inventory,
    ProductLocation.both,
  ];

  /// Método para obtener ubicaciones de lista de compras (shoppingList y both)
  static List<ProductLocation> get shoppingListLocations => [
    ProductLocation.shoppingList,
    ProductLocation.both,
  ];
}

/// Extension para funcionalidades adicionales de ProductLocation
extension ProductLocationExtension on ProductLocation {
  /// Método para mover un producto a otra ubicación
  ProductLocation moveTo(ProductLocation newLocation) {
    // Si ya está en la ubicación solicitada, no hacer nada
    if (this == newLocation) return this;
    
    // Si está en "ambos" lugares y se solicita mover a uno específico, actualizar
    if (this == ProductLocation.both) {
      return newLocation;
    }
    
    // Si está en un lugar específico y se solicita mover al otro, usar "ambos"
    if ((this == ProductLocation.inventory && newLocation == ProductLocation.shoppingList) ||
        (this == ProductLocation.shoppingList && newLocation == ProductLocation.inventory)) {
      return ProductLocation.both;
    }
    
    // En cualquier otro caso, actualizar a la nueva ubicación
    return newLocation;
  }

  /// Método para eliminar de una ubicación específica
  ProductLocation? removeFrom(ProductLocation locationToRemove) {
    if (this == ProductLocation.both) {
      // Si está en ambos lugares, quitar solo de la ubicación especificada
      if (locationToRemove == ProductLocation.inventory) {
        return ProductLocation.shoppingList;
      } else if (locationToRemove == ProductLocation.shoppingList) {
        return ProductLocation.inventory;
      }
    } else if (this == locationToRemove) {
      // Si solo está en la ubicación a eliminar, retornar null (eliminar completamente)
      return null;
    }
    
    // Si no está en la ubicación a eliminar, no hacer cambios
    return this;
  }

  /// Método para verificar si puede moverse a una ubicación específica
  bool canMoveTo(ProductLocation destination) {
    // Siempre se puede mover a cualquier ubicación
    return true;
  }

  /// Método para obtener el color asociado a cada ubicación
  int get colorValue {
    switch (this) {
      case ProductLocation.inventory:
        return 0xFF4CAF50; // Verde
      case ProductLocation.shoppingList:
        return 0xFF2196F3; // Azul
      case ProductLocation.both:
        return 0xFF9C27B0; // Púrpura
    }
  }
}

/// Clase de utilidades para ProductLocation
class ProductLocationUtils {
  /// Método para filtrar productos por ubicación
  static bool productMatchesLocation(ProductLocation productLocation, ProductLocation filterLocation) {
    switch (filterLocation) {
      case ProductLocation.inventory:
        return productLocation.isInInventory;
      case ProductLocation.shoppingList:
        return productLocation.isInShoppingList;
      case ProductLocation.both:
        return productLocation == ProductLocation.both;
    }
  }

  /// Método para obtener ubicaciones sugeridas según el contexto
  static List<ProductLocation> getSuggestedLocations(String context) {
    switch (context.toLowerCase()) {
      case 'add_to_inventory':
        return [ProductLocation.inventory, ProductLocation.both];
      case 'add_to_shopping':
        return [ProductLocation.shoppingList, ProductLocation.both];
      default:
        return ProductLocation.allLocations;
    }
  }

  /// Método para validar una ubicación
  static bool isValidLocation(String locationString) {
    try {
      ProductLocation.fromString(locationString);
      return true;
    } catch (e) {
      return false;
    }
  }
}