// lib/widgets/recipes/recipe_category_selector.dart
// Widget para seleccionar categorías de recetas

import 'package:flutter/material.dart';
import '../../config/theme.dart';

class RecipeCategorySelector extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const RecipeCategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          
          return Padding(
            padding: EdgeInsets.only(
              right: 8,
              left: index == 0 ? 0 : 0,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onCategorySelected(category),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.coralMain 
                        : isDarkMode
                            ? const Color(0xFF2A2A2A)
                            : AppTheme.peachLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                    border: Border.all(
                      color: isSelected 
                          ? AppTheme.coralMain 
                          : isDarkMode
                              ? const Color(0xFF3A3A3A)
                              : AppTheme.peachLight,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected 
                            ? Colors.white 
                            : isDarkMode
                                ? Colors.white
                                : AppTheme.darkGrey,
                        fontWeight: isSelected 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}