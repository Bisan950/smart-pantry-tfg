// lib/providers/auth_provider.dart - Actualizado con soporte para avatares

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/firebase_error_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provider para gestionar el estado de autenticación en toda la aplicación
/// ACTUALIZADO: Incluye mejor soporte para avatares
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  
  // Estado interno
  UserModel? _user;
  bool _isLoading = false;
  String _error = '';
  bool _isInitialized = false;
  
  // Getters
  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get userId => _user?.id ?? '';
  bool get isInitialized => _isInitialized;
  
  // Constructor
  AuthProvider() {
    _initialize();
  }
  
  // Inicialización mejorada
  // En el método _initialize, cambiar la lógica:
  Future<void> _initialize() async {
    _isLoading = true;
    
    try {
      // Dar tiempo para que Firebase Auth se inicialice
      await Future.delayed(Duration(milliseconds: 500));
      
      // CAMBIO: Usar la misma lógica que la versión antigua
      final hasSession = await _authService.hasActiveSession();
      if (hasSession) {
        print('Sesión guardada detectada. Intentando restaurar...');
        final autoLoginResult = await _authService.autoSignIn();
        
        if (autoLoginResult['success'] == true) {
          if (autoLoginResult['userModel'] != null) {
            _user = autoLoginResult['userModel'];
            print('Sesión restaurada exitosamente para ${_user?.email}');
          }
        } else {
          print('Error al restaurar sesión: ${autoLoginResult['error']}');
          await _authService.clearSession();
        }
      }
    } catch (e) {
      print('Error en restauración automática: $e');
    }
    notifyListeners();
    
    // Suscribirse a los cambios de estado de autenticación
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
      } else {
        // Solo actualizar si no tenemos usuario o es diferente
        if (_user == null || _user!.id != firebaseUser.uid) {
          try {
            final userDoc = await _firestoreService.users.doc(firebaseUser.uid).get();
            
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              
              _user = UserModel(
                id: firebaseUser.uid,
                email: userData['email'] as String,
                name: userData['name'] as String,
                photoUrl: userData['photoUrl'] as String? ?? '',
                avatarId: userData['avatarId'] as String?,
                favoriteRecipes: List<String>.from(userData['favoriteRecipes'] ?? []),
                preferences: Map<String, dynamic>.from(userData['preferences'] ?? {}),
              );
            } else {
              _user = UserModel(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? '',
                name: firebaseUser.displayName ?? 'Usuario',
                photoUrl: firebaseUser.photoURL ?? '',
              );
              
              await _createUserDocument(firebaseUser);
            }
          } catch (e) {
            print('Error al obtener datos del usuario: $e');
            _user = UserModel(
              id: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              name: firebaseUser.displayName ?? 'Usuario',
              photoUrl: firebaseUser.photoURL ?? '',
            );
          }
        }
      }
      
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }, onError: (e) {
      _error = 'Error en la autenticación: $e';
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    });
  }
  
  // Método para crear el documento del usuario si no existe
  Future<void> _createUserDocument(User firebaseUser) async {
    try {
      await _firestoreService.users.doc(firebaseUser.uid).set({
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? '',
        'name': firebaseUser.displayName ?? 'Usuario',
        'photoUrl': firebaseUser.photoURL ?? '',
        'avatarId': null, // NUEVO: Inicializar avatarId como null
        'favoriteRecipes': [],
        'preferences': {},
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      _initializeMealPlansCollection(firebaseUser.uid);
      
      print('Documento de usuario creado exitosamente');
    } catch (e) {
      print('Error al crear documento de usuario: $e');
    }
  }
  
  // Inicializar la colección de planes de comida
  Future<void> _initializeMealPlansCollection(String userId) async {
    try {
      final initDoc = {
        'id': 'init',
        'date': DateTime.now().toIso8601String(),
        'mealTypeId': 'init',
        'recipe': {'id': 'init', 'name': 'init'},
        'isCompleted': false,
        'isInit': true,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      final mealPlanRef = _firestoreService.firestore
          .collection('users')
          .doc(userId)
          .collection('mealPlans')
          .doc('init');
          
      await mealPlanRef.set(initDoc);
      
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await mealPlanRef.delete();
          print('Documento de inicialización de planes de comida eliminado');
        } catch (e) {
          print('Error al eliminar documento de inicialización: $e');
        }
      });
      
      print('Colección de planes de comida inicializada correctamente');
    } catch (e) {
      print('Error al inicializar colección de planes de comida: $e');
    }
  }
  
  // Registro con email y contraseña
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    bool rememberMe = true,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      final result = await _authService.registerWithEmailAndPassword(
        email, 
        password, 
        name,
        rememberMe: rememberMe,
      );
      
      if (result['success'] == true) {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          try {
            await _firestoreService.users.doc(userId).set({
              'uid': userId,
              'email': email,
              'name': name,
              'photoUrl': '',
              'avatarId': null, // NUEVO: Inicializar avatarId como null
              'favoriteRecipes': [],
              'preferences': {},
              'createdAt': FieldValue.serverTimestamp(),
              'lastLogin': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            
            await _initializeMealPlansCollection(userId);
            
            print('Usuario registrado e inicializado correctamente');
          } catch (e) {
            print('Error al inicializar estructuras después del registro: $e');
          }
        }
        
        return true;
      } else {
        _setError(FirebaseErrorHelper.getMessageFromErrorCode(result['error']));
        return false;
      }
    } catch (e) {
      _setError(FirebaseErrorHelper.getMessageFromErrorCode(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Inicio de sesión con email y contraseña
  Future<bool> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      final result = await _authService.signInWithEmailAndPassword(
        email, 
        password,
        rememberMe: rememberMe,
      );
      
      if (result['success'] == true) {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          try {
            await _firestoreService.users.doc(userId).update({
              'lastLogin': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            print('Error al actualizar lastLogin: $e');
          }
        }
        
        return true;
      } else {
        _setError(FirebaseErrorHelper.getMessageFromErrorCode(result['error']));
        return false;
      }
    } catch (e) {
      _setError(FirebaseErrorHelper.getMessageFromErrorCode(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Método para intentar iniciar sesión con datos guardados
  Future<bool> tryAutoLogin() async {
    try {
      _setLoading(true);
      _clearError();
      
      final result = await _authService.autoSignIn();
      
      if (result['success'] == true) {
        if (result['userModel'] != null) {
          _user = result['userModel'];
          notifyListeners();
        }
        return true;
      } else {
        _setError(result['error'] ?? 'No se pudo restaurar la sesión');
        return false;
      }
    } catch (e) {
      _setError('Error al intentar inicio de sesión automático: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Cierre de sesión
  Future<void> signOut({bool keepSession = false}) async {
    try {
      _setLoading(true);
      await _authService.signOut(clearSessionData: !keepSession);
      _clearError();
    } catch (e) {
      _setError('Error al cerrar sesión: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Recuperación de contraseña
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _clearError();
      
      final result = await _authService.resetPassword(email);
      
      if (result['success'] == true) {
        return true;
      } else {
        _setError(FirebaseErrorHelper.getMessageFromErrorCode(result['error']));
        return false;
      }
    } catch (e) {
      _setError(FirebaseErrorHelper.getMessageFromErrorCode(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Actualizar perfil de usuario - ACTUALIZADO para avatares
  Future<bool> updateProfile({
    String? name,
    String? photoUrl,
    String? avatarId, // NUEVO: Parámetro para avatarId
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      if (_user == null) {
        _setError('No hay usuario autenticado');
        return false;
      }
      
      // Preparar datos de actualización
      Map<String, dynamic> updateData = {};
      
      if (name != null) updateData['name'] = name;
      if (photoUrl != null) updateData['photoUrl'] = photoUrl;
      if (avatarId != null) {
        updateData['avatarId'] = avatarId;
        // Si se establece un avatarId, limpiar photoUrl
        updateData['photoUrl'] = '';
      }
      
      if (updateData.isNotEmpty) {
        await _firestoreService.users.doc(_user!.id).update(updateData);
        
        // Actualizar modelo local
        _user = _user!.copyWith(
          name: name ?? _user!.name,
          photoUrl: photoUrl ?? (avatarId != null ? '' : _user!.photoUrl),
          avatarId: avatarId ?? _user!.avatarId,
        );
        
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      _setError('Error al actualizar perfil: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // NUEVO: Método específico para actualizar avatar
  Future<bool> updateAvatar(String avatarId) async {
    return updateProfile(avatarId: avatarId);
  }
  
  // NUEVO: Método específico para limpiar avatar
  Future<bool> clearAvatar() async {
    try {
      _setLoading(true);
      _clearError();
      
      if (_user == null) {
        _setError('No hay usuario autenticado');
        return false;
      }
      
      await _firestoreService.users.doc(_user!.id).update({
        'avatarId': null,
        'photoUrl': '',
      });
      
      _user = _user!.copyWith(avatarId: null, photoUrl: '');
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error al limpiar avatar: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Eliminar cuenta
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _clearError();
      
      final success = await _authService.deleteAccount();
      return success;
    } catch (e) {
      _setError('Error al eliminar cuenta: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Control de estado
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }
  
  void _clearError() {
    _error = '';
  }
  
  // Método para añadir una receta a favoritos
  Future<bool> addToFavorites(String recipeId) async {
    try {
      if (_user == null) return false;
      
      final userRef = _firestoreService.users.doc(_user!.id);
      await userRef.update({
        'favoriteRecipes': FieldValue.arrayUnion([recipeId]),
      });
      
      final updatedFavorites = List<String>.from(_user!.favoriteRecipes)..add(recipeId);
      _user = _user!.copyWith(favoriteRecipes: updatedFavorites);
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error al añadir a favoritos: $e');
      return false;
    }
  }
  
  // Método para quitar una receta de favoritos
  Future<bool> removeFromFavorites(String recipeId) async {
    try {
      if (_user == null) return false;
      
      final userRef = _firestoreService.users.doc(_user!.id);
      await userRef.update({
        'favoriteRecipes': FieldValue.arrayRemove([recipeId]),
      });
      
      final updatedFavorites = List<String>.from(_user!.favoriteRecipes)
        ..removeWhere((id) => id == recipeId);
      _user = _user!.copyWith(favoriteRecipes: updatedFavorites);
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error al quitar de favoritos: $e');
      return false;
    }
  }
  
  // Verificar si una receta está en favoritos
  bool isRecipeFavorite(String recipeId) {
    return _user?.favoriteRecipes.contains(recipeId) ?? false;
  }
  
  // Método para guardar preferencias del usuario
  Future<bool> savePreference(String key, dynamic value) async {
    try {
      if (_user == null) return false;
      
      final userRef = _firestoreService.users.doc(_user!.id);
      await userRef.update({
        'preferences.$key': value,
      });
      
      final updatedPreferences = Map<String, dynamic>.from(_user!.preferences)
        ..[key] = value;
      _user = _user!.copyWith(preferences: updatedPreferences);
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error al guardar preferencia: $e');
      return false;
    }
  }
  
  // Obtener una preferencia del usuario
  dynamic getPreference(String key, {dynamic defaultValue}) {
    return _user?.preferences[key] ?? defaultValue;
  }
  
  // Verificar si las colecciones del usuario están inicializadas
  Future<Map<String, bool>> verifyUserInitialization() async {
    try {
      if (_user == null) {
        return {
          'userDoc': false,
          'mealPlans': false,
        };
      }
      
      final userDoc = await _firestoreService.users.doc(_user!.id).get();
      final userDocExists = userDoc.exists;
      
      final mealPlansCollection = await _firestoreService.firestore
          .collection('users')
          .doc(_user!.id)
          .collection('mealPlans')
          .limit(1)
          .get();
      
      return {
        'userDoc': userDocExists,
        'mealPlans': mealPlansCollection.docs.isNotEmpty,
      };
    } catch (e) {
      print('Error al verificar inicialización: $e');
      return {
        'userDoc': false,
        'mealPlans': false,
        'error': true,
      };
    }
  }
  
  // Forzar la inicialización de las colecciones del usuario
  Future<bool> forceUserInitialization() async {
    try {
      if (_user == null) return false;
      
      final status = await verifyUserInitialization();
      
      if (status['userDoc'] == false) {
        await _firestoreService.users.doc(_user!.id).set({
          'uid': _user!.id,
          'email': _user!.email,
          'name': _user!.name,
          'photoUrl': _user!.photoUrl,
          'avatarId': _user!.avatarId, // NUEVO: Incluir avatarId
          'favoriteRecipes': _user!.favoriteRecipes,
          'preferences': _user!.preferences,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      
      if (status['mealPlans'] == false) {
        await _initializeMealPlansCollection(_user!.id);
      }
      
      return true;
    } catch (e) {
      print('Error al forzar inicialización: $e');
      return false;
    }
  }
}