// lib/widgets/recipes/recipe_image_widget.dart

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/recipe_model.dart';
import '../../screens/recipes/recipe_image_screen.dart';

/// Widget para mostrar la imagen de una receta con opciones para editarla
class RecipeImageWidget extends StatelessWidget {
  final Recipe recipe;
  final Function(Recipe) onImageUpdated;
  final double height;
  final bool showEditButton;
  final bool isHero;
  final String? heroTag;
  
  const RecipeImageWidget({
    super.key,
    required this.recipe,
    required this.onImageUpdated,
    this.height = 200,
    this.showEditButton = true,
    this.isHero = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = _buildImage(context);
    
    // Si es un héroe y se proporciona una etiqueta, envolvemos en un widget Hero
    if (isHero && heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }
    
    return imageWidget;
  }
  
  Widget _buildImage(BuildContext context) {
    return Material(  // Usar Material para evitar errores de context
      color: Colors.transparent,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.peachLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Imagen o placeholder
                if (recipe.imageUrl.isNotEmpty)
                  Image.network(
                    recipe.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                  )
                else
                  _buildPlaceholder(),
                
                // Gradiente para mejorar legibilidad
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.5),
                      ],
                      stops: const [0.7, 1.0],
                    ),
                  ),
                ),
                
                // Botón de edición
                if (showEditButton)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => _navigateToImageEdit(context),
                          tooltip: recipe.imageUrl.isEmpty ? 'Añadir imagen' : 'Editar imagen',
                        ),
                      ),
                    ),
                  ),
                
                // Mensaje si no hay imagen
                if (recipe.imageUrl.isEmpty && showEditButton)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.coralMain,
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMedium,
                            vertical: AppTheme.spacingSmall,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Añadir una imagen a la receta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
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
    );
  }
  
  Widget _buildPlaceholder() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.peachLight.withOpacity(0.3),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 48,
              color: AppTheme.coralMain.withOpacity(0.5),
            ),
            const SizedBox(height: 10),
            if (!showEditButton) // Solo mostrar texto si no es editable
              Text(
                'Sin imagen',
                style: TextStyle(
                  color: AppTheme.coralMain.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _navigateToImageEdit(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeImageScreen(recipe: recipe),
      ),
    );
    
    // Si se actualizó la imagen, notificar al padre
    if (result == true) {
      // Aquí se asume que la pantalla RecipeImageScreen ha actualizado correctamente la receta en la base de datos
      // El componente padre debe recargar los datos para obtener la URL actualizada
      onImageUpdated(recipe);
    }
  }
}