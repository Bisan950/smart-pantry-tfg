// lib/models/shopping_list_preferences_model.dart

import 'package:flutter/material.dart';
import '../config/theme.dart';

class ShoppingListPreferences {
  // Configuraciones de vista existentes
  final bool showPurchased;
  final bool isListView;
  final bool showInventorySuggestions;
  final bool showInventoryItems;
  
  // Configuraciones de personalización existentes
  final ShoppingListTheme theme;
  final String backgroundStyle;
  final bool enableAnimations;
  final bool enableHapticFeedback;
  
  // Configuraciones de comportamiento existentes
  final bool autoExpandCategories;
  final bool groupByCategory;
  final bool showItemDetails;
  final bool enableSwipeActions;
  
  // NUEVAS configuraciones de widgets personalizados
  final Map<String, dynamic> widgetPreferences;
  final List<String> favoriteWidgets;
  final Map<String, int> widgetOrder;
  final bool enableCustomWidgets;
  final double cardBorderRadius;
  final double cardElevation;
  final bool showProductImages;
  final bool compactMode;
  final String sortingPreference;
  final bool enableQuickActions;
  final Map<String, bool> categoryVisibility;
  final bool enableSmartSuggestions;
  final int maxItemsPerCategory;
  
  const ShoppingListPreferences({
    // Vista por defecto
    this.showPurchased = true,
    this.isListView = false,
    this.showInventorySuggestions = true,
    this.showInventoryItems = false,
    
    // Personalización por defecto
    this.theme = ShoppingListTheme.default_,
    this.backgroundStyle = 'default',
    this.enableAnimations = true,
    this.enableHapticFeedback = true,
    
    // Comportamiento por defecto
    this.autoExpandCategories = false,
    this.groupByCategory = true,
    this.showItemDetails = true,
    this.enableSwipeActions = true,
    
    // Nuevos valores por defecto
    this.widgetPreferences = const {},
    this.favoriteWidgets = const ['quick_add', 'recent_items', 'suggestions'],
    this.widgetOrder = const {'quick_add': 0, 'recent_items': 1, 'suggestions': 2},
    this.enableCustomWidgets = true,
    this.cardBorderRadius = 12.0,
    this.cardElevation = 2.0,
    this.showProductImages = true,
    this.compactMode = false,
    this.sortingPreference = 'category',
    this.enableQuickActions = true,
    this.categoryVisibility = const {},
    this.enableSmartSuggestions = true,
    this.maxItemsPerCategory = 10,
  });

  // Crear desde Map (para SharedPreferences)
  factory ShoppingListPreferences.fromMap(Map<String, dynamic> map) {
    return ShoppingListPreferences(
      showPurchased: map['showPurchased'] ?? true,
      isListView: map['isListView'] ?? false,
      showInventorySuggestions: map['showInventorySuggestions'] ?? true,
      showInventoryItems: map['showInventoryItems'] ?? false,
      
      theme: ShoppingListTheme.values.firstWhere(
        (t) => t.name == (map['theme'] ?? 'default_'),
        orElse: () => ShoppingListTheme.default_,
      ),
      backgroundStyle: map['backgroundStyle'] ?? 'default',
      enableAnimations: map['enableAnimations'] ?? true,
      enableHapticFeedback: map['enableHapticFeedback'] ?? true,
      
      autoExpandCategories: map['autoExpandCategories'] ?? false,
      groupByCategory: map['groupByCategory'] ?? true,
      showItemDetails: map['showItemDetails'] ?? true,
      enableSwipeActions: map['enableSwipeActions'] ?? true,
      widgetPreferences: Map<String, dynamic>.from(map['widgetPreferences'] ?? {}),
      favoriteWidgets: List<String>.from(map['favoriteWidgets'] ?? ['quick_add', 'recent_items', 'suggestions']),
      widgetOrder: Map<String, int>.from(map['widgetOrder'] ?? {'quick_add': 0, 'recent_items': 1, 'suggestions': 2}),
      enableCustomWidgets: map['enableCustomWidgets'] ?? true,
      cardBorderRadius: (map['cardBorderRadius'] ?? 12.0).toDouble(),
      cardElevation: (map['cardElevation'] ?? 2.0).toDouble(),
      showProductImages: map['showProductImages'] ?? true,
      compactMode: map['compactMode'] ?? false,
      sortingPreference: map['sortingPreference'] ?? 'category',
      enableQuickActions: map['enableQuickActions'] ?? true,
      categoryVisibility: Map<String, bool>.from(map['categoryVisibility'] ?? {}),
      enableSmartSuggestions: map['enableSmartSuggestions'] ?? true,
      maxItemsPerCategory: map['maxItemsPerCategory'] ?? 10,
    );
  }

  // Convertir a Map (para SharedPreferences)
  Map<String, dynamic> toMap() {
    return {
      'showPurchased': showPurchased,
      'isListView': isListView,
      'showInventorySuggestions': showInventorySuggestions,
      'showInventoryItems': showInventoryItems,
      
      'theme': theme.name,
      'backgroundStyle': backgroundStyle,
      'enableAnimations': enableAnimations,
      'enableHapticFeedback': enableHapticFeedback,
      
      'autoExpandCategories': autoExpandCategories,
      'groupByCategory': groupByCategory,
      'showItemDetails': showItemDetails,
      'enableSwipeActions': enableSwipeActions,
      'widgetPreferences': widgetPreferences,
      'favoriteWidgets': favoriteWidgets,
      'widgetOrder': widgetOrder,
      'enableCustomWidgets': enableCustomWidgets,
      'cardBorderRadius': cardBorderRadius,
      'cardElevation': cardElevation,
      'showProductImages': showProductImages,
      'compactMode': compactMode,
      'sortingPreference': sortingPreference,
      'enableQuickActions': enableQuickActions,
      'categoryVisibility': categoryVisibility,
      'enableSmartSuggestions': enableSmartSuggestions,
      'maxItemsPerCategory': maxItemsPerCategory,
    };
  }

  // Método para copiar con cambios
  ShoppingListPreferences copyWith({
    bool? showPurchased,
    bool? isListView,
    bool? showInventorySuggestions,
    bool? showInventoryItems,
    ShoppingListTheme? theme,
    String? backgroundStyle,
    bool? enableAnimations,
    bool? enableHapticFeedback,
    bool? autoExpandCategories,
    bool? groupByCategory,
    bool? showItemDetails,
    bool? enableSwipeActions,
    Map<String, dynamic>? widgetPreferences,
    List<String>? favoriteWidgets,
    Map<String, int>? widgetOrder,
    bool? enableCustomWidgets,
    double? cardBorderRadius,
    double? cardElevation,
    bool? showProductImages,
    bool? compactMode,
    String? sortingPreference,
    bool? enableQuickActions,
    Map<String, bool>? categoryVisibility,
    bool? enableSmartSuggestions,
    int? maxItemsPerCategory,
  }) {
    return ShoppingListPreferences(
      showPurchased: showPurchased ?? this.showPurchased,
      isListView: isListView ?? this.isListView,
      showInventorySuggestions: showInventorySuggestions ?? this.showInventorySuggestions,
      showInventoryItems: showInventoryItems ?? this.showInventoryItems,
      theme: theme ?? this.theme,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      autoExpandCategories: autoExpandCategories ?? this.autoExpandCategories,
      groupByCategory: groupByCategory ?? this.groupByCategory,
      showItemDetails: showItemDetails ?? this.showItemDetails,
      enableSwipeActions: enableSwipeActions ?? this.enableSwipeActions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShoppingListPreferences &&
        other.showPurchased == showPurchased &&
        other.isListView == isListView &&
        other.showInventorySuggestions == showInventorySuggestions &&
        other.showInventoryItems == showInventoryItems &&
        other.theme == theme &&
        other.backgroundStyle == backgroundStyle &&
        other.enableAnimations == enableAnimations &&
        other.enableHapticFeedback == enableHapticFeedback &&
        other.autoExpandCategories == autoExpandCategories &&
        other.groupByCategory == groupByCategory &&
        other.showItemDetails == showItemDetails &&
        other.enableSwipeActions == enableSwipeActions;
  }

  @override
  int get hashCode {
    return Object.hash(
      showPurchased,
      isListView,
      showInventorySuggestions,
      showInventoryItems,
      theme,
      backgroundStyle,
      enableAnimations,
      enableHapticFeedback,
      autoExpandCategories,
      groupByCategory,
      showItemDetails,
      enableSwipeActions,
    );
  }
}

// Enum para temas de Shopping List
enum ShoppingListTheme {
  default_('default', 'Por Defecto', AppTheme.coralMain, AppTheme.backgroundGrey),
  ocean('ocean', 'Océano', AppTheme.softTeal, Color(0xFFF0F9FF)),
  sunset('sunset', 'Atardecer', Color(0xFFFF6B6B), Color(0xFFFFF5F5)),
  forest('forest', 'Bosque', Color(0xFF4ECDC4), Color(0xFFF0FDFA)),
  lavender('lavender', 'Lavanda', Color(0xFF9B59B6), Color(0xFFFAF5FF)),
  golden('golden', 'Dorado', Color(0xFFFFB74D), Color(0xFFFFFBF0)),
  rose('rose', 'Rosa', Color(0xFFE91E63), Color(0xFFFCF4FF)),
  mint('mint', 'Menta', Color(0xFF26A69A), Color(0xFFF0FDF4));

  const ShoppingListTheme(this.name, this.displayName, this.primaryColor, this.backgroundColor);
  
  final String name;
  final String displayName;
  final Color primaryColor;
  final Color backgroundColor;
  
  // Obtener colores secundarios basados en el color primario
  Color get secondaryColor => primaryColor.withOpacity(0.1);
  Color get accentColor => primaryColor.withOpacity(0.8);
  
  // Gradientes para fondos
  LinearGradient get backgroundGradient {
    switch (this) {
      case ShoppingListTheme.ocean:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
        );
      case ShoppingListTheme.sunset:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF5F5), Color(0xFFFEE2E2), Color(0xFFFECACA)],
        );
      case ShoppingListTheme.forest:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDFA), Color(0xFFCCFBF1), Color(0xFF99F6E4)],
        );
      case ShoppingListTheme.lavender:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF), Color(0xFFE9D5FF)],
        );
      case ShoppingListTheme.golden:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBF0), Color(0xFFFEF3C7), Color(0xFFFDE68A)],
        );
      case ShoppingListTheme.rose:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFCF4FF), Color(0xFFFAE8FF), Color(0xFFF5D0FE)],
        );
      case ShoppingListTheme.mint:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
        );
      default:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.backgroundGrey, AppTheme.lightGrey.withOpacity(0.3)],
        );
    }
  }
}

// Estilos de fondo disponibles
enum BackgroundStyle {
  solid('solid', 'Sólido'),
  gradient('gradient', 'Degradado'),
  pattern('pattern', 'Patrón Sutil');

  const BackgroundStyle(this.value, this.displayName);
  
  final String value;
  final String displayName;
}