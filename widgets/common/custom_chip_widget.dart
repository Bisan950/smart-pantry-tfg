import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// CustomChip - Chip personalizado para etiquetas o filtros en SmartPantry
/// 
/// Utilizado para:
/// - Mostrar categorías de productos
/// - Crear filtros seleccionables
/// - Mostrar etiquetas en productos o recetas
/// - Indicar estados o atributos
class CustomChip extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isDeleteable;
  final VoidCallback? onDelete;
  final double? fontSize;
  final EdgeInsets? padding;

  const CustomChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.isDeleteable = false,
    this.onDelete,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Actualización de colores según la nueva paleta
    final chipBackgroundColor = backgroundColor ?? 
        (isSelected ? AppTheme.coralMain.withOpacity(0.15) : AppTheme.lightGrey);
    
    final chipTextColor = textColor ?? 
        (isSelected ? AppTheme.coralMain : AppTheme.darkGrey);

    // Efecto de elevación sutil
    final boxShadow = isSelected ? [
      BoxShadow(
        color: AppTheme.darkGrey.withOpacity(0.05),
        blurRadius: 4,
        offset: const Offset(0, 2),
      )
    ] : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMedium,
          vertical: AppTheme.spacingSmall,
        ),
        decoration: BoxDecoration(
          color: chipBackgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill), // Usando BorderRadiusPill para forma de píldora
          boxShadow: boxShadow,
          border: isSelected 
              ? Border.all(color: AppTheme.coralMain.withOpacity(0.3), width: 1.0)
              : Border.all(color: AppTheme.lightGrey.withOpacity(0.8), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                // Usar versiones redondeadas de los iconos
                _getRoundedIcon(icon!),
                size: 16,
                color: chipTextColor,
              ),
              const SizedBox(width: AppTheme.spacingXSmall),
            ],
            Text(
              label,
              style: TextStyle(
                color: chipTextColor,
                fontSize: fontSize ?? 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isDeleteable && onDelete != null) ...[
              const SizedBox(width: AppTheme.spacingXSmall),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.close_rounded, // Usando el icono redondeado
                    size: 16,
                    color: chipTextColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Helper para conseguir la versión redondeada de un icono si está disponible
  IconData _getRoundedIcon(IconData icon) {
    // Tabla de conversión para iconos comunes
    final roundedIcons = {
      Icons.add: Icons.add_rounded,
      Icons.remove: Icons.remove_rounded,
      Icons.close: Icons.close_rounded,
      Icons.check: Icons.check_rounded,
      Icons.favorite: Icons.favorite_rounded,
      Icons.star: Icons.star_rounded,
      Icons.home: Icons.home_rounded,
      Icons.settings: Icons.settings_rounded,
      Icons.person: Icons.person_rounded,
      Icons.shopping_cart: Icons.shopping_cart_rounded,
      Icons.delete: Icons.delete_rounded,
      Icons.edit: Icons.edit_rounded,
      Icons.search: Icons.search_rounded,
      Icons.menu: Icons.menu_rounded,
      Icons.info: Icons.info_rounded,
      Icons.alarm: Icons.alarm_rounded,
      Icons.restaurant: Icons.restaurant_rounded,
      Icons.kitchen: Icons.kitchen_rounded,
      Icons.inventory: Icons.inventory_rounded,
      Icons.category: Icons.category_rounded,
      // Puedes añadir más iconos según sea necesario
    };
    
    // Retornar la versión redondeada si existe, o mantener el icono original
    return roundedIcons[icon] ?? icon;
  }
}