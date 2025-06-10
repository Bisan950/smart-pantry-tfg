// lib/services/expiry_settings_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expiry_settings_model.dart';

class ExpirySettingsService {
  // Singleton
  static final ExpirySettingsService _instance = ExpirySettingsService._internal();
  factory ExpirySettingsService() => _instance;
  ExpirySettingsService._internal();

  // Referencia al usuario actual
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Referencia a la colección de configuraciones
  DocumentReference? get _userSettingsRef {
    final userId = _userId;
    if (userId == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('expiry');
  }

  // Obtener configuraciones actuales
  Future<ExpirySettings> getSettings() async {
    try {
      final userId = _userId;
      if (userId == null) {
        return ExpirySettings(userId: '');
      }

      final docSnapshot = await _userSettingsRef?.get();
      
      if (docSnapshot == null || !docSnapshot.exists) {
        // Crear configuraciones por defecto si no existen
        final defaultSettings = ExpirySettings(userId: userId);
        await saveSettings(defaultSettings);
        return defaultSettings;
      }
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      return ExpirySettings.fromMap({
        'userId': userId,
        ...data,
      });
    } catch (e) {
      print('Error al obtener configuraciones de caducidad: $e');
      return ExpirySettings(userId: _userId ?? '');
    }
  }

  // Guardar configuraciones
  Future<void> saveSettings(ExpirySettings settings) async {
    try {
      if (_userSettingsRef == null) {
        throw Exception('Usuario no autenticado');
      }
      
      await _userSettingsRef!.set(settings.toMap());
    } catch (e) {
      print('Error al guardar configuraciones de caducidad: $e');
      rethrow;
    }
  }
}