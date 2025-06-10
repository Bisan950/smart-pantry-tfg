import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/recipe_model.dart';
import 'difficulty_indicator.dart';
import 'time_indicator.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool showCategories;
  final bool compact;
  final bool useHeroAnimation;
  final bool showDeleteButton;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onDelete,
    this.showCategories = true,
    this.compact = false,
    this.useHeroAnimation = true,
    this.showDeleteButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.symmetric(
        vertical: AppTheme.spacingSmall,
        horizontal: compact ? AppTheme.spacingSmall / 2 : AppTheme.spacingMedium,
      ),
      clipBehavior: Clip.antiAlias,
      elevation: compact ? 2 : 3,
      shadowColor: isDarkMode 
          ? Colors.black.withOpacity(0.3)
          : AppTheme.darkGrey.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        onLongPress: showDeleteButton && onDelete != null 
            ? () => _showRecipeOptions(context) 
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe image con Hero animation
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusLarge)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Aquí está el Hero condicional
                      _buildRecipeImage(),
                      
                      // Overlay gradient para mejorar legibilidad
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.4),
                              ],
                              stops: const [0.7, 1.0],
                            ),
                          ),
                        ),
                      ),
                      
                      // Tiempo de preparación
                      Positioned(
                        top: AppTheme.spacingSmall,
                        right: AppTheme.spacingSmall,
                        child: _buildTimeIndicator(isDarkMode),
                      ),
                      
                      // Categoría principal
                      if (recipe.categories.isNotEmpty && !compact)
                        Positioned(
                          bottom: AppTheme.spacingSmall,
                          left: AppTheme.spacingSmall,
                          child: _buildCategoryTag(recipe.categories.first),
                        ),
                        
                      // Botón de eliminar (ahora en la esquina superior IZQUIERDA)
                      if (showDeleteButton && onDelete != null)
                        Positioned(
                          top: 8,
                          left: 8, // Cambiado de right a left
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onDelete,
                                  splashColor: AppTheme.coralMain,
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Recipe content
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe name
                  Text(
                    recipe.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppTheme.pureWhite : AppTheme.darkGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: AppTheme.spacingXSmall),
                  
                  // Brief description - only shown if not compact
                  if (!compact) ...[
                    Text(
                      recipe.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? AppTheme.lightGrey : AppTheme.mediumGrey,
                        height: 1.3, // Mejor espaciado de línea
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                  ],
                  
                  // Additional information
                  Wrap(
                    spacing: AppTheme.spacingSmall,
                    runSpacing: AppTheme.spacingXSmall,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Difficulty
                      DifficultyIndicator(
                        difficulty: recipe.difficulty,
                        showLabel: !compact,
                        size: 12,
                      ),
                      
                      // Number of servings
                      _buildServingsIndicator(isDarkMode),
                    ],
                  ),
                  
                  // Additional categories (if there are more than one)
                  if (showCategories && recipe.categories.length > 1 && !compact) ...[
                    const SizedBox(height: AppTheme.spacingSmall),
                    _buildAdditionalCategories(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método para mostrar opciones de receta en un bottom sheet
  void _showRecipeOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Padding(
              padding: const EdgeInsets.only(
                left: 20, 
                right: 20, 
                bottom: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Opciones de receta
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                color: AppTheme.coralMain,
              ),
              title: const Text('Editar receta'),
              onTap: () {
                Navigator.pop(context);
                // Aquí irá la navegación a la pantalla de edición
              },
            ),
            
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Colors.red[400],
              ),
              title: const Text('Eliminar receta'),
              onTap: () {
                Navigator.pop(context);
                if (onDelete != null) {
                  onDelete!();
                }
              },
            ),
            
            ListTile(
              leading: Icon(
                Icons.share_outlined,
                color: AppTheme.darkGrey,
              ),
              title: const Text('Compartir receta'),
              onTap: () {
                Navigator.pop(context);
                // Aquí irá la lógica para compartir
              },
            ),
          ],
        ),
      ),
    );
  }

  // Método de construcción de imagen
  Widget _buildRecipeImage() {
    // Widget de imagen que se usará con o sin Hero
    final imageWidget = recipe.imageUrl.isNotEmpty
        ? Image.network(
            recipe.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          )
        : _buildPlaceholder();
        
    // Retorna Hero o la imagen directamente según el valor de useHeroAnimation
    return useHeroAnimation
        ? Hero(
            tag: 'recipe_image_${recipe.id}',
            child: imageWidget,
          )
        : imageWidget;
  }

  Widget _buildPlaceholder() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.peachLight.withOpacity(0.3),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 48,
          color: AppTheme.coralMain.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildTimeIndicator(bool isDarkMode) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppTheme.spacingSmall,
      vertical: AppTheme.spacingXSmall,
    ),
    decoration: BoxDecoration(
      color: isDarkMode
          ? Colors.black.withOpacity(0.6)
          : Colors.white.withOpacity(0.85),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TimeIndicator(
          minutes: recipe.totalTime,
          showLabel: false,
          size: 14,
          color: AppTheme.coralMain,
        ),
        // Eliminado el Text con el número de minutos
      ],
    ),
  );
}


  Widget _buildCategoryTag(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.coralMain,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: AppTheme.pureWhite,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildServingsIndicator(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppTheme.peachLight.withOpacity(isDarkMode ? 0.2 : 0.3),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_alt_rounded,
            size: 14,
            color: AppTheme.coralMain,
          ),
          const SizedBox(width: 4),
          Text(
            '${recipe.servings} ${recipe.servings == 1 ? 'porción' : 'porc.'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppTheme.pureWhite : AppTheme.darkGrey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalCategories() {
    return SizedBox(
      height: 26,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recipe.categories.length - 1, // Skip the first one already shown above
        itemBuilder: (context, index) {
          final actualIndex = index + 1; // Start from the second category
          return Container(
            margin: EdgeInsets.only(
              right: actualIndex < recipe.categories.length - 1
                  ? AppTheme.spacingXSmall
                  : 0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSmall,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppTheme.peachLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
              border: Border.all(
                color: AppTheme.coralMain.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              recipe.categories[actualIndex],
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.coralMain,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}