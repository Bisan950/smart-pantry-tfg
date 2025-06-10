// lib/screens/inventory/favorites_screen.dart - VERSIÓN OPTIMIZADA

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../providers/shopping_list_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/inventory/favorite_product_card.dart';
// En TODOS estos archivos:

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  // Controladores y estado local
  late final TextEditingController _searchController;
  String _searchQuery = '';
  
  // Cache optimizado
  List<Product> _filteredItems = [];
  bool _hasInitialized = false;
  
  // Control de operaciones
  final Set<String> _processingItems = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    
    // Inicialización optimizada después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeFavorites() async {
    if (!mounted || _hasInitialized) return;
    
    final provider = context.read<ShoppingListProvider>();
    
    // Solo cargar si no hay favoritos y no está cargando
    if (provider.favoriteProducts.isEmpty && !provider.isFavoritesLoading) {
      print('🔄 Inicializando favoritos...');
      await provider.loadFavorites();
      
      if (mounted) {
        setState(() {
          _hasInitialized = true;
        });
        _updateFilteredItems(provider.favoriteProducts);
      }
    } else {
      setState(() {
        _hasInitialized = true;
      });
      _updateFilteredItems(provider.favoriteProducts);
    }
  }

  void _updateFilteredItems(List<Product> favorites) {
    if (!mounted) return;
    
    final query = _searchQuery.toLowerCase().trim();
    
    if (query.isEmpty) {
      _filteredItems = List.from(favorites);
    } else {
      _filteredItems = favorites.where((product) {
        return product.name.toLowerCase().contains(query) ||
               product.category.toLowerCase().contains(query);
      }).toList();
    }
    
    // Ordenar por nombre para consistencia
    _filteredItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _onSearchChanged(String value) {
    if (!mounted) return;
    
    setState(() {
      _searchQuery = value;
    });
    
    // Aplicar filtro inmediatamente con los datos actuales
    final provider = context.read<ShoppingListProvider>();
    _updateFilteredItems(provider.favoriteProducts);
  }

  void _clearSearch() {
    if (!mounted) return;
    
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    
    final provider = context.read<ShoppingListProvider>();
    _updateFilteredItems(provider.favoriteProducts);
  }

  Future<void> _addToInventory(Product product) async {
    if (!mounted || _processingItems.contains(product.id)) return;
    
    setState(() {
      _processingItems.add(product.id);
    });

    try {
      final provider = context.read<ShoppingListProvider>();
      final result = await provider.addFavoriteToInventory(product);
      
      if (mounted) {
        _showSnackBar(
          result 
            ? '${product.name} añadido al inventario'
            : 'Error al añadir al inventario',
          result ? AppTheme.successGreen : AppTheme.errorRed,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al añadir al inventario', AppTheme.errorRed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingItems.remove(product.id);
        });
      }
    }
  }

  Future<void> _addToShoppingList(Product product) async {
    if (!mounted || _processingItems.contains('shopping_${product.id}')) return;
    
    setState(() {
      _processingItems.add('shopping_${product.id}');
    });

    try {
      final provider = context.read<ShoppingListProvider>();
      
      final shoppingItem = ShoppingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: product.name,
        quantity: 1,
        unit: product.unit,
        category: product.category,
        isPurchased: false,
      );
      
      await provider.addItem(shoppingItem);
      
      if (mounted) {
        _showSnackBar(
          '${product.name} añadido a la lista de compras', 
          AppTheme.successGreen,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al añadir a la lista de compras', AppTheme.errorRed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingItems.remove('shopping_${product.id}');
        });
      }
    }
  }

  Future<void> _removeFromFavorites(Product product) async {
    if (!mounted || _processingItems.contains('remove_${product.id}')) return;
    
    // Mostrar diálogo de confirmación
    final confirmed = await _showDeleteConfirmationDialog(product.name);
    if (!confirmed) return;
    
    setState(() {
      _processingItems.add('remove_${product.id}');
    });

    try {
      final provider = context.read<ShoppingListProvider>();
      final result = await provider.removeFromFavorites(product.id);
      
      if (mounted) {
        if (result) {
          _showSnackBar(
            '${product.name} eliminado de favoritos',
            AppTheme.successGreen,
          );
          
          // Actualizar filtros inmediatamente para UI responsiva
          _updateFilteredItems(provider.favoriteProducts);
        } else {
          _showSnackBar('Error al eliminar de favoritos', AppTheme.errorRed);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al eliminar de favoritos', AppTheme.errorRed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingItems.remove('remove_${product.id}');
        });
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog(String productName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar favorito'),
        content: Text('¿Estás seguro de eliminar "$productName" de tus favoritos?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.mediumGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        margin: const EdgeInsets.all(AppTheme.spacingMedium),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    
    try {
      final provider = context.read<ShoppingListProvider>();
      await provider.loadFavorites();
      
      if (mounted) {
        _updateFilteredItems(provider.favoriteProducts);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al actualizar datos', AppTheme.errorRed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Productos Favoritos',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Consumer<ShoppingListProvider>(
        builder: (context, provider, child) {
          // Estado de carga inicial
          if (!_hasInitialized || provider.isFavoritesLoading) {
            return const Center(
              child: LoadingIndicator(message: 'Cargando favoritos...'),
            );
          }

          // Estado de error
          if (provider.error?.isNotEmpty == true) {
            return _buildErrorState(provider.error!);
          }

          // Actualizar filtros cuando cambien los favoritos
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateFilteredItems(provider.favoriteProducts);
            }
          });

          // Estado vacío
          if (provider.favoriteProducts.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              _buildSearchBar(),
              _buildFavoritesList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: AppTheme.errorRed,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            Text(
              'Error al cargar favoritos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.mediumGrey,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.favorite_border_rounded,
      title: 'No tienes favoritos',
      message: 'Añade productos a tus favoritos desde el inventario para acceder a ellos rápidamente.',
      buttonText: 'Ir al inventario',
      onButtonPressed: () {
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar favoritos...',
          hintStyle: const TextStyle(color: AppTheme.mediumGrey),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.coralMain),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, color: AppTheme.mediumGrey),
                onPressed: _clearSearch,
              )
            : null,
          filled: true,
          fillColor: AppTheme.pureWhite,
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingMedium,
            horizontal: AppTheme.spacingLarge,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            borderSide: const BorderSide(color: AppTheme.coralMain, width: 2),
          ),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildFavoritesList() {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.coralMain,
        child: _filteredItems.isEmpty
          ? _buildNoResultsState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
                vertical: AppTheme.spacingSmall,
              ),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final product = _filteredItems[index];
                final isProcessingAny = _processingItems.contains(product.id) ||
                                       _processingItems.contains('shopping_${product.id}') ||
                                       _processingItems.contains('remove_${product.id}');
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
                  child: FavoriteProductCard(
                    key: ValueKey(product.id),
                    product: product,
                    isProcessing: isProcessingAny,
                    onAddToInventory: () => _addToInventory(product),
                    onAddToShoppingList: () => _addToShoppingList(product),
                    onRemoveFromFavorites: () => _removeFromFavorites(product),
                  ),
                );
              },
            ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              decoration: BoxDecoration(
                color: AppTheme.peachLight.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 60,
                color: AppTheme.coralMain,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            Text(
              'No se encontraron favoritos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              _searchQuery.isEmpty 
                ? 'No tienes productos favoritos aún'
                : 'Prueba con otros términos de búsqueda',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.mediumGrey,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            if (_searchQuery.isNotEmpty)
              TextButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Limpiar búsqueda'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.coralMain,
                ),
              ),
          ],
        ),
      ),
    );
  }
}