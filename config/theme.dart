import 'package:flutter/material.dart';

/// SmartPantry Theme Configuration
/// Define la paleta de colores, temas y estilos para toda la aplicación

class AppTheme {
  // Colores principales
  static const Color coralMain = Color(0xFFFF5A5F);      // Color principal coral
  static const Color peachLight = Color(0xFFFFCBBC);     // Fondo melocotón claro
  static const Color pureWhite = Color(0xFFFFFFFF);      // Blanco puro
  static const Color darkGrey = Color(0xFF333333);       // Gris oscuro para texto

  // Colores secundarios
  static const Color yellowAccent = Color(0xFFFFD166);   // Amarillo suave para acentos
  static const Color softTeal = Color(0xFF06D6A0);       // Verde azulado suave
  
  // Colores adicionales
  static const Color mediumGrey = Color(0xFF777777);     // Gris medio para textos secundarios
  static const Color lightGrey = Color(0xFFF5F5F5);      // Gris claro para fondos
  static const Color backgroundGrey = Color(0xFFF9F9F9); // Gris muy claro para fondos alternativos
  
  // NUEVOS: Colores para notificaciones y estados
  static const Color successGreen = Color(0xFF4CAF50);   // Verde para éxito
  static const Color successGreenLight = Color(0xFF81C784);
  static const Color warningOrange = Color(0xFFFF9F1C);  // Naranja para advertencias
  static const Color warningOrangeLight = Color(0xFFFFB74D);
  static const Color errorRed = Color(0xFFE63946);       // Rojo para errores
  static const Color errorRedLight = Color(0xFFEF5350);
  static const Color infoBlue = Color(0xFF2196F3);       // Azul para información
  static const Color infoBluLight = Color(0xFF64B5F6);
  
  // Colores específicos para notificaciones
  static const Color notificationBackground = Color(0xFF1A202C);
  static const Color notificationText = Color(0xFFFFFFFF);
  static const Color notificationAccent = coralMain;
  
  // Colores para diferentes prioridades
  static const Color priorityHigh = errorRed;
  static const Color priorityMedium = warningOrange;
  static const Color priorityLow = successGreen;
  
  static MaterialColor createMaterialColor(Color color) {
    List<double> strengths = <double>[.05, .1, .2, .3, .4, .5, .6, .7, .8, .9];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (final double strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
  
  // Bordes redondeados
  static const double borderRadiusSmall = 12.0;          // Más redondeado que antes
  static const double borderRadiusMedium = 16.0;         // Más redondeado que antes
  static const double borderRadiusLarge = 24.0;          // Más redondeado que antes
  static const double borderRadiusXLarge = 32.0;         // Más redondeado que antes
  static const double borderRadiusPill = 50.0;           // Forma de píldora

  // Espaciado
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  static const double spacingXXLarge = 48.0;             // Espaciado extra grande
  
  // Elevaciones
  static const double elevationTiny = 1.0;               // Elevación muy sutil
  static const double elevationSmall = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationLarge = 8.0;
  static const double elevationHigh = 8.0;
  static const double elevationVeryHigh = 12.0;    // Elevación extra alta
  static const double elevationExtreme = 16.0; 

  // NUEVAS: Sombras para notificaciones
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: darkGrey.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> notificationShadow = [
    BoxShadow(
      color: darkGrey.withOpacity(0.2),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: darkGrey.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  // Propiedades de tema claro
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: coralMain,
    scaffoldBackgroundColor: pureWhite,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: coralMain,
      onPrimary: pureWhite,
      secondary: yellowAccent,
      onSecondary: darkGrey,
      error: errorRed,
      onError: pureWhite,
      surface: pureWhite,
      onSurface: darkGrey,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppColorsExtension.light,
      CategoryColorsExtension.light,
    ],
    // Estilos de texto
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: darkGrey,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: darkGrey,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: darkGrey,
        letterSpacing: -0.25,
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: darkGrey,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: darkGrey,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: darkGrey,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: darkGrey,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: darkGrey,
      ),
      titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: darkGrey,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: darkGrey,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: darkGrey,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: mediumGrey,
      ),
    ),
    
    // Estilos de botones
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: coralMain,
        foregroundColor: pureWhite,
        elevation: elevationSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLarge,
          vertical: spacingMedium,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: coralMain,
        side: const BorderSide(color: coralMain),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLarge,
          vertical: spacingMedium,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: coralMain,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingMedium,
          vertical: spacingSmall,
        ),
      ),
    ),
    
    // Estilos de campos de texto
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightGrey,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingMedium,
        vertical: spacingMedium,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        borderSide: const BorderSide(color: coralMain, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        borderSide: const BorderSide(color: errorRed, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        borderSide: const BorderSide(color: errorRed, width: 2),
      ),
      hintStyle: const TextStyle(color: mediumGrey),
      labelStyle: const TextStyle(color: mediumGrey),
    ),
    
    // Estilos de tarjetas
    cardTheme: CardTheme(
      color: pureWhite,
      elevation: elevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
      ),
      margin: const EdgeInsets.all(spacingSmall),
      shadowColor: darkGrey.withOpacity(0.1),
    ),
    
    // Estilos de appbar
    appBarTheme: const AppBarTheme(
      backgroundColor: pureWhite,
      foregroundColor: darkGrey,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: darkGrey),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: darkGrey,
      ),
    ),
    
    // Estilos de tabs
    tabBarTheme: const TabBarTheme(
      labelColor: coralMain,
      unselectedLabelColor: mediumGrey,
      indicatorColor: coralMain,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 14,
      ),
    ),
    
    // Estilos de bottom navigation bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: pureWhite,
      selectedItemColor: coralMain,
      unselectedItemColor: mediumGrey,
      type: BottomNavigationBarType.fixed,
      elevation: elevationMedium,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12),
    ),

    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return coralMain;
        }
        return null;
      }),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
    ),

    // ACTUALIZADO: Switch theme con mejor integración
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return coralMain;
        }
        return mediumGrey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return coralMain.withOpacity(0.3);
        }
        return lightGrey;
      }),
    ),

    // Chip theme
    chipTheme: ChipThemeData(
      backgroundColor: lightGrey,
      disabledColor: lightGrey.withOpacity(0.5),
      selectedColor: coralMain.withOpacity(0.2),
      secondarySelectedColor: coralMain,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: const TextStyle(color: darkGrey),
      secondaryLabelStyle: const TextStyle(color: pureWhite),
      brightness: Brightness.light,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusPill),
      ),
    ),

    // Floating action button theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: coralMain,
      foregroundColor: pureWhite,
      extendedTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),

    // Divider theme
    dividerTheme: const DividerThemeData(
      color: lightGrey,
      thickness: 1,
      space: spacingMedium,
    ),

    // NUEVO: Configuración de snackbars
    snackBarTheme: SnackBarThemeData(
  backgroundColor: notificationBackground,
  contentTextStyle: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: notificationText,
  ),
  actionTextColor: coralMain,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(borderRadiusMedium),
  ),
  behavior: SnackBarBehavior.floating,
  insetPadding: const EdgeInsets.all(spacingMedium), // ✅ Changed from 'margin' to 'insetPadding'
),
    
    // NUEVO: Configuración de diálogos
    dialogTheme: DialogTheme(
      backgroundColor: pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: darkGrey,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: darkGrey,
      ),
    ),
    
    // Configuración de bottom sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(borderRadiusLarge),
        ),
      ),
    ),
  );
  
  // Propiedades de tema oscuro
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: coralMain,
    scaffoldBackgroundColor: const Color(0xFF121212), // Dark mode background
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: coralMain,
      onPrimary: pureWhite,
      secondary: yellowAccent,
      onSecondary: darkGrey,
      error: errorRed,
      onError: pureWhite,
      surface: const Color(0xFF1E1E1E), // Color de fondo de tarjetas más oscuro
      onSurface: pureWhite,
      // Versiones más oscuras para el tema oscuro
      surfaceContainerHighest: const Color(0xFF2C2C2C),
      inverseSurface: peachLight.withOpacity(0.05),
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppColorsExtension.dark,
      CategoryColorsExtension.dark,
    ],

    // Estilos de texto para tema oscuro
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: pureWhite,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: pureWhite,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: pureWhite,
        letterSpacing: -0.25,
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: pureWhite,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: pureWhite,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: pureWhite,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: pureWhite,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: pureWhite,
      ),
      titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: pureWhite,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: lightGrey,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: lightGrey,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: mediumGrey,
      ),
    ),
    
    // Estilos de botones para tema oscuro
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: coralMain,
        foregroundColor: pureWhite,
        elevation: elevationSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLarge,
          vertical: spacingMedium,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: coralMain,
        side: const BorderSide(color: coralMain),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLarge,
          vertical: spacingMedium,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: coralMain,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingMedium,
          vertical: spacingSmall,
        ),
      ),
    ),
    
    // Estilos de campos de texto para tema oscuro
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingMedium,
        vertical: spacingMedium,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        borderSide: const BorderSide(color: coralMain, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        borderSide: const BorderSide(color: errorRed, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        borderSide: const BorderSide(color: errorRed, width: 2),
      ),
      hintStyle: TextStyle(color: mediumGrey.withOpacity(0.7)),
      labelStyle: TextStyle(color: mediumGrey.withOpacity(0.9)),
    ),
    
    // Estilos de tarjetas para tema oscuro
    cardTheme: CardTheme(
      color: const Color(0xFF1E1E1E),
      elevation: elevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
      ),
      margin: const EdgeInsets.all(spacingSmall),
      shadowColor: Colors.black.withOpacity(0.3),
    ),
    
    // Estilos de appbar para tema oscuro
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: pureWhite,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: pureWhite),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: pureWhite,
      ),
    ),
    
    // Estilos de tabs para tema oscuro
    tabBarTheme: const TabBarTheme(
      labelColor: coralMain,
      unselectedLabelColor: mediumGrey,
      indicatorColor: coralMain,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 14,
      ),
    ),
    
    // Estilos de bottom navigation bar para tema oscuro
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: coralMain,
      unselectedItemColor: mediumGrey,
      type: BottomNavigationBarType.fixed,
      elevation: elevationMedium,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12),
    ),

    // Checkbox theme para tema oscuro
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return coralMain;
        }
        return Colors.grey.shade800;
      }),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
    ),

    // Switch theme para tema oscuro
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return coralMain;
        }
        return Colors.grey.shade400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return coralMain.withOpacity(0.5);
        }
        return Colors.grey.shade800;
      }),
    ),

    // Chip theme para tema oscuro
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade800,
      disabledColor: Colors.grey.shade900,
      selectedColor: coralMain.withOpacity(0.3),
      secondarySelectedColor: coralMain,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: const TextStyle(color: pureWhite),
      secondaryLabelStyle: const TextStyle(color: pureWhite),
      brightness: Brightness.dark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusPill),
      ),
    ),

    // Floating action button theme para tema oscuro
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: coralMain,
      foregroundColor: pureWhite,
      extendedTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),

    // Divider theme para tema oscuro
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2C2C2C),
      thickness: 1,
      space: spacingMedium,
    ),

    // SnackBar para tema oscuro
    snackBarTheme: SnackBarThemeData(
  backgroundColor: const Color(0xFF2C2C2C),
  contentTextStyle: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: pureWhite,
  ),
  actionTextColor: coralMain,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(borderRadiusMedium),
  ),
  behavior: SnackBarBehavior.floating,
  insetPadding: const EdgeInsets.all(spacingMedium), // ✅ Changed from 'margin' to 'insetPadding'
),
    
    // Diálogos para tema oscuro
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: pureWhite,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: pureWhite,
      ),
    ),
    
    // Bottom sheet para tema oscuro
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(borderRadiusLarge),
        ),
      ),
    ),
  );

  // NUEVOS: Métodos de utilidad para notificaciones
  
  // Obtener color según el tipo de notificación
  static Color getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'expiry':
      case 'caducidad':
        return errorRed;
      case 'stock':
      case 'inventario':
        return warningOrange;
      case 'shopping':
      case 'compras':
        return infoBlue;
      case 'meal_plan':
      case 'comidas':
        return successGreen;
      case 'recipe':
      case 'recetas':
        return coralMain;
      default:
        return mediumGrey;
    }
  }
  
  // Obtener icono según el tipo de notificación
  static IconData getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'expiry':
      case 'caducidad':
        return Icons.warning_amber_rounded;
      case 'stock':
      case 'inventario':
        return Icons.inventory_2_outlined;
      case 'shopping':
      case 'compras':
        return Icons.shopping_cart_outlined;
      case 'meal_plan':
      case 'comidas':
        return Icons.restaurant_menu_outlined;
      case 'recipe':
      case 'recetas':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
  
  // Obtener estilo de texto para diferentes contextos
  static TextStyle getNotificationTextStyle({
    required BuildContext context,
    bool isTitle = false,
    bool isSubtitle = false,
  }) {
    final theme = Theme.of(context);
    
    if (isTitle) {
      return TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      );
    } else if (isSubtitle) {
      return TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: theme.colorScheme.onSurface.withOpacity(0.7),
      );
    } else {
      return TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      );
    }
  }
  
  // Crear decoración para contenedores de estado
  static BoxDecoration getStatusDecoration({
    required Color color,
    bool isSelected = false,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadiusMedium),
      border: hasBorder ? Border.all(
        color: color.withOpacity(isSelected ? 0.3 : 0.1),
        width: isSelected ? 2 : 1,
      ) : null,
    );
  }
  
  // Crear gradiente para fondos especiales
  static LinearGradient getNotificationGradient(String type) {
    final color = getNotificationColor(type);
    return LinearGradient(
      colors: [
        color.withOpacity(0.1),
        color.withOpacity(0.05),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

/// TextStyles - Para acceso fácil a los estilos de texto comunes
class AppTextStyles {
  // Estilos de título
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.25,
  );
  
  static const TextStyle heading4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle heading5 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  
  // Estilos de cuerpo
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    height: 1.4,
  );
  
  // Estilos de botón
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
  );
  
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
  );
  
  // Estilos de etiqueta
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
  
  // Estilos de caption
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  // NUEVOS: Estilos específicos para notificaciones
  static const TextStyle notificationTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
  
  static const TextStyle notificationSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.1,
  );
  
  static const TextStyle notificationBody = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.1,
  );
  
  static const TextStyle notificationTime = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  // NUEVOS: Estilos para estados
  static const TextStyle statusActive = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AppTheme.successGreen,
  );
  
  static const TextStyle statusWarning = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AppTheme.warningOrange,
  );
  
  static const TextStyle statusError = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AppTheme.errorRed,
  );

  // NUEVOS: Estilos para prioridades
  static const TextStyle priorityHigh = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppTheme.priorityHigh,
  );
  
  static const TextStyle priorityMedium = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppTheme.priorityMedium,
  );
  
  static const TextStyle priorityLow = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppTheme.priorityLow,
  );
}

/// Extensión de colores adaptativos para el tema
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerLow;
  final Color onSurfaceVariant;
  final Color onSurfaceSecondary;
  final Color borderColor;
  final Color shadowColor;
  final Color categoryBackground;
  final Color categoryForeground;

  const AppColorsExtension({
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerLow,
    required this.onSurfaceVariant,
    required this.onSurfaceSecondary,
    required this.borderColor,
    required this.shadowColor,
    required this.categoryBackground,
    required this.categoryForeground,
  });

  @override
  AppColorsExtension copyWith({
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerLow,
    Color? onSurfaceVariant,
    Color? onSurfaceSecondary,
    Color? borderColor,
    Color? shadowColor,
    Color? categoryBackground,
    Color? categoryForeground,
  }) {
    return AppColorsExtension(
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      onSurfaceSecondary: onSurfaceSecondary ?? this.onSurfaceSecondary,
      borderColor: borderColor ?? this.borderColor,
      shadowColor: shadowColor ?? this.shadowColor,
      categoryBackground: categoryBackground ?? this.categoryBackground,
      categoryForeground: categoryForeground ?? this.categoryForeground,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh: Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      surfaceContainerLow: Color.lerp(surfaceContainerLow, other.surfaceContainerLow, t)!,
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      onSurfaceSecondary: Color.lerp(onSurfaceSecondary, other.onSurfaceSecondary, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      categoryBackground: Color.lerp(categoryBackground, other.categoryBackground, t)!,
      categoryForeground: Color.lerp(categoryForeground, other.categoryForeground, t)!,
    );
  }

  // Colores para tema claro
  static const light = AppColorsExtension(
    surfaceContainer: Color(0xFFF8F8F8),
    surfaceContainerHigh: Color(0xFFEEEEEE),
    surfaceContainerLow: Color(0xFFFCFCFC),
    onSurfaceVariant: Color(0xFF666666),
    onSurfaceSecondary: Color(0xFF888888),
    borderColor: Color(0xFFE0E0E0),
    shadowColor: Color(0x1A000000),
    categoryBackground: Color(0xFFF0F0F0),
    categoryForeground: AppTheme.darkGrey,
  );

  // Colores para tema oscuro
  static const dark = AppColorsExtension(
    surfaceContainer: Color(0xFF2C2C2C),
    surfaceContainerHigh: Color(0xFF383838),
    surfaceContainerLow: Color(0xFF1E1E1E),
    onSurfaceVariant: Color(0xFFB0B0B0),
    onSurfaceSecondary: Color(0xFF888888),
    borderColor: Color(0xFF404040),
    shadowColor: Color(0x40000000),
    categoryBackground: Color(0xFF383838),
    categoryForeground: AppTheme.pureWhite,
  );
}

/// Extensión para colores de categorías adaptativos
class CategoryColorsExtension extends ThemeExtension<CategoryColorsExtension> {
  final List<Color> categoryColors;
  final List<Color> categoryColorsLight;

  const CategoryColorsExtension({
    required this.categoryColors,
    required this.categoryColorsLight,
  });

  @override
  CategoryColorsExtension copyWith({
    List<Color>? categoryColors,
    List<Color>? categoryColorsLight,
  }) {
    return CategoryColorsExtension(
      categoryColors: categoryColors ?? this.categoryColors,
      categoryColorsLight: categoryColorsLight ?? this.categoryColorsLight,
    );
  }

  @override
  CategoryColorsExtension lerp(ThemeExtension<CategoryColorsExtension>? other, double t) {
    if (other is! CategoryColorsExtension) {
      return this;
    }
    return CategoryColorsExtension(
      categoryColors: categoryColors.asMap().entries.map((entry) {
        final index = entry.key;
        final color = entry.value;
        final otherColor = index < other.categoryColors.length 
            ? other.categoryColors[index] 
            : color;
        return Color.lerp(color, otherColor, t)!;
      }).toList(),
      categoryColorsLight: categoryColorsLight.asMap().entries.map((entry) {
        final index = entry.key;
        final color = entry.value;
        final otherColor = index < other.categoryColorsLight.length 
            ? other.categoryColorsLight[index] 
            : color;
        return Color.lerp(color, otherColor, t)!;
      }).toList(),
    );
  }

  // Colores base para categorías
  static const light = CategoryColorsExtension(
    categoryColors: [
      Color(0xFF64B5F6), // Azul
      Color(0xFF00B4D8), // Cian
      Color(0xFF8D6E63), // Marrón
      Color(0xFF81C784), // Verde
      Color(0xFFFFB74D), // Naranja
      Color(0xFFBA68C8), // Púrpura
      Color(0xFFFF8A65), // Coral
      Color(0xFF4DB6AC), // Teal
    ],
    categoryColorsLight: [
      Color(0xFFE3F2FD), // Azul claro
      Color(0xFFE0F7FA), // Cian claro
      Color(0xFFEFEBE9), // Marrón claro
      Color(0xFFE8F5E8), // Verde claro
      Color(0xFFFFF3E0), // Naranja claro
      Color(0xFFF3E5F5), // Púrpura claro
      Color(0xFFFBE9E7), // Coral claro
      Color(0xFFE0F2F1), // Teal claro
    ],
  );

  static const dark = CategoryColorsExtension(
    categoryColors: [
      Color(0xFF42A5F5), // Azul más brillante
      Color(0xFF26C6DA), // Cian más brillante
      Color(0xFFA1887F), // Marrón más claro
      Color(0xFF66BB6A), // Verde más brillante
      Color(0xFFFFCA28), // Naranja más brillante
      Color(0xFFAB47BC), // Púrpura más brillante
      Color(0xFFFF7043), // Coral más brillante
      Color(0xFF26A69A), // Teal más brillante
    ],
    categoryColorsLight: [
      Color(0xFF1A237E), // Azul oscuro
      Color(0xFF006064), // Cian oscuro
      Color(0xFF3E2723), // Marrón oscuro
      Color(0xFF1B5E20), // Verde oscuro
      Color(0xFFE65100), // Naranja oscuro
      Color(0xFF4A148C), // Púrpura oscuro
      Color(0xFFBF360C), // Coral oscuro
      Color(0xFF004D40), // Teal oscuro
    ],
  );
}

/// Mixin para facilitar el acceso a colores del tema
mixin ThemeAwareMixin {
  // Obtener colores primarios
  Color getPrimaryTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  Color getSecondaryTextColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>();
    return appColors?.onSurfaceSecondary ?? 
           Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
  }

  Color getVariantTextColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>();
    return appColors?.onSurfaceVariant ?? 
           Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
  }

  // Obtener colores de superficie
  Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  Color getSurfaceContainerColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>();
    return appColors?.surfaceContainer ?? 
           Theme.of(context).colorScheme.surface;
  }

  Color getSurfaceContainerHighColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>();
    return appColors?.surfaceContainerHigh ?? 
           Theme.of(context).colorScheme.surface;
  }

  Color getSurfaceContainerLowColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>();
    return appColors?.surfaceContainerLow ?? 
           Theme.of(context).colorScheme.surface;
  }

  // Obtener colores de borde y sombra
  Color getBorderColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>();
    return appColors?.borderColor ?? 
           Theme.of(context).colorScheme.outline;
  }

  Color getShadowColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>();
    return appColors?.shadowColor ?? 
           Colors.black.withOpacity(0.1);
  }

  // Obtener colores de categoría
  Color getCategoryColor(BuildContext context, int index) {
    final categoryColors = Theme.of(context).extension<CategoryColorsExtension>();
    if (categoryColors != null && index < categoryColors.categoryColors.length) {
      return categoryColors.categoryColors[index];
    }
    return AppTheme.coralMain;
  }

  Color getCategoryBackgroundColor(BuildContext context, int index) {
    final categoryColors = Theme.of(context).extension<CategoryColorsExtension>();
    if (categoryColors != null && index < categoryColors.categoryColorsLight.length) {
      return categoryColors.categoryColorsLight[index];
    }
    return AppTheme.peachLight.withOpacity(0.1);
  }

  // Verificar si es tema oscuro
  bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}