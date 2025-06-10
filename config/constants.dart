/// Constantes globales para SmartPantry
/// Valores reutilizables en toda la aplicación para mantener consistencia
library;

import 'package:flutter/material.dart';

class AppConstants {
  // Duración de animaciones
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // Tamaños de imágenes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;
  
  // Tamaños de pantalla (breakpoints)
  static const double breakpointMobile = 480;
  static const double breakpointTablet = 768;
  static const double breakpointDesktop = 1024;
  
  // Dimensiones máximas
  static const double maxCardWidth = 400;
  static const double maxContentWidth = 600;
  static const double maxDialogWidth = 450;
  
  // Dimensiones de componentes específicos
  static const double bottomNavBarHeight = 60;
  static const double appBarHeight = 56;
  static const double productCardHeight = 100;
  static const double recipeCardHeight = 180;
  
  // Padding estándar
  static const EdgeInsets paddingSmall = EdgeInsets.all(8);
  static const EdgeInsets paddingMedium = EdgeInsets.all(16);
  static const EdgeInsets paddingLarge = EdgeInsets.all(24);
  static const EdgeInsets paddingHorizontalMedium = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets paddingVerticalMedium = EdgeInsets.symmetric(vertical: 16);
  
  // Valores prefijados
  static const int maxProductsInInventory = 500;
  static const int minDaysToExpiration = 3; // Productos cercanos a caducar
  static const int maxRecentRecipes = 10;
  
  // Cadenas de texto reusables
  static const String appName = "SmartPantry";
  static const String appTagline = "Tu despensa inteligente en un solo lugar";
}

/// Rutas para navegación
class AppRoutes {
  // Pantallas de autenticación
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  
  // Pantallas principales
  static const String dashboard = '/dashboard';
  static const String inventory = '/inventory';
  static const String addProduct = '/add-product';
  static const String productDetail = '/product-detail';
  static const String recipes = '/recipes';
  static const String recipeDetail = '/recipe-detail';
  static const String mealPlanner = '/meal-planner';
  static const String shoppingList = '/shopping-list';
  static const String settings = '/settings';
  static const String expiryControl = '/expiry-control';
  static const String dbMigration = '/admin';
}

/// Iconos específicos de la aplicación
class AppIcons {
  static const IconData home = Icons.home_rounded;
  static const IconData inventory = Icons.inventory_2_rounded;
  static const IconData recipe = Icons.restaurant_menu_rounded;
  static const IconData shoppingList = Icons.shopping_cart_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData addProduct = Icons.add_circle_outline_rounded;
  static const IconData scanner = Icons.qr_code_scanner_rounded;
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData fridge = Icons.kitchen_rounded;
  static const IconData pantry = Icons.shelves;
  static const IconData expired = Icons.warning_amber_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.filter_list_rounded;
  static const IconData sort = Icons.sort_rounded;
  static const IconData check = Icons.check_circle_outline_rounded;
  static const IconData uncheck = Icons.radio_button_unchecked_rounded;
  static const IconData camera = Icons.camera_alt_rounded;
  static const IconData voice = Icons.mic_rounded;
}

/// Assets - Rutas de los recursos
class AppAssets {
  // Imágenes
  static const String logoPath = 'assets/images/logo.png';
  static const String logoFullPath = 'assets/images/logo_full.png';
  static const String backgroundPath = 'assets/images/background.png';
  static const String placeholderProductPath = 'assets/images/placeholder_product.png';
  static const String placeholderRecipePath = 'assets/images/placeholder_recipe.png';
  
  // Animaciones
  static const String loadingAnimPath = 'assets/animations/loading.json';
  static const String successAnimPath = 'assets/animations/success.json';
  static const String errorAnimPath = 'assets/animations/error.json';
}