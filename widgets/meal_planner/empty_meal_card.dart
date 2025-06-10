import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Widget que muestra una tarjeta vacía para añadir comidas
class EmptyMealCard extends StatelessWidget {
  final String mealTypeId;
  final String mealTypeName;
  final IconData mealTypeIcon;
  final VoidCallback onAddPressed;

  const EmptyMealCard({
    super.key,
    required this.mealTypeId,
    required this.mealTypeName,
    required this.mealTypeIcon,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: 4.0, // Reducido para evitar desbordamiento
      ),
      elevation: AppTheme.elevationTiny, // Elevación más sutil
      shadowColor: AppTheme.darkGrey.withOpacity(0.1), // Sombra más sutil
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        side: BorderSide(
          color: isDarkMode ? Colors.transparent : AppTheme.peachLight.withOpacity(0.5),
          width: 1.0,
        ),
      ),
      color: isDarkMode ? null : AppTheme.pureWhite,
      child: InkWell(
        onTap: onAddPressed,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Row(
            children: [
              // Icono del tipo de comida
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSmall),
                decoration: BoxDecoration(
                  color: AppTheme.peachLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                child: Icon(
                  mealTypeIcon,
                  color: AppTheme.coralMain,
                  size: 24.0,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              
              // Texto para añadir comida
              Expanded(
                child: Text(
                  'Añadir ${mealTypeName.toLowerCase()}',
                  style: TextStyle(
                    color: isDarkMode ? AppTheme.lightGrey : AppTheme.mediumGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              // Botón para añadir
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: AppTheme.coralMain.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: AppTheme.coralMain,
                  size: 20.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}