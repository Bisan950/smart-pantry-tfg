import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Obtener el icono apropiado para una categoría
IconData getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'frutas':
    case 'fruta':
    case 'verduras':
    case 'verdura':
    case 'frutas y verduras':
      return Icons.eco_rounded;  // Actualizado a iconos redondeados
    case 'lácteos':
    case 'lacteos':
      return Icons.water_drop_rounded;  // Actualizado a iconos redondeados
    case 'carne':
    case 'carnes':
    case 'pescado':
    case 'pescados':
      return Icons.restaurant_rounded;  // Actualizado a iconos redondeados
    case 'bebidas':
      return Icons.local_drink_rounded;  // Actualizado a iconos redondeados
    case 'limpieza':
      return Icons.cleaning_services_rounded;  // Actualizado a iconos redondeados
    case 'panadería':
    case 'panaderia':
    case 'pan':
      return Icons.bakery_dining_rounded;  // Actualizado a iconos redondeados
    case 'congelados':
      return Icons.ac_unit_rounded;  // Actualizado a iconos redondeados
    default:
      return Icons.shopping_basket_rounded;  // Actualizado a iconos redondeados
  }
}

/// Obtener el color apropiado para una categoría
Color getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'frutas':
    case 'fruta':
    case 'verduras':
    case 'verdura':
    case 'frutas y verduras':
      return AppTheme.successGreen;
    case 'lácteos':
    case 'lacteos':
      return AppTheme.softTeal;  // Actualizado a softTeal de la nueva paleta
    case 'carne':
    case 'carnes':
    case 'pescado':
    case 'pescados':
      return AppTheme.coralMain;  // Actualizado a coralMain
    case 'bebidas':
      return AppTheme.yellowAccent;  // Actualizado a yellowAccent
    case 'limpieza':
      return AppTheme.softTeal;  // Actualizado a softTeal
    case 'panadería':
    case 'panaderia':
    case 'pan':
      return AppTheme.warningOrange;  // Actualizado a warningOrange
    case 'congelados':
      return AppTheme.softTeal.withOpacity(0.8);  // Actualizado para usar softTeal
    default:
      return AppTheme.coralMain;  // Actualizado a coralMain
  }
}