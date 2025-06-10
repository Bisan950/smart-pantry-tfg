import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/meal_type_model.dart';

/// Widget para seleccionar el tipo de comida
class MealTypeSelector extends StatelessWidget {
  final List<MealType> mealTypes;
  final String selectedMealTypeId;
  final Function(String) onMealTypeSelected;

  const MealTypeSelector({
    super.key,
    required this.mealTypes,
    required this.selectedMealTypeId,
    required this.onMealTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Calcular el ancho disponible para los botones
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = AppTheme.spacingMedium * 2; // Padding horizontal total
    final availableWidth = screenWidth - padding;
    
    // Cada botón debe ocupar un porcentaje del ancho disponible
    final buttonWidth = (availableWidth / mealTypes.length) - 4; // 4px para margen
    
    return SingleChildScrollView(  // Añadir scroll horizontal por si acaso
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: mealTypes.map((mealType) {
          final isSelected = mealType.id == selectedMealTypeId;
          
          // Determinar colores basados en la selección
          final backgroundColor = isSelected 
              ? AppTheme.coralMain 
              : Theme.of(context).brightness == Brightness.light
                  ? AppTheme.lightGrey
                  : AppTheme.darkGrey.withOpacity(0.3);
          
          final textColor = isSelected 
              ? AppTheme.pureWhite 
              : Theme.of(context).brightness == Brightness.light
                  ? AppTheme.darkGrey
                  : AppTheme.lightGrey;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                onPressed: () => onMealTypeSelected(mealType.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColor,
                  foregroundColor: textColor,
                  elevation: isSelected ? AppTheme.elevationSmall : 0,
                  shadowColor: isSelected 
                      ? AppTheme.darkGrey.withOpacity(0.2) 
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,  // Reducido para evitar desbordamiento
                    vertical: 10.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mealType.icon,
                      size: 22.0,
                      color: textColor,
                    ),
                    const SizedBox(height: 6.0),
                    // Texto que se ajusta al espacio disponible
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        mealType.name,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}