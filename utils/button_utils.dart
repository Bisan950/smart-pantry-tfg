// lib/utils/button_utils.dart

import 'package:flutter/material.dart';

/// Clase de utilidades para botones que ayuda a evitar errores de tipo
class ButtonUtils {
  /// Convierte una función void en VoidCallback segura
  /// Esta función ayuda a evitar errores de tipo cuando se pasa una función a un botón
  static VoidCallback? createCallback(bool condition, void Function() function) {
    if (condition) {
      return null;
    } else {
      return () {
        function();
      };
    }
  }
}