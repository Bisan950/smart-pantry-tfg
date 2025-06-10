// lib/services/preferences_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shopping_list_preferences_model.dart';

class PreferencesService {
  static const String _shoppingListPrefsKey = 'shopping_list_preferences';
  static const String _globalPrefsKey = 'global_preferences';
  
  static PreferencesService? _instance;
  static SharedPreferences? _prefs;
  
  PreferencesService._();
  
  static Future<PreferencesService> getInstance() async {
    _instance ??= PreferencesService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }
  
  // === SHOPPING LIST PREFERENCES ===
  
  /// Guardar preferencias de Shopping List
  Future<bool> saveShoppingListPreferences(ShoppingListPreferences preferences) async {
    try {
      final prefsMap = preferences.toMap();
      final prefsJson = jsonEncode(prefsMap);
      return await _prefs!.setString(_shoppingListPrefsKey, prefsJson);
    } catch (e) {
      print('Error al guardar preferencias de Shopping List: $e');
      return false;
    }
  }
  
  /// Cargar preferencias de Shopping List
  Future<ShoppingListPreferences> loadShoppingListPreferences() async {
    try {
      final prefsJson = _prefs!.getString(_shoppingListPrefsKey);
      
      if (prefsJson == null || prefsJson.isEmpty) {
        return const ShoppingListPreferences(); // Preferencias por defecto
      }
      
      final prefsMap = jsonDecode(prefsJson) as Map<String, dynamic>;
      return ShoppingListPreferences.fromMap(prefsMap);
    } catch (e) {
      print('Error al cargar preferencias de Shopping List: $e');
      return const ShoppingListPreferences(); // Preferencias por defecto en caso de error
    }
  }
  
  /// Actualizar una preferencia específica de Shopping List
  Future<bool> updateShoppingListPreference<T>(String key, T value) async {
    try {
      final currentPrefs = await loadShoppingListPreferences();
      final prefsMap = currentPrefs.toMap();
      prefsMap[key] = value;
      
      final updatedPrefs = ShoppingListPreferences.fromMap(prefsMap);
      return await saveShoppingListPreferences(updatedPrefs);
    } catch (e) {
      print('Error al actualizar preferencia $key: $e');
      return false;
    }
  }
  
  /// Resetear preferencias de Shopping List a valores por defecto
  Future<bool> resetShoppingListPreferences() async {
    try {
      const defaultPrefs = ShoppingListPreferences();
      return await saveShoppingListPreferences(defaultPrefs);
    } catch (e) {
      print('Error al resetear preferencias de Shopping List: $e');
      return false;
    }
  }
  
  // === GLOBAL PREFERENCES ===
  
  /// Guardar preferencia global
  Future<bool> saveGlobalPreference(String key, dynamic value) async {
    try {
      final globalPrefs = await loadGlobalPreferences();
      globalPrefs[key] = value;
      
      final prefsJson = jsonEncode(globalPrefs);
      return await _prefs!.setString(_globalPrefsKey, prefsJson);
    } catch (e) {
      print('Error al guardar preferencia global $key: $e');
      return false;
    }
  }
  
  /// Cargar preferencias globales
  Future<Map<String, dynamic>> loadGlobalPreferences() async {
    try {
      final prefsJson = _prefs!.getString(_globalPrefsKey);
      
      if (prefsJson == null || prefsJson.isEmpty) {
        return <String, dynamic>{};
      }
      
      return jsonDecode(prefsJson) as Map<String, dynamic>;
    } catch (e) {
      print('Error al cargar preferencias globales: $e');
      return <String, dynamic>{};
    }
  }
  
  /// Obtener una preferencia global específica
  Future<T?> getGlobalPreference<T>(String key, {T? defaultValue}) async {
    try {
      final globalPrefs = await loadGlobalPreferences();
      return globalPrefs[key] as T? ?? defaultValue;
    } catch (e) {
      print('Error al obtener preferencia global $key: $e');
      return defaultValue;
    }
  }
  
  // === UTILIDADES ===
  
  /// Limpiar todas las preferencias
  Future<bool> clearAllPreferences() async {
    try {
      await _prefs!.remove(_shoppingListPrefsKey);
      await _prefs!.remove(_globalPrefsKey);
      return true;
    } catch (e) {
      print('Error al limpiar preferencias: $e');
      return false;
    }
  }
  
  /// Verificar si existen preferencias guardadas
  bool hasShoppingListPreferences() {
    return _prefs!.containsKey(_shoppingListPrefsKey);
  }
  
  /// Exportar todas las preferencias (para backup)
  Future<Map<String, dynamic>> exportAllPreferences() async {
    try {
      final shoppingListPrefs = await loadShoppingListPreferences();
      final globalPrefs = await loadGlobalPreferences();
      
      return {
        'shopping_list': shoppingListPrefs.toMap(),
        'global': globalPrefs,
        'export_date': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      };
    } catch (e) {
      print('Error al exportar preferencias: $e');
      return {};
    }
  }
  
  /// Importar preferencias (desde backup)
  Future<bool> importPreferences(Map<String, dynamic> data) async {
    try {
      if (data.containsKey('shopping_list')) {
        final shoppingListData = data['shopping_list'] as Map<String, dynamic>;
        final shoppingListPrefs = ShoppingListPreferences.fromMap(shoppingListData);
        await saveShoppingListPreferences(shoppingListPrefs);
      }
      
      if (data.containsKey('global')) {
        final globalData = data['global'] as Map<String, dynamic>;
        final globalJson = jsonEncode(globalData);
        await _prefs!.setString(_globalPrefsKey, globalJson);
      }
      
      return true;
    } catch (e) {
      print('Error al importar preferencias: $e');
      return false;
    }
  }
  
  // === MÉTODOS DE CONVENIENCIA PARA SHOPPING LIST ===
  
  /// Alternar vista de productos comprados
  Future<bool> toggleShowPurchased() async {
    final currentPrefs = await loadShoppingListPreferences();
    return await updateShoppingListPreference('showPurchased', !currentPrefs.showPurchased);
  }
  
  /// Alternar vista de lista/categorías
  Future<bool> toggleListView() async {
    final currentPrefs = await loadShoppingListPreferences();
    return await updateShoppingListPreference('isListView', !currentPrefs.isListView);
  }
  
  /// Alternar sugerencias de inventario
  Future<bool> toggleInventorySuggestions() async {
    final currentPrefs = await loadShoppingListPreferences();
    return await updateShoppingListPreference('showInventorySuggestions', !currentPrefs.showInventorySuggestions);
  }
  
  /// Cambiar tema de Shopping List
  Future<bool> changeShoppingListTheme(ShoppingListTheme theme) async {
    return await updateShoppingListPreference('theme', theme.name);
  }
  
  /// Cambiar estilo de fondo
  Future<bool> changeBackgroundStyle(String style) async {
    return await updateShoppingListPreference('backgroundStyle', style);
  }
  
  /// Alternar animaciones
  Future<bool> toggleAnimations() async {
    final currentPrefs = await loadShoppingListPreferences();
    return await updateShoppingListPreference('enableAnimations', !currentPrefs.enableAnimations);
  }
  
  /// Alternar feedback háptico
  Future<bool> toggleHapticFeedback() async {
    final currentPrefs = await loadShoppingListPreferences();
    return await updateShoppingListPreference('enableHapticFeedback', !currentPrefs.enableHapticFeedback);
  }
}