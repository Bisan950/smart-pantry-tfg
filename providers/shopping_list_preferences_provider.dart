// lib/providers/shopping_list_preferences_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/shopping_list_preferences_model.dart';
import '../services/preferences_service.dart';
import '../services/auth_service.dart';
import '../services/user_preferences_service.dart';

class ShoppingListPreferencesProvider with ChangeNotifier {
  ShoppingListPreferences _preferences = const ShoppingListPreferences();
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _currentUserId;
  
  late UserPreferencesService _userPreferencesService;
  
  // Getters
  ShoppingListPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  
  // Getters específicos para facilitar el acceso
  bool get showPurchased => _preferences.showPurchased;
  bool get isListView => _preferences.isListView;
  bool get showInventorySuggestions => _preferences.showInventorySuggestions;
  bool get showInventoryItems => _preferences.showInventoryItems;
  ShoppingListTheme get theme => _preferences.theme;
  String get backgroundStyle => _preferences.backgroundStyle;
  bool get enableAnimations => _preferences.enableAnimations;
  bool get enableHapticFeedback => _preferences.enableHapticFeedback;
  bool get autoExpandCategories => _preferences.autoExpandCategories;
  bool get groupByCategory => _preferences.groupByCategory;
  bool get showItemDetails => _preferences.showItemDetails;
  bool get enableSwipeActions => _preferences.enableSwipeActions;
  
  // Constructor
  ShoppingListPreferencesProvider() {
    _initializePreferences();
  }
  
  /// Inicializar el provider cargando las preferencias del usuario actual
  Future<void> _initializePreferences() async {
    try {
      _setLoading(true);
      _userPreferencesService = await UserPreferencesService.getInstance();
      
      // Obtener el ID del usuario actual
      final authService = AuthService();
      _currentUserId = authService.currentUser?.uid;
      
      if (_currentUserId != null) {
        _preferences = await _userPreferencesService.loadUserShoppingPreferences();
        print('Preferencias cargadas para usuario: $_currentUserId');
      } else {
        _preferences = const ShoppingListPreferences();
        print('Usuario no autenticado, usando preferencias por defecto');
      }
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('Shopping List Preferences cargadas: ${_preferences.toMap()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar preferencias: $e');
      }
      _preferences = const ShoppingListPreferences();
      _isInitialized = true;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Cambiar usuario (llamar cuando el usuario inicie/cierre sesión)
  Future<void> switchUser(String? newUserId) async {
    if (_currentUserId != newUserId) {
      _currentUserId = newUserId;
      await _initializePreferences();
    }
  }
  
  /// Sincronizar preferencias entre dispositivos
  Future<void> syncPreferences() async {
    if (_currentUserId != null) {
      try {
        final success = await _userPreferencesService.syncPreferences();
        if (success) {
          _preferences = await _userPreferencesService.loadUserShoppingPreferences();
          notifyListeners();
        }
      } catch (e) {
        print('Error al sincronizar preferencias: $e');
      }
    }
  }
  
  // Métodos para actualizar preferencias específicas de widgets
  Future<void> updateWidgetPreference(String widgetId, dynamic value) async {
    final updatedWidgetPrefs = Map<String, dynamic>.from(_preferences.widgetPreferences);
    updatedWidgetPrefs[widgetId] = value;
    
    await _updatePreference(
      'widgetPreferences',
      updatedWidgetPrefs,
      (value) => _preferences.copyWith(widgetPreferences: value),
    );
  }
  
  Future<void> updateFavoriteWidgets(List<String> widgets) async {
    await _updatePreference(
      'favoriteWidgets',
      widgets,
      (value) => _preferences.copyWith(favoriteWidgets: value),
    );
  }
  
  Future<void> updateWidgetOrder(Map<String, int> order) async {
    await _updatePreference(
      'widgetOrder',
      order,
      (value) => _preferences.copyWith(widgetOrder: value),
    );
  }
  
  Future<void> toggleCustomWidgets() async {
    await _updatePreference(
      'enableCustomWidgets',
      !_preferences.enableCustomWidgets,
      (value) => _preferences.copyWith(enableCustomWidgets: value),
    );
  }
  
  Future<void> updateCardBorderRadius(double radius) async {
    await _updatePreference(
      'cardBorderRadius',
      radius,
      (value) => _preferences.copyWith(cardBorderRadius: value),
    );
  }
  
  Future<void> updateCardElevation(double elevation) async {
    await _updatePreference(
      'cardElevation',
      elevation,
      (value) => _preferences.copyWith(cardElevation: value),
    );
  }
  
  Future<void> toggleProductImages() async {
    await _updatePreference(
      'showProductImages',
      !_preferences.showProductImages,
      (value) => _preferences.copyWith(showProductImages: value),
    );
  }
  
  Future<void> toggleCompactMode() async {
    await _updatePreference(
      'compactMode',
      !_preferences.compactMode,
      (value) => _preferences.copyWith(compactMode: value),
    );
  }
  
  Future<void> updateSortingPreference(String sorting) async {
    await _updatePreference(
      'sortingPreference',
      sorting,
      (value) => _preferences.copyWith(sortingPreference: value),
    );
  }
  
  Future<void> toggleQuickActions() async {
    await _updatePreference(
      'enableQuickActions',
      !_preferences.enableQuickActions,
      (value) => _preferences.copyWith(enableQuickActions: value),
    );
  }
  
  Future<void> updateCategoryVisibility(String category, bool visible) async {
    final updatedVisibility = Map<String, bool>.from(_preferences.categoryVisibility);
    updatedVisibility[category] = visible;
    
    await _updatePreference(
      'categoryVisibility',
      updatedVisibility,
      (value) => _preferences.copyWith(categoryVisibility: value),
    );
  }
  
  Future<void> toggleSmartSuggestions() async {
    await _updatePreference(
      'enableSmartSuggestions',
      !_preferences.enableSmartSuggestions,
      (value) => _preferences.copyWith(enableSmartSuggestions: value),
    );
  }
  
  Future<void> updateMaxItemsPerCategory(int maxItems) async {
    await _updatePreference(
      'maxItemsPerCategory',
      maxItems,
      (value) => _preferences.copyWith(maxItemsPerCategory: value),
    );
  }
  
  /// Alternar mostrar productos comprados
  Future<void> toggleShowPurchased() async {
    await _updatePreference(
      'showPurchased',
      !_preferences.showPurchased,
      (value) => _preferences.copyWith(showPurchased: value),
    );
  }
  
  /// Alternar vista de lista/categorías
  Future<void> toggleListView() async {
    await _updatePreference(
      'isListView',
      !_preferences.isListView,
      (value) => _preferences.copyWith(isListView: value),
    );
  }
  
  /// Alternar sugerencias de inventario
  Future<void> toggleInventorySuggestions() async {
    await _updatePreference(
      'showInventorySuggestions',
      !_preferences.showInventorySuggestions,
      (value) => _preferences.copyWith(showInventorySuggestions: value),
    );
  }
  
  /// Alternar vista expandida de inventario
  Future<void> toggleInventoryItems() async {
    await _updatePreference(
      'showInventoryItems',
      !_preferences.showInventoryItems,
      (value) => _preferences.copyWith(showInventoryItems: value),
    );
  }
  
  /// Cambiar tema
  Future<void> changeTheme(ShoppingListTheme newTheme) async {
    await _updatePreference(
      'theme',
      newTheme.name,
      (value) => _preferences.copyWith(theme: newTheme),
    );
    
    // Feedback háptico si está habilitado
    if (_preferences.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }
  
  /// Cambiar estilo de fondo
  Future<void> changeBackgroundStyle(String newStyle) async {
    await _updatePreference(
      'backgroundStyle',
      newStyle,
      (value) => _preferences.copyWith(backgroundStyle: newStyle),
    );
  }
  
  /// Alternar animaciones
  Future<void> toggleAnimations() async {
    await _updatePreference(
      'enableAnimations',
      !_preferences.enableAnimations,
      (value) => _preferences.copyWith(enableAnimations: value),
    );
  }
  
  /// Alternar feedback háptico
  Future<void> toggleHapticFeedback() async {
    await _updatePreference(
      'enableHapticFeedback',
      !_preferences.enableHapticFeedback,
      (value) => _preferences.copyWith(enableHapticFeedback: value),
    );
  }
  
  /// Alternar expansión automática de categorías
  Future<void> toggleAutoExpandCategories() async {
    await _updatePreference(
      'autoExpandCategories',
      !_preferences.autoExpandCategories,
      (value) => _preferences.copyWith(autoExpandCategories: value),
    );
  }
  
  /// Alternar agrupación por categoría
  Future<void> toggleGroupByCategory() async {
    await _updatePreference(
      'groupByCategory',
      !_preferences.groupByCategory,
      (value) => _preferences.copyWith(groupByCategory: value),
    );
  }
  
  /// Alternar mostrar detalles de items
  Future<void> toggleShowItemDetails() async {
    await _updatePreference(
      'showItemDetails',
      !_preferences.showItemDetails,
      (value) => _preferences.copyWith(showItemDetails: value),
    );
  }
  
  /// Alternar acciones de deslizar
  Future<void> toggleSwipeActions() async {
    await _updatePreference(
      'enableSwipeActions',
      !_preferences.enableSwipeActions,
      (value) => _preferences.copyWith(enableSwipeActions: value),
    );
  }
  
  // === MÉTODOS PARA CONFIGURACIONES MÚLTIPLES ===
  
  /// Aplicar un preset de configuración
  Future<void> applyPreset(ShoppingListPreferencesPreset preset) async {
    ShoppingListPreferences newPrefs;
    
    switch (preset) {
      case ShoppingListPreferencesPreset.minimal:
        newPrefs = _preferences.copyWith(
          isListView: true,
          showItemDetails: false,
          enableAnimations: false,
          showInventorySuggestions: false,
        );
        break;
      case ShoppingListPreferencesPreset.detailed:
        newPrefs = _preferences.copyWith(
          isListView: false,
          showItemDetails: true,
          enableAnimations: true,
          showInventorySuggestions: true,
          autoExpandCategories: true,
        );
        break;
      case ShoppingListPreferencesPreset.performance:
        newPrefs = _preferences.copyWith(
          enableAnimations: false,
          showInventorySuggestions: false,
          enableHapticFeedback: false,
        );
        break;
      case ShoppingListPreferencesPreset.accessible:
        newPrefs = _preferences.copyWith(
          showItemDetails: true,
          enableHapticFeedback: true,
          autoExpandCategories: true,
        );
        break;
    }
    
    await _savePreferences(newPrefs);
    _preferences = newPrefs;
    notifyListeners();
  }
  
  /// Resetear todas las preferencias a valores por defecto
  Future<void> resetToDefault() async {
    try {
      _setLoading(true);
      const defaultPrefs = ShoppingListPreferences();
      await _savePreferences(defaultPrefs);
      _preferences = defaultPrefs;
      
      if (_preferences.enableHapticFeedback) {
        HapticFeedback.mediumImpact();
      }
      
      if (kDebugMode) {
        print('Preferencias reseteadas a valores por defecto');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al resetear preferencias: $e');
      }
    } finally {
      _setLoading(false);
    }
  }
  
  // === MÉTODOS PRIVADOS ===
  
  /// Método genérico para actualizar preferencias
  Future<void> _updatePreference<T>(
    String key,
    T value,
    ShoppingListPreferences Function(T) updateFunction,
  ) async {
    if (_currentUserId == null) {
      print('No se puede actualizar preferencia: usuario no autenticado');
      return;
    }
    
    try {
      _setLoading(true);
      
      final newPrefs = updateFunction(value);
      await _savePreferences(newPrefs);
      
      _preferences = newPrefs;
      
      if (kDebugMode) {
        print('Preferencia $key actualizada para usuario $_currentUserId: $value');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al actualizar preferencia $key: $e');
      }
    } finally {
      _setLoading(false);
    }
  }
  
  /// Guardar preferencias usando el servicio de usuario
  Future<void> _savePreferences(ShoppingListPreferences newPrefs) async {
    final success = await _userPreferencesService.saveUserShoppingPreferences(newPrefs);
    if (!success) {
      throw Exception('Error al guardar preferencias del usuario');
    }
  }
  
  /// Control de estado de carga
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // === UTILIDADES ===
  
  /// Obtener información de las preferencias actuales
  Map<String, dynamic> getPreferencesInfo() {
    return {
      'preferences': _preferences.toMap(),
      'isInitialized': _isInitialized,
      'isLoading': _isLoading,
      'theme': _preferences.theme.displayName,
      'themeColors': {
        'primary': _preferences.theme.primaryColor.value,
        'background': _preferences.theme.backgroundColor.value,
      },
    };
  }
  
  /// Verificar si una configuración específica está habilitada
  bool isConfigEnabled(String configKey) {
    switch (configKey.toLowerCase()) {
      case 'showpurchased':
        return _preferences.showPurchased;
      case 'listview':
        return _preferences.isListView;
      case 'inventorysuggestions':
        return _preferences.showInventorySuggestions;
      case 'animations':
        return _preferences.enableAnimations;
      case 'hapticfeedback':
        return _preferences.enableHapticFeedback;
      case 'autoexpand':
        return _preferences.autoExpandCategories;
      case 'groupbycategory':
        return _preferences.groupByCategory;
      case 'itemdetails':
        return _preferences.showItemDetails;
      case 'swipeactions':
        return _preferences.enableSwipeActions;
      default:
        return false;
    }
  }
  
  /// Exportar preferencias actuales
  Future<Map<String, dynamic>> exportPreferences() async {
    return {
      'shopping_list_preferences': _preferences.toMap(),
      'export_timestamp': DateTime.now().toIso8601String(),
      'version': '1.0.0',
    };
  }
  
  /// Importar preferencias desde un mapa
  Future<bool> importPreferences(Map<String, dynamic> data) async {
    try {
      if (data.containsKey('shopping_list_preferences')) {
        final prefsData = data['shopping_list_preferences'] as Map<String, dynamic>;
        final newPrefs = ShoppingListPreferences.fromMap(prefsData);
        await _savePreferences(newPrefs);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error al importar preferencias: $e');
      }
      return false;
    }
  }
}

// Enum para presets de configuración
enum ShoppingListPreferencesPreset {
  minimal,
  detailed,
  performance,
  accessible,
}

extension ShoppingListPreferencesPresetExtension on ShoppingListPreferencesPreset {
  String get displayName {
    switch (this) {
      case ShoppingListPreferencesPreset.minimal:
        return 'Minimalista';
      case ShoppingListPreferencesPreset.detailed:
        return 'Detallado';
      case ShoppingListPreferencesPreset.performance:
        return 'Rendimiento';
      case ShoppingListPreferencesPreset.accessible:
        return 'Accesible';
    }
  }
  
  String get description {
    switch (this) {
      case ShoppingListPreferencesPreset.minimal:
        return 'Vista simple y limpia con menos elementos';
      case ShoppingListPreferencesPreset.detailed:
        return 'Muestra toda la información disponible';
      case ShoppingListPreferencesPreset.performance:
        return 'Optimizado para dispositivos lentos';
      case ShoppingListPreferencesPreset.accessible:
        return 'Configuración para mejor accesibilidad';
    }
  }
}