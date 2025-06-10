import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shopping_list_preferences_model.dart';
import '../services/auth_service.dart';

class UserPreferencesService {
  static UserPreferencesService? _instance;
  static SharedPreferences? _prefs;
  static FirebaseFirestore? _firestore;
  
  UserPreferencesService._();
  
  static Future<UserPreferencesService> getInstance() async {
    _instance ??= UserPreferencesService._();
    _prefs ??= await SharedPreferences.getInstance();
    _firestore ??= FirebaseFirestore.instance;
    return _instance!;
  }
  
  /// Obtener el ID del usuario actual
  Future<String?> _getCurrentUserId() async {
    final authService = AuthService();
    final currentUser = authService.currentUser;
    return currentUser?.uid;
  }
  
  /// Clave única para las preferencias del usuario
  String _getUserPreferencesKey(String userId) {
    return 'user_${userId}_shopping_preferences';
  }
  
  /// Guardar preferencias del usuario (local y en la nube)
  Future<bool> saveUserShoppingPreferences(ShoppingListPreferences preferences) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return false;
      
      final prefsMap = preferences.toMap();
      final prefsJson = jsonEncode(prefsMap);
      
      // Guardar localmente
      final localSuccess = await _prefs!.setString(_getUserPreferencesKey(userId), prefsJson);
      
      // Guardar en Firestore para sincronización entre dispositivos
      try {
        await _firestore!.collection('users').doc(userId).update({
          'shoppingPreferences': prefsMap,
          'lastPreferencesUpdate': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error al sincronizar preferencias en la nube: $e');
        // Continuar aunque falle la sincronización
      }
      
      return localSuccess;
    } catch (e) {
      print('Error al guardar preferencias del usuario: $e');
      return false;
    }
  }
  
  /// Cargar preferencias del usuario
  Future<ShoppingListPreferences> loadUserShoppingPreferences() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return const ShoppingListPreferences();
      
      // Intentar cargar desde local primero
      final localPrefsJson = _prefs!.getString(_getUserPreferencesKey(userId));
      
      if (localPrefsJson != null && localPrefsJson.isNotEmpty) {
        final prefsMap = jsonDecode(localPrefsJson) as Map<String, dynamic>;
        return ShoppingListPreferences.fromMap(prefsMap);
      }
      
      // Si no hay preferencias locales, intentar cargar desde Firestore
      try {
        final userDoc = await _firestore!.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data()?['shoppingPreferences'] != null) {
          final cloudPrefs = userDoc.data()!['shoppingPreferences'] as Map<String, dynamic>;
          final preferences = ShoppingListPreferences.fromMap(cloudPrefs);
          
          // Guardar localmente para futuras cargas
          await _prefs!.setString(_getUserPreferencesKey(userId), jsonEncode(cloudPrefs));
          
          return preferences;
        }
      } catch (e) {
        print('Error al cargar preferencias desde la nube: $e');
      }
      
      return const ShoppingListPreferences();
    } catch (e) {
      print('Error al cargar preferencias del usuario: $e');
      return const ShoppingListPreferences();
    }
  }
  
  /// Sincronizar preferencias entre dispositivos
  Future<bool> syncPreferences() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return false;
      
      final userDoc = await _firestore!.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?['shoppingPreferences'] != null) {
        final cloudPrefs = userDoc.data()!['shoppingPreferences'] as Map<String, dynamic>;
        final preferences = ShoppingListPreferences.fromMap(cloudPrefs);
        
        // Actualizar preferencias locales
        final prefsJson = jsonEncode(cloudPrefs);
        await _prefs!.setString(_getUserPreferencesKey(userId), prefsJson);
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error al sincronizar preferencias: $e');
      return false;
    }
  }
  
  /// Resetear preferencias del usuario
  Future<bool> resetUserPreferences() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return false;
      
      const defaultPrefs = ShoppingListPreferences();
      return await saveUserShoppingPreferences(defaultPrefs);
    } catch (e) {
      print('Error al resetear preferencias del usuario: $e');
      return false;
    }
  }
  
  /// Exportar preferencias del usuario
  Future<Map<String, dynamic>> exportUserPreferences() async {
    final preferences = await loadUserShoppingPreferences();
    final userId = await _getCurrentUserId();
    
    return {
      'userId': userId,
      'exportDate': DateTime.now().toIso8601String(),
      'preferences': preferences.toMap(),
      'version': '1.0',
    };
  }
  
  /// Importar preferencias del usuario
  Future<bool> importUserPreferences(Map<String, dynamic> data) async {
    try {
      if (data['preferences'] != null) {
        final preferences = ShoppingListPreferences.fromMap(data['preferences']);
        return await saveUserShoppingPreferences(preferences);
      }
      return false;
    } catch (e) {
      print('Error al importar preferencias: $e');
      return false;
    }
  }
}