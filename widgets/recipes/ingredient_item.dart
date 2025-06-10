import 'package:flutter/material.dart';
import '../../config/theme.dart';

class IngredientItem extends StatelessWidget {
  final String name;
  final num quantity;
  final String unit;
  final bool isAvailable;
  final VoidCallback? onAddToShoppingList;

  const IngredientItem({
    super.key,
    required this.name,
    required this.quantity,
    required this.unit,
    this.isAvailable = false,
    this.onAddToShoppingList,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
      child: Row(
        children: [
          // Icono de ingrediente
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.peachLight.withOpacity(isDarkMode ? 0.2 : 0.3),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            ),
            child: Icon(
              Icons.restaurant_rounded,
              color: AppTheme.coralMain,
              size: 22,
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingMedium),
          
          // Nombre y cantidad del ingrediente
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$quantity $unit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? AppTheme.lightGrey : AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
          
          // Estado de disponibilidad
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSmall,
              vertical: AppTheme.spacingXSmall / 2,
            ),
            decoration: BoxDecoration(
              color: isAvailable
                  ? AppTheme.successGreen.withOpacity(0.2)
                  : AppTheme.coralMain.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
            ),
            child: Text(
              isAvailable ? 'Disponible' : 'Falta',
              style: TextStyle(
                fontSize: 12,
                color: isAvailable
                    ? AppTheme.successGreen
                    : AppTheme.coralMain,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Botón para añadir a la lista de compras (solo visible si no está disponible)
          if (!isAvailable && onAddToShoppingList != null)
            IconButton(
              icon: Icon(
                Icons.add_shopping_cart_rounded,
                size: 20,
                color: AppTheme.coralMain,
              ),
              onPressed: onAddToShoppingList,
              tooltip: 'Añadir a lista de compras',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}