// lib/utils/firebase_error_helper.dart

import 'package:firebase_auth/firebase_auth.dart';

/// Helper para traducir los códigos de error de Firebase a mensajes amigables
class FirebaseErrorHelper {
  /// Traduce los errores de Firebase Auth a mensajes amigables en español
  static String getMessageFromErrorCode(Object error) {
    // Si el error es una FirebaseAuthException, procesarlo específicamente
    if (error is FirebaseAuthException) {
      switch (error.code) {
        // Errores de inicio de sesión
        case 'invalid-email':
          return 'El formato del correo electrónico no es válido.';
        case 'user-disabled':
          return 'Esta cuenta ha sido deshabilitada.';
        case 'user-not-found':
          return 'No existe una cuenta con este correo electrónico.';
        case 'wrong-password':
          return 'La contraseña es incorrecta.';
        case 'invalid-credential':
          return 'Credenciales incorrectas. Verifica tu email y contraseña.';
        case 'INVALID_LOGIN_CREDENTIALS':
          return 'El email o la contraseña son incorrectos.';
        
        // Errores de registro
        case 'email-already-in-use':
          return 'Ya existe una cuenta con este correo electrónico.';
        case 'weak-password':
          return 'La contraseña es demasiado débil. Debe tener al menos 6 caracteres.';
        case 'operation-not-allowed':
          return 'Esta operación no está permitida. Contacta al soporte.';
        
        // Errores de recuperación de contraseña
        case 'expired-action-code':
          return 'El código de acción ha expirado.';
        case 'invalid-action-code':
          return 'El código de acción no es válido.';
        
        // Otros errores comunes
        case 'network-request-failed':
          return 'Error de conexión a Internet. Verifica tu conexión e inténtalo de nuevo.';
        case 'too-many-requests':
          return 'Demasiados intentos fallidos. Inténtalo más tarde.';
          
        // Errores generales
        default:
          return 'Se produjo un error: ${error.code}';
      }
    } 
    // Para otros tipos de errores, mostrar el mensaje directamente
    else {
      return 'Error: ${error.toString()}';
    }
  }
}