// lib/screens/shopping_list/components/category_selector_simplified.dart
// Versión actualizada con el nuevo diseño minimalista

import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../utils/category_helpers.dart';

class CategorySelectorSimplified extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategorySelectorSimplified({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    // Lista de categorías comunes
    final categories = [
      'General',
      'Frutas',
      'Lácteos',
      'Carnes',
      'Bebidas',
      'Limpieza',
      'Panadería',
      'Congelados',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.spacingXSmall,
            bottom: AppTheme.spacingSmall, // Aumentado para más espacio
          ),
          child: Text(
            'Categoría',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600, // Ligeramente más grueso
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.pureWhite
                  : AppTheme.darkGrey,
            ),
          ),
        ),
        Wrap(
          spacing: AppTheme.spacingSmall,
          runSpacing: AppTheme.spacingSmall,
          children: categories.map((category) {
            final isSelected = selectedCategory == category;
            final categoryColor = getCategoryColor(category);
            final categoryIcon = getCategoryIcon(category);
            
            // Calcular el color principal para la categoría seleccionada
            // Usar coral como color base si está seleccionado, pero manteniendo el matiz del color original
            final displayColor = isSelected
                ? _blendWithCoral(categoryColor)
                : categoryColor;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 2), // Pequeño margen para la sombra
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge), // Más redondeado
                child: InkWell(
                  onTap: () => onCategorySelected(category),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  splashColor: displayColor.withOpacity(0.1),
                  highlightColor: displayColor.withOpacity(0.05),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMedium,
                      vertical: AppTheme.spacingSmall,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? displayColor.withOpacity(0.1)
                          : Theme.of(context).brightness == Brightness.light
                              ? AppTheme.lightGrey.withOpacity(0.5) // Más sutil
                              : const Color(0xFF1E1E1E), // Más oscuro y consistente
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                      border: Border.all(
                        color: isSelected
                            ? displayColor
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: displayColor.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ícono animado
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 200),
                          tween: Tween<double>(
                            begin: 0.9,
                            end: isSelected ? 1.0 : 0.9,
                          ),
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: Icon(
                                categoryIcon,
                                size: 16,
                                color: isSelected
                                    ? displayColor
                                    : Theme.of(context).brightness == Brightness.light
                                        ? AppTheme.darkGrey
                                        : AppTheme.mediumGrey,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: AppTheme.spacingSmall),
                        // Texto con posible animación
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? displayColor
                                : Theme.of(context).brightness == Brightness.light
                                    ? AppTheme.darkGrey
                                    : AppTheme.mediumGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Método para combinar el color de la categoría con el coral
  // para mantener la identidad de la categoría pero armonizar con el diseño
  Color _blendWithCoral(Color originalColor) {
    // Obtener los componentes HSL del color original
    HSLColor hslOriginal = HSLColor.fromColor(originalColor);
    // Obtener los componentes HSL del coral
    HSLColor hslCoral = HSLColor.fromColor(AppTheme.coralMain);
    
    // Combinar los colores, manteniendo algo del tono original
    // pero acercándolo al coral para mantener la coherencia de diseño
    return HSLColor.fromAHSL(
      1.0,
      // Conservar parcialmente el tono original
      lerpDouble(hslOriginal.hue, hslCoral.hue, 0.3)!,
      // Usar la saturación del coral para consistencia
      hslCoral.saturation,
      // Usar la luminosidad del coral para consistencia
      hslCoral.lightness,
    ).toColor();
  }
  
  // Función helper para interpolar entre dos valores
  double? lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}