// lib/screens/recipes/recipe_image_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/recipe_model.dart';
import '../../services/recipe_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/image_selector.dart';


class RecipeImageScreen extends StatefulWidget {
  final Recipe recipe;
  
  const RecipeImageScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeImageScreen> createState() => _RecipeImageScreenState();
}

class _RecipeImageScreenState extends State<RecipeImageScreen> {
  final RecipeService _recipeService = RecipeService();
  final StorageService _storageService = StorageService();
  
  bool _isLoading = false;
  File? _recipeImage;
  String _imageUrl = '';
  bool _imageChanged = false;
  
  @override
  void initState() {
    super.initState();
    _imageUrl = widget.recipe.imageUrl;
  }
  
  Future<void> _saveRecipeImage() async {
    if (!_imageChanged) {
      Navigator.pop(context);
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      String imageUrl = _imageUrl;
      
      // Si hay una nueva imagen, subirla
      if (_recipeImage != null) {
        if (kDebugMode) {
          print('Subiendo nueva imagen para receta ${widget.recipe.id}');
        }
        
        final uploadedUrl = await _storageService.uploadRecipeImage(_recipeImage!, widget.recipe.id);
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        } else {
          throw Exception('No se pudo subir la imagen');
        }
      } else if (_imageChanged) {
        // Si se eliminó la imagen
        imageUrl = '';
      }
      
      // Actualizar la receta con la nueva URL de imagen
      final updatedRecipe = widget.recipe.copyWith(imageUrl: imageUrl);
      await _recipeService.updateRecipe(updatedRecipe);
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagen actualizada correctamente'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      
      // Volver a la pantalla anterior con resultado positivo
      Navigator.pop(context, true);
    } catch (e) {
      if (kDebugMode) {
        print('Error al actualizar imagen: $e');
      }
      
      // Mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar imagen: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _cancelAndGoBack() {
    if (_imageChanged) {
      // Preguntar si realmente desea descartar los cambios
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Descartar cambios?'),
          content: const Text('Si sales ahora, se perderán los cambios realizados en la imagen.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Seguir editando'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar diálogo
                Navigator.pop(context); // Volver a la pantalla anterior
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralMain,
                foregroundColor: Colors.white,
              ),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Editar imagen',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _cancelAndGoBack,
        ),
        actions: [
          // Botón para guardar
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _saveRecipeImage,
            tooltip: 'Guardar cambios',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Guardando imagen...')
          : _buildContent(),
    );
  }
  
  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen de la receta
          const SectionHeader(
            title: 'Imagen de la receta',
            icon: Icons.photo_camera_rounded,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          
          Text(
            'La imagen ayuda a identificar la receta y la hace más atractiva.',
            style: TextStyle(
              color: AppTheme.mediumGrey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          
          // Selector de imagen
          ImageSelector(
            currentImageUrl: _imageUrl,
            title: 'imagen de la receta',
            height: 300,
            onImageSelected: (File image) {
              setState(() {
                _recipeImage = image;
                _imageChanged = true;
              });
            },
            onImageRemoved: () {
              setState(() {
                _recipeImage = null;
                _imageUrl = '';
                _imageChanged = true;
              });
            },
          ),
          const SizedBox(height: AppTheme.spacingXLarge),
          
          // Consejos para tomar buenas fotos
          const SectionHeader(
            title: 'Consejos para fotos de calidad',
            icon: Icons.lightbulb_outline_rounded,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          
          _buildTip(
            icon: Icons.wb_sunny_rounded,
            title: 'Utiliza buena iluminación',
            description: 'Usa luz natural siempre que sea posible. Evita la luz directa que crea sombras duras.',
          ),
          
          _buildTip(
            icon: Icons.crop_rounded,
            title: 'Encuadra adecuadamente',
            description: 'Asegúrate de que el plato ocupe la mayor parte de la foto, mostrando los detalles importantes.',
          ),
          
          _buildTip(
            icon: Icons.colorize_rounded,
            title: 'Destaca los colores',
            description: 'Los platos coloridos son más atractivos. Considera la presentación antes de fotografiar.',
          ),
          
          _buildTip(
            icon: Icons.camera_alt_rounded,
            title: 'Elige el mejor ángulo',
            description: 'Prueba diferentes ángulos: desde arriba para platos planos o lateral para mostrar altura.',
          ),
          
          _buildTip(
            icon: Icons.style_rounded,
            title: 'Mantén un estilo consistente',
            description: 'Usar un estilo similar en todas tus fotos hace que tu colección de recetas se vea más profesional.',
          ),
          
          const SizedBox(height: AppTheme.spacingXLarge * 2),
          
          // Botón para guardar
          CustomButton(
            text: 'Guardar cambios',
            icon: Icons.save_rounded,
            onPressed: _saveRecipeImage,
            type: ButtonType.primary,
            isFullWidth: true,
          ),
          const SizedBox(height: AppTheme.spacingLarge),
        ],
      ),
    );
  }
  
  Widget _buildTip({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : AppTheme.peachLight.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: AppTheme.coralMain.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppTheme.coralMain,
            size: 24,
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppTheme.mediumGrey,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}