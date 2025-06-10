// lib/screens/inventory/inventory_screen.dart - Con ProductCard Mejorado Integrado

import 'package:flutter/material.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../services/inventory_service.dart';
import '../../widgets/common/bottom_navigation.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/inventory/storage_location_selector.dart';
import '../../widgets/inventory/product_card.dart'; // IMPORT DEL NUEVO PRODUCT CARD
import 'favorites_screen.dart';
import '../../models/product_location_model.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> 
    with TickerProviderStateMixin {
  int _currentNavIndex = 1;
  String _selectedLocation = 'Nevera';
  final TextEditingController _searchController = TextEditingController();
  final InventoryService _inventoryService = InventoryService();
  bool _isLoading = true;
  List<Product> _allProducts = [];
  String _errorMessage = '';
  String _searchQuery = '';
  
  List<Product> _shoppingListProducts = [];
  bool _showShoppingListSuggestions = true;
  
  late AnimationController _animationController;
  late AnimationController _headerAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _headerFadeAnimation;
  
  // Variables para header colapsable - MEJORADAS
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderCollapsed = false;
  double _scrollOffset = 0.0;
  static const double _scrollThreshold = 120.0;
  
  final List<StorageLocation> _storageLocations = StorageLocationSelector.defaultLocations;
  
  final List<BottomNavigationItem> _navItems = [
    BottomNavigationItem(label: 'Inicio', icon: Icons.home_rounded),
    BottomNavigationItem(label: 'Inventario', icon: Icons.inventory_2_rounded),
    BottomNavigationItem(label: 'Planificador', icon: Icons.calendar_today_rounded),
    BottomNavigationItem(label: 'Compras', icon: Icons.shopping_cart_rounded),
    BottomNavigationItem(label: 'Recetas', icon: Icons.restaurant_menu_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupScrollListener();
    _loadProducts();
    _loadShoppingListProducts();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _headerFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _headerAnimationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      final shouldCollapse = offset > _scrollThreshold;
      
      if (shouldCollapse != _isHeaderCollapsed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isHeaderCollapsed = shouldCollapse;
              _scrollOffset = offset;
            });
            
            if (shouldCollapse && !_headerAnimationController.isAnimating) {
              _headerAnimationController.forward();
            } else if (!shouldCollapse && !_headerAnimationController.isAnimating) {
              _headerAnimationController.reverse();
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _headerAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadShoppingListProducts() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final products = await _inventoryService.getProductsByAppLocation(ProductLocation.shoppingList);
      
      if (mounted) {
        setState(() {
          _shoppingListProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar productos de la lista de compras: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadProducts() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      await _inventoryService.initialize();
      final products = await _inventoryService.getAllProducts();
      products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      
      if (mounted) {
        setState(() {
          _allProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar productos: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onNavTap(int index) {
    if (_currentNavIndex == index) return;
    
    setState(() => _currentNavIndex = index);
    
    switch (index) {
      case 0: Navigator.pushNamedAndRemoveUntil(context, Routes.dashboard, (route) => false); break;
      case 1: Navigator.pushNamedAndRemoveUntil(context, Routes.inventory, (route) => false); break;
      case 2: Navigator.pushNamedAndRemoveUntil(context, Routes.mealPlanner, (route) => false); break;
      case 3: Navigator.pushNamedAndRemoveUntil(context, Routes.shoppingList, (route) => false); break;
      case 4: Navigator.pushNamedAndRemoveUntil(context, Routes.recipes, (route) => false); break;
    }
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query.toLowerCase());
  }
  
  void _navigateToAddProduct() {
    Navigator.pushNamed(context, Routes.addProduct).then((result) {
      if (result == true && mounted) {
        _loadProducts();
        _loadShoppingListProducts();
      }
    });
  }
  
  void _navigateToFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FavoritesScreen()),
    ).then((_) {
      if (mounted) {
        _loadProducts();
        _loadShoppingListProducts();
      }
    });
  }

  // Mostrar diálogo de confirmación para unir productos
void _showMergeProductsDialog() async {
  try {
    setState(() => _isLoading = true);
    
    // Obtener productos que se pueden unir
    final duplicateGroups = await _inventoryService.getProductsThatCanBeMerged();
    
    setState(() => _isLoading = false);
    
    if (duplicateGroups.isEmpty) {
      _showSnackBar('No hay productos duplicados para unir', AppTheme.softTeal, Icons.info);
      return;
    }
    
    // Mostrar diálogo de confirmación
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.merge, color: AppTheme.softTeal),
            SizedBox(width: 12),
            Text('Unir duplicados'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se encontraron ${duplicateGroups.length} grupos de productos duplicados:'),
            SizedBox(height: 16),
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: duplicateGroups.entries.map((entry) {
                    final productName = entry.value.first.name;
                    final count = entry.value.length;
                    final totalQuantity = entry.value.fold<int>(0, (sum, p) => sum + p.quantity);
                    final unit = entry.value.first.unit;
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.softTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2, color: AppTheme.softTeal, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(productName, style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('$count productos → Total: $totalQuantity $unit',
                                     style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              '⚠️ Esta acción no se puede deshacer. Los productos duplicados se eliminarán y sus cantidades se sumarán.',
              style: TextStyle(fontSize: 12, color: AppTheme.warningOrange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performMergeProducts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.softTeal,
              foregroundColor: AppTheme.pureWhite,
            ),
            child: Text('Unir productos'),
          ),
        ],
      ),
    );
    
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnackBar('Error: $e', AppTheme.errorRed, Icons.error);
  }
}

// Realizar la unión de productos
Future<void> _performMergeProducts() async {
  try {
    setState(() => _isLoading = true);
    
    final mergedProducts = await _inventoryService.mergeDuplicateProducts();
    
    if (mounted) {
      setState(() => _isLoading = false);
      _loadProducts(); // Recargar productos
      
      _showSnackBar(
        'Productos unidos correctamente. Total: ${mergedProducts.length}',
        AppTheme.successGreen,
        Icons.check_circle,
      );
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al unir productos: $e', AppTheme.errorRed, Icons.error);
    }
  }
}

// Método auxiliar para mostrar SnackBar
void _showSnackBar(String message, Color color, IconData icon) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
    ),
  );
}
  
  // MÉTODO MEJORADO PARA ELIMINAR PRODUCTO
  void _deleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.errorRed),
            SizedBox(width: 8),
            Text('Eliminar producto'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de eliminar este producto?'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_getCategoryIcon(product.category), 
                       color: AppTheme.errorRed, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, 
                             style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${product.quantity} ${product.unit} • ${product.location}',
                             style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteProduct(product);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteProduct(Product product) async {
    try {
      await _inventoryService.deleteProduct(product.id);
      if (mounted) {
        _loadProducts();
        _loadShoppingListProducts();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('${product.name} eliminado correctamente'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Error al eliminar: $e'),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // CALLBACK PARA MANEJAR CAMBIOS DE FAVORITOS
  void _onFavoriteToggle() {
    // Recargar productos para reflejar cambios
    _loadProducts();
  }

  // CALLBACK PARA MANEJAR ACCIONES DEL CARRITO
  void _onCartAction() {
    // Recargar ambas listas para reflejar cambios
    _loadProducts();
    _loadShoppingListProducts();
  }

  // Header expandido MEJORADO
  Widget _buildExpandedHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.softTeal,
            AppTheme.softTeal.withOpacity(0.9),
            AppTheme.yellowAccent.withOpacity(0.6),
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          _buildBackgroundEffects(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHeaderTop(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _headerFadeAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _headerFadeAnimation.value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - _headerFadeAnimation.value) * 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mi Inventario',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.pureWhite,
                                        letterSpacing: -1,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Organiza y controla tus productos',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppTheme.pureWhite.withOpacity(0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      _buildQuickStats(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return Stack(
      children: [
        Positioned(
          top: -50, right: -50,
          child: Container(
            width: 150, height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.pureWhite.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: -30, left: -30,
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.coralMain.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          top: 100, right: 50,
          child: Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.pureWhite.withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderTop() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.pureWhite.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.pureWhite.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_rounded, color: AppTheme.pureWhite, size: 16),
            const SizedBox(width: 8),
            Text(
              'Mi Despensa',
              style: TextStyle(
                color: AppTheme.pureWhite,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      Row(
        children: [
          _buildHeaderButton(icon: Icons.favorite_rounded, onTap: _navigateToFavorites),
          const SizedBox(width: 16),
          _buildHeaderButton(
            icon: Icons.access_time_rounded, 
            onTap: () => Navigator.pushNamed(context, Routes.expiryControl),
          ),
          const SizedBox(width: 16),
          // NUEVO BOTÓN DE UNIR PRODUCTOS
          _buildHeaderButton(
            icon: Icons.merge_rounded, 
            onTap: _showMergeProductsDialog,
          ),
        ],
      ),
    ],
  );
}

  Widget _buildHeaderButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.pureWhite.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.pureWhite.withOpacity(0.3)),
        ),
        child: Icon(icon, color: AppTheme.pureWhite, size: 20),
      ),
    );
  }

  Widget _buildQuickStats() {
    final stats = _getInventoryStats();
    final lowStockCount = _allProducts.where((p) => p.quantity < 3).length;
    final expiringCount = _allProducts.where((p) => 
      p.expiryDate != null && 
      p.expiryDate!.difference(DateTime.now()).inDays <= 3
    ).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatBadge('${stats['total']}', 'Productos', Icons.inventory_2_rounded),
          const SizedBox(width: 12),
          _buildStatBadge('$lowStockCount', 'Stock bajo', Icons.warning_rounded),
          const SizedBox(width: 12),
          _buildStatBadge('$expiringCount', 'Por vencer', Icons.schedule_rounded),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.pureWhite.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.pureWhite, size: 14),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(
                color: AppTheme.pureWhite, fontSize: 14, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(
                color: AppTheme.pureWhite.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // Barra de búsqueda moderna
  Widget _buildModernSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          hintStyle: TextStyle(color: AppTheme.mediumGrey, fontSize: 16),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.softTeal, size: 24),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear_rounded, color: AppTheme.mediumGrey),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                ),
              IconButton(
                icon: Icon(Icons.tune_rounded, color: AppTheme.softTeal),
                onPressed: () => _showFilterBottomSheet(),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLarge,
            vertical: AppTheme.spacingMedium,
          ),
        ),
      ),
    );
  }

  // Selector de ubicación mejorado
  Widget _buildLocationSelector() {
    return Container(
      height: 80,
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _storageLocations.take(5).length,
        separatorBuilder: (context, index) => SizedBox(width: AppTheme.spacingSmall),
        itemBuilder: (context, index) {
          final location = _storageLocations[index];
          return _buildLocationCard(location);
        },
      ),
    );
  }

  Widget _buildLocationCard(StorageLocation location) {
    final isSelected = _selectedLocation == location.name;
    final count = _allProducts.where((p) => p.location == location.name).length;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedLocation = location.name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 85, height: 80,
        padding: EdgeInsets.all(AppTheme.spacingSmall),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [location.color, location.color.withOpacity(0.7)],
          ) : null,
          color: isSelected ? null : AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          border: Border.all(
            color: isSelected ? location.color : AppTheme.lightGrey,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? location.color.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 12 : 4,
              offset: Offset(0, isSelected ? 6 : 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(location.icon, 
                 color: isSelected ? AppTheme.pureWhite : location.color, size: 22),
            SizedBox(height: 4),
            Flexible(
              child: Text(location.name,
                style: TextStyle(
                  color: isSelected ? AppTheme.pureWhite : AppTheme.darkGrey,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count > 0) ...[
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppTheme.pureWhite.withOpacity(0.2)
                      : location.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
                child: Text('$count',
                  style: TextStyle(
                    color: isSelected ? AppTheme.pureWhite : location.color,
                    fontSize: 9, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // LISTA DE PRODUCTOS MEJORADA CON NUEVO PRODUCT CARD
  Widget _buildProductList() {
    final filteredByLocation = _allProducts.where((product) => 
      product.location == _selectedLocation
    ).toList();
    
    final filteredProducts = _searchQuery.isEmpty
        ? filteredByLocation
        : filteredByLocation.where((product) => 
            product.name.toLowerCase().contains(_searchQuery) ||
            product.category.toLowerCase().contains(_searchQuery)
          ).toList();
    
    if (filteredProducts.isEmpty) {
      return SizedBox(height: 400, child: _buildEmptyState());
    }
    
    return Column(
      children: filteredProducts.asMap().entries.map((entry) {
        final index = entry.key;
        final product = entry.value;
        
        return AnimatedOpacity(
          duration: Duration(milliseconds: 300 + (index * 30)),
          opacity: 1.0,
          curve: Curves.easeInOut,
          child: ProductCard(
            name: product.name,
            quantity: '${product.quantity}',
            unit: product.unit,
            maxQuantity: product.maxQuantity,
            expiryDate: product.expiryDate,
            category: product.category,
            location: product.location,
            product: product,
            showLocationBadge: true,
            
            onTap: () => Navigator.pushNamed(
  context, 
  Routes.productDetail,
  arguments: {'product': product},
).then((_) {
  if (mounted) {
    _loadProducts();
    _loadShoppingListProducts();
  }
}),
            
            onEdit: () => Navigator.pushNamed(
              context, 
              Routes.addProduct,
              arguments: {'productToEdit': product},
            ).then((result) {
              if (result == true && mounted) {
                _loadProducts();
                _loadShoppingListProducts();
              }
            }),
            
            onDelete: () => _deleteProduct(product),
            
            // NUEVOS CALLBACKS PARA FAVORITOS Y CARRITO
            onFavoriteToggle: _onFavoriteToggle,
            onCartAction: _onCartAction,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacingXLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.softTeal, AppTheme.softTeal.withOpacity(0.6)],
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(Icons.inventory_2_rounded, size: 48, color: AppTheme.pureWhite),
          ),
          SizedBox(height: AppTheme.spacingLarge),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No se encontraron productos' 
                : 'No hay productos en $_selectedLocation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
          ),
          SizedBox(height: AppTheme.spacingSmall),
          Text(
            _searchQuery.isNotEmpty
                ? 'Intenta con otros términos de búsqueda'
                : 'Añade productos para empezar a organizar tu inventario',
            style: TextStyle(fontSize: 14, color: AppTheme.mediumGrey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spacingXLarge),
          ElevatedButton.icon(
            onPressed: _navigateToAddProduct,
            icon: Icon(Icons.add_rounded),
            label: Text('Añadir producto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralMain,
              foregroundColor: AppTheme.pureWhite,
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
                vertical: AppTheme.spacingMedium,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusLarge)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(AppTheme.spacingLarge),
        decoration: BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusLarge)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.lightGrey, borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(height: AppTheme.spacingLarge),
            Text('Filtrar productos', 
                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
            SizedBox(height: AppTheme.spacingLarge),
            // Opciones de filtro aquí
            Text('Filtros próximamente...'),
            SizedBox(height: AppTheme.spacingLarge),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getInventoryStats() {
    final uniqueLocations = _allProducts.map((p) => p.location).toSet().length;
    return {
      'total': _allProducts.length,
      'locations': uniqueLocations,
    };
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'frutas':
      case 'fruta':
        return Icons.apple_rounded;
      case 'verduras':
      case 'verdura':
        return Icons.eco_rounded;
      case 'lácteos':
      case 'lacteo':
        return Icons.egg_rounded;
      case 'carnes':
      case 'carne':
        return Icons.restaurant_menu_rounded;
      case 'pescado':
      case 'mariscos':
        return Icons.set_meal_rounded;
      case 'bebidas':
      case 'bebida':
        return Icons.local_drink_rounded;
      case 'congelados':
        return Icons.ac_unit_rounded;
      case 'snacks':
      case 'aperitivos':
        return Icons.fastfood_rounded;
      case 'cereales':
      case 'pasta':
        return Icons.breakfast_dining_rounded;
      case 'conservas':
        return Icons.inventory_2_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Future<void> _showQuantityDialog(BuildContext context, Product product) async {
    int quantity = 1;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Añadir ${product.name}'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿Cuántas unidades quieres añadir al inventario?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacingMedium),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
                    icon: Icon(Icons.remove_circle_outline_rounded, color: AppTheme.coralMain),
                  ),
                  const SizedBox(width: AppTheme.spacingSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.softTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    ),
                    child: Text(
                      '$quantity',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.softTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSmall),
                  IconButton(
                    onPressed: () => setState(() => quantity++),
                    icon: Icon(Icons.add_circle_outline_rounded, color: AppTheme.softTeal),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.mediumGrey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.softTeal,
                foregroundColor: AppTheme.pureWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
              ),
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
    
    if (result == true) {
      await _addToInventory(product, quantity);
    }
  }

  Future<void> _addToInventory(Product product, int quantity) async {
    try {
      await _inventoryService.moveProductToInventory(product.id);
      
      if (quantity > 1) {
        final updatedProduct = await _inventoryService.getProductById(product.id);
        
        if (updatedProduct != null) {
          final productWithNewQuantity = updatedProduct.copyWith(quantity: quantity);
          await _inventoryService.updateProduct(productWithNewQuantity);
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se añadieron $quantity ${product.unit} de ${product.name} al inventario'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge)),
            margin: const EdgeInsets.all(AppTheme.spacingMedium),
          ),
        );
        
        _loadShoppingListProducts();
        _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge)),
            margin: const EdgeInsets.all(AppTheme.spacingMedium),
          ),
        );
      }
    }
  }

  // Widget para la sección de productos de lista de compras (mejorado)
  Widget _buildShoppingListSuggestions() {
    if (_shoppingListProducts.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.coralMain, AppTheme.coralMain.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.coralMain.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _showShoppingListSuggestions = !_showShoppingListSuggestions),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingMedium),
                      decoration: BoxDecoration(
                        color: AppTheme.pureWhite.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                      ),
                      child: Icon(Icons.shopping_cart_rounded, color: AppTheme.pureWhite, size: 24),
                    ),
                    SizedBox(width: AppTheme.spacingMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lista de compras',
                            style: TextStyle(
                              color: AppTheme.pureWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_shoppingListProducts.length} productos listos para añadir',
                            style: TextStyle(
                              color: AppTheme.pureWhite.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _showShoppingListSuggestions ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppTheme.pureWhite,
                      size: 24,
                    ),
                  ],
                ),
                
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: _showShoppingListSuggestions
                    ? Column(
                        children: [
                          SizedBox(height: AppTheme.spacingLarge),
                          ..._shoppingListProducts.take(3).map((product) => 
                            _buildShoppingListItem(product),
                          ),
                          if (_shoppingListProducts.length > 3)
                            Padding(
                              padding: EdgeInsets.only(top: AppTheme.spacingMedium),
                              child: TextButton(
                                onPressed: () => Navigator.pushNamed(context, Routes.shoppingList),
                                style: TextButton.styleFrom(
                                  backgroundColor: AppTheme.pureWhite.withOpacity(0.2),
                                  foregroundColor: AppTheme.pureWhite,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                                  ),
                                ),
                                child: Text('Ver todos (${_shoppingListProducts.length})'),
                              ),
                            ),
                        ],
                      )
                    : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShoppingListItem(Product product) {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacingSmall),
      padding: EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.pureWhite.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(_getCategoryIcon(product.category), color: AppTheme.pureWhite, size: 20),
          SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    color: AppTheme.pureWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  product.category,
                  style: TextStyle(
                    color: AppTheme.pureWhite.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showQuantityDialog(context, product),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.pureWhite.withOpacity(0.2),
              foregroundColor: AppTheme.pureWhite,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
            child: Text('Añadir', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: RefreshIndicator(
                  color: AppTheme.softTeal,
                  backgroundColor: AppTheme.pureWhite,
                  onRefresh: () async {
                    await Future.wait([_loadProducts(), _loadShoppingListProducts()]);
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // SliverAppBar MEJORADO
                      SliverAppBar(
                        expandedHeight: 220,
                        floating: false,
                        pinned: true,
                        elevation: 0,
                        backgroundColor: AppTheme.softTeal,
                        surfaceTintColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        forceElevated: false,
                        automaticallyImplyLeading: false,
                        leading: null,
                        title: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _isHeaderCollapsed ? 1.0 : 0.0,
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_rounded, color: AppTheme.pureWhite, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Inventario',
                                style: TextStyle(
                                  color: AppTheme.pureWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        actions: _isHeaderCollapsed
                          ? [
                              IconButton(
                                icon: Icon(Icons.favorite_rounded, color: AppTheme.pureWhite),
                                onPressed: _navigateToFavorites,
                              ),
                              IconButton(
                                icon: Icon(Icons.access_time_rounded, color: AppTheme.pureWhite),
                                onPressed: () => Navigator.pushNamed(context, Routes.expiryControl),
                              ),
                              const SizedBox(width: 8),
                            ]
                          : null,
                        flexibleSpace: FlexibleSpaceBar(
                          background: _buildExpandedHeader(),
                          collapseMode: CollapseMode.parallax,
                          stretchModes: const [
                            StretchMode.zoomBackground,
                            StretchMode.fadeTitle,
                          ],
                        ),
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(35),
                          child: Container(
                            height: 35,
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundGrey,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 40, height: 4,
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGrey,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Contenido principal
                      SliverToBoxAdapter(
                        child: Container(
                          color: AppTheme.backgroundGrey,
                          child: Column(
                            children: [
                              const SizedBox(height: 30),
                              
                              // Sugerencias de lista de compras
                              if (_shoppingListProducts.isNotEmpty) ...[
                                _buildShoppingListSuggestions(),
                                SizedBox(height: AppTheme.spacingLarge),
                              ],
                              
                              // Barra de búsqueda
                              _buildModernSearchBar(),
                              SizedBox(height: AppTheme.spacingLarge),
                              
                              // Selector de ubicación
                              _buildLocationSelector(),
                              SizedBox(height: AppTheme.spacingLarge),
                              
                              // Lista de productos CON EL NUEVO PRODUCT CARD
                              Container(
                                constraints: BoxConstraints(
                                  minHeight: MediaQuery.of(context).size.height * 0.3,
                                ),
                                child: _errorMessage.isNotEmpty
                                    ? _buildErrorState()
                                    : _buildProductList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddProduct,
        backgroundColor: AppTheme.coralMain,
        foregroundColor: AppTheme.pureWhite,
        elevation: AppTheme.elevationSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir'),
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        items: _navItems,
        showLabels: false,
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 400,
      padding: EdgeInsets.all(AppTheme.spacingXLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorRed),
          ),
          SizedBox(height: AppTheme.spacingLarge),
          Text(
            'Error al cargar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
          ),
          SizedBox(height: AppTheme.spacingSmall),
          Text(
            _errorMessage,
            style: TextStyle(fontSize: 14, color: AppTheme.mediumGrey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spacingXLarge),
          ElevatedButton.icon(
            onPressed: _loadProducts,
            icon: Icon(Icons.refresh_rounded),
            label: Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralMain,
              foregroundColor: AppTheme.pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}