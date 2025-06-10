import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/meal_plan_model.dart';

class MealPlanCard extends StatelessWidget {
  final MealPlan mealPlan;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onCompleteToggle;

  const MealPlanCard({
    super.key,
    required this.mealPlan,
    this.onTap,
    this.onDelete,
    this.onCompleteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = mealPlan.recipe;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.pureWhite,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              border: Border.all(
                color: mealPlan.isCompleted 
                    ? AppTheme.successGreen.withOpacity(0.3)
                    : AppTheme.lightGrey.withOpacity(0.5),
                width: mealPlan.isCompleted ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen de la receta con overlay mejorado
                if (recipe != null && recipe.imageUrl.isNotEmpty)
                  _buildImageSection(recipe)
                else
                  _buildPlaceholderSection(),
                
                // Información de la receta
                _buildContentSection(recipe),
                
                // Acciones mejoradas
                if (onDelete != null || onCompleteToggle != null)
                  _buildActionsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(dynamic recipe) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppTheme.borderRadiusLarge),
        topRight: Radius.circular(AppTheme.borderRadiusLarge),
      ),
      child: Stack(
        children: [
          // Imagen principal
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Image.network(
              recipe.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.peachLight.withOpacity(0.3),
                        AppTheme.coralMain.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.restaurant_rounded,
                      color: AppTheme.coralMain.withOpacity(0.5),
                      size: 40,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Overlay con gradiente
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
          
          // Indicadores en la esquina superior
          Positioned(
            top: AppTheme.spacingMedium,
            left: AppTheme.spacingMedium,
            child: Row(
              children: [
                // Disponibilidad de ingredientes
                if (recipe.ingredients.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMedium,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getIngredientsColor(recipe.availableIngredientsPercentage),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_rounded,
                          size: 14,
                          color: AppTheme.pureWhite,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${(recipe.availableIngredientsPercentage * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.pureWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Indicador de completado mejorado
          if (mealPlan.isCompleted)
            Positioned(
              top: AppTheme.spacingMedium,
              right: AppTheme.spacingMedium,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      color: AppTheme.pureWhite,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Completado',
                      style: TextStyle(
                        color: AppTheme.pureWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Información superpuesta en la parte inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(AppTheme.spacingMedium),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Tiempo de cocción
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSmall,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.pureWhite.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppTheme.coralMain,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${recipe.cookingTime} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(width: AppTheme.spacingSmall),
                  
                  // Calorías
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSmall,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.pureWhite.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: AppTheme.warningOrange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${recipe.calories} kcal',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Spacer(),
                  
                  // Dificultad
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSmall,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(recipe.difficulty).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getDifficultyIcon(recipe.difficulty),
                          size: 14,
                          color: AppTheme.pureWhite,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _getDifficultyText(recipe.difficulty),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.pureWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderSection() {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppTheme.borderRadiusLarge),
        topRight: Radius.circular(AppTheme.borderRadiusLarge),
      ),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.peachLight.withOpacity(0.3),
              AppTheme.coralMain.withOpacity(0.1),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_rounded,
                size: 40,
                color: AppTheme.coralMain.withOpacity(0.5),
              ),
              SizedBox(height: AppTheme.spacingSmall),
              Text(
                'Sin imagen',
                style: TextStyle(
                  color: AppTheme.coralMain.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentSection(dynamic recipe) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre de la receta
          Text(
            recipe?.name ?? 'Receta sin nombre',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: mealPlan.isCompleted 
                  ? AppTheme.mediumGrey 
                  : AppTheme.darkGrey,
              decoration: mealPlan.isCompleted 
                  ? TextDecoration.lineThrough 
                  : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          SizedBox(height: AppTheme.spacingSmall),
          
          // Descripción
          if (recipe != null && recipe.description.isNotEmpty)
            Text(
              recipe.description,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mediumGrey,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          
          if (recipe != null && recipe.description.isNotEmpty)
            SizedBox(height: AppTheme.spacingMedium),
          
          // Categorías/Tags
          if (recipe != null && recipe.categories.isNotEmpty)
            Wrap(
              spacing: AppTheme.spacingSmall,
              runSpacing: AppTheme.spacingSmall,
              children: recipe.categories.take(3).map<Widget>((category) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSmall,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.coralMain.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    border: Border.all(
                      color: AppTheme.coralMain.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.coralMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacingLarge,
        0,
        AppTheme.spacingLarge,
        AppTheme.spacingMedium,
      ),
      child: Row(
        children: [
          // Botón para marcar como completado/deshacer - SOLO TEXTO
          if (onCompleteToggle != null)
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextButton.icon(
                  onPressed: () => onCompleteToggle!(!mealPlan.isCompleted),
                  icon: Icon(
                    mealPlan.isCompleted 
                        ? Icons.undo_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                  ),
                  label: Text(
                    mealPlan.isCompleted ? 'Deshacer' : 'Completar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: mealPlan.isCompleted 
                        ? AppTheme.mediumGrey
                        : AppTheme.successGreen,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    ),
                  ),
                ),
              ),
            ),
          
          if (onCompleteToggle != null && onDelete != null)
            SizedBox(width: AppTheme.spacingMedium),
          
          // Botón para eliminar
          if (onDelete != null)
            SizedBox(
              height: 40,
              width: 40,
              child: ElevatedButton(
                onPressed: onDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed.withOpacity(0.1),
                  foregroundColor: AppTheme.errorRed,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Métodos auxiliares (mantienen la misma lógica)
  Color _getIngredientsColor(double percentage) {
    if (percentage >= 0.8) return AppTheme.successGreen;
    if (percentage >= 0.5) return AppTheme.yellowAccent;
    return AppTheme.coralMain;
  }
  
  IconData _getDifficultyIcon(dynamic difficulty) {
    if (difficulty == null) return Icons.help_outline_rounded;
    
    if (difficulty is int || difficulty.runtimeType.toString().contains('DifficultyLevel')) {
      switch (difficulty) {
        case 0:
          return Icons.sentiment_satisfied_rounded;
        case 1:
          return Icons.sentiment_neutral_rounded;
        case 2:
          return Icons.sentiment_dissatisfied_rounded;
        default:
          return Icons.help_outline_rounded;
      }
    }
    
    if (difficulty is String) {
      final difficultyLower = difficulty.toLowerCase();
      if (difficultyLower.contains('fácil') || difficultyLower.contains('facil') || difficultyLower.contains('easy')) {
        return Icons.sentiment_satisfied_rounded;
      } else if (difficultyLower.contains('media') || difficultyLower.contains('medium')) {
        return Icons.sentiment_neutral_rounded;
      } else if (difficultyLower.contains('difícil') || difficultyLower.contains('dificil') || difficultyLower.contains('hard')) {
        return Icons.sentiment_dissatisfied_rounded;
      }
    }
    
    return Icons.help_outline_rounded;
  }
  
  Color _getDifficultyColor(dynamic difficulty) {
    if (difficulty == null) return AppTheme.mediumGrey;
    
    if (difficulty is int || difficulty.runtimeType.toString().contains('DifficultyLevel')) {
      switch (difficulty) {
        case 0:
          return AppTheme.successGreen;
        case 1:
          return AppTheme.yellowAccent;
        case 2:
          return AppTheme.coralMain;
        default:
          return AppTheme.mediumGrey;
      }
    }
    
    if (difficulty is String) {
      final difficultyLower = difficulty.toLowerCase();
      if (difficultyLower.contains('fácil') || difficultyLower.contains('facil') || difficultyLower.contains('easy')) {
        return AppTheme.successGreen;
      } else if (difficultyLower.contains('media') || difficultyLower.contains('medium')) {
        return AppTheme.yellowAccent;
      } else if (difficultyLower.contains('difícil') || difficultyLower.contains('dificil') || difficultyLower.contains('hard')) {
        return AppTheme.coralMain;
      }
    }
    
    return AppTheme.mediumGrey;
  }
  
  String _getDifficultyText(dynamic difficulty) {
    if (difficulty == null) return 'Desconocida';
    
    if (difficulty is int || difficulty.runtimeType.toString().contains('DifficultyLevel')) {
      switch (difficulty) {
        case 0:
          return 'Fácil';
        case 1:
          return 'Media';
        case 2:
          return 'Difícil';
        default:
          return 'Desconocida';
      }
    }
    
    if (difficulty is String) {
      final difficultyLower = difficulty.toLowerCase();
      if (difficultyLower.contains('fácil') || difficultyLower.contains('facil') || difficultyLower.contains('easy')) {
        return 'Fácil';
      } else if (difficultyLower.contains('media') || difficultyLower.contains('medium')) {
        return 'Media';
      } else if (difficultyLower.contains('difícil') || difficultyLower.contains('dificil') || difficultyLower.contains('hard')) {
        return 'Difícil';
      }
    }
    
    return 'Desconocida';
  }
}