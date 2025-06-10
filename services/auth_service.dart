import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  // Singleton para acceso global al servicio
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  // Claves para SharedPreferences
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userIdKey = 'userId';
  static const String _userEmailKey = 'userEmail';
  
  // Instancia de FirebaseAuth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Instancia de FirestoreService
  final FirestoreService _firestoreService = FirestoreService();
  
  // Getter para el usuario actual
  User? get currentUser => _auth.currentUser;
  
  // Getter para el stream de estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Guardar información de sesión
  // Guardar información de sesión
  Future<void> saveUserSession(String userId, String email, {bool rememberMe = true}) async {
    print('🔍 DEBUG saveUserSession llamado:');
    print('  - userId: $userId');
    print('  - email: $email');
    print('  - rememberMe: $rememberMe');
    
    if (!rememberMe) {
      print('❌ No guardando sesión porque rememberMe es false');
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userEmailKey, email);
    
    print('✅ Sesión guardada exitosamente:');
    print('  - Clave $_isLoggedInKey: true');
    print('  - Clave $_userIdKey: $userId');
    print('  - Clave $_userEmailKey: $email');
    
    // Verificar inmediatamente que se guardó
    final verificacion = await prefs.getBool(_isLoggedInKey);
    print('🔍 Verificación inmediata - isLoggedIn: $verificacion');
  }
  
  // Verificar si hay una sesión guardada
  Future<bool> hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    final userId = prefs.getString(_userIdKey);
    final email = prefs.getString(_userEmailKey);
    
    print('🔍 DEBUG hasActiveSession:');
    print('  - isLoggedIn: $isLoggedIn');
    print('  - userId: $userId');
    print('  - email: $email');
    print('  - Claves buscadas: $_isLoggedInKey, $_userIdKey, $_userEmailKey');
    
    return isLoggedIn;
  }
  
  // Obtener el ID del usuario guardado
  Future<String?> getLoggedInUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }
  
  // Obtener el email del usuario guardado
  Future<String?> getLoggedInUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }
  
  // Borrar información de sesión al cerrar sesión
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    
    print('Sesión eliminada');
  }
  
  // MÉTODO MEJORADO PARA REGISTRO
  Future<Map<String, dynamic>> registerWithEmailAndPassword(
    String email, 
    String password,
    String name,
    {bool rememberMe = true} // Parámetro para recordar sesión
  ) async {
    try {
      print('Iniciando registro para: $email');
      
      // Crear el usuario en Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      final currentUser = userCredential.user;
      
      if (currentUser == null) {
        print('Error: usuario nulo después del registro');
        return {
          'success': false,
          'error': 'Usuario no creado',
          'userModel': null
        };
      }
      
      print('Usuario creado: ${currentUser.uid}');
      
      try {
        // Crear el documento del usuario en Firestore
        final userData = {
          'uid': currentUser.uid,
          'email': email,
          'name': name,
          'photoUrl': '',
          'createdAt': DateTime.now().toIso8601String(),
          'favoriteRecipes': [],
          'preferences': {},
        };
        
        await _firestoreService.users.doc(currentUser.uid).set(userData);
        
        // Guardar información de sesión si rememberMe es true
        if (rememberMe) {
          await saveUserSession(currentUser.uid, email, rememberMe: rememberMe);
        }
        
        // Crear y devolver el modelo
        final userModel = UserModel(
          id: currentUser.uid,
          email: email,
          name: name,
        );
        
        return {
          'success': true,
          'error': '',
          'userModel': userModel
        };
      } catch (firestoreError) {
        print('Error al crear documento en Firestore: $firestoreError');
        
        // Si falla la escritura en Firestore, eliminar el usuario de Auth
        try {
          await currentUser.delete();
        } catch (e) {
          print('Error al eliminar usuario después de fallo en Firestore: $e');
        }
        
        return {
          'success': false,
          'error': 'Error al crear perfil de usuario: $firestoreError',
          'userModel': null
        };
      }
    } on FirebaseAuthException catch (e) {
      print('Error FirebaseAuth al registrar usuario: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': e,
        'userModel': null
      };
    } catch (e) {
      print('Error general al registrar usuario: $e');
      return {
        'success': false,
        'error': e,
        'userModel': null
      };
    }
  }
  
  // MÉTODO MEJORADO PARA INICIO DE SESIÓN
  // Método mejorado para iniciar sesión
  Future<Map<String, dynamic>> signInWithEmailAndPassword(
    String email, 
    String password,
    {bool rememberMe = true}
  ) async {
    try {
      print('Iniciando sesión para: $email');
      
      // NO incluir esta línea - causa error en móviles:
      // await _auth.setPersistence(Persistence.LOCAL);
      
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      final user = userCredential.user;
      
      if (user == null) {
        return {
          'success': false,
          'error': 'Usuario no encontrado',
          'userModel': null
        };
      }
      
      // Guardar sesión si rememberMe es true
      if (rememberMe) {
        await saveUserSession(user.uid, email, rememberMe: rememberMe);
      }
      
      // Obtener datos del usuario desde Firestore
      try {
        final userDoc = await _firestoreService.users.doc(user.uid).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          
          final userModel = UserModel(
            id: user.uid,
            email: userData['email'] as String,
            name: userData['name'] as String,
            photoUrl: userData['photoUrl'] as String? ?? '',
            avatarId: userData['avatarId'] as String?,
            favoriteRecipes: List<String>.from(userData['favoriteRecipes'] ?? []),
            preferences: Map<String, dynamic>.from(userData['preferences'] ?? {}),
          );
          
          return {
            'success': true,
            'error': '',
            'userModel': userModel
          };
        }
      } catch (e) {
        print('Error al obtener datos de Firestore: $e');
      }
      
      // Si no se pueden obtener datos de Firestore, crear modelo básico
      final userModel = UserModel(
        id: user.uid,
        email: email,
        name: user.displayName ?? 'Usuario',
        photoUrl: user.photoURL ?? '',
      );
      
      return {
        'success': true,
        'error': '',
        'userModel': userModel
      };
    } on FirebaseAuthException catch (e) {
      print('Error FirebaseAuth al iniciar sesión: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': e,
        'userModel': null
      };
    } catch (e) {
      print('Error general al iniciar sesión: $e');
      return {
        'success': false,
        'error': e,
        'userModel': null
      };
    }
  }
  
  // Método para cerrar sesión ACTUALIZADO
  Future<void> signOut({bool clearSessionData = true}) async {
    // Eliminar datos de sesión si se solicita
    if (clearSessionData) {
      await clearSession();
    }
    await _auth.signOut();
  }
  
  // Método mejorado para iniciar sesión automáticamente
  // Método mejorado para iniciar sesión automáticamente
  // Método para iniciar sesión automáticamente con la sesión guardada
  Future<Map<String, dynamic>> autoSignIn() async {
    try {
      final hasSession = await hasActiveSession();
      
      if (!hasSession) {
        return {
          'success': false,
          'error': 'No hay sesión guardada',
          'userModel': null
        };
      }
      
      final userId = await getLoggedInUserId();
      final userEmail = await getLoggedInUserEmail();
      
      if (userId == null || userEmail == null) {
        // Limpiar sesión inválida
        await clearSession();
        return {
          'success': false,
          'error': 'Sesión inválida',
          'userModel': null
        };
      }
      
      // Verificar si el usuario ya está autenticado
      if (_auth.currentUser?.uid == userId) {
        // Ya está autenticado con el mismo usuario
        print('Usuario ya autenticado: $userId');
        
        // Obtener datos del usuario desde Firestore
        final userDoc = await _firestoreService.users.doc(userId).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          
          final userModel = UserModel(
            id: userId,
            email: userData['email'] as String? ?? userEmail,
            name: userData['name'] as String? ?? 'Usuario',
            photoUrl: userData['photoUrl'] as String? ?? '',
            avatarId: userData['avatarId'] as String?,
            favoriteRecipes: userData['favoriteRecipes'] is List 
                ? List<String>.from((userData['favoriteRecipes'] as List).map((item) => item.toString()))
                : [],
            preferences: userData['preferences'] is Map
                ? Map<String, dynamic>.from(userData['preferences'] as Map)
                : {},
          );
          
          return {
            'success': true,
            'error': '',
            'userModel': userModel
          };
        }
      }
      
      // El usuario no está autenticado o tiene otro usuario, 
      // aquí normalmente solicitaríamos la contraseña nuevamente
      // pero como queremos auto-login, solo indicamos éxito parcial
      return {
        'success': true,
        'partialAuth': true,
        'userId': userId,
        'userEmail': userEmail,
        'error': '',
        'userModel': null
      };
    } catch (e) {
      print('Error en autoSignIn: $e');
      return {
        'success': false,
        'error': 'Error al restaurar sesión: $e',
        'userModel': null
      };
    }
  }
  
 
  
 // ... existing code ...

  // Método mejorado para recuperar contraseña
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'error': ''
      };
    } on FirebaseAuthException catch (e) {
      print('Error al enviar email de recuperación: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': e
      };
    } catch (e) {
      print('Error general al enviar email de recuperación: $e');
      return {
        'success': false,
        'error': e
      };
    }
  }

// ... existing code ...
  
  // Método para actualizar perfil de usuario
  Future<bool> updateUserProfile({
    required String userId,
    String? name,
    String? photoUrl,
  }) async {
    try {
      final userRef = _firestoreService.users.doc(userId);
      
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      
      if (updates.isNotEmpty) {
        await userRef.update(updates);
        return true;
      }
      return false;
    } catch (e) {
      print('Error al actualizar perfil: $e');
      return false;
    }
  }
  
  // Método para eliminar cuenta ACTUALIZADO
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Eliminar datos del usuario en Firestore
        await _firestoreService.users.doc(user.uid).delete();
        
        // Eliminar datos de sesión
        await clearSession();
        
        // Eliminar cuenta de autenticación
        await user.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error al eliminar cuenta: $e');
      return false;
    }
  }
}