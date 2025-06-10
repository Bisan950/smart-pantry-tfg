import 'package:flutter/material.dart';
import '../../models/recipe_model.dart';
import '../../config/theme.dart';

class RecipeIngredientsList extends StatelessWidget {
  final List<RecipeIngredient> ingredients;

  const RecipeIngredientsList({
    super.key,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return Center(
        child: Text(
          'No hay ingredientes disponibles',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: AppTheme.mediumGrey,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = ingredients[index];
        return Card(
          elevation: AppTheme.elevationTiny,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2C2C2C)
              : AppTheme.lightGrey.withOpacity(0.5),
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Row(
              children: [
                // Indicador de disponibilidad
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: ingredient.isAvailable
                        ? AppTheme.successGreen
                        : ingredient.isOptional
                            ? AppTheme.yellowAccent
                            : AppTheme.coralMain,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (ingredient.isAvailable
                                ? AppTheme.successGreen
                                : ingredient.isOptional
                                    ? AppTheme.yellowAccent
                                    : AppTheme.coralMain)
                            .withOpacity(0.2),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Nombre del ingrediente
                Expanded(
                  child: Text(
                    ingredient.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                
                // Cantidad y unidad
                if (ingredient.quantity != null || ingredient.unit.isNotEmpty)
                  Text(
                    '${ingredient.quantity ?? ''} ${ingredient.unit}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                
                // Etiqueta de opcional
                if (ingredient.isOptional)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.yellowAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                    ),
                    child: Text(
                      'Opcional',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.yellowAccent.withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}