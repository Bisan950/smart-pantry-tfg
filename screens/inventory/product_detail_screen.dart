// lib/screens/inventory/product_detail_screen.dart - MEJORADO CON MACROS NUTRICIONALES

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../services/inventory_service.dart';
import '../../services/nutritional_analysis_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/inventory/product_counter.dart';
import 'add_product_screen.dart';
import '../../models/product_location_model.dart';
import '../../services/shopping_list_service.dart';
import '../../providers/shopping_list_provider.dart';


class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  final InventoryService _inventoryService = InventoryService();
  final NutritionalAnalysisService _nutritionalService = NutritionalAnalysisService(); // ¡NUEVO!
  final ImagePicker _picker = ImagePicker();
  
  late int _currentQuantity;
  late int _maxQuantity;
  late bool _hasMaxQuantity;
  int _step = 1;
  bool _isLoading = false;
  bool _isAnalyzingNutrition = false; // ¡NUEVO!
  
  // ¡NUEVA VARIABLE PARA INFORMACIÓN NUTRICIONAL!
  NutritionalInfo? _nutritionalInfo;
  
  // Animaciones
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _currentQuantity = widget.product.quantity;
    _maxQuantity = widget.product.maxQuantity;
    _hasMaxQuantity = widget.product.maxQuantity > 0;
    _nutritionalInfo = widget.product.nutritionalInfo; // ¡CARGAR INFO NUTRICIONAL!
    
    _setDefaultStepForUnit(widget.product.unit);
    _initAnimations();
  }
  
  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ¡NUEVO MÉTODO PARA ESCANEAR ETIQUETA NUTRICIONAL!
  Future<void> _scanNutritionalLabel() async {
    if (_isAnalyzingNutrition) return;
    
    try {
      final imageSource = await _showImageSourceDialog();
      if (imageSource == null) return;
      
      setState(() {
        _isAnalyzingNutrition = true;
      });
      
      final XFile? image = await _picker.pickImage(
        source: imageSource,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      
      if (image == null) {
        setState(() {
          _isAnalyzingNutrition = false;
        });
        return;
      }
      
      final imageFile = File(image.path);
      final nutritionalInfo = await _nutritionalService.analyzeNutritionalLabel(imageFile);
      
      if (nutritionalInfo != null && mounted) {
        setState(() {
          _nutritionalInfo = nutritionalInfo;
        });
        
        // Actualizar en la base de datos
        await _updateProductNutritionalInfo(nutritionalInfo);
        
        _showSuccessSnackBar('¡Información nutricional detectada correctamente!');
        _showNutritionalInfoDialog(nutritionalInfo);
      } else if (mounted) {
        _showWarningSnackBar('No se pudo detectar información nutricional clara. Intenta con una imagen más nítida.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al analizar etiqueta: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingNutrition = false;
        });
      }
    }
  }
  
  // ¡NUEVO MÉTODO PARA MOSTRAR OPCIONES DE FUENTE DE IMAGEN!
  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        title: Text('Seleccionar imagen'),
        content: Text('¿Cómo quieres capturar la etiqueta nutricional?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt, size: 18),
                SizedBox(width: 8),
                Text('Cámara'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library, size: 18),
                SizedBox(width: 8),
                Text('Galería'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ¡NUEVO MÉTODO PARA MOSTRAR INFORMACIÓN NUTRICIONAL DETECTADA!
  void _showNutritionalInfoDialog(NutritionalInfo info) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        child: Container(
          padding: EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      color: AppTheme.successGreen,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: Text(
                      'Información Nutricional Detectada',
                      style: AppTextStyles.heading5.copyWith(
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingLarge),
              
              _buildNutritionalInfoRow('Porción', 
                info.servingUnit ?? '${info.servingSize?.toStringAsFixed(0)}g'),
              if (info.calories != null)
                _buildNutritionalInfoRow('Calorías', '${info.calories} kcal'),
              if (info.proteins != null)
                _buildNutritionalInfoRow('Proteínas', '${info.proteins!.toStringAsFixed(1)}g'),
              if (info.carbohydrates != null)
                _buildNutritionalInfoRow('Carbohidratos', '${info.carbohydrates!.toStringAsFixed(1)}g'),
              if (info.fats != null)
                _buildNutritionalInfoRow('Grasas', '${info.fats!.toStringAsFixed(1)}g'),
              if (info.fiber != null)
                _buildNutritionalInfoRow('Fibra', '${info.fiber!.toStringAsFixed(1)}g'),
              if (info.sugar != null)
                _buildNutritionalInfoRow('Azúcares', '${info.sugar!.toStringAsFixed(1)}g'),
              if (info.sodium != null)
                _buildNutritionalInfoRow('Sodio', '${info.sodium!.toStringAsFixed(0)}mg'),
              
              SizedBox(height: AppTheme.spacingLarge),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNutritionalInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppTheme.mediumGrey,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ¡NUEVO MÉTODO PARA ACTUALIZAR INFORMACIÓN NUTRICIONAL EN LA BD!
  Future<void> _updateProductNutritionalInfo(NutritionalInfo nutritionalInfo) async {
    try {
      final updatedProduct = widget.product.copyWith(
        nutritionalInfo: nutritionalInfo,
      );
      
      await _inventoryService.updateProduct(updatedProduct);
    } catch (e) {
      print('Error actualizando información nutricional: $e');
    }
  }

  // Método para establecer el paso predeterminado según la unidad
  void _setDefaultStepForUnit(String unit) {
    final Map<String, List<int>> stepOptions = {
      'unidades': [1, 2, 5, 10],
      'g': [5, 10, 25, 50, 100, 250, 500],
      'kg': [1, 2, 5],
      'ml': [5, 10, 25, 50, 100, 250, 500],
      'L': [1, 2, 5],
      'paquete': [1, 2, 5],
      'lata': [1, 2, 5],
      'botella': [1, 2, 5],
    };
    
    final steps = stepOptions[unit] ?? [1];
    setState(() {
      _step = steps.first;
    });
  }

  void _updateQuantity(int newQuantity) async {
    // Actualizar el estado local inmediatamente para mejor UX
    setState(() {
      _currentQuantity = newQuantity;
    });
    
    try {
      // Actualizar en la base de datos en segundo plano
      if (_hasMaxQuantity) {
        _inventoryService.updateProductQuantity(
          widget.product.id, 
          newQuantity,
          maxQuantity: _maxQuantity,
        );
      } else {
        _inventoryService.updateProductQuantity(widget.product.id, newQuantity);
      }
      
      // Verificar si el producto debe eliminarse
      if (newQuantity <= 0) {
        _showRemoveProductDialog();
      }
    } catch (e) {
      // En caso de error, restaurar el estado anterior y mostrar mensaje
      if (mounted) {
        setState(() {
          _currentQuantity = widget.product.quantity; // Restaurar cantidad original
        });
        _showErrorSnackBar('Error al actualizar cantidad: $e');
      }
    }
  }

  void _editProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(productToEdit: widget.product),
      ),
    );
    
    // Solo recargar si se realizaron cambios
    if (result == true) {
      _reloadProductDetails();
    }
  }

  void _reloadProductDetails() async {
    if (_isLoading) return; // Evitar múltiples llamadas simultáneas
    
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedProduct = await _inventoryService.getProductById(widget.product.id);
      
      if (updatedProduct != null && mounted) {
        setState(() {
          _currentQuantity = updatedProduct.quantity;
          _maxQuantity = updatedProduct.maxQuantity;
          _hasMaxQuantity = updatedProduct.maxQuantity > 0;
          _nutritionalInfo = updatedProduct.nutritionalInfo;
          _isLoading = false;
        });
        
        _showSuccessSnackBar('Producto actualizado correctamente');
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (updatedProduct == null) {
          Navigator.pop(context);
          _showErrorSnackBar('El producto ya no existe');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error al cargar producto: $e');
      }
    }
  }

  void _deleteProduct() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Estás seguro de eliminar ${widget.product.name}?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.mediumGrey)),
          ),
          TextButton(
            onPressed: () {
              _inventoryService.deleteProduct(widget.product.id);
              Navigator.pop(context);
              Navigator.pop(context);
              _showSuccessSnackBar('${widget.product.name} eliminado');
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showRemoveProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Producto agotado'),
        content: Text('La cantidad de ${widget.product.name} ahora es cero. ¿Deseas eliminarlo de tu inventario?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.mediumGrey)),
          ),
          TextButton(
            onPressed: () {
              _inventoryService.deleteProduct(widget.product.id);
              Navigator.pop(context);
              Navigator.pop(context);
              _showSuccessSnackBar('${widget.product.name} eliminado');
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // [RESTO DE MÉTODOS HELPER EXISTENTES...]
  
  String _getExpiryStatusText() {
    if (widget.product.expiryDate == null) {
      return 'Sin fecha de caducidad';
    }
    
    final daysUntilExpiry = widget.product.daysUntilExpiry;
    
    if (daysUntilExpiry < 0) {
      return 'Caducado hace ${-daysUntilExpiry} días';
    } else if (daysUntilExpiry == 0) {
      return 'Caduca hoy';
    } else if (daysUntilExpiry == 1) {
      return 'Caduca mañana';
    } else {
      return 'Caduca en $daysUntilExpiry días';
    }
  }

  Color _getExpiryStatusColor() {
    if (widget.product.expiryDate == null) {
      return AppTheme.darkGrey;
    }
    
    final daysUntilExpiry = widget.product.daysUntilExpiry;
    
    if (daysUntilExpiry < 0) {
      return AppTheme.errorRed;
    } else if (daysUntilExpiry <= 3) {
      return AppTheme.warningOrange;
    } else if (daysUntilExpiry <= 7) {
      return AppTheme.warningOrange.withOpacity(0.7);
    } else {
      return AppTheme.successGreen;
    }
  }
  
  Color _getProgressColor(double percentage) {
    if (percentage <= 0.25) {
      return AppTheme.errorRed;
    } else if (percentage <= 0.5) {
      return AppTheme.warningOrange;
    } else {
      return AppTheme.successGreen;
    }
  }
  
  Color _getLocationColor() {
    switch (widget.product.location) {
      case 'Nevera':
        return const Color(0xFF64B5F6);
      case 'Congelador':
        return const Color(0xFF00B4D8);
      case 'Despensa':
        return AppTheme.warningOrange;
      case 'Armario':
        return const Color(0xFF8D6E63);
      case 'Especias':
        return AppTheme.coralMain;
      default:
        return const Color(0xFF64B5F6);
    }
  }

  List<int> _getStepOptions() {
    final Map<String, List<int>> stepOptions = {
      'unidades': [1, 2, 5, 10],
      'g': [5, 10, 25, 50, 100, 250, 500],
      'kg': [1, 2, 5],
      'ml': [5, 10, 25, 50, 100, 250, 500],
      'L': [1, 2, 5],
      'paquete': [1, 2, 5],
      'lata': [1, 2, 5],
      'botella': [1, 2, 5],
    };
    
    return stepOptions[widget.product.unit] ?? [1];
  }

  // [MÉTODOS DE SHOPPING LIST EXISTENTES...]
  
  Future<void> _addToShoppingList() async {
    try {
      final shoppingItem = ShoppingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: widget.product.name,
        quantity: 1,
        unit: widget.product.unit,
        category: widget.product.category,
        isPurchased: false,
      );
      
      final shoppingListService = ShoppingListService();
      await shoppingListService.addShoppingItem(shoppingItem);
      
      if (mounted) {
        _reloadProductDetails();
        _showSuccessSnackBar('${widget.product.name} añadido al carrito');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }
  
  Future<int?> _showQuantityDialog() async {
    final quantityController = TextEditingController(text: "1");
    
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cantidad para el carrito'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad (${widget.product.unit})',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  borderSide: const BorderSide(color: AppTheme.coralMain, width: 2),
                ),
              ),
              cursorColor: AppTheme.coralMain,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.mediumGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                Navigator.of(context).pop(quantity);
              } else {
                _showErrorSnackBar('Por favor, introduce una cantidad válida');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralMain,
              foregroundColor: AppTheme.pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addToShoppingListWithQuantity() async {
    final quantity = await _showQuantityDialog();
    
    if (quantity == null) return;
    
    try {
      final shoppingItem = ShoppingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: widget.product.name,
        quantity: quantity,
        unit: widget.product.unit,
        category: widget.product.category,
        isPurchased: false,
      );
      
      final shoppingListService = ShoppingListService();
      await shoppingListService.addShoppingItem(shoppingItem);
      
      if (mounted) {
        _reloadProductDetails();
        _showSuccessSnackBar('${widget.product.name} añadido al carrito ($quantity ${widget.product.unit})');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.pureWhite, size: 20),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.pureWhite,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.successGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.all(AppTheme.spacingMedium),
    ),
  );
}

void _showWarningSnackBar(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.warning_rounded, color: AppTheme.pureWhite, size: 20),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.pureWhite,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.warningOrange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.all(AppTheme.spacingMedium),
    ),
  );
}

void _showErrorSnackBar(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_rounded, color: AppTheme.pureWhite, size: 20),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.pureWhite,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.errorRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.all(AppTheme.spacingMedium),
    ),
  );
}

  @override
Widget build(BuildContext context) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final percentRemaining = _hasMaxQuantity ? (_currentQuantity / _maxQuantity).clamp(0.0, 1.0) : 1.0;
  
  return Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: CustomAppBar(
      title: widget.product.name,
      actions: [
        Container(
          margin: EdgeInsets.only(right: AppTheme.spacingSmall),
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          ),
          child: IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed),
            onPressed: _deleteProduct,
            tooltip: 'Eliminar producto',
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        // Contenido scrolleable
        Expanded(
          child: _isLoading 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralMain),
                    ),
                    SizedBox(height: AppTheme.spacingMedium),
                    Text(
                      'Cargando producto...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMedium),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero Section - Imagen del producto
                          _buildHeroSection(),
                          SizedBox(height: AppTheme.spacingLarge),
                          
                          // Información básica del producto
                          _buildBasicInfoSection(),
                          SizedBox(height: AppTheme.spacingMedium),
                          
                          // Sección de información nutricional
                          _buildNutritionalInfoSection(),
                          SizedBox(height: AppTheme.spacingMedium),
                          
                          // Información de stock y cantidad
                          if (_hasMaxQuantity) ...[
                            _buildStockSection(percentRemaining),
                            SizedBox(height: AppTheme.spacingMedium),
                          ],
                          
                          // Gestión de cantidad
                          _buildQuantitySection(),
                          SizedBox(height: AppTheme.spacingMedium),
                          
                          // Información de caducidad
                          _buildExpirySection(),
                          SizedBox(height: AppTheme.spacingMedium),
                          
                          // Sección de ubicación y acciones
                          _buildLocationSection(),
                          
                          // Espacio adicional para evitar que el contenido se oculte detrás de los botones
                          SizedBox(height: AppTheme.spacingLarge),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ),
        
        // Botones anclados en la parte inferior
        _buildBottomActionButtons(),
      ],
    ),
  );
}

// Nuevo método para los botones anclados en la parte inferior
Widget _buildBottomActionButtons() {
  return Container(
    padding: EdgeInsets.all(AppTheme.spacingMedium),
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón principal de editar
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.coralMain,
                  AppTheme.coralMain.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.coralMain.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                onTap: _editProduct,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        color: AppTheme.pureWhite,
                        size: 24,
                      ),
                      SizedBox(width: AppTheme.spacingMedium),
                      Text(
                        'Editar Producto',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppTheme.pureWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          SizedBox(height: AppTheme.spacingMedium),
          
          // Botones secundarios
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.softTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    border: Border.all(color: AppTheme.softTeal.withOpacity(0.3)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => _buildAddToCartSheet(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppTheme.borderRadiusLarge),
                            ),
                          ),
                        );
                      },
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_rounded,
                              color: AppTheme.softTeal,
                              size: 20,
                            ),
                            SizedBox(width: AppTheme.spacingSmall),
                            Text(
                              'Al Carrito',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppTheme.softTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.yellowAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    border: Border.all(color: AppTheme.yellowAccent.withOpacity(0.3)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                      onTap: () {
                        // Compartir producto o añadir a favoritos
                        _showSuccessSnackBar('Funcionalidad próximamente');
                      },
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.share_rounded,
                              color: AppTheme.yellowAccent,
                              size: 20,
                            ),
                            SizedBox(width: AppTheme.spacingSmall),
                            Text(
                              'Compartir',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppTheme.yellowAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  // ¡NUEVA SECCIÓN HERO MEJORADA!
  Widget _buildHeroSection() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.coralMain.withOpacity(0.1),
            AppTheme.peachLight.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Imagen del producto
          if (widget.product.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
              child: Image.network(
                widget.product.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
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
                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
              ),
            )
          else
            _buildImagePlaceholder(),
          
          // Overlay con información básica
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(AppTheme.spacingLarge),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppTheme.borderRadiusXLarge),
                  bottomRight: Radius.circular(AppTheme.borderRadiusXLarge),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.product.name,
                          style: AppTextStyles.heading4.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppTheme.spacingSmall),
                        Row(
                          children: [
                            _buildInfoChip(
                              context: context,
                              icon: _getLocationIcon(widget.product.location),
                              label: widget.product.location,
                              color: _getLocationColor(),
                            ),
                            SizedBox(width: AppTheme.spacingSmall),
                            _buildInfoChip(
                              context: context,
                              icon: _getCategoryIcon(widget.product.category),
                              label: widget.product.category,
                              color: AppTheme.softTeal,
                            ),
                          ],
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

  // ¡NUEVA SECCIÓN DE INFORMACIÓN BÁSICA MEJORADA!
  Widget _buildBasicInfoSection() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.coralMain.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.coralMain,
                  size: 20,
                ),
              ),
              SizedBox(width: AppTheme.spacingSmall),
              Text(
                'Información del producto',
                style: AppTextStyles.heading5.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLarge),
          
          // Cantidad actual destacada
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppTheme.spacingMedium),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.coralMain.withOpacity(0.1),
                  AppTheme.peachLight.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cantidad disponible',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$_currentQuantity ${widget.product.unit}',
                      style: AppTextStyles.heading4.copyWith(
                        color: AppTheme.coralMain,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.coralMain.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: AppTheme.coralMain,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ¡NUEVA SECCIÓN DE INFORMACIÓN NUTRICIONAL!
Widget _buildNutritionalInfoSection() {
  return Container(
    padding: EdgeInsets.all(AppTheme.spacingLarge),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.softTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: AppTheme.softTeal,
                size: 20,
              ),
            ),
            SizedBox(width: AppTheme.spacingSmall),
            Expanded(
              child: Text(
                'Información Nutricional',
                style: AppTextStyles.heading5.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (_nutritionalInfo != null)
              IconButton(
                icon: Icon(Icons.edit_rounded, size: 20),
                color: AppTheme.softTeal,
                onPressed: () => _showManualNutritionDialog(),
                tooltip: 'Editar información nutricional',
              ),
          ],
        ),
        SizedBox(height: AppTheme.spacingMedium),
        
        if (_nutritionalInfo != null && _nutritionalInfo!.hasNutritionalInfo) ...[
          // Mostrar información nutricional existente
          _buildNutritionalDisplay(),
        ] else ...[
          // Estado vacío mejorado
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppTheme.spacingLarge),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.lightGrey.withOpacity(0.05),
                  AppTheme.peachLight.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              border: Border.all(
                color: AppTheme.lightGrey.withOpacity(0.2),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingMedium),
                  decoration: BoxDecoration(
                    color: AppTheme.mediumGrey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppTheme.mediumGrey,
                    size: 32,
                  ),
                ),
                SizedBox(height: AppTheme.spacingMedium),
                Text(
                  'Sin información nutricional',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppTheme.mediumGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppTheme.spacingSmall),
                Text(
                  'Añade información nutricional para un mejor control de tu dieta',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppTheme.mediumGrey.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacingLarge),
        ],
        
        // Botones de acción organizados en grid
        _buildNutritionActionButtons(),
      ],
    ),
  );
}

Widget _buildNutritionActionButtons() {
  return Column(
    children: [
      // Botón principal para escanear
      Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.softTeal,
              AppTheme.softTeal.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppTheme.softTeal.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            onTap: _isAnalyzingNutrition ? null : _scanNutritionalLabel,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacingSmall),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                    ),
                    child: Icon(
                      Icons.document_scanner_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isAnalyzingNutrition) ...[
                          Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: AppTheme.spacingSmall),
                              Expanded(
                                child: Text(
                                  'Analizando...',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Procesando etiqueta',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ] else ...[
                          Text(
                            'Escanear Etiqueta',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Detecta calorías y macros',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      
      SizedBox(height: AppTheme.spacingMedium),
      
      // Botón secundario para añadir manualmente
      Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.coralMain.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          border: Border.all(
            color: AppTheme.coralMain.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            onTap: _showManualNutritionDialog,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_rounded,
                    color: AppTheme.coralMain,
                    size: 18,
                  ),
                  SizedBox(width: AppTheme.spacingSmall),
                  Flexible(
                    child: Text(
                      'Añadir Manualmente',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppTheme.coralMain,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

  // Widget para mostrar información nutricional
Widget _buildNutritionalDisplay() {
  if (_nutritionalInfo == null || !_nutritionalInfo!.hasNutritionalInfo) {
    return SizedBox.shrink();
  }

  final info = _nutritionalInfo!;
  
  return Container(
    padding: EdgeInsets.all(AppTheme.spacingMedium),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.successGreen.withOpacity(0.05),
          AppTheme.softTeal.withOpacity(0.08),
        ],
      ),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      border: Border.all(
        color: AppTheme.successGreen.withOpacity(0.2),
        width: 1.5,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header compacto con opciones
        _buildNutritionHeader(info),
        
        SizedBox(height: AppTheme.spacingMedium),
        
        // Información en formato lista compacta
        _buildNutritionList(info),
      ],
    ),
  );
}

Widget _buildNutritionHeader(NutritionalInfo info) {
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          Icons.check_circle_rounded,
          color: AppTheme.successGreen,
          size: 16,
        ),
      ),
      SizedBox(width: AppTheme.spacingSmall),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Info Nutricional',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.successGreen,
              ),
            ),
            if (info.servingUnit != null || info.servingSize != null)
              Text(
                'Por ${info.servingUnit ?? "${info.servingSize?.toStringAsFixed(0)}g"}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppTheme.mediumGrey,
                ),
              ),
          ],
        ),
      ),
      // Botones de acción compactos
      _buildCompactActionButtons(),
    ],
  );
}

Widget _buildCompactActionButtons() {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.softTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.softTeal.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _showManualNutritionDialog,
            child: Icon(
              Icons.edit_rounded,
              size: 14,
              color: AppTheme.softTeal,
            ),
          ),
        ),
      ),
      SizedBox(width: 4),
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.errorRed.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              setState(() {
                _nutritionalInfo = null;
              });
            },
            child: Icon(
              Icons.delete_rounded,
              size: 14,
              color: AppTheme.errorRed,
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildNutritionList(NutritionalInfo info) {
  return Column(
    children: [
      // Calorías destacadas
      if (info.calories != null)
        _buildNutritionRow(
          icon: Icons.local_fire_department_rounded,
          label: 'Calorías',
          value: '${info.calories} kcal',
          color: AppTheme.warningOrange,
          isHighlight: true,
        ),
      
      // Macronutrientes
      if (info.proteins != null)
        _buildNutritionRow(
          icon: Icons.fitness_center_rounded,
          label: 'Proteínas',
          value: '${info.proteins!.toStringAsFixed(1)}g',
          color: AppTheme.coralMain,
        ),
      
      if (info.carbohydrates != null)
        _buildNutritionRow(
          icon: Icons.grain_rounded,
          label: 'Carbohidratos',
          value: '${info.carbohydrates!.toStringAsFixed(1)}g',
          color: AppTheme.softTeal,
        ),
      
      if (info.fats != null)
        _buildNutritionRow(
          icon: Icons.opacity_rounded,
          label: 'Grasas',
          value: '${info.fats!.toStringAsFixed(1)}g',
          color: AppTheme.yellowAccent,
        ),
      
      // Información adicional
      if (info.fiber != null)
        _buildNutritionRow(
          icon: Icons.eco_rounded,
          label: 'Fibra',
          value: '${info.fiber!.toStringAsFixed(1)}g',
          color: AppTheme.successGreen,
        ),
      
      if (info.sugar != null)
        _buildNutritionRow(
          icon: Icons.cake_rounded,
          label: 'Azúcares',
          value: '${info.sugar!.toStringAsFixed(1)}g',
          color: AppTheme.coralMain,
        ),
      
      if (info.sodium != null)
        _buildNutritionRow(
          icon: Icons.water_drop_rounded,
          label: 'Sodio',
          value: '${info.sodium!.toStringAsFixed(0)}mg',
          color: AppTheme.mediumGrey,
        ),
    ],
  );
}

Widget _buildNutritionRow({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
  bool isHighlight = false,
}) {
  return Container(
    margin: EdgeInsets.only(bottom: AppTheme.spacingSmall),
    padding: EdgeInsets.symmetric(
      horizontal: AppTheme.spacingMedium,
      vertical: isHighlight ? AppTheme.spacingMedium : AppTheme.spacingSmall,
    ),
    decoration: BoxDecoration(
      color: isHighlight 
        ? color.withOpacity(0.1)
        : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      border: isHighlight 
        ? Border.all(color: color.withOpacity(0.2))
        : null,
    ),
    child: Row(
      children: [
        Container(
          padding: EdgeInsets.all(isHighlight ? 6 : 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            color: color,
            size: isHighlight ? 16 : 14,
          ),
        ),
        SizedBox(width: AppTheme.spacingSmall),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppTheme.mediumGrey,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
            color: isHighlight ? color : AppTheme.darkGrey,
            fontSize: isHighlight ? 14 : 12,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildMacroChip(String text, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Diálogo para editar información nutricional manual
  void _showManualNutritionDialog() {
    final controllers = {
      'calories': TextEditingController(text: _nutritionalInfo?.calories?.toString() ?? ''),
      'proteins': TextEditingController(text: _nutritionalInfo?.proteins?.toString() ?? ''),
      'carbs': TextEditingController(text: _nutritionalInfo?.carbohydrates?.toString() ?? ''),
      'fats': TextEditingController(text: _nutritionalInfo?.fats?.toString() ?? ''),
      'fiber': TextEditingController(text: _nutritionalInfo?.fiber?.toString() ?? ''),
      'sugar': TextEditingController(text: _nutritionalInfo?.sugar?.toString() ?? ''),
      'sodium': TextEditingController(text: _nutritionalInfo?.sodium?.toString() ?? ''),
      'servingSize': TextEditingController(text: _nutritionalInfo?.servingSize?.toString() ?? ''),
      'servingUnit': TextEditingController(text: _nutritionalInfo?.servingUnit ?? ''),
    };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_rounded, color: AppTheme.coralMain),
                  SizedBox(width: AppTheme.spacingMedium),
                  Text(
                    'Información Nutricional',
                    style: AppTextStyles.heading4.copyWith(
                      color: AppTheme.coralMain,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingLarge),
              
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Porción
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers['servingSize'],
                              decoration: InputDecoration(
                                labelText: 'Tamaño porción (g)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingMedium),
                          Expanded(
                            child: TextField(
                              controller: controllers['servingUnit'],
                              decoration: InputDecoration(
                                labelText: 'Descripción porción',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spacingMedium),
                      
                      // Calorías
                      TextField(
                        controller: controllers['calories'],
                        decoration: InputDecoration(
                          labelText: 'Calorías (kcal)',
                          prefixIcon: Icon(Icons.local_fire_department_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: AppTheme.spacingMedium),
                      
                      // Macros principales
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers['proteins'],
                              decoration: InputDecoration(
                                labelText: 'Proteínas (g)',
                                prefixIcon: Icon(Icons.fitness_center_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingMedium),
                          Expanded(
                            child: TextField(
                              controller: controllers['carbs'],
                              decoration: InputDecoration(
                                labelText: 'Carbohidratos (g)',
                                prefixIcon: Icon(Icons.grain_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spacingMedium),
                      
                      // Grasas y fibra
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers['fats'],
                              decoration: InputDecoration(
                                labelText: 'Grasas (g)',
                                prefixIcon: Icon(Icons.opacity_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingMedium),
                          Expanded(
                            child: TextField(
                              controller: controllers['fiber'],
                              decoration: InputDecoration(
                                labelText: 'Fibra (g)',
                                prefixIcon: Icon(Icons.eco_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spacingMedium),
                      
                      // Azúcar y sodio
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers['sugar'],
                              decoration: InputDecoration(
                                labelText: 'Azúcares (g)',
                                prefixIcon: Icon(Icons.cake_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingMedium),
                          Expanded(
                            child: TextField(
                              controller: controllers['sodium'],
                              decoration: InputDecoration(
                                labelText: 'Sodio (mg)',
                                prefixIcon: Icon(Icons.water_drop_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: AppTheme.spacingLarge),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar'),
                  ),
                  SizedBox(width: AppTheme.spacingMedium),
                  ElevatedButton(
                    onPressed: () async {
                      final nutritionalInfo = _nutritionalService.createManualNutritionalInfo(
                        servingSize: double.tryParse(controllers['servingSize']!.text),
                        servingUnit: controllers['servingUnit']!.text.isNotEmpty ? controllers['servingUnit']!.text : null,
                        calories: int.tryParse(controllers['calories']!.text),
                        proteins: double.tryParse(controllers['proteins']!.text),
                        carbohydrates: double.tryParse(controllers['carbs']!.text),
                        fats: double.tryParse(controllers['fats']!.text),
                        fiber: double.tryParse(controllers['fiber']!.text),
                        sugar: double.tryParse(controllers['sugar']!.text),
                        sodium: double.tryParse(controllers['sodium']!.text),
                      );
                      
                      setState(() {
                        _nutritionalInfo = nutritionalInfo;
                      });
                      
                      await _updateProductNutritionalInfo(nutritionalInfo);
                      
                      Navigator.pop(context);
                      _showSuccessSnackBar('Información nutricional guardada');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.coralMain,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  

  // Widget para mostrar el progreso de stock
  Widget _buildStockSection(double percentRemaining) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getProgressColor(percentRemaining).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.assessment_rounded,
                  color: _getProgressColor(percentRemaining),
                  size: 20,
                ),
              ),
              SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: Text(
                  'Nivel de stock',
                  style: AppTextStyles.heading5.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
                decoration: BoxDecoration(
                  color: _getProgressColor(percentRemaining),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                ),
                child: Text(
                  '${(percentRemaining * 100).toInt()}%',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.pureWhite,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLarge),
          
          // Barra de progreso
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF2C2C2C) 
                : AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
            ),
            child: FractionallySizedBox(
              widthFactor: percentRemaining,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getProgressColor(percentRemaining),
                      _getProgressColor(percentRemaining).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                ),
              ),
            ),
          ),
          SizedBox(height: AppTheme.spacingMedium),
          
          Text(
            '$_currentQuantity / $_maxQuantity ${widget.product.unit}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppTheme.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }

  // Sección de gestión de cantidad mejorada
  Widget _buildQuantitySection() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.yellowAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: AppTheme.yellowAccent,
                  size: 20,
                ),
              ),
              SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: Text(
                  'Gestionar cantidad',
                  style: AppTextStyles.heading5.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              
              // Selector de paso
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.yellowAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  border: Border.all(color: AppTheme.yellowAccent.withOpacity(0.3)),
                ),
                child: DropdownButton<int>(
                  value: _step,
                  isDense: true,
                  underline: SizedBox(),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  items: _getStepOptions().map((step) => DropdownMenuItem<int>(
                    value: step,
                    child: Text(
                      '$step ${widget.product.unit}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppTheme.yellowAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _step = value;
                      });
                    }
                  },
                  icon: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppTheme.yellowAccent,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLarge),
          
          IgnorePointer(
            ignoring: _isLoading,
            child: Opacity(
              opacity: _isLoading ? 0.5 : 1.0,
              child: ProductCounter(
                value: _currentQuantity,
                minValue: 0,
                maxValue: _hasMaxQuantity ? _maxQuantity : 9999,
                step: _step,
                unit: widget.product.unit,
                onChanged: _updateQuantity,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sección de caducidad mejorada
  Widget _buildExpirySection() {
    final expiryColor = _getExpiryStatusColor();
    final expiryIcon = widget.product.daysUntilExpiry < 0
        ? Icons.error_outline_rounded
        : widget.product.daysUntilExpiry <= 3
            ? Icons.warning_amber_rounded
            : Icons.event_rounded;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: expiryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  expiryIcon,
                  color: expiryColor,
                  size: 20,
                ),
              ),
              SizedBox(width: AppTheme.spacingSmall),
              Text(
                'Fecha de caducidad',
                style: AppTextStyles.heading5.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLarge),
          
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppTheme.spacingMedium),
            decoration: BoxDecoration(
              color: expiryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              border: Border.all(color: expiryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
  widget.product.expiryDate != null
      ? '${widget.product.expiryDate!.day.toString().padLeft(2, '0')}/${widget.product.expiryDate!.month.toString().padLeft(2, '0')}/${widget.product.expiryDate!.year}'
      : 'No establecida',
  style: AppTextStyles.heading5.copyWith(
    color: expiryColor,
    fontWeight: FontWeight.bold,
  ),
),
                      SizedBox(height: 4),
                      Text(
                        _getExpiryStatusText(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMedium,
                    vertical: AppTheme.spacingSmall,
                  ),
                  decoration: BoxDecoration(
                    color: expiryColor,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                  ),
                  child: Text(
                    widget.product.daysUntilExpiry >= 0 
                        ? '${widget.product.daysUntilExpiry} días'
                        : 'Caducado',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppTheme.pureWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sección de ubicación mejorada
  Widget _buildLocationSection() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getLocationColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getLocationIcon(widget.product.location),
                  color: _getLocationColor(),
                  size: 20,
                ),
              ),
              SizedBox(width: AppTheme.spacingSmall),
              Text(
                'Ubicación del producto',
                style: AppTextStyles.heading5.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLarge),
          
          // Indicador de ubicación
          _buildLocationIndicator(context, widget.product),
          
          SizedBox(height: AppTheme.spacingLarge),
          
          // Información adicional
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppTheme.spacingMedium),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.mediumGrey,
                  size: 20,
                ),
                SizedBox(width: AppTheme.spacingSmall),
                Expanded(
                  child: Text(
                    'Este producto está disponible en ${widget.product.location}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Botones de acción flotantes mejorados
  Widget _buildFloatingActionButtons() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón principal de editar
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.coralMain,
                  AppTheme.coralMain.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.coralMain.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                onTap: _editProduct,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        color: AppTheme.pureWhite,
                        size: 24,
                      ),
                      SizedBox(width: AppTheme.spacingMedium),
                      Text(
                        'Editar Producto',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppTheme.pureWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          SizedBox(height: AppTheme.spacingMedium),
          
          // Botones secundarios
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.softTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    border: Border.all(color: AppTheme.softTeal.withOpacity(0.3)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => _buildAddToCartSheet(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppTheme.borderRadiusLarge),
                            ),
                          ),
                        );
                      },
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_rounded,
                              color: AppTheme.softTeal,
                              size: 20,
                            ),
                            SizedBox(width: AppTheme.spacingSmall),
                            Text(
                              'Al Carrito',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppTheme.softTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.yellowAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    border: Border.all(color: AppTheme.yellowAccent.withOpacity(0.3)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                      onTap: () {
                        // Compartir producto o añadir a favoritos
                        _showSuccessSnackBar('Funcionalidad próximamente');
                      },
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.share_rounded,
                              color: AppTheme.yellowAccent,
                              size: 20,
                            ),
                            SizedBox(width: AppTheme.spacingSmall),
                            Text(
                              'Compartir',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppTheme.yellowAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // [RESTO DE MÉTODOS HELPER EXISTENTES...]
  
  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fastfood_rounded,
            size: 64,
            color: AppTheme.coralMain.withOpacity(0.3),
          ),
          SizedBox(height: AppTheme.spacingSmall),
          Text(
            'Sin imagen',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppTheme.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Indicador visual de la ubicación del producto
  Widget _buildLocationIndicator(BuildContext context, Product product) {
    Widget buildIndicator(IconData icon, String text, bool isActive) {
      final indicatorColor = isActive 
          ? _getLocationColor()
          : AppTheme.mediumGrey;
      
      return Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: AppTheme.spacingMedium,
            horizontal: AppTheme.spacingSmall,
          ),
          decoration: BoxDecoration(
            color: isActive 
                ? indicatorColor.withOpacity(0.1)
                : Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2C)
                    : AppTheme.lightGrey.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            border: Border.all(
              color: isActive 
                  ? indicatorColor.withOpacity(0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? indicatorColor : AppTheme.mediumGrey,
                size: 20,
              ),
              SizedBox(width: AppTheme.spacingSmall),
              Flexible(
                child: Text(
                  text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isActive ? indicatorColor : AppTheme.mediumGrey,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildIndicator(
          Icons.inventory_2_rounded,
          'Inventario',
          product.isAvailableIn(ProductLocation.inventory),
        ),
        
        SizedBox(width: AppTheme.spacingMedium),
        
        buildIndicator(
          Icons.shopping_cart_rounded,
          'Carrito',
          product.isAvailableIn(ProductLocation.shoppingList),
        ),
      ],
    );
  }

  // Bottom sheet para añadir al carrito
  Widget _buildAddToCartSheet(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: AppTheme.spacingMedium),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
              ),
            ),
            
            // Título
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
                vertical: AppTheme.spacingSmall,
              ),
              child: Row(
                children: [
                  Text(
                    'Añadir al carrito',
                    style: AppTextStyles.heading5.copyWith(
                      color: isDarkMode ? AppTheme.pureWhite : AppTheme.darkGrey,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),
            
            Divider(),
            
            // Opción 1: Añadir 1 unidad
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.softTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
                child: Icon(
                  Icons.add_shopping_cart_rounded,
                  color: AppTheme.softTeal,
                  size: 24,
                ),
              ),
              title: Text(
                'Añadir 1 unidad',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Añadir ${widget.product.name} al carrito (1 ${widget.product.unit})',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppTheme.mediumGrey,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _addToShoppingList();
              },
            ),
            
            // Opción 2: Especificar cantidad
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.coralMain.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: AppTheme.coralMain,
                  size: 24,
                ),
              ),
              title: Text(
                'Especificar cantidad',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Elegir una cantidad específica para añadir',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppTheme.mediumGrey,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _addToShoppingListWithQuantity();
              },
            ),
            
            SizedBox(height: AppTheme.spacingMedium),
          ],
        ),
      ),
    );
  }

  // Métodos para obtener iconos
  IconData _getLocationIcon(String location) {
    switch (location) {
      case 'Nevera':
        return Icons.kitchen_rounded;
      case 'Congelador':
        return Icons.ac_unit_rounded;
      case 'Despensa':
        return Icons.inventory_2_rounded;
      case 'Armario':
        return Icons.door_sliding_rounded;
      case 'Especias':
        return Icons.restaurant_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'lácteos':
        return Icons.egg_alt_rounded;
      case 'frutas':
        return Icons.apple_rounded;
      case 'verduras':
        return Icons.eco_rounded;
      case 'carnes':
        return Icons.restaurant_menu_rounded;
      case 'pescados':
        return Icons.set_meal_rounded;
      case 'granos':
        return Icons.grain_rounded;
      case 'bebidas':
        return Icons.local_drink_rounded;
      case 'snacks':
        return Icons.cookie_rounded;
      case 'congelados':
        return Icons.ac_unit_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}