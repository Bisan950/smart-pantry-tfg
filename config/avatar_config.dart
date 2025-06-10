// lib/config/avatar_config.dart - Configuración completa con todos los iconos disponibles

import '../models/avatar_model.dart';

/// Configuración centralizada de todos los avatares disponibles
/// 
/// Configuración actualizada para incluir todos los iconos de comida disponibles
class AvatarConfig {
  /// Lista completa de configuraciones de avatares
  static const List<Map<String, dynamic>> _avatarConfigs = [
    // === FILA 1: FRUTAS Y VERDURAS ===
    {'id': 'icono_001', 'name': 'Naranja', 'file': 'icono_001.png', 'category': 'Frutas'},
    {'id': 'icono_003', 'name': 'Aguacate', 'file': 'icono_003.png', 'category': 'Frutas'},
    {'id': 'icono_004', 'name': 'Arándanos', 'file': 'icono_004.png', 'category': 'Frutas'},
    {'id': 'icono_005', 'name': 'Frambuesas', 'file': 'icono_005.png', 'category': 'Frutas'},
    {'id': 'icono_006', 'name': 'Tomate', 'file': 'icono_006.png', 'category': 'Frutas'},
    {'id': 'icono_007', 'name': 'Brócoli', 'file': 'icono_007.png', 'category': 'Verduras'},
    {'id': 'icono_008', 'name': 'Coco', 'file': 'icono_008.png', 'category': 'Frutas'},
    {'id': 'icono_009', 'name': 'Kiwi', 'file': 'icono_009.png', 'category': 'Frutas'},
    {'id': 'icono_010', 'name': 'Cerezas', 'file': 'icono_010.png', 'category': 'Frutas'},
    {'id': 'icono_011', 'name': 'Piña', 'file': 'icono_011.png', 'category': 'Frutas'},
    {'id': 'icono_012', 'name': 'Ajo', 'file': 'icono_012.png', 'category': 'Verduras'},
    {'id': 'icono_013', 'name': 'Guisantes', 'file': 'icono_013.png', 'category': 'Verduras'},
    {'id': 'icono_014', 'name': 'Lechuga', 'file': 'icono_014.png', 'category': 'Verduras'},
    {'id': 'icono_015', 'name': 'Coliflor', 'file': 'icono_015.png', 'category': 'Verduras'},
    {'id': 'icono_016', 'name': 'Maíz', 'file': 'icono_016.png', 'category': 'Verduras'},
    {'id': 'icono_017', 'name': 'Papa', 'file': 'icono_017.png', 'category': 'Verduras'},

    // === FILA 2: VERDURAS Y COMIDAS PREPARADAS ===
    {'id': 'icono_018', 'name': 'Berenjena', 'file': 'icono_018.png', 'category': 'Verduras'},
    {'id': 'icono_019', 'name': 'Calabaza', 'file': 'icono_019.png', 'category': 'Verduras'},
    {'id': 'icono_020', 'name': 'Champiñón', 'file': 'icono_020.png', 'category': 'Verduras'},
    {'id': 'icono_021', 'name': 'Pimiento', 'file': 'icono_021.png', 'category': 'Verduras'},
    {'id': 'icono_022', 'name': 'Hamburguesa', 'file': 'icono_022.png', 'category': 'Comida Rápida'},
    {'id': 'icono_023', 'name': 'Hot Dog', 'file': 'icono_023.png', 'category': 'Comida Rápida'},
    {'id': 'icono_024', 'name': 'Pizza', 'file': 'icono_024.png', 'category': 'Comida Rápida'},
    {'id': 'icono_025', 'name': 'Sopa', 'file': 'icono_025.png', 'category': 'Platos'},
    {'id': 'icono_026', 'name': 'Pasta', 'file': 'icono_026.png', 'category': 'Platos'},
    {'id': 'icono_027', 'name': 'Sandwich', 'file': 'icono_027.png', 'category': 'Comida Rápida'},
    {'id': 'icono_028', 'name': 'Café', 'file': 'icono_028.png', 'category': 'Bebidas'},
    {'id': 'icono_029', 'name': 'Jugo', 'file': 'icono_029.png', 'category': 'Bebidas'},
    {'id': 'icono_030', 'name': 'Vino', 'file': 'icono_030.png', 'category': 'Bebidas'},
    {'id': 'icono_031', 'name': 'Manzana', 'file': 'icono_031.png', 'category': 'Frutas'},
    {'id': 'icono_032', 'name': 'Plátano', 'file': 'icono_032.png', 'category': 'Frutas'},
    {'id': 'icono_038', 'name': 'Ciruela', 'file': 'icono_038.png', 'category': 'Frutas'},

    // === FILA 3: COMIDAS VARIADAS ===
    {'id': 'icono_039', 'name': 'Fresa', 'file': 'icono_039.png', 'category': 'Frutas'},
    {'id': 'icono_040', 'name': 'Champiñón Café', 'file': 'icono_040.png', 'category': 'Verduras'},
    {'id': 'icono_041', 'name': 'Queso', 'file': 'icono_041.png', 'category': 'Lácteos'},
    {'id': 'icono_048', 'name': 'Manzana Roja', 'file': 'icono_048.png', 'category': 'Frutas'},
    {'id': 'icono_049', 'name': 'Ensalada', 'file': 'icono_049.png', 'category': 'Platos'},
    {'id': 'icono_050', 'name': 'Huevos', 'file': 'icono_050.png', 'category': 'Proteínas'},
    {'id': 'icono_051', 'name': 'Brócoli Verde', 'file': 'icono_051.png', 'category': 'Verduras'},
    {'id': 'icono_058', 'name': 'Helado', 'file': 'icono_058.png', 'category': 'Postres'},
    {'id': 'icono_059', 'name': 'Paleta', 'file': 'icono_059.png', 'category': 'Postres'},
    {'id': 'icono_060', 'name': 'Pastel', 'file': 'icono_060.png', 'category': 'Postres'},
    {'id': 'icono_068', 'name': 'Panqueques', 'file': 'icono_068.png', 'category': 'Desayuno'},
    {'id': 'icono_069', 'name': 'Pretzel', 'file': 'icono_069.png', 'category': 'Snacks'},
    {'id': 'icono_070', 'name': 'Sartén', 'file': 'icono_070.png', 'category': 'Utensilios'},
    {'id': 'icono_078', 'name': 'Cuchara', 'file': 'icono_078.png', 'category': 'Utensilios'},
    {'id': 'icono_079', 'name': 'Taza', 'file': 'icono_079.png', 'category': 'Utensilios'},
    {'id': 'icono_080', 'name': 'Pan', 'file': 'icono_080.png', 'category': 'Panadería'},

    // === FILA 4: ÚLTIMA FILA ===
    {'id': 'icono_081', 'name': 'Mermelada', 'file': 'icono_081.png', 'category': 'Conservas'},

    // === ICONOS PREMIUM ===
    {'id': 'icono_089', 'name': 'Chocolate', 'file': 'icono_089.png', 'category': 'Dulces', 'premium': true},
    {'id': 'icono_090', 'name': 'Galletas', 'file': 'icono_090.png', 'category': 'Dulces', 'premium': true},
  ];

  /// Genera la lista de modelos de avatar a partir de la configuración
  static List<AvatarModel> generateAvatars() {
    return _avatarConfigs.map((config) {
      return AvatarModel(
        id: config['id'] as String,
        name: config['name'] as String,
        assetPath: 'assets/avatars/${config['file'] as String}',
        category: config['category'] as String,
        isPremium: config['premium'] as bool? ?? false,
      );
    }).toList();
  }

  /// Obtener avatares por categoría
  static List<AvatarModel> getAvatarsByCategory(String category) {
    return generateAvatars()
        .where((avatar) => avatar.category == category)
        .toList();
  }

  /// Obtener todas las categorías disponibles
  static List<String> getAvailableCategories() {
    return _avatarConfigs
        .map((config) => config['category'] as String)
        .toSet()
        .toList()
      ..sort();
  }

  /// Obtener avatares gratuitos
  static List<AvatarModel> getFreeAvatars() {
    return generateAvatars()
        .where((avatar) => !avatar.isPremium)
        .toList();
  }

  /// Obtener avatares premium
  static List<AvatarModel> getPremiumAvatars() {
    return generateAvatars()
        .where((avatar) => avatar.isPremium)
        .toList();
  }

  /// Buscar avatares por nombre o categoría
  static List<AvatarModel> searchAvatars(String query) {
    if (query.isEmpty) return generateAvatars();
    
    final allAvatars = generateAvatars();
    final lowerQuery = query.toLowerCase();
    
    return allAvatars.where((avatar) => 
      avatar.name.toLowerCase().contains(lowerQuery) ||
      avatar.category.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  /// Obtener un avatar aleatorio
  static AvatarModel getRandomAvatar() {
    final allAvatars = generateAvatars();
    allAvatars.shuffle();
    return allAvatars.first;
  }

  /// Obtener avatar por ID
  static AvatarModel? getAvatarById(String id) {
    try {
      return generateAvatars().firstWhere((avatar) => avatar.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtener estadísticas de avatares
  static Map<String, int> getAvatarStats() {
    final avatars = generateAvatars();
    final categories = getAvailableCategories();
    
    Map<String, int> stats = {
      'total': avatars.length,
      'free': getFreeAvatars().length,
      'premium': getPremiumAvatars().length,
    };
    
    // Agregar conteo por categoría
    for (String category in categories) {
      stats[category.toLowerCase().replaceAll(' ', '_')] = getAvatarsByCategory(category).length;
    }
    
    return stats;
  }

  /// Obtener avatares sugeridos para el usuario
  static List<AvatarModel> getSuggestedAvatars([int limit = 6]) {
    final allAvatars = generateAvatars();
    
    // Priorizar frutas y verduras para una app de cocina
    final suggested = <AvatarModel>[];
    
    // Agregar algunas frutas populares
    final fruits = getAvatarsByCategory('Frutas');
    fruits.shuffle();
    suggested.addAll(fruits.take(3));
    
    // Agregar algunas verduras
    final vegetables = getAvatarsByCategory('Verduras');
    vegetables.shuffle();
    suggested.addAll(vegetables.take(2));
    
    // Agregar uno de comida rápida
    final fastFood = getAvatarsByCategory('Comida Rápida');
    if (fastFood.isNotEmpty) {
      fastFood.shuffle();
      suggested.add(fastFood.first);
    }
    
    // Si necesitamos más, agregar cualquier otro
    if (suggested.length < limit) {
      final remaining = allAvatars.where((avatar) => !suggested.contains(avatar)).toList();
      remaining.shuffle();
      suggested.addAll(remaining.take(limit - suggested.length));
    }
    
    return suggested.take(limit).toList();
  }

  /// Obtener el avatar más popular de cada categoría
  static List<AvatarModel> getFeaturedAvatars() {
    final featured = <AvatarModel>[];
    
    // Avatar destacado de cada categoría
    final fruitsChoice = getAvatarById('icono_001'); // Naranja
    final vegetablesChoice = getAvatarById('icono_007'); // Brócoli
    final fastFoodChoice = getAvatarById('icono_022'); // Hamburguesa
    final dishesChoice = getAvatarById('icono_025'); // Sopa
    final sweetsChoice = getAvatarById('icono_089'); // Chocolate
    final drinksChoice = getAvatarById('icono_028'); // Café
    final dessertsChoice = getAvatarById('icono_058'); // Helado
    
    if (fruitsChoice != null) featured.add(fruitsChoice);
    if (vegetablesChoice != null) featured.add(vegetablesChoice);
    if (fastFoodChoice != null) featured.add(fastFoodChoice);
    if (dishesChoice != null) featured.add(dishesChoice);
    if (drinksChoice != null) featured.add(drinksChoice);
    if (dessertsChoice != null) featured.add(dessertsChoice);
    if (sweetsChoice != null) featured.add(sweetsChoice);
    
    return featured;
  }

  /// Verificar si un avatar es válido
  static bool isValidAvatarId(String id) {
    return getAvatarById(id) != null;
  }

  /// Obtener el primer avatar disponible (avatar por defecto)
  static AvatarModel getDefaultAvatar() {
    return generateAvatars().first;
  }

  /// Obtener avatares por tipo de comida específico
  static List<AvatarModel> getAvatarsByFoodType(String foodType) {
    switch (foodType.toLowerCase()) {
      case 'saludable':
        return [
          ...getAvatarsByCategory('Frutas'),
          ...getAvatarsByCategory('Verduras'),
        ];
      case 'rapida':
        return getAvatarsByCategory('Comida Rápida');
      case 'dulce':
        return [
          ...getAvatarsByCategory('Postres'),
          ...getAvatarsByCategory('Dulces'),
        ];
      case 'bebidas':
        return getAvatarsByCategory('Bebidas');
      default:
        return generateAvatars();
    }
  }

  /// Obtener avatares perfectos para diferentes ocasiones
  static List<AvatarModel> getAvatarsForOccasion(String occasion) {
    switch (occasion.toLowerCase()) {
      case 'desayuno':
        return [
          getAvatarById('icono_068'), // Panqueques
          getAvatarById('icono_050'), // Huevos
          getAvatarById('icono_028'), // Café
          getAvatarById('icono_080'), // Pan
          getAvatarById('icono_081'), // Mermelada
        ].where((avatar) => avatar != null).cast<AvatarModel>().toList();
      
      case 'cena':
        return [
          getAvatarById('icono_025'), // Sopa
          getAvatarById('icono_026'), // Pasta
          getAvatarById('icono_049'), // Ensalada
          getAvatarById('icono_022'), // Hamburguesa
        ].where((avatar) => avatar != null).cast<AvatarModel>().toList();
      
      case 'postre':
        return [
          getAvatarById('icono_058'), // Helado
          getAvatarById('icono_059'), // Paleta
          getAvatarById('icono_060'), // Pastel
          getAvatarById('icono_089'), // Chocolate
          getAvatarById('icono_090'), // Galletas
        ].where((avatar) => avatar != null).cast<AvatarModel>().toList();
      
      default:
        return getFeaturedAvatars();
    }
  }
}