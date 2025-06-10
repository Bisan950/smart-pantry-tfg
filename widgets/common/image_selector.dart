// lib/widgets/common/image_selector.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';

class ImageSelector extends StatefulWidget {
  final String? currentImageUrl;
  final Function(File) onImageSelected;
  final Function() onImageRemoved;
  final String title;
  final double height;
  final bool showRemoveButton;

  const ImageSelector({
    super.key,
    this.currentImageUrl,
    required this.onImageSelected,
    required this.onImageRemoved,
    this.title = 'Imagen',
    this.height = 200,
    this.showRemoveButton = true,
  });

  @override
  State<ImageSelector> createState() => _ImageSelectorState();
}

class _ImageSelectorState extends State<ImageSelector> {
  final _picker = ImagePicker();
  File? _selectedImage;

  // Método para tomar una foto con la cámara
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
        });
        widget.onImageSelected(_selectedImage!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al tomar la foto: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  // Método para seleccionar una imagen de la galería
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        widget.onImageSelected(_selectedImage!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar la imagen: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }
  
  // Mostrar opciones de imagen
  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusLarge)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.mediumGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall)
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 15),
              child: Text('Opciones de imagen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildImageOptionTile(
              icon: Icons.camera_alt_rounded,
              title: 'Tomar foto',
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            _buildImageOptionTile(
              icon: Icons.photo_library_rounded,
              title: 'Seleccionar de la galería',
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            if ((_selectedImage != null || widget.currentImageUrl != null) && widget.showRemoveButton)
              _buildImageOptionTile(
                icon: Icons.delete_rounded,
                title: 'Eliminar imagen',
                color: AppTheme.errorRed,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                  });
                  widget.onImageRemoved();
                },
              ),
            const SizedBox(height: AppTheme.spacingLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              color: color == null 
                ? Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : AppTheme.peachLight.withOpacity(0.3)
                : color.withOpacity(0.1),
            ),
            child: Row(
              children: [
                Icon(icon, color: color ?? AppTheme.coralMain, size: 26),
                const SizedBox(width: 15),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF222222)
            : AppTheme.peachLight.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: AppTheme.coralMain.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: _showImageOptions,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge - 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge - 2),
          child: _buildImageContent(),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    // Si hay una imagen seleccionada, mostrarla
    if (_selectedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            _selectedImage!,
            fit: BoxFit.cover,
          ),
          // Superposición sutil para hacer el texto más legible
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Información de la imagen
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
              ),
              child: const Text(
                'Imagen seleccionada',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Si hay una URL de imagen existente, mostrarla
    if (widget.currentImageUrl != null && widget.currentImageUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.currentImageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppTheme.coralMain,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_rounded,
                      size: 48,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                    const Text(
                      'Error al cargar la imagen',
                      style: TextStyle(
                        color: AppTheme.errorRed,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Superposición sutil
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Información de la imagen
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
              ),
              child: const Text(
                'Imagen guardada',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Si no hay imagen, mostrar placeholder
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_rounded,
          size: 48,
          color: AppTheme.coralMain.withOpacity(0.7),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        Text(
          'Añadir ${widget.title.toLowerCase()}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingXSmall),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
          child: Text(
            'Toma una foto o selecciona de la galería',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}