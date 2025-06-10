// lib/screens/inventory/add_product_screen.dart - COMPLETO CON IA Y MACROS

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../services/inventory_service.dart';
import '../../services/improved_barcode_service.dart';
import '../../services/nutritional_analysis_service.dart';
import '../../services/ai_product_analysis_service.dart'; // ¡NUEVO IMPORT!
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/inventory/storage_location_selector.dart';
import '../../widgets/inventory/product_counter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'expiry_date_scanner_screen.dart';
import '../../services/storage_service.dart';
import '../../providers/shopping_list_provider.dart';
import '../../services/shopping_list_service.dart';
import 'enhanced_barcode_scanner_screen.dart';
import "../../config/routes.dart";
import 'dart:async'; // Para Timer

// Define ActionButton fuera de la clase principal para evitar errores
class ActionButtonData {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final ButtonType type;

  ActionButtonData({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.type,
  });
}

class AddProductScreen extends StatefulWidget {
  final Product? productToEdit;
  final String? barcodeValue;
  final bool? fromShoppingList;
  
  
  const AddProductScreen({
    super.key,
    this.productToEdit,
    this.barcodeValue,
    this.fromShoppingList,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _inventoryService = InventoryService();
  final _barcodeService = ImprovedBarcodeService();
  final _nutritionalService = NutritionalAnalysisService();
  final _aiProductService = AIProductAnalysisService(); // ¡NUEVO SERVICIO!
  final _picker = ImagePicker();
  
  
  
  // Animaciones optimizadas
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  String _selectedLocationId = 'Nevera';
  int _quantity = 1;
  int _maxQuantity = 0;
  int _step = 1;
  bool _useMaxQuantity = false;
  String _unit = 'unidades';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 7));
  bool _isScanning = false;
  bool _isEditing = false;
  bool _isLoadingBarcode = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;
  bool _isAnalyzingNutrition = false;
  bool _isAnalyzingProduct = false; // ¡NUEVO ESTADO PARA IA!
  String? _productId;
  String? _barcodeValue;
  File? _productImage;
  String _imageUrl = '';
  bool _imageChanged = false;
  
  // Variable para información nutricional
  NutritionalInfo? _nutritionalInfo;
  
  // Datos predefinidos optimizados
  static const List<String> _categories = [
    'Lácteos', 'Frutas', 'Verduras', 'Carnes', 'Pescados', 'Granos', 
    'Bebidas', 'Snacks', 'Congelados', 'Panadería', 'Cereales', 
    'Condimentos', 'Conservas', 'Dulces',
  ];
  
  static const List<String> _units = [
    'unidades', 'g', 'kg', 'ml', 'L', 'paquete', 'lata', 'botella',
  ];
  
  static const Map<String, List<int>> _stepOptions = {
    'unidades': [1, 2, 5, 10],
    'g': [5, 10, 25, 50, 100, 250, 500],
    'kg': [1, 2, 5],
    'ml': [5, 10, 25, 50, 100, 250, 500],
    'L': [1, 2, 5],
    'paquete': [1, 2, 5],
    'lata': [1, 2, 5],
    'botella': [1, 2, 5],
  };

  // LLAMAR ESTE MÉTODO EN initState
@override
void initState() {
  super.initState();
  _initAnimations();
  _initializeData();
  _setupSafetyTimeout();
  
  // Timeout específico para operaciones de IA
  Timer.periodic(Duration(seconds: 5), (timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    
    // Verificar si hay estados inconsistentes
    if (_isAnalyzingProduct) {
      print('⚠️ Verificando estado de análisis IA...');
    }
  });
}

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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

  void _initializeData() {
    if (widget.productToEdit != null) {
      _loadProductData(widget.productToEdit!);
    }
    
    if (widget.barcodeValue != null && widget.barcodeValue!.isNotEmpty) {
      _barcodeValue = widget.barcodeValue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadProductFromBarcode(_barcodeValue!);
      });
    }
    
    _setDefaultStepForUnit(_unit);
  }

  void _loadProductData(Product product) {
    _isEditing = true;
    _productId = product.id;
    _nameController.text = product.name;
    _categoryController.text = product.category;
    _quantity = product.quantity;
    _unit = product.unit;
    _imageUrl = product.imageUrl;
    _nutritionalInfo = product.nutritionalInfo;
    
    if (product.maxQuantity > 0) {
      _maxQuantity = product.maxQuantity;
      _useMaxQuantity = true;
    }
    
    if (product.expiryDate != null) {
      _expiryDate = product.expiryDate!;
    }
    
    _selectedLocationId = _getLocationId(product.location);
    _setDefaultStepForUnit(_unit);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _analyzeProductWithAI() async {
  if (_isAnalyzingProduct) return;
  
  try {
    // Mostrar opciones de imagen
    final imageSource = await _showImageSourceDialog();
    if (imageSource == null) return;
    
    setState(() {
      _isAnalyzingProduct = true;
    });
    
    print('🔍 Iniciando análisis de producto con IA...');
    
    // Capturar imagen
    final XFile? image = await _picker.pickImage(
      source: imageSource,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    
    if (image == null) {
      print('❌ No se seleccionó imagen');
      setState(() {
        _isAnalyzingProduct = false;
      });
      return;
    }
    
    final imageFile = File(image.path);
    print('📸 Imagen capturada: ${imageFile.path}');
    
    // Verificar que el archivo existe y tiene contenido
    if (!await imageFile.exists()) {
      print('❌ El archivo de imagen no existe');
      _showErrorSnackBar('Error: El archivo de imagen no es válido');
      setState(() {
        _isAnalyzingProduct = false;
      });
      return;
    }
    
    final fileSize = await imageFile.length();
    print('📊 Tamaño de imagen: ${fileSize} bytes');
    
    if (fileSize == 0) {
      print('❌ El archivo de imagen está vacío');
      _showErrorSnackBar('Error: El archivo de imagen está vacío');
      setState(() {
        _isAnalyzingProduct = false;
      });
      return;
    }
    
    // TIMEOUT ESPECÍFICO PARA IA
    print('🤖 Enviando imagen a IA para análisis...');
    final Future<Product?> analysisTask = _aiProductService.analyzeProductFromImage(imageFile);
    final Future<Product?> result = analysisTask.timeout(
      Duration(seconds: 30), // Aumentar timeout
      onTimeout: () {
        print('⏰ Timeout en análisis de IA - Producto individual');
        return null;
      },
    );
    
    final analyzedProduct = await result;
    print('📋 Resultado del análisis: ${analyzedProduct != null ? 'Éxito' : 'Falló'}');
    
    if (analyzedProduct != null && mounted) {
      print('✅ Producto identificado: ${analyzedProduct.name}');
      // Rellenar automáticamente todos los campos
      _fillFormWithAIData(analyzedProduct);
      
      // Guardar la imagen si es necesario
      setState(() {
        _productImage = imageFile;
        _imageChanged = true;
      });
      
      _showSuccessSnackBar('¡Producto identificado automáticamente por IA!');
      _showAIAnalysisResultDialog(analyzedProduct);
    } else if (mounted) {
      print('⚠️ No se pudo identificar el producto');
      _showWarningSnackBar('No se pudo identificar el producto. Verifica que la imagen sea clara y contenga un producto alimentario visible.');
    }
  } catch (e) {
    print('❌ Error en análisis de IA: $e');
    print('📍 Stack trace: ${StackTrace.current}');
    if (mounted) {
      _showErrorSnackBar('Error al analizar producto: ${e.toString()}');
    }
  } finally {
    // CRÍTICO: Siempre resetear el estado, sin importar el resultado
    if (mounted) {
      setState(() {
        _isAnalyzingProduct = false;
      });
    }
  }
}
  // MÉTODO PARA RELLENAR EL FORMULARIO CON DATOS DE IA
  void _fillFormWithAIData(Product analyzedProduct) {
    setState(() {
      // Información básica
      _nameController.text = analyzedProduct.name;
      _categoryController.text = analyzedProduct.category;
      _quantity = analyzedProduct.quantity;
      _unit = analyzedProduct.unit;
      
      // Fecha de caducidad
      if (analyzedProduct.expiryDate != null) {
        _expiryDate = analyzedProduct.expiryDate!;
      }
      
      // Ubicación
      _selectedLocationId = _getLocationId(analyzedProduct.location);
      
      // Información nutricional
      _nutritionalInfo = analyzedProduct.nutritionalInfo;
      
      // Ajustar paso según la unidad
      _setDefaultStepForUnit(_unit);
    });
  }

  void _showAIAnalysisResultDialog(Product analyzedProduct) {
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
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.successGreen,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Producto Identificado por IA',
                        style: AppTextStyles.heading5.copyWith(
                          color: AppTheme.successGreen,
                        ),
                      ),
                      Text(
                        'Los campos se han rellenado automáticamente',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingLarge),
            
            // Información detectada
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMedium),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Producto', analyzedProduct.name),
                  _buildInfoRow('Categoría', analyzedProduct.category),
                  _buildInfoRow('Cantidad', '${analyzedProduct.quantity} ${analyzedProduct.unit}'),
                  _buildInfoRow('Ubicación sugerida', analyzedProduct.location),
                  if (analyzedProduct.expiryDate != null)
                    _buildInfoRow('Caducidad estimada', 
                      '${analyzedProduct.expiryDate!.day.toString().padLeft(2, '0')}/${analyzedProduct.expiryDate!.month.toString().padLeft(2, '0')}/${analyzedProduct.expiryDate!.year}'),
                  if (analyzedProduct.nutritionalInfo?.hasNutritionalInfo == true)
                    _buildInfoRow('Info nutricional', 'Estimada automáticamente'),
                ],
              ),
            ),
            
            if (analyzedProduct.notes.isNotEmpty) ...[
              SizedBox(height: AppTheme.spacingMedium),
              Container(
                padding: EdgeInsets.all(AppTheme.spacingMedium),
                decoration: BoxDecoration(
                  color: AppTheme.yellowAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  border: Border.all(color: AppTheme.yellowAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppTheme.yellowAccent, size: 20),
                    SizedBox(width: AppTheme.spacingSmall),
                    Expanded(
                      child: Text(
                        'Puedes editar cualquier campo antes de guardar',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppTheme.yellowAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: AppTheme.spacingLarge),
            
            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Limpiar campos si el usuario no quiere usar la información
                    _showResetConfirmationDialog();
                  },
                  child: Text('Descartar'),
                ),
                SizedBox(width: AppTheme.spacingMedium),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Usar Macros'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  // MÉTODO HELPER PARA MOSTRAR FILAS DE INFORMACIÓN
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppTheme.mediumGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MÉTODO PARA CONFIRMAR RESET DE CAMPOS
  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        title: Text('¿Limpiar campos?'),
        content: Text('¿Quieres descartar la información detectada y limpiar todos los campos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeMultipleProducts() async {
  if (_isAnalyzingProduct) return;
  
  try {
    final imageSource = await _showImageSourceDialog();
    if (imageSource == null) return;
    
    setState(() {
      _isAnalyzingProduct = true;
    });
    
    print('🔍 Iniciando análisis de múltiples productos...');
    
    final XFile? image = await _picker.pickImage(
      source: imageSource,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    
    if (image == null) {
      print('❌ No se seleccionó imagen');
      setState(() {
        _isAnalyzingProduct = false;
      });
      return;
    }
    
    final imageFile = File(image.path);
    print('📸 Imagen capturada para análisis múltiple: ${imageFile.path}');
    
    // Verificar que el archivo existe y tiene contenido
    if (!await imageFile.exists()) {
      print('❌ El archivo de imagen no existe');
      _showErrorSnackBar('Error: El archivo de imagen no es válido');
      setState(() {
        _isAnalyzingProduct = false;
      });
      return;
    }
    
    final fileSize = await imageFile.length();
    print('📊 Tamaño de imagen: ${fileSize} bytes');
    
    // TIMEOUT ESPECÍFICO PARA MÚLTIPLES PRODUCTOS
    print('🤖 Enviando imagen a IA para análisis múltiple...');
    final Future<List<Product>> analysisTask = _aiProductService.analyzeMultipleProductsFromImage(imageFile);
    final Future<List<Product>> result = analysisTask.timeout(
      Duration(seconds: 45), // Más tiempo para múltiples productos
      onTimeout: () {
        print('⏰ Timeout en análisis de IA - Múltiples productos');
        return <Product>[];
      },
    );
    
    final products = await result;
    print('📋 Productos identificados: ${products.length}');
    
    if (products.isNotEmpty && mounted) {
      print('✅ Se identificaron ${products.length} productos');
      for (int i = 0; i < products.length; i++) {
        print('  - Producto ${i + 1}: ${products[i].name}');
      }
      _showMultipleProductsDialog(products);
    } else if (mounted) {
      print('⚠️ No se pudieron identificar productos en la imagen');
      _showWarningSnackBar('No se pudieron identificar productos en la imagen. Verifica que la imagen contenga productos alimentarios claramente visibles.');
    }
    
  } catch (e) {
    print('❌ Error en análisis múltiple: $e');
    print('📍 Stack trace: ${StackTrace.current}');
    if (mounted) {
      _showErrorSnackBar('Error al analizar productos: ${e.toString()}');
    }
  } finally {
    // CRÍTICO: Siempre resetear el estado
    if (mounted) {
      setState(() {
        _isAnalyzingProduct = false;
      });
    }
  }
}

void _resetLoadingStates() {
  if (mounted) {
    print('🔄 Reseteando todos los estados de carga');
    setState(() {
      _isScanning = false;
      _isLoadingBarcode = false;
      _isUploadingImage = false;
      _isSaving = false;
      _isAnalyzingNutrition = false;
      _isAnalyzingProduct = false; // IMPORTANTE: Este era el que causaba el problema
    });
  }
}



  // DIÁLOGO PARA MÚLTIPLES PRODUCTOS
  void _showMultipleProductsDialog(List<Product> products) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.coralMain),
                  SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: Text(
                      '${products.length} Productos Detectados',
                      style: AppTextStyles.heading4.copyWith(
                        color: AppTheme.coralMain,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingLarge),
              
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: AppTheme.spacingMedium),
                      padding: EdgeInsets.all(AppTheme.spacingMedium),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGrey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${product.category} • ${product.quantity} ${product.unit} • ${product.location}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              SizedBox(height: AppTheme.spacingLarge),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cerrar'),
                  ),
                  SizedBox(width: AppTheme.spacingMedium),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showBulkAddConfirmation(products);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.coralMain,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Añadir todos'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // CONFIRMACIÓN PARA AÑADIR MÚLTIPLES PRODUCTOS
  void _showBulkAddConfirmation(List<Product> products) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        title: Text('Añadir ${products.length} productos'),
        content: Text('¿Quieres añadir todos estos productos a tu inventario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _bulkAddProducts(products);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: Text('Añadir todos'),
          ),
        ],
      ),
    );
  }

  // MÉTODO CORREGIDO PARA AÑADIR MÚLTIPLES PRODUCTOS
Future<void> _bulkAddProducts(List<Product> products) async {
  if (_isSaving) return; // Prevenir múltiples ejecuciones
  
  setState(() {
    _isSaving = true;
  });
  
  try {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    int addedCount = 0;
    
    for (int i = 0; i < products.length; i++) {
      try {
        final product = products[i];
        // Crear ID único para cada producto
        final productId = '${DateTime.now().millisecondsSinceEpoch}_$i';
        
        final productWithUser = Product(
          id: productId,
          name: product.name,
          quantity: product.quantity,
          maxQuantity: product.maxQuantity,
          unit: product.unit,
          expiryDate: product.expiryDate,
          imageUrl: product.imageUrl,
          category: product.category,
          location: product.location,
          userId: userId,
          nutritionalInfo: product.nutritionalInfo,
        );
        
        await _inventoryService.addProduct(productWithUser);
        addedCount++;
        
        // Pequeña pausa para evitar sobrecarga
        await Future.delayed(Duration(milliseconds: 100));
        
      } catch (e) {
        print('Error añadiendo producto ${products[i].name}: $e');
        // Continuar con el siguiente producto
        continue;
      }
    }
    
    if (mounted) {
      _showSuccessSnackBar('$addedCount de ${products.length} productos añadidos correctamente');
      
      // Pequeña pausa antes de navegar
      await Future.delayed(Duration(milliseconds: 500));
      
      _handleNavigationAfterSave();
    }
    
  } catch (e) {
    if (mounted) {
      _showErrorSnackBar('Error al añadir productos: $e');
    }
  } finally {
    // CRÍTICO: Siempre resetear el estado de carga
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }
}

  // MÉTODO PARA ESCANEAR ETIQUETA NUTRICIONAL
  Future<void> _scanNutritionalLabel() async {
    if (_isAnalyzingNutrition) return;
    
    try {
      // Mostrar opciones de imagen
      final imageSource = await _showImageSourceDialog();
      if (imageSource == null) return;
      
      setState(() {
        _isAnalyzingNutrition = true;
      });
      
      // Capturar imagen
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
      
      // Analizar con IA
      final nutritionalInfo = await _nutritionalService.analyzeNutritionalLabel(imageFile);
      
      if (nutritionalInfo != null && mounted) {
        setState(() {
          _nutritionalInfo = nutritionalInfo;
        });
        
        _showSuccessSnackBar('¡Información nutricional detectada correctamente!');
        
        // Mostrar resultados
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
  
  // MÉTODO PARA MOSTRAR OPCIONES DE FUENTE DE IMAGEN
  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar imagen'),
        content: Text('¿Cómo quieres capturar la imagen?'),
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
  
  // MÉTODO PARA MOSTRAR INFORMACIÓN NUTRICIONAL DETECTADA
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
              // Header
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
              
              // Información detectada
              _buildNutritionalInfoRow('Tamaño de porción', 
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
              
              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _nutritionalInfo = null;
                      });
                      Navigator.pop(context);
                    },
                    child: Text('Descartar'),
                  ),
                  SizedBox(width: AppTheme.spacingMedium),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Usar Macros'),
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

 // Diálogo para añadir información nutricional manual
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
             // Header
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
             
             // Formulario
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
             
             // Botones
             Row(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 TextButton(
                   onPressed: () => Navigator.pop(context),
                   child: Text('Cancelar'),
                 ),
                 SizedBox(width: AppTheme.spacingMedium),
                 ElevatedButton(
                   onPressed: () {
                     // Guardar información nutricional manual
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

 // MÉTODO DE GUARDADO ACTUALIZADO CON INFORMACIÓN NUTRICIONAL
 Future<void> _saveProduct() async {
   if (!_formKey.currentState!.validate() || _isSaving) return;
   
   if (_useMaxQuantity && _quantity > _maxQuantity) {
     _showErrorSnackBar('La cantidad actual ($_quantity) no puede superar la cantidad máxima ($_maxQuantity)');
     return;
   }
   
   setState(() {
     _isSaving = true;
   });
   
   try {
     final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
     final productId = _isEditing ? _productId! : DateTime.now().millisecondsSinceEpoch.toString();
     
     String imageUrl = _imageUrl;
     if (_productImage != null && _imageChanged) {
       setState(() {
         _isUploadingImage = true;
       });
       
       try {
         final storageService = StorageService();
         final uploadedUrl = await storageService.uploadProductImage(_productImage!, productId);
         if (uploadedUrl != null) {
           imageUrl = uploadedUrl;
         }
       } catch (e) {
         print('Error al subir imagen: $e');
       } finally {
         setState(() {
           _isUploadingImage = false;
         });
       }
     }
     
     // CREAR PRODUCTO CON INFORMACIÓN NUTRICIONAL
     final product = Product(
       id: productId,
       name: _nameController.text.trim(),
       quantity: _quantity,
       maxQuantity: _useMaxQuantity ? _maxQuantity : 0,
       unit: _unit,
       expiryDate: _expiryDate,
       imageUrl: imageUrl,
       category: _categoryController.text.trim(),
       location: _getLocationName(_selectedLocationId),
       userId: userId,
       nutritionalInfo: _nutritionalInfo, // INCLUIR INFO NUTRICIONAL
     );
     
     if (_isEditing) {
       await _inventoryService.updateProduct(product);
     } else {
       await _inventoryService.addProduct(product);
     }
     
     if (mounted) {
       _showSuccessSnackBar(_isEditing ? 'Producto actualizado correctamente' : 'Producto añadido correctamente');
       _handleNavigationAfterSave();
     }
   } catch (e) {
     _showErrorSnackBar('Error al guardar: $e');
   } finally {
     if (mounted) {
       setState(() {
         _isSaving = false;
       });
     }
   }
 }

 
Future<void> _loadProductFromBarcode(String barcode) async {
  setState(() {
    _isLoadingBarcode = true;
  });
  
  try {
    final product = await _barcodeService.createEnhancedProductFromBarcode(barcode);
    
    if (product != null && mounted) {
      setState(() {
        _nameController.text = product.name;
        _categoryController.text = product.category;
        _quantity = product.quantity;
        _maxQuantity = product.maxQuantity;
        _useMaxQuantity = product.maxQuantity > 0;
        _unit = product.unit;
        
        if (product.expiryDate != null) {
          _expiryDate = product.expiryDate!;
        }
        
        _selectedLocationId = _getLocationId(product.location);
        _setDefaultStepForUnit(_unit);
      });
      
      // Mostrar diálogo de confirmación si se obtuvo información nutricional
      if (product.nutritionalInfo != null && product.nutritionalInfo!.hasNutritionalInfo) {
        _showNutritionalConfirmationDialog(product.nutritionalInfo!, product.name);
      } else {
        _showSuccessSnackBar('Producto encontrado: ${product.name}');
      }
    } else if (mounted) {
      _showWarningSnackBar('Información de producto no encontrada. Por favor, completa manualmente los campos.');
    }
  } catch (e) {
    if (mounted) {
      _showErrorSnackBar('Error al procesar código de barras: $e');
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingBarcode = false;
      });
    }
  }
}

void _showNutritionalConfirmationDialog(NutritionalInfo nutritionalInfo, String productName) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('📊 Información Nutricional Encontrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se encontró información nutricional para "$productName":\n'),
            if (nutritionalInfo.calories != null)
              Text('• Calorías: ${nutritionalInfo.calories} kcal'),
            if (nutritionalInfo.proteins != null)
              Text('• Proteínas: ${nutritionalInfo.proteins!.toStringAsFixed(1)}g'),
            if (nutritionalInfo.carbohydrates != null)
              Text('• Carbohidratos: ${nutritionalInfo.carbohydrates!.toStringAsFixed(1)}g'),
            if (nutritionalInfo.fats != null)
              Text('• Grasas: ${nutritionalInfo.fats!.toStringAsFixed(1)}g'),
            const SizedBox(height: 16),
            const Text('¿Quieres añadir esta información nutricional al producto?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showSuccessSnackBar('Producto añadido sin información nutricional');
            },
            child: const Text('No, gracias'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _nutritionalInfo = nutritionalInfo;
              });
              Navigator.of(context).pop();
              _showSuccessSnackBar('Producto añadido con información nutricional');
            },
            child: const Text('Sí, añadir'),
          ),
        ],
      );
    },
  );
}

 void _setDefaultStepForUnit(String unit) {
   final steps = _stepOptions[unit] ?? [1];
   if (mounted) {
     setState(() {
       _step = steps.first;
     });
   }
 }

 Future<void> _takePhoto() async {
   try {
     final XFile? photo = await _picker.pickImage(
       source: ImageSource.camera,
       maxWidth: 1024,
       maxHeight: 1024,
       imageQuality: 85,
     );
     
     if (photo != null && mounted) {
       setState(() {
         _productImage = File(photo.path);
         _imageChanged = true;
       });
     }
   } catch (e) {
     _showErrorSnackBar('Error al tomar la foto: $e');
   }
 }

 Future<void> _pickImageFromGallery() async {
   try {
     final XFile? image = await _picker.pickImage(
       source: ImageSource.gallery,
       maxWidth: 1024,
       maxHeight: 1024,
       imageQuality: 85,
     );
     
     if (image != null && mounted) {
       setState(() {
         _productImage = File(image.path);
         _imageChanged = true;
       });
     }
   } catch (e) {
     _showErrorSnackBar('Error al seleccionar la imagen: $e');
   }
 }

 void _showImageOptions() {
   if (!mounted) return;
   
   showModalBottomSheet(
     context: context,
     isScrollControlled: true,
     backgroundColor: Colors.transparent,
     builder: (context) => _buildImageOptionsSheet(),
   );
 }

 Widget _buildImageOptionsSheet() {
   return Container(
     decoration: BoxDecoration(
       color: Theme.of(context).colorScheme.surface,
       borderRadius: BorderRadius.vertical(
         top: Radius.circular(AppTheme.borderRadiusXLarge),
       ),
     ),
     child: SafeArea(
       child: Padding(
         padding: EdgeInsets.all(AppTheme.spacingLarge),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             // Handle bar
             Container(
               width: 40,
               height: 4,
               decoration: BoxDecoration(
                 color: AppTheme.mediumGrey.withOpacity(0.3),
                 borderRadius: BorderRadius.circular(2),
               ),
             ),
             SizedBox(height: AppTheme.spacingLarge),
             
             Text(
               'Opciones de imagen',
               style: AppTextStyles.heading4.copyWith(
                 color: Theme.of(context).colorScheme.onSurface,
               ),
             ),
             SizedBox(height: AppTheme.spacingLarge),
             
             _buildImageOptionButton(
               icon: Icons.camera_alt_rounded,
               title: 'Tomar foto',
               onTap: () {
                 Navigator.pop(context);
                 _takePhoto();
               },
             ),
             SizedBox(height: AppTheme.spacingMedium),
             
             _buildImageOptionButton(
               icon: Icons.photo_library_rounded,
               title: 'Seleccionar de la galería',
               onTap: () {
                 Navigator.pop(context);
                 _pickImageFromGallery();
               },
             ),
             
             if (_productImage != null || _imageUrl.isNotEmpty) ...[
               SizedBox(height: AppTheme.spacingMedium),
               _buildImageOptionButton(
                 icon: Icons.delete_rounded,
                 title: 'Eliminar imagen',
                 color: AppTheme.errorRed,
                 onTap: () {
                   Navigator.pop(context);
                   setState(() {
                     _productImage = null;
                     if (_imageUrl.isNotEmpty) {
                       _imageUrl = '';
                       _imageChanged = true;
                     }
                   });
                 },
               ),
             ],
             
             SizedBox(height: AppTheme.spacingLarge),
           ],
         ),
       ),
     ),
   );
 }

 Widget _buildImageOptionButton({
   required IconData icon,
   required String title,
   required VoidCallback onTap,
   Color? color,
 }) {
   return Container(
     width: double.infinity,
     decoration: BoxDecoration(
       color: (color ?? AppTheme.coralMain).withOpacity(0.1),
       borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
       border: Border.all(
         color: (color ?? AppTheme.coralMain).withOpacity(0.2),
       ),
     ),
     child: Material(
       color: Colors.transparent,
       child: InkWell(
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
         onTap: onTap,
         child: Padding(
           padding: EdgeInsets.all(AppTheme.spacingLarge),
           child: Row(
             children: [
               Container(
                 padding: EdgeInsets.all(AppTheme.spacingMedium),
                 decoration: BoxDecoration(
                   color: (color ?? AppTheme.coralMain).withOpacity(0.2),
                   borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                 ),
                 child: Icon(
                   icon,
                   color: color ?? AppTheme.coralMain,
                   size: 24,
                 ),
               ),
               SizedBox(width: AppTheme.spacingMedium),
               Expanded(
                 child: Text(
                   title,
                   style: AppTextStyles.bodyLarge.copyWith(
                     fontWeight: FontWeight.w600,
                     color: color ?? AppTheme.darkGrey,
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

 String _getLocationId(String locationName) {
   const locationMap = {
     'Nevera': 'Nevera',
     'Despensa': 'Despensa',
     'Congelador': 'Congelador',
     'Armario': 'Armario',
     'Especias': 'Especias',
   };
   return locationMap[locationName] ?? 'Nevera';
 }

 String _getLocationName(String locationId) {
   const locationMap = {
     'Nevera': 'Nevera',
     'Despensa': 'Despensa',
     'Congelador': 'Congelador',
     'Armario': 'Armario',
     'Especias': 'Especias',
   };
   return locationMap[locationId] ?? 'Nevera';
 }

 Future<void> _selectDate(BuildContext context) async {
   final DateTime? picked = await showDatePicker(
     context: context,
     initialDate: _expiryDate,
     firstDate: DateTime.now(),
     lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
     builder: (context, child) {
       return Theme(
         data: Theme.of(context).copyWith(
           colorScheme: Theme.of(context).colorScheme.copyWith(
             primary: AppTheme.coralMain,
             onPrimary: AppTheme.pureWhite,
             surface: AppTheme.pureWhite,
           ),
         ),
         child: child!,
       );
     },
   );
   if (picked != null && picked != _expiryDate && mounted) {
     setState(() {
       _expiryDate = picked;
     });
   }
 }

 Future<void> _navigateToExpiryDateScanner() async {
   if (!mounted) return;
   
   final tempProduct = Product(
     id: _productId ?? '',
     name: _nameController.text.isNotEmpty ? _nameController.text : 'Producto',
     quantity: _quantity,
     maxQuantity: _useMaxQuantity ? _maxQuantity : 0,
     unit: _unit,
     expiryDate: _expiryDate,
     imageUrl: _imageUrl,
     category: _categoryController.text.isNotEmpty ? _categoryController.text : 'Otros',
     location: _getLocationName(_selectedLocationId),
     userId: FirebaseAuth.instance.currentUser?.uid ?? '',
   );
   
   final result = await Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => ExpiryDateScannerScreen(product: tempProduct),
     ),
   );
   
   if (result is DateTime && mounted) {
     setState(() {
       _expiryDate = result;
     });
   }
 }

 IconData _getExpiryIcon() {
   final daysUntilExpiry = _expiryDate.difference(DateTime.now()).inDays;
   
   if (daysUntilExpiry < 0) return Icons.warning_amber_rounded;
   if (daysUntilExpiry <= 3) return Icons.timer_rounded;
   if (daysUntilExpiry <= 7) return Icons.pending_outlined;
   return Icons.check_circle_outline_rounded;
 }
 
 String _getExpiryDaysText() {
   final daysUntilExpiry = _expiryDate.difference(DateTime.now()).inDays;
   
   if (daysUntilExpiry < 0) return 'Producto caducado';
   if (daysUntilExpiry == 0) return 'Caduca hoy';
   if (daysUntilExpiry == 1) return 'Caduca mañana';
   if (daysUntilExpiry <= 3) return 'Caduca pronto: $daysUntilExpiry días';
   if (daysUntilExpiry <= 7) return 'Caduca en $daysUntilExpiry días';
   return 'Caduca en $daysUntilExpiry días';
 }
 
 Color _getExpiryColor() {
   final daysUntilExpiry = _expiryDate.difference(DateTime.now()).inDays;
   
   if (daysUntilExpiry < 0) return AppTheme.errorRed;
   if (daysUntilExpiry <= 3) return AppTheme.yellowAccent;
   if (daysUntilExpiry <= 7) return AppTheme.coralMain.withOpacity(0.7);
   return AppTheme.softTeal;
 }

 Future<void> _scanBarcode() async {
   if (_isScanning) return;
   
   setState(() {
     _isScanning = true;
   });
   
   try {
     final result = await Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => const EnhancedBarcodeScannerScreen(),
       ),
     );
     
     if (result != null && mounted) {
       if (result is Product) {
         setState(() {
           _nameController.text = result.name;
           _categoryController.text = result.category;
           _quantity = result.quantity;
           _maxQuantity = result.maxQuantity;
           _useMaxQuantity = result.maxQuantity > 0;
           _unit = result.unit;
           
           if (result.imageUrl.isNotEmpty) {
             _imageUrl = result.imageUrl;
           }
           
           if (result.expiryDate != null) {
             _expiryDate = result.expiryDate!;
           }
           
           _selectedLocationId = _getLocationId(result.location);
           _setDefaultStepForUnit(_unit);
         });
         
         _showSuccessSnackBar('Producto encontrado: ${result.name}');
       } else if (result is String) {
         await _loadProductFromBarcode(result);
       }
     }
   } catch (e) {
     _showErrorSnackBar('Error al escanear: $e');
   } finally {
     if (mounted) {
       setState(() {
         _isScanning = false;
       });
     }
   }
 }

 void _handleNavigationAfterSave() {
  Future.delayed(Duration(milliseconds: 100), () { // Reducir delay
    if (!mounted) return;
    
    try {
      if (Navigator.canPop(context)) {
        // ✅ SOLUCIÓN: Retornar el producto actualizado
        final updatedProduct = Product(
          id: _productId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          quantity: _quantity,
          maxQuantity: _useMaxQuantity ? _maxQuantity : 0,
          unit: _unit,
          expiryDate: _expiryDate,
          imageUrl: _imageUrl,
          category: _categoryController.text.trim(),
          location: _getLocationName(_selectedLocationId),
          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
          nutritionalInfo: _nutritionalInfo,
        );
        
        Navigator.pop(context, updatedProduct);
      } else {
        // Solo como fallback si no hay rutas anteriores
        Navigator.pushNamedAndRemoveUntil(
          context, 
          Routes.dashboard, 
          (route) => false,
        );
      }
    } catch (e) {
      print('Error en navegación: $e');
      Navigator.pop(context, true); // Fallback
    }
  });
}

void _setupSafetyTimeout() {
  // Timeout más agresivo para IA
  Timer(Duration(seconds: 25), () {
    if (mounted && _isAnalyzingProduct) {
      print('🚨 TIMEOUT CRÍTICO: Forzando reset de análisis IA');
      setState(() {
        _isAnalyzingProduct = false;
        _isScanning = false;
        _isLoadingBarcode = false;
        _isUploadingImage = false;
        _isSaving = false;
        _isAnalyzingNutrition = false;
      });
      _showWarningSnackBar('Análisis cancelado por timeout. Inténtalo de nuevo.');
    }
  });
}



 Future<void> _addToShoppingList() async {
   if (!_formKey.currentState!.validate()) return;
   
   try {
     final quantity = await _showQuantityDialog();
     if (quantity == null) return;
     
     final shoppingItem = ShoppingItem(
       id: DateTime.now().millisecondsSinceEpoch.toString(),
       name: _nameController.text.trim(),
       quantity: quantity.toInt(),
       unit: _unit,
       category: _categoryController.text.trim(),
       isPurchased: false,
     );
     
     final shoppingListService = ShoppingListService();
     await shoppingListService.addShoppingItem(shoppingItem);
     
     _showSuccessSnackBar('Producto añadido a la lista de compras');
     
     if (mounted) {
       _handleNavigationAfterShoppingList();
     }
   } catch (e) {
     _showErrorSnackBar('Error al añadir a la lista: $e');
   }
 }

 void _handleNavigationAfterShoppingList() {
   Future.delayed(Duration(milliseconds: 500), () {
     if (!mounted) return;
     
     try {
       if (widget.fromShoppingList == true || _isEditing) {
         if (Navigator.canPop(context)) {
           Navigator.pop(context, true);
         } else {
           Navigator.pushNamedAndRemoveUntil(
             context, 
             Routes.shoppingList, 
             (route) => false,
           );
         }
       } else {
         _resetForm();
       }
     } catch (e) {
       print('Error en navegación de shopping list: $e');
       Navigator.pushNamedAndRemoveUntil(
         context, 
         Routes.dashboard, 
         (route) => false,
       );
     }
   });
 }

 void _resetForm() {
   _nameController.clear();
   _categoryController.clear();
   setState(() {
     _quantity = 1;
     _maxQuantity = 0;
     _useMaxQuantity = false;
     _unit = 'unidades';
     _expiryDate = DateTime.now().add(const Duration(days: 7));
     _productImage = null;
     _imageUrl = '';
     _imageChanged = false;
     _nutritionalInfo = null; // RESETEAR INFO NUTRICIONAL
   });
 }

 Future<int?> _showQuantityDialog() async {
   final quantityController = TextEditingController(text: "1");
   
   return showDialog<int>(
     context: context,
     builder: (context) => Dialog(
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
       ),
       child: Padding(
         padding: EdgeInsets.all(AppTheme.spacingLarge),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Row(
               children: [
                 Container(
                   padding: EdgeInsets.all(AppTheme.spacingMedium),
                   decoration: BoxDecoration(
                     color: AppTheme.coralMain.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                   ),
                   child: Icon(
                     Icons.shopping_cart_rounded,
                     color: AppTheme.coralMain,
                     size: 24,
                   ),
                 ),
                 SizedBox(width: AppTheme.spacingMedium),
                 Expanded(
                   child: Text(
                     'Cantidad para la lista',
                     style: AppTextStyles.heading5.copyWith(
                       color: Theme.of(context).colorScheme.onSurface,
                     ),
                   ),
                 ),
               ],
             ),
             SizedBox(height: AppTheme.spacingLarge),
             
             TextField(
               controller: quantityController,
               keyboardType: TextInputType.number,
               decoration: InputDecoration(
                 labelText: 'Cantidad ($_unit)',
                 border: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                 ),
                 prefixIcon: Icon(
                   Icons.add_shopping_cart_rounded,
                   color: AppTheme.coralMain,
                 ),
               ),
             ),
             SizedBox(height: AppTheme.spacingLarge),
             
             Row(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 TextButton(
                   onPressed: () => Navigator.of(context).pop(null),
                   child: Text('Cancelar'),
                 ),
                 SizedBox(width: AppTheme.spacingMedium),
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
                   ),
                   child: Text('Aceptar'),
                 ),
               ],
             ),
           ],
         ),
       ),
     ),
   );
 }

 Future<void> _addToFavorites() async {
   if (!_formKey.currentState!.validate()) return;
   
   try {
     final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
     final productId = DateTime.now().millisecondsSinceEpoch.toString();
     
     final product = Product(
       id: productId,
       name: _nameController.text.trim(),
       quantity: _quantity,
       maxQuantity: _useMaxQuantity ? _maxQuantity : 0,
       unit: _unit,
       expiryDate: _expiryDate,
       imageUrl: '',
       category: _categoryController.text.trim(),
       location: _getLocationName(_selectedLocationId),
       userId: userId,
     );
     
     final shoppingListService = ShoppingListService();
     final result = await shoppingListService.addProductToFavorites(product);
     
     if (result) {
       _showSuccessSnackBar('Producto añadido a favoritos');
     } else {
       throw Exception('No se pudo añadir a favoritos');
     }
   } catch (e) {
     _showErrorSnackBar('Error al añadir a favoritos: $e');
   }
 }

 void _showSuccessSnackBar(String message) {
   if (!mounted) return;
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
       content: Row(
         children: [
           Icon(Icons.check_circle_rounded, color: AppTheme.pureWhite, size: 20),
           SizedBox(width: AppTheme.spacingMedium),
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
       margin: EdgeInsets.all(AppTheme.spacingMedium),
     ),
   );
 }

 void _showWarningSnackBar(String message) {
   if (!mounted) return;
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
       content: Row(
         children: [
           Icon(Icons.warning_rounded, color: AppTheme.pureWhite, size: 20),
           SizedBox(width: AppTheme.spacingMedium),
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
       margin: EdgeInsets.all(AppTheme.spacingMedium),
     ),
   );
 }

 void _showErrorSnackBar(String message) {
   if (!mounted) return;
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
       content: Row(
         children: [
           Icon(Icons.error_rounded, color: AppTheme.pureWhite, size: 20),
           SizedBox(width: AppTheme.spacingMedium),
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
       margin: EdgeInsets.all(AppTheme.spacingMedium),
     ),
   );
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     backgroundColor: Theme.of(context).scaffoldBackgroundColor,
     appBar: CustomAppBar(
       title: _isEditing ? 'Editar Producto' : 'Añadir Producto',
       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
       actions: _isEditing 
         ? [
             Container(
               margin: EdgeInsets.only(right: AppTheme.spacingMedium),
               decoration: BoxDecoration(
                 color: AppTheme.successGreen.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
               ),
               child: IconButton(
                 icon: Icon(Icons.check_rounded, color: AppTheme.successGreen),
                 onPressed: _isSaving ? null : _saveProduct,
                 tooltip: 'Guardar cambios',
               ),
             ),
           ]
         : null,
     ),
     body: Stack(
       children: [
         FadeTransition(
           opacity: _fadeAnimation,
           child: SlideTransition(
             position: _slideAnimation,
             child: LayoutBuilder(
               builder: (context, constraints) {
                 return SingleChildScrollView(
                   physics: const AlwaysScrollableScrollPhysics(),
                   padding: EdgeInsets.fromLTRB(
                     AppTheme.spacingMedium,
                     AppTheme.spacingSmall,
                     AppTheme.spacingMedium,
                     AppTheme.spacingXXLarge + 80,
                   ),
                   child: ConstrainedBox(
                     constraints: BoxConstraints(
                       minHeight: constraints.maxHeight - AppTheme.spacingXXLarge - 80,
                     ),
                     child: Form(
                       key: _formKey,
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.stretch,
                         children: [
                           // Escáner de código de barras y análisis por IA
                           if (!_isEditing) ...[
                             _buildBarcodeScanner(),
                             SizedBox(height: AppTheme.spacingLarge),
                           ],
                           
                           // Información básica del producto
                           _buildBasicInfoSection(),
                           SizedBox(height: AppTheme.spacingLarge),
                           
                           // Sección de imagen
                           _buildImageSection(),
                           SizedBox(height: AppTheme.spacingLarge),
                           
                           // SECCIÓN DE INFORMACIÓN NUTRICIONAL
                           _buildNutritionalInfoSection(),
                           SizedBox(height: AppTheme.spacingLarge),
                           
                           // Cantidad y unidades
                           _buildQuantitySection(),
                           SizedBox(height: AppTheme.spacingLarge),
                           
                           // Fecha de caducidad
                           _buildExpirySection(),
                           SizedBox(height: AppTheme.spacingLarge),
                           
                           // Ubicación
                           _buildLocationSection(),
                         ],
                       ),
                     ),
                   ),
                 );
               },
             ),
           ),
         ),
         
         // Botones de acción flotantes
         Positioned(
           left: 0,
           right: 0,
           bottom: 0,
           child: _buildFloatingActionButtons(),
         ),
         
         // Overlay de carga
         if (_isScanning || _isLoadingBarcode || _isUploadingImage || _isSaving || _isAnalyzingNutrition || _isAnalyzingProduct)
  _buildLoadingOverlay(),
       ],
     ),
   );
 }

 Widget _buildNutritionalInfoSection() {
  return _buildSectionCard(
    title: 'Información Nutricional',
    icon: Icons.analytics_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Estado actual de la información nutricional
        if (_nutritionalInfo != null) ...[
          _buildNutritionalInfoDisplay(),
          SizedBox(height: AppTheme.spacingLarge),
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

 Widget _buildNutritionalInfoDisplay() {
  if (_nutritionalInfo == null) return SizedBox.shrink();
  
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

Widget _buildAdditionalInfoGrid(NutritionalInfo info) {
  final additionalInfo = <Map<String, dynamic>>[];
  
  if (info.fiber != null) {
    additionalInfo.add({
      'icon': Icons.eco_rounded,
      'label': 'Fibra',
      'value': '${info.fiber!.toStringAsFixed(1)}g',
      'color': AppTheme.successGreen,
    });
  }
  
  if (info.sugar != null) {
    additionalInfo.add({
      'icon': Icons.cake_rounded,
      'label': 'Azúcares',
      'value': '${info.sugar!.toStringAsFixed(1)}g',
      'color': AppTheme.coralMain,
    });
  }
  
  if (info.sodium != null) {
    additionalInfo.add({
      'icon': Icons.water_drop_rounded,
      'label': 'Sodio',
      'value': '${info.sodium!.toStringAsFixed(0)}mg',
      'color': AppTheme.mediumGrey,
    });
  }
  
  return Wrap(
    spacing: AppTheme.spacingSmall,
    runSpacing: AppTheme.spacingSmall,
    children: additionalInfo.map((info) => _buildAdditionalInfoChip(
      icon: info['icon'],
      label: info['label'],
      value: info['value'],
      color: info['color'],
    )).toList(),
  );
}

Widget _buildAdditionalInfoChip({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: AppTheme.spacingMedium,
      vertical: AppTheme.spacingSmall,
    ),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        SizedBox(width: AppTheme.spacingSmall),
        Text(
          '$label: $value',
          style: AppTextStyles.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Widget _buildMacrosGrid(NutritionalInfo info) {
  final macros = <Map<String, dynamic>>[];
  
  if (info.proteins != null) {
    macros.add({
      'icon': Icons.fitness_center_rounded,
      'label': 'Proteínas',
      'value': '${info.proteins!.toStringAsFixed(1)}g',
      'color': AppTheme.coralMain,
    });
  }
  
  if (info.carbohydrates != null) {
    macros.add({
      'icon': Icons.grain_rounded,
      'label': 'Carbohid...',
      'value': '${info.carbohydrates!.toStringAsFixed(1)}g',
      'color': AppTheme.softTeal,
    });
  }
  
  if (info.fats != null) {
    macros.add({
      'icon': Icons.opacity_rounded,
      'label': 'Grasas',
      'value': '${info.fats!.toStringAsFixed(1)}g',
      'color': AppTheme.yellowAccent,
    });
  }
  
  return Container(
    height: 80,
    child: Row(
      children: macros.asMap().entries.map((entry) {
        final index = entry.key;
        final macro = entry.value;
        
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index < macros.length - 1 ? AppTheme.spacingSmall : 0,
            ),
            child: _buildMacroCard(
              icon: macro['icon'],
              label: macro['label'],
              value: macro['value'],
              color: macro['color'],
            ),
          ),
        );
      }).toList(),
    ),
  );
}

Widget _buildMacroCard({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  return Container(
    padding: EdgeInsets.all(AppTheme.spacingSmall),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      border: Border.all(
        color: color.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 12,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppTheme.mediumGrey,
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

Widget _buildIconButton({
  required IconData icon,
  required Color color,
  required VoidCallback onPressed,
  required String tooltip,
}) {
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        onTap: onPressed,
        child: Icon(
          icon,
          size: 18,
          color: color,
        ),
      ),
    ),
  );
}

Widget _buildCaloriesCard(int calories) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(AppTheme.spacingLarge),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          AppTheme.warningOrange.withOpacity(0.1),
          AppTheme.yellowAccent.withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      border: Border.all(
        color: AppTheme.warningOrange.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.spacingMedium),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          ),
          child: Icon(
            Icons.local_fire_department_rounded,
            color: AppTheme.warningOrange,
            size: 28,
          ),
        ),
        SizedBox(width: AppTheme.spacingLarge),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calorías',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppTheme.mediumGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$calories kcal',
                style: AppTextStyles.heading4.copyWith(
                  color: AppTheme.warningOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

 Widget _buildMacroChip(String text, IconData icon) {
   return Container(
     padding: EdgeInsets.symmetric(
       horizontal: AppTheme.spacingSmall,
       vertical: 4,
     ),
     decoration: BoxDecoration(
       color: AppTheme.softTeal.withOpacity(0.1),
       borderRadius: BorderRadius.circular(16),
       border: Border.all(color: AppTheme.softTeal.withOpacity(0.3)),
     ),
     child: Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Icon(icon, size: 14, color: AppTheme.softTeal),
         SizedBox(width: 4),
         Text(
           text,
           style: AppTextStyles.bodySmall.copyWith(
             color: AppTheme.softTeal,
             fontWeight: FontWeight.w600,
           ),
         ),
       ],
     ),
   );
 }

 // WIDGET MEJORADO PARA EL ESCÁNER DE CÓDIGO DE BARRAS CON IA
 Widget _buildBarcodeScanner() {
   return Column(
     children: [
       // Escáner de código de barras original
       Container(
         height: 120,
         decoration: BoxDecoration(
           gradient: LinearGradient(
             begin: Alignment.topLeft,
             end: Alignment.bottomRight,
             colors: [
               AppTheme.coralMain,
               AppTheme.coralMain.withOpacity(0.8),
             ],
           ),
           borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
           boxShadow: [
             BoxShadow(
               color: AppTheme.coralMain.withOpacity(0.25),
               blurRadius: 12,
               offset: Offset(0, 4),
             ),
           ],
         ),
         child: Material(
           color: Colors.transparent,
           child: InkWell(
             borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
             onTap: _isScanning ? null : _scanBarcode,
             child: Padding(
               padding: EdgeInsets.all(AppTheme.spacingLarge),
               child: Row(
                 children: [
                   Container(
                     padding: EdgeInsets.all(AppTheme.spacingMedium),
                     decoration: BoxDecoration(
                       color: AppTheme.pureWhite.withOpacity(0.2),
                       borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                     ),
                     child: Icon(
                       Icons.qr_code_scanner_rounded,
                       size: 28,
                       color: Colors.white,
                     ),
                   ),
                   SizedBox(width: AppTheme.spacingMedium),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Text(
                           'Escanear código',
                           style: AppTextStyles.heading5.copyWith(
                             color: Colors.white,
                             fontSize: 16,
                           ),
                           overflow: TextOverflow.ellipsis,
                         ),
                         SizedBox(height: 4),
                         Text(
                           'Toca para escanear código de barras',
                           style: AppTextStyles.bodySmall.copyWith(
                             color: Colors.white.withOpacity(0.9),
                             fontSize: 12,
                           ),
                           overflow: TextOverflow.ellipsis,
                           maxLines: 2,
                         ),
                       ],
                     ),
                   ),
                   if (_isScanning)
                     SizedBox(
                       width: 20,
                       height: 20,
                       child: CircularProgressIndicator(
                         strokeWidth: 2,
                         valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                       ),
                     ),
                 ],
               ),
             ),
           ),
         ),
       ),
       
       SizedBox(height: AppTheme.spacingMedium),
       
       // NUEVA SECCIÓN DE ANÁLISIS POR IA
       Row(
         children: [
           // Análisis de producto individual
           Expanded(
             child: Container(
               height: 80,
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
                     color: AppTheme.softTeal.withOpacity(0.25),
                     blurRadius: 8,
                     offset: Offset(0, 2),
                   ),
                 ],
               ),
               child: Material(
                 color: Colors.transparent,
                 child: InkWell(
                   borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                   onTap: _isAnalyzingProduct ? null : _analyzeProductWithAI,
                   child: Padding(
                     padding: EdgeInsets.all(AppTheme.spacingMedium),
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         if (_isAnalyzingProduct) ...[
                           SizedBox(
                             width: 20,
                             height: 20,
                             child: CircularProgressIndicator(
                               strokeWidth: 2,
                               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                             ),
                           ),
                           SizedBox(height: 4),
                           Text(
                             'Analizando...',
                             style: AppTextStyles.bodySmall.copyWith(
                               color: Colors.white,
                               fontWeight: FontWeight.bold,
                             ),
                             textAlign: TextAlign.center,
                           ),
                         ] else ...[
                           Icon(
                             Icons.auto_awesome_rounded,
                             size: 24,
                             color: Colors.white,
                           ),
                           SizedBox(height: 4),
                           Text(
                             'IA Producto',
                             style: AppTextStyles.bodySmall.copyWith(
                               color: Colors.white,
                               fontWeight: FontWeight.bold,
                             ),
                             textAlign: TextAlign.center,
                           ),
                         ],
                       ],
                     ),
                   ),
                 ),
               ),
             ),
           ),
           
           SizedBox(width: AppTheme.spacingMedium),
           
           // Análisis de múltiples productos
           Expanded(
             child: Container(
               height: 80,
               decoration: BoxDecoration(
                 gradient: LinearGradient(
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                   colors: [
                     AppTheme.yellowAccent,
                     AppTheme.yellowAccent.withOpacity(0.8),
                   ],
                 ),
                 borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                 boxShadow: [
                   BoxShadow(
                     color: AppTheme.yellowAccent.withOpacity(0.25),
                     blurRadius: 8,
                     offset: Offset(0, 2),
                   ),
                 ],
               ),
               child: Material(
                 color: Colors.transparent,
                 child: InkWell(
                   borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                   onTap: _isAnalyzingProduct ? null : _analyzeMultipleProducts,
                   child: Padding(
                     padding: EdgeInsets.all(AppTheme.spacingMedium),
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         if (_isAnalyzingProduct) ...[
                           SizedBox(
                             width: 20,
                             height: 20,
                             child: CircularProgressIndicator(
                               strokeWidth: 2,
                               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                             ),
                           ),
                           SizedBox(height: 4),
                           Text(
                             'Analizando...',
                             style: AppTextStyles.bodySmall.copyWith(
                               color: Colors.white,
                               fontWeight: FontWeight.bold,
                             ),
                             textAlign: TextAlign.center,
                           ),
                         ] else ...[
                           Icon(
                             Icons.scatter_plot_rounded,
                             size: 24,
                             color: Colors.white,
                           ),
                           SizedBox(height: 4),
                           Text(
                             'Múltiples',
                             style: AppTextStyles.bodySmall.copyWith(
                               color: Colors.white,
                               fontWeight: FontWeight.bold,
                             ),
                             textAlign: TextAlign.center,
                           ),
                         ],
                       ],
                     ),
                   ),
                 ),
               ),
             ),
           ),
         ],
       ),
       
       // Texto explicativo
       SizedBox(height: AppTheme.spacingSmall),
       Container(
         padding: EdgeInsets.all(AppTheme.spacingMedium),
         decoration: BoxDecoration(
           color: AppTheme.lightGrey.withOpacity(0.1),
           borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
         ),
         child: Row(
           children: [
             Icon(
               Icons.lightbulb_outline_rounded,
               color: AppTheme.mediumGrey,
               size: 18,
             ),
             SizedBox(width: AppTheme.spacingSmall),
             Expanded(
               child: Text(
                 'Usa IA para productos sin código de barras. Perfecto para frutas, verduras y productos frescos.',
                 style: AppTextStyles.bodySmall.copyWith(
                   color: AppTheme.mediumGrey,
                   fontStyle: FontStyle.italic,
                 ),
               ),
             ),
           ],
         ),
       ),
     ],
   );
 }

 // Resto de widgets de construcción de UI
 Widget _buildBasicInfoSection() {
   return _buildSectionCard(
     title: 'Información básica',
     icon: Icons.info_outline_rounded,
     child: Column(
       children: [
         _buildTextField(
           label: 'Nombre del producto',
           controller: _nameController,
           icon: Icons.label_outline_rounded,
           validator: (value) {
             if (value == null || value.trim().isEmpty) {
               return 'Por favor, ingresa el nombre del producto';
             }
             return null;
           },
         ),
         SizedBox(height: AppTheme.spacingMedium),
         _buildTextField(
           label: 'Categoría',
           controller: _categoryController,
           icon: Icons.category_outlined,
           suffixIcon: Icons.arrow_drop_down_rounded,
           onTap: _showCategorySelector,
           readOnly: true,
           validator: (value) {
             if (value == null || value.trim().isEmpty) {
               return 'Por favor, selecciona una categoría';
             }
             return null;
           },
         ),
       ],
     ),
   );
 }

 Widget _buildImageSection() {
   return _buildSectionCard(
     title: 'Imagen del producto',
     icon: Icons.photo_camera_rounded,
     child: Column(
       children: [
         GestureDetector(
           onTap: _showImageOptions,
           child: Container(
             height: 180,
             width: double.infinity,
             decoration: BoxDecoration(
               color: AppTheme.peachLight.withOpacity(0.1),
               borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
               border: Border.all(
                 color: AppTheme.coralMain.withOpacity(0.2),
                 width: 2,
               ),
             ),
             child: ClipRRect(
               borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge - 2),
               child: _buildImageContent(),
             ),
           ),
         ),
         SizedBox(height: AppTheme.spacingMedium),
         Row(
           children: [
             Expanded(
               child: _buildImageButton(
                 label: 'Cámara',
                 icon: Icons.camera_alt_rounded,
                 onTap: _takePhoto,
                 color: AppTheme.coralMain,
               ),
             ),
             SizedBox(width: AppTheme.spacingSmall),
             Expanded(
               child: _buildImageButton(
                 label: 'Galería',
                 icon: Icons.photo_library_rounded,
                 onTap: _pickImageFromGallery,
                 color: AppTheme.softTeal,
               ),
             ),
           ],
         ),
       ],
     ),
     );
 }

 Widget _buildImageButton({
   required String label,
   required IconData icon,
   required VoidCallback onTap,
   required Color color,
 }) {
   return Container(
     height: 44,
     decoration: BoxDecoration(
       color: color.withOpacity(0.1),
       borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
       border: Border.all(color: color.withOpacity(0.3)),
     ),
     child: Material(
       color: Colors.transparent,
       child: InkWell(
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
         onTap: onTap,
         child: Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(icon, color: color, size: 18),
             SizedBox(width: 6),
             Text(
               label,
               style: AppTextStyles.bodySmall.copyWith(
                 color: color,
                 fontWeight: FontWeight.w600,
               ),
             ),
           ],
         ),
       ),
     ),
   );
 }

 Widget _buildImageContent() {
   if (_productImage != null) {
     return Stack(
       fit: StackFit.expand,
       children: [
         Image.file(_productImage!, fit: BoxFit.cover),
         Positioned(
           top: 8,
           right: 8,
           child: Container(
             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
             decoration: BoxDecoration(
               color: AppTheme.successGreen,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Icon(Icons.check_circle, color: Colors.white, size: 14),
                 SizedBox(width: 4),
                 Text(
                   'Nueva',
                   style: AppTextStyles.caption.copyWith(
                     color: Colors.white,
                     fontWeight: FontWeight.w600,
                   ),
                 ),
               ],
             ),
           ),
         ),
       ],
     );
   }
   
   if (_imageUrl.isNotEmpty) {
     return Stack(
       fit: StackFit.expand,
       children: [
         Image.network(
           _imageUrl,
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
                   Icon(Icons.broken_image_rounded, size: 32, color: AppTheme.errorRed),
                   SizedBox(height: 8),
                   Text(
                     'Error al cargar imagen',
                     style: AppTextStyles.bodySmall.copyWith(color: AppTheme.errorRed),
                   ),
                 ],
               ),
             );
           },
         ),
         Positioned(
           top: 8,
           right: 8,
           child: Container(
             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
             decoration: BoxDecoration(
               color: AppTheme.softTeal,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Icon(Icons.cloud_done, color: Colors.white, size: 14),
                 SizedBox(width: 4),
                 Text(
                   'Guardada',
                   style: AppTextStyles.caption.copyWith(
                     color: Colors.white,
                     fontWeight: FontWeight.w600,
                   ),
                 ),
               ],
             ),
           ),
         ),
       ],
     );
   }
   
   return Column(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
       Icon(
         Icons.add_photo_alternate_rounded,
         size: 40,
         color: AppTheme.coralMain,
       ),
       SizedBox(height: 8),
       Text(
         'Añadir imagen',
         style: AppTextStyles.bodyMedium.copyWith(
           fontWeight: FontWeight.w600,
           color: AppTheme.coralMain,
         ),
       ),
       Text(
         'Toca para seleccionar',
         style: AppTextStyles.bodySmall.copyWith(
           color: AppTheme.mediumGrey,
         ),
       ),
     ],
   );
 }

 Widget _buildQuantitySection() {
   return _buildSectionCard(
     title: 'Cantidad y unidades',
     icon: Icons.scale_rounded,
     child: Column(
       children: [
         Row(
           children: [
             Expanded(child: _buildUnitDropdown()),
             SizedBox(width: AppTheme.spacingMedium),
             Expanded(child: _buildStepDropdown()),
           ],
         ),
         SizedBox(height: AppTheme.spacingMedium),
         
         Container(
           padding: EdgeInsets.all(AppTheme.spacingMedium),
           decoration: BoxDecoration(
             color: AppTheme.coralMain.withOpacity(0.05),
             borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
           ),
           child: Column(
             children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(
                     'Cantidad actual',
                     style: AppTextStyles.bodyMedium.copyWith(
                       fontWeight: FontWeight.w600,
                     ),
                   ),
                   Container(
                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                     decoration: BoxDecoration(
                       color: AppTheme.coralMain,
                       borderRadius: BorderRadius.circular(16),
                     ),
                     child: Text(
                       '$_quantity $_unit',
                       style: AppTextStyles.bodySmall.copyWith(
                         color: Colors.white,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ),
                 ],
               ),
               SizedBox(height: AppTheme.spacingMedium),
               ProductCounter(
                 value: _quantity,
                 minValue: 0,
                 maxValue: _useMaxQuantity ? _maxQuantity : 9999,
                 step: _step,
                 unit: _unit,
                 onChanged: (value) {
                   setState(() {
                     _quantity = value;
                     if (_useMaxQuantity && _quantity > _maxQuantity) {
                       _showWarningSnackBar('La cantidad no puede superar el máximo');
                       _quantity = _maxQuantity;
                     }
                   });
                 },
               ),
             ],
           ),
         ),
         
         SizedBox(height: AppTheme.spacingMedium),
         _buildMaxQuantityToggle(),
       ],
     ),
   );
 }

 Widget _buildMaxQuantityToggle() {
   return Container(
     padding: EdgeInsets.all(AppTheme.spacingMedium),
     decoration: BoxDecoration(
       color: _useMaxQuantity 
         ? AppTheme.successGreen.withOpacity(0.05)
         : AppTheme.lightGrey.withOpacity(0.1),
       borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
       border: Border.all(
         color: _useMaxQuantity 
           ? AppTheme.successGreen.withOpacity(0.2)
           : AppTheme.lightGrey.withOpacity(0.3),
       ),
     ),
     child: Column(
       children: [
         Row(
           children: [
             Icon(
               Icons.inventory_rounded,
               color: _useMaxQuantity ? AppTheme.successGreen : AppTheme.mediumGrey,
               size: 20,
             ),
             SizedBox(width: AppTheme.spacingSmall),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     'Cantidad máxima',
                     style: AppTextStyles.bodyMedium.copyWith(
                       fontWeight: FontWeight.w600,
                     ),
                   ),
                   Text(
                     'Para mostrar progreso de stock',
                     style: AppTextStyles.bodySmall.copyWith(
                       color: AppTheme.mediumGrey,
                     ),
                   ),
                 ],
               ),
             ),
             Switch(
               value: _useMaxQuantity,
               onChanged: (value) {
                 setState(() {
                   _useMaxQuantity = value;
                   if (value && _maxQuantity < _quantity) {
                     _maxQuantity = _quantity * 2;
                   }
                 });
               },
               activeColor: AppTheme.successGreen,
             ),
           ],
         ),
         
         if (_useMaxQuantity) ...[
           SizedBox(height: AppTheme.spacingMedium),
           Divider(height: 1),
           SizedBox(height: AppTheme.spacingMedium),
           
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(
                 'Máximo: $_maxQuantity $_unit',
                 style: AppTextStyles.bodyMedium.copyWith(
                   fontWeight: FontWeight.w600,
                   color: AppTheme.successGreen,
                 ),
               ),
             ],
           ),
           SizedBox(height: AppTheme.spacingSmall),
           
           ProductCounter(
             value: _maxQuantity,
             minValue: _quantity,
             maxValue: 9999,
             step: _step,
             unit: _unit,
             onChanged: (value) {
               setState(() {
                 _maxQuantity = value;
               });
             },
           ),
         ],
       ],
     ),
   );
 }

 Widget _buildExpirySection() {
  return _buildSectionCard(
    title: 'Fecha de caducidad',
    icon: Icons.event_note_rounded,
    child: Column(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.spacingMedium),
          decoration: BoxDecoration(
            color: _getExpiryColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            border: Border.all(color: _getExpiryColor().withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(_getExpiryIcon(), color: _getExpiryColor(), size: 20),
              SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getExpiryDaysText(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getExpiryColor(),
                      ),
                    ),
                    Text(
                      '${_expiryDate.day.toString().padLeft(2, '0')}/${_expiryDate.month.toString().padLeft(2, '0')}/${_expiryDate.year}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: AppTheme.spacingMedium),
        
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildDateButton(),
            ),
            SizedBox(width: AppTheme.spacingSmall),
            _buildScanDateButton(),
          ],
        ),
      ],
    ),
  );
}

 Widget _buildDateButton() {
  return Container(
    height: 48,
    decoration: BoxDecoration(
      color: AppTheme.peachLight.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      border: Border.all(color: AppTheme.coralMain.withOpacity(0.2)),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        onTap: () => _selectDate(context),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: AppTheme.coralMain, size: 18),
              SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: Text(
                  '${_expiryDate.day.toString().padLeft(2, '0')}/${_expiryDate.month.toString().padLeft(2, '0')}/${_expiryDate.year}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
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

 Widget _buildScanDateButton() {
   return Container(
     width: 48,
     height: 48,
     decoration: BoxDecoration(
       gradient: LinearGradient(
         colors: [AppTheme.softTeal, AppTheme.softTeal.withOpacity(0.8)],
       ),
       borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
     ),
     child: Material(
       color: Colors.transparent,
       child: InkWell(
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
         onTap: _navigateToExpiryDateScanner,
         child: Icon(
           Icons.document_scanner_rounded,
           color: Colors.white,
           size: 20,
         ),
       ),
     ),
   );
 }

 Widget _buildLocationSection() {
   return _buildSectionCard(
     title: 'Ubicación',
     icon: Icons.kitchen_rounded,
     child: StorageLocationSelector(
       locations: StorageLocationSelector.defaultLocations,
       selectedLocationId: _selectedLocationId,
       onLocationSelected: (locationId) {
         setState(() {
           _selectedLocationId = locationId;
         });
       },
     ),
   );
 }

 Widget _buildSectionCard({
   required String title,
   required IconData icon,
   required Widget child,
 }) {
   return Container(
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
     child: Padding(
       padding: EdgeInsets.all(AppTheme.spacingMedium),
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
                 child: Icon(icon, color: AppTheme.coralMain, size: 20),
               ),
               SizedBox(width: AppTheme.spacingSmall),
               Text(
                 title,
                 style: AppTextStyles.heading5.copyWith(
                   color: Theme.of(context).colorScheme.onSurface,
                 ),
               ),
             ],
           ),
           SizedBox(height: AppTheme.spacingMedium),
           child,
         ],
       ),
     ),
   );
 }

 Widget _buildTextField({
   required String label,
   required TextEditingController controller,
   required IconData icon,
   IconData? suffixIcon,
   VoidCallback? onTap,
   bool readOnly = false,
   String? Function(String?)? validator,
 }) {
   return TextFormField(
     controller: controller,
     validator: validator,
     readOnly: readOnly,
     onTap: onTap,
     style: AppTextStyles.bodyMedium.copyWith(
       fontWeight: FontWeight.w500,
     ),
     decoration: InputDecoration(
       labelText: label,
       prefixIcon: Icon(icon, color: AppTheme.coralMain, size: 20),
       suffixIcon: suffixIcon != null 
         ? Icon(suffixIcon, color: AppTheme.coralMain, size: 20)
         : null,
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
         borderSide: BorderSide(color: AppTheme.lightGrey),
       ),
       enabledBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
         borderSide: BorderSide(color: AppTheme.lightGrey),
       ),
       focusedBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
         borderSide: BorderSide(color: AppTheme.coralMain, width: 2),
       ),
       contentPadding: EdgeInsets.symmetric(
         horizontal: AppTheme.spacingMedium,
         vertical: AppTheme.spacingMedium,
       ),
     ),
   );
 }

 Widget _buildUnitDropdown() {
   return Container(
     height: 48,
     padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
     decoration: BoxDecoration(
       border: Border.all(color: AppTheme.lightGrey),
       borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
     ),
     child: DropdownButtonHideUnderline(
       child: DropdownButton<String>(
         value: _unit,
         isExpanded: true,
         icon: Icon(Icons.arrow_drop_down, color: AppTheme.coralMain),
         items: _units.map((unit) {
           return DropdownMenuItem(
             value: unit,
             child: Text(
               unit,
               style: AppTextStyles.bodyMedium.copyWith(
                 fontWeight: FontWeight.w500,
               ),
             ),
           );
         }).toList(),
         onChanged: (value) {
           if (value != null) {
             setState(() {
               _unit = value;
               _setDefaultStepForUnit(value);
             });
           }
         },
       ),
     ),
   );
 }

 Widget _buildStepDropdown() {
   return Container(
     height: 48,
     padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
     decoration: BoxDecoration(
       border: Border.all(color: AppTheme.lightGrey),
       borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
     ),
     child: DropdownButtonHideUnderline(
       child: DropdownButton<int>(
         value: _step,
         isExpanded: true,
         icon: Icon(Icons.arrow_drop_down, color: AppTheme.softTeal),
         items: (_stepOptions[_unit] ?? [1]).map((step) {
           return DropdownMenuItem(
             value: step,
             child: Text(
               '$step $_unit',
               style: AppTextStyles.bodyMedium.copyWith(
                 fontWeight: FontWeight.w500,
               ),
             ),
           );
         }).toList(),
         onChanged: (value) {
           if (value != null) {
             setState(() {
               _step = value;
             });
           }
         },
       ),
     ),
   );
 }

 void _showCategorySelector() {
   showDialog(
     context: context,
     builder: (context) => Dialog(
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
       ),
       child: Container(
         constraints: BoxConstraints(
           maxHeight: MediaQuery.of(context).size.height * 0.7,
         ),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Padding(
               padding: EdgeInsets.all(AppTheme.spacingLarge),
               child: Row(
                 children: [
                   Icon(Icons.category_rounded, color: AppTheme.coralMain),
                   SizedBox(width: AppTheme.spacingMedium),
                   Expanded(
                     child: Text(
                       'Seleccionar categoría',
                       style: AppTextStyles.heading4.copyWith(
                         color: Theme.of(context).colorScheme.onSurface,
                       ),
                     ),
                   ),
                 ],
               ),
             ),
             SizedBox(height: AppTheme.spacingMedium),
             Divider(),
             
             Flexible(
               child: ListView.builder(
                 shrinkWrap: true,
                 itemCount: _categories.length,
                 itemBuilder: (context, index) {
                   final category = _categories[index];
                   final isSelected = _categoryController.text == category;
                   
                   return Container(
                     margin: EdgeInsets.symmetric(
                       horizontal: AppTheme.spacingLarge,
                       vertical: AppTheme.spacingSmall,
                     ),
                     decoration: BoxDecoration(
                       color: isSelected 
                         ? AppTheme.coralMain.withOpacity(0.1)
                         : Colors.transparent,
                       borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                       border: isSelected 
                         ? Border.all(color: AppTheme.coralMain.withOpacity(0.3))
                         : null,
                     ),
                     child: ListTile(
                       title: Text(
                         category,
                         style: AppTextStyles.bodyLarge.copyWith(
                           fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                           color: isSelected ? AppTheme.coralMain : Theme.of(context).colorScheme.onSurface,
                         ),
                       ),
                       leading: Container(
                         padding: EdgeInsets.all(AppTheme.spacingSmall),
                         decoration: BoxDecoration(
                           color: isSelected 
                             ? AppTheme.coralMain.withOpacity(0.2)
                             : AppTheme.lightGrey.withOpacity(0.3),
                           borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                         ),
                         child: Icon(
                           _getCategoryIcon(category),
                           color: isSelected ? AppTheme.coralMain : AppTheme.mediumGrey,
                           size: 20,
                         ),
                       ),
                       trailing: isSelected
                           ? Container(
                               padding: EdgeInsets.all(4),
                               decoration: BoxDecoration(
                                 color: AppTheme.coralMain,
                                 borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                               ),
                               child: Icon(
                                 Icons.check_rounded,
                                 color: AppTheme.pureWhite,
                                 size: 16,
                               ),
                             )
                           : null,
                       contentPadding: EdgeInsets.symmetric(
                         horizontal: AppTheme.spacingLarge,
                         vertical: AppTheme.spacingSmall,
                       ),
                       onTap: () {
                         setState(() {
                           _categoryController.text = category;
                         });
                         Navigator.pop(context);
                       },
                     ),
                   );
                 },
               ),
             ),
           ],
         ),
       ),
     ),
   );
 }

 IconData _getCategoryIcon(String category) {
   switch (category.toLowerCase()) {
     case 'lácteos':
       return Icons.egg_alt_outlined;
     case 'frutas':
       return Icons.apple_rounded;
     case 'verduras':
       return Icons.eco_rounded;
     case 'carnes':
       return Icons.restaurant_rounded;
     case 'pescados':
       return Icons.set_meal_rounded;
     case 'granos':
       return Icons.grain_rounded;
     case 'bebidas':
       return Icons.local_drink_rounded;
     case 'snacks':
       return Icons.fastfood_rounded;
     case 'congelados':
       return Icons.ac_unit_rounded;
     case 'panadería':
       return Icons.bakery_dining_rounded;
     case 'cereales':
       return Icons.breakfast_dining_rounded;
     case 'condimentos':
       return Icons.soup_kitchen_rounded;
     case 'conservas':
       return Icons.inventory_2_rounded;
     case 'dulces':
       return Icons.cake_rounded;
     default:
       return Icons.category_rounded;
   }
 }

 Widget _buildFloatingActionButtons() {
   return Container(
     padding: EdgeInsets.all(AppTheme.spacingLarge),
     decoration: BoxDecoration(
       gradient: LinearGradient(
         begin: Alignment.topCenter,
         end: Alignment.bottomCenter,
         colors: [
           Colors.transparent,
           Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
           Theme.of(context).scaffoldBackgroundColor,
         ],
       ),
     ),
     child: SafeArea(
       child: _buildActionButtons(),
     ),
   );
 }

 Widget _buildActionButtons() {
   if (widget.fromShoppingList == true) {
     return _buildBottomButtonBar(
       primaryButton: ActionButtonData(
         icon: Icons.shopping_cart_outlined,
         label: 'Añadir al Carrito',
         onPressed: _addToShoppingList,
         type: ButtonType.primary,
       ),
       secondaryButtons: [
         ActionButtonData(
           icon: Icons.favorite_border_rounded,
           label: 'Favoritos',
           onPressed: _addToFavorites,
           type: ButtonType.secondary,
         ),
         ActionButtonData(
           icon: Icons.save_rounded,
           label: 'Guardar',
           onPressed: _saveProduct,
           type: ButtonType.text,
         ),
       ],
     );
   } else if (_isEditing) {
     return _buildBottomButtonBar(
       primaryButton: ActionButtonData(
         icon: Icons.check_rounded,
         label: 'Actualizar Producto',
         onPressed: _saveProduct,
         type: ButtonType.primary,
       ),
       secondaryButtons: [
         ActionButtonData(
           icon: Icons.favorite_border_rounded,
           label: 'Favoritos',
           onPressed: _addToFavorites,
           type: ButtonType.secondary,
         ),
         ActionButtonData(
           icon: Icons.shopping_cart_outlined,
           label: 'Al carrito',
           onPressed: _addToShoppingList,
           type: ButtonType.text,
         ),
       ],
     );
   } else {
     return _buildBottomButtonBar(
       primaryButton: ActionButtonData(
         icon: Icons.add_rounded,
         label: 'Guardar Producto',
         onPressed: _saveProduct,
         type: ButtonType.primary,
       ),
       secondaryButtons: [
         ActionButtonData(
           icon: Icons.favorite_border_rounded,
           label: 'Favoritos',
           onPressed: _addToFavorites,
           type: ButtonType.secondary,
         ),
         ActionButtonData(
           icon: Icons.shopping_cart_outlined,
           label: 'Al carrito',
           onPressed: _addToShoppingList,
           type: ButtonType.text,
         ),
       ],
     );
   }
 }

 Widget _buildBottomButtonBar({
   required ActionButtonData primaryButton,
   required List<ActionButtonData> secondaryButtons,
 }) {
   return Column(
     children: [
       Container(
         width: double.infinity,
         height: 56,
         decoration: BoxDecoration(
           gradient: LinearGradient(
             begin: Alignment.centerLeft,
             end: Alignment.centerRight,
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
             onTap: primaryButton.onPressed,
             child: Center(
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(
                     primaryButton.icon,
                     color: AppTheme.pureWhite,
                     size: 24,
                   ),
                   SizedBox(width: AppTheme.spacingMedium),
                   Text(
                     primaryButton.label,
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
       
       Row(
         children: secondaryButtons.asMap().entries.map((entry) {
           final index = entry.key;
           final button = entry.value;
           
           return Expanded(
             child: Padding(
               padding: EdgeInsets.only(
                 left: index > 0 ? AppTheme.spacingSmall : 0,
               ),
               child: _buildSecondaryButton(button),
             ),
           );
         }).toList(),
       ),
     ],
   );
 }

 Widget _buildSecondaryButton(ActionButtonData button) {
   Color buttonColor;
   Color backgroundColor;
   
   switch (button.type) {
     case ButtonType.secondary:
       buttonColor = AppTheme.softTeal;
       backgroundColor = AppTheme.softTeal.withOpacity(0.1);
       break;
     case ButtonType.text:
       buttonColor = AppTheme.warningOrange;
       backgroundColor = AppTheme.warningOrange.withOpacity(0.1);
       break;
       default:
       buttonColor = AppTheme.coralMain;
       backgroundColor = AppTheme.coralMain.withOpacity(0.1);
   }
   
   return Container(
     height: 48,
     decoration: BoxDecoration(
       color: backgroundColor,
       borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
       border: Border.all(
         color: buttonColor.withOpacity(0.3),
       ),
     ),
     child: Material(
       color: Colors.transparent,
       child: InkWell(
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
         onTap: button.onPressed,
         child: Center(
           child: Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(
                 button.icon,
                 color: buttonColor,
                 size: 20,
               ),
               SizedBox(width: AppTheme.spacingSmall),
               Flexible(
                 child: Text(
                   button.label,
                   style: AppTextStyles.bodySmall.copyWith(
                     color: buttonColor,
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
   );
 }

 bool _hasMainMacros(NutritionalInfo info) {
  return info.proteins != null || info.carbohydrates != null || info.fats != null;
}

bool _hasAdditionalInfo(NutritionalInfo info) {
  return info.fiber != null || info.sugar != null || info.sodium != null;
}

 // MÉTODO ACTUALIZADO PARA EL OVERLAY DE CARGA
 Widget _buildLoadingOverlay() {
   String loadingText;
   String loadingDescription;
   
   if (_isScanning) {
     loadingText = 'Escaneando código...';
     loadingDescription = 'Mantén la cámara enfocada en el código';
   } else if (_isAnalyzingProduct) {
     loadingText = 'Analizando producto con IA...';
     loadingDescription = 'Identificando producto y estimando información...';
   } else if (_isAnalyzingNutrition) {
     loadingText = 'Analizando etiqueta nutricional...';
     loadingDescription = 'Detectando información nutricional con IA...';
   } else if (_isUploadingImage) {
     loadingText = 'Subiendo imagen...';
     loadingDescription = 'Guardando imagen en la nube...';
   } else if (_isLoadingBarcode) {
     loadingText = 'Cargando información...';
     loadingDescription = 'Obteniendo datos del producto...';
   } else if (_isSaving) {
     loadingText = 'Guardando producto...';
     loadingDescription = 'Guardando en el inventario...';
   } else {
     loadingText = 'Procesando...';
     loadingDescription = 'Por favor, espera un momento';
   }

   return Container(
     color: Colors.black.withOpacity(0.6),
     child: Center(
       child: Container(
         padding: EdgeInsets.all(AppTheme.spacingXLarge),
         decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.surface,
           borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
           boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.2),
               blurRadius: 20,
               offset: Offset(0, 8),
             ),
           ],
         ),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Container(
               width: 80,
               height: 80,
               padding: EdgeInsets.all(AppTheme.spacingLarge),
               decoration: BoxDecoration(
                 color: AppTheme.coralMain.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
               ),
               child: CircularProgressIndicator(
                 valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralMain),
                 strokeWidth: 4,
               ),
             ),
             SizedBox(height: AppTheme.spacingLarge),
             
             Text(
               loadingText,
               style: AppTextStyles.heading5.copyWith(
                 color: Theme.of(context).colorScheme.onSurface,
               ),
             ),
             SizedBox(height: AppTheme.spacingMedium),
             
             Text(
               loadingDescription,
               style: AppTextStyles.bodySmall.copyWith(
                 color: AppTheme.mediumGrey,
                 fontWeight: FontWeight.w500,
               ),
               textAlign: TextAlign.center,
             ),
           ],
         ),
       ),
     ),
   );
 }
}


