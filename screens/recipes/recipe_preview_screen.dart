import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/recipe_model.dart';
import '../../widgets/recipes/recipe_card.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_button.dart';
import '../../services/recipe_service.dart';
import 'recipe_image_screen.dart';

class RecipePreviewScreen extends StatefulWidget {
  final Recipe recipe;
  
  const RecipePreviewScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipePreviewScreen> createState() => _RecipePreviewScreenState();
}

class _RecipePreviewScreenState extends State<RecipePreviewScreen> {
  late Recipe _recipe;
  final RecipeService _recipeService = RecipeService();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _loadRecipe();
  }
  
  // Cargar la receta más reciente para tener la URL de imagen actualizada
  Future<void> _loadRecipe() async {
    try {
      final updatedRecipe = await _recipeService.getRecipeById(_recipe.id);
      if (updatedRecipe != null) {
        setState(() {
          _recipe = updatedRecipe;
        });
      }
    } catch (e) {
      print('Error al cargar receta actualizada: $e');
    }
  }
  
  // Método para navegar a la pantalla de edición de imagen
  Future<void> _navigateToImageEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeImageScreen(recipe: _recipe),
      ),
    );
    
    // Si se actualizó la imagen, recargar la receta
    if (result == true) {
      setState(() {
        _isLoading = true;
      });
      
      await _loadRecipe();
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Vista previa de la receta',
        actions: [
          // Botón para editar imagen
          IconButton(
            icon: const Icon(Icons.photo_camera),
            onPressed: _navigateToImageEdit,
            tooltip: 'Editar imagen',
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información sobre la vista previa
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    decoration: BoxDecoration(
                      color: AppTheme.peachLight.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                      border: Border.all(
                        color: AppTheme.coralMain.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.coralMain,
                              size: 24,
                            ),
                            const SizedBox(width: AppTheme.spacingSmall),
                            const Expanded(
                              child: Text(
                                'Así se verá tu receta',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingSmall),
                        const Text(
                          'Puedes editar la imagen de la receta para hacerla más atractiva. Una buena imagen ayuda a identificar rápidamente la receta y hace que destaque en tu colección.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                  
                  // Sección de vista previa de tarjeta
                  const Text(
                    'Vista previa de la tarjeta:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  
                  // Tarjeta de receta centrada
                  Center(
                    child: SizedBox(
                      width: 300,
                      child: RecipeCard(
                        recipe: _recipe,
                        onTap: () {}, // No hacemos nada, solo es visualización
                        showCategories: true,
                        compact: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXLarge),
                  
                  // Sección de vista previa completa
                  const Text(
                    'Vista previa de detalle:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  
                  // Vista de detalle simulada
                  Container(
                    height: 260,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Imagen o placeholder
                          _recipe.imageUrl.isNotEmpty
                              ? Image.network(
                                  _recipe.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                                )
                              : _buildImagePlaceholder(),
                          
                          // Gradiente para legibilidad
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.1),
                                  Colors.black.withOpacity(0.7),
                                ],
                                stops: const [0.6, 1.0],
                              ),
                            ),
                          ),
                          
                          // Categorías en la parte inferior
                          if (_recipe.categories.isNotEmpty)
                            Positioned(
                              bottom: AppTheme.spacingMedium,
                              left: AppTheme.spacingMedium,
                              right: AppTheme.spacingMedium,
                              child: Wrap(
                                spacing: AppTheme.spacingSmall,
                                runSpacing: AppTheme.spacingXSmall,
                                children: _recipe.categories.take(3).map((category) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingMedium,
                                      vertical: AppTheme.spacingXSmall,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.coralMain,
                                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        color: AppTheme.pureWhite,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                  
                  // Botón para editar imagen
                  CustomButton(
                    text: _recipe.imageUrl.isEmpty ? 'Añadir imagen' : 'Cambiar imagen',
                    icon: Icons.photo_camera_rounded,
                    onPressed: _navigateToImageEdit,
                    type: ButtonType.primary,
                    isFullWidth: true,
                  ),
                  
                  const SizedBox(height: AppTheme.spacingMedium),
                  
                  // Botón para volver
                  CustomButton(
                    text: 'Volver',
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.pop(context),
                    type: ButtonType.outline,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: AppTheme.spacingXLarge),
                ],
              ),
            ),
    );
  }
  
  Widget _buildImagePlaceholder() {
    return Container(
      color: AppTheme.peachLight.withOpacity(0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 80,
              color: AppTheme.coralMain.withOpacity(0.5),
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              'No hay imagen disponible',
              style: TextStyle(
                color: AppTheme.coralMain.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}