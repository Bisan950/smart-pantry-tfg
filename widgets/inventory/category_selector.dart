// lib/screens/shopping_list/components/category_selector_simplified.dart

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
        const Padding(
          padding: EdgeInsets.only(
            left: AppTheme.spacingXSmall,
            bottom: AppTheme.spacingXSmall,
          ),
          child: Text(
            'Categoría',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
            
            return InkWell(
              onTap: () => onCategorySelected(category),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSmall,
                  vertical: AppTheme.spacingXSmall,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? categoryColor.withOpacity(0.2)
                      : Theme.of(context).brightness == Brightness.light
                          ? AppTheme.lightGrey
                          : AppTheme.darkGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                  border: isSelected
                      ? Border.all(color: categoryColor, width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      categoryIcon,
                      size: 16,
                      color: isSelected
                          ? categoryColor
                          : Theme.of(context).brightness == Brightness.light
                              ? AppTheme.darkGrey
                              : AppTheme.mediumGrey,
                    ),
                    const SizedBox(width: AppTheme.spacingXSmall),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? categoryColor
                            : Theme.of(context).brightness == Brightness.light
                                ? AppTheme.darkGrey
                                : AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}