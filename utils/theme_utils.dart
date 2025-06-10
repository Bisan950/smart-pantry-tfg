import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Utilidades para trabajar con el tema de la aplicación
class ThemeUtils {
  /// Obtener el color adaptativo para contenedores
  static Color getContainerColor(BuildContext context, {bool elevated = false}) {
    final appColors = Theme.of(context).extension<AppColorsExtension>();
    if (elevated) {
      return appColors?.surfaceContainerHigh ?? 
             Theme.of(context).colorScheme.surface;
    }
    return appColors?.surfaceContainer ?? 
           Theme.of(context).colorScheme.surface;
  }

  /// Obtener el color de texto adaptativo
  static Color getTextColor(BuildContext context, {bool secondary = false}) {
    if (secondary) {
      final appColors = Theme.of(context).extension<AppColorsExtension>();
      return appColors?.onSurfaceSecondary ?? 
             Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Obtener el color de sombra adaptativo
  static Color getShadowColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>();
    return appColors?.shadowColor ?? 
           (Theme.of(context).brightness == Brightness.dark 
               ? Colors.black.withOpacity(0.4)
               : Colors.black.withOpacity(0.1));
  }

  /// Obtener el color de borde adaptativo
  static Color getBorderColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>();
    return appColors?.borderColor ?? 
           Theme.of(context).colorScheme.outline;
  }

  /// Obtener gradiente adaptativo para overlays
  static LinearGradient getOverlayGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        (isDark ? Colors.black : Colors.black).withOpacity(0.4),
      ],
    );
  }

  /// Obtener color de categoría por índice
  static Color getCategoryColor(BuildContext context, int index) {
    final categoryColors = Theme.of(context).extension<CategoryColorsExtension>();
    if (categoryColors != null && index < categoryColors.categoryColors.length) {
      return categoryColors.categoryColors[index];
    }
    return AppTheme.coralMain;
  }

  /// Obtener color de fondo de categoría por índice
  static Color getCategoryBackgroundColor(BuildContext context, int index) {
    final categoryColors = Theme.of(context).extension<CategoryColorsExtension>();
    if (categoryColors != null && index < categoryColors.categoryColorsLight.length) {
      return categoryColors.categoryColorsLight[index];
    }
    return AppTheme.peachLight.withOpacity(0.1);
  }

  /// Verificar si es tema oscuro
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Obtener decoración de contenedor adaptativa
  static BoxDecoration getContainerDecoration(BuildContext context, {
    bool elevated = false,
    bool hasBorder = false,
    Color? customColor,
  }) {
    return BoxDecoration(
      color: customColor ?? getContainerColor(context, elevated: elevated),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      border: hasBorder ? Border.all(
        color: getBorderColor(context),
        width: 1,
      ) : null,
      boxShadow: elevated ? [
        BoxShadow(
          color: getShadowColor(context),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ] : null,
    );
  }
}