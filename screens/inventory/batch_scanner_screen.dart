// lib/screens/inventory/batch_scanner_screen.dart

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../services/barcode_service.dart';
import '../../services/inventory_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/inventory/product_card.dart';
import 'add_product_screen.dart';
import 'barcode_scanner_screen.dart';

class BatchScannerScreen extends StatefulWidget {
  const BatchScannerScreen({super.key});

  @override
  State<BatchScannerScreen> createState() => _BatchScannerScreenState();
}

class _BatchScannerScreenState extends State<BatchScannerScreen> {
  final BarcodeService _barcodeService = BarcodeService();
  final InventoryService _inventoryService = InventoryService();
  
  // Lista de productos escaneados
  final List<Product> _scannedProducts = [];
  
  // Estados
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
  }
  
  Future<void> _startScanning() async {
    // Navegar a la pantalla de escaneo individual
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );
    
    // Si se escaneó un producto, añadirlo a la lista
    if (result == true) {
      _refreshProducts();
    }
  }
  
  Future<void> _refreshProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // En una implementación real, aquí obtendríamos los productos recién añadidos
      // Por ahora, simulamos un retraso
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Obtener los productos más recientes
      final recentProducts = await _inventoryService.getRecentProducts(5);
      
      // Actualizar la lista
      setState(() {
        // Añadir solo los productos que no están ya en la lista
        for (final product in recentProducts) {
          if (!_scannedProducts.any((p) => p.id == product.id)) {
            _scannedProducts.add(product);
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar productos: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _addProductManually() async {
    // Navegar a la pantalla de añadir producto
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddProductScreen(),
      ),
    );
    
    // Si se añadió un producto, actualizar la lista
    if (result == true) {
      _refreshProducts();
    }
  }
  
  Future<void> _saveAllProducts() async {
    if (_scannedProducts.isEmpty) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // En una implementación real, aquí guardaríamos todos los productos
      // en una sola operación si fuera necesario
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_scannedProducts.length} productos guardados correctamente'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          margin: const EdgeInsets.all(AppTheme.spacingMedium),
        ),
      );
      
      // Volver a la pantalla anterior
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar productos: $e';
        _isSaving = false;
      });
    }
  }
  
  void _removeProduct(Product product) {
    setState(() {
      _scannedProducts.removeWhere((p) => p.id == product.id);
    });
  }
  
  Future<void> _editProduct(Product product) async {
    // Navegar a la pantalla de edición
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(
          productToEdit: product,
        ),
      ),
    );
    
    // Si se editó el producto, actualizar la lista
    if (result == true) {
      _refreshProducts();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Escaneo por lotes',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshProducts,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }
  
  Widget _buildBody() {
    // Si está cargando, mostrar indicador
    if (_isLoading) {
      return const Center(
        child: LoadingIndicator(message: 'Cargando productos...'),
      );
    }
    
    // Si hay un error, mostrar mensaje
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: AppTheme.coralMain,
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacingXLarge),
              CustomButton(
                text: 'Intentar de nuevo',
                onPressed: _refreshProducts,
                type: ButtonType.primary,
                icon: Icons.refresh_rounded,
              ),
            ],
          ),
        ),
      );
    }
    
    // Si no hay productos, mostrar mensaje
    if (_scannedProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                decoration: BoxDecoration(
                  color: AppTheme.peachLight.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_basket_rounded,
                  size: 80,
                  color: AppTheme.coralMain,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              Text(
                'No hay productos escaneados',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppTheme.spacingMedium),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
                child: Text(
                  'Escanea un código de barras para añadir un producto',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mediumGrey,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXLarge),
              CustomButton(
                text: 'Escanear producto',
                onPressed: _startScanning,
                type: ButtonType.primary,
                icon: Icons.qr_code_scanner_rounded,
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              CustomButton(
                text: 'Añadir manualmente',
                onPressed: _addProductManually,
                type: ButtonType.secondary,
                icon: Icons.edit_rounded,
              ),
            ],
          ),
        ),
      );
    }
    
    // Mostrar lista de productos
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          itemCount: _scannedProducts.length,
          itemBuilder: (context, index) {
            final product = _scannedProducts[index];
            
            return Dismissible(
              key: Key(product.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppTheme.spacingLarge),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                child: const Icon(
                  Icons.delete_rounded,
                  color: AppTheme.pureWhite,
                  size: 28,
                ),
              ),
              onDismissed: (direction) => _removeProduct(product),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
                child: ProductCard(
                  name: product.name,
                  quantity: product.formattedQuantity(),
                  unit: product.unit,
                  category: product.category,
                  location: product.location,
                  expiryDate: product.expiryDate,
                  maxQuantity: product.maxQuantity,
                  onTap: () => _editProduct(product),
                  onEdit: () => _editProduct(product),
                  onDelete: () => _removeProduct(product),
                ),
              ),
            );
          },
        ),
        
        // Overlay de carga al guardar
        if (_isSaving)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Card(
                elevation: AppTheme.elevationSmall,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingLarge),
                  child: LoadingIndicator(message: 'Guardando productos...'),
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLarge,
        vertical: AppTheme.spacingMedium,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Escanear más',
                onPressed: _startScanning,
                type: ButtonType.secondary,
                icon: Icons.qr_code_scanner_rounded,
              ),
            ),
            const SizedBox(width: AppTheme.spacingLarge),
            Expanded(
              child: CustomButton(
                text: 'Guardar todo',
                onPressed: _scannedProducts.isNotEmpty ? _saveAllProducts : null,
                type: ButtonType.primary,
                icon: Icons.save_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}