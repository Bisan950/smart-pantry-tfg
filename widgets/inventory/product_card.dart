// lib/widgets/inventory/product_card.dart
// Versión corregida compatible con servicios existentes

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../models/product_location_model.dart';
import '../../services/inventory_service.dart';
import '../../services/shopping_list_service.dart';
import '../../providers/shopping_list_provider.dart';

class ProductCard extends StatefulWidget {
  final String name;
  final String quantity;
  final String unit;
  final int maxQuantity;
  final DateTime? expiryDate;
  final String category;
  final String location;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Product? product;
  final bool showLocationBadge;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onCartAction;

  const ProductCard({
    super.key,
    required this.name,
    required this.quantity,
    required this.unit,
    this.maxQuantity = 0,
    this.expiryDate,
    required this.category,
    required this.location,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.product,
    this.showLocationBadge = true,
    this.onFavoriteToggle,
    this.onCartAction,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _favoriteAnimation;
  bool _isPressed = false;
  bool _isFavorite = false;
  bool _isInCart = false;
  
  final InventoryService _inventoryService = InventoryService();
  final ShoppingListService _shoppingListService = ShoppingListService();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeStates();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _favoriteAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  void _initializeStates() {
  if (widget.product != null) {
    _isFavorite = widget.product!.isFavorite;
    // Verificar si está en el carrito basándose en ProductLocation
    _isInCart = widget.product!.productLocation == ProductLocation.both ||
               widget.product!.productLocation == ProductLocation.shoppingList;
  }
}

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Gestos táctiles optimizados
  void _onTapDown(TapDownDetails details) {
    if (!_isPressed) {
      _controller.forward();
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_isPressed) {
      _controller.reverse();
      setState(() => _isPressed = false);
      widget.onTap();
    }
  }

  void _onTapCancel() {
    if (_isPressed) {
      _controller.reverse();
      setState(() => _isPressed = false);
    }
  }

  // Toggle favoritos con animación
Future<void> _toggleFavorite() async {
  if (widget.product == null) return;
  
  // Haptic feedback
  HapticFeedback.lightImpact();
  
  // Animación inmediata para feedback visual
  _controller.forward().then((_) => _controller.reverse());
  
  try {
    final newFavoriteStatus = !_isFavorite;
    
    // Actualizar UI inmediatamente
    setState(() => _isFavorite = newFavoriteStatus);
    
    if (newFavoriteStatus) {
      // AÑADIR A FAVORITOS: Usar ShoppingListService
      final success = await _shoppingListService.addProductToFavorites(widget.product!);
      if (success) {
        // También actualizar el producto en inventario
        final updatedProduct = widget.product!.copyWith(isFavorite: true);
        await _inventoryService.updateProduct(updatedProduct);
        _showSnackBar('Añadido a favoritos ❤️', AppTheme.coralMain, Icons.favorite);
      } else {
        // Revertir si falla
        setState(() => _isFavorite = false);
        _showSnackBar('Error al añadir a favoritos', AppTheme.errorRed, Icons.error_outline);
        return;
      }
    } else {
      // QUITAR DE FAVORITOS: Necesitamos obtener el ID del favorito y eliminarlo
      // Primero actualizar el producto en inventario
      final updatedProduct = widget.product!.copyWith(isFavorite: false);
      await _inventoryService.updateProduct(updatedProduct);
      
      // Buscar y eliminar de favoritos por nombre (ya que no tenemos el favoriteId)
      final favoriteProducts = await _shoppingListService.getFavoriteProducts();
      final favoriteToRemove = favoriteProducts.firstWhere(
        (fav) => fav.name == widget.product!.name,
        orElse: () => throw Exception('Favorito no encontrado'),
      );
      
      await _shoppingListService.removeFromFavorites(favoriteToRemove.id);
      _showSnackBar('Quitado de favoritos', AppTheme.mediumGrey, Icons.favorite_border);
    }
    
    widget.onFavoriteToggle?.call();
  } catch (e) {
    // Revertir cambio si hay error
    setState(() => _isFavorite = !_isFavorite);
    _showSnackBar('Error: $e', AppTheme.errorRed, Icons.error_outline);
  }
}
  // Acción rápida del carrito
Future<void> _quickCartAction() async {
  if (widget.product == null) return;
  
  HapticFeedback.mediumImpact();
  
  try {
    if (_isInCart) {
      await _removeFromCart();
    } else {
      await _addToCart();
    }
  } catch (e) {
    _showSnackBar('Error: $e', AppTheme.errorRed, Icons.error_outline);
  }
}

 // Añadir al carrito
Future<void> _addToCart([int? customQuantity]) async {
  if (widget.product == null) return;
  
  try {
    // Crear ShoppingItem desde el producto
    final shoppingItem = ShoppingItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: widget.product!.name,
      quantity: customQuantity ?? 1,
      maxQuantity: widget.product!.maxQuantity,
      unit: widget.product!.unit,
      category: widget.product!.category,
      location: widget.product!.location,
      imageUrl: widget.product!.imageUrl,
      expiryDate: widget.product!.expiryDate,
      isPurchased: false,
      isSuggested: false,
    );
    
    // Usar ShoppingListService para añadir al carrito
    final shoppingListService = ShoppingListService();
    final result = await shoppingListService.addShoppingItem(shoppingItem);
    final success = result != null; // Convert String? to bool
    
    if (success) {
      // Actualizar el producto para que esté en ambos lugares
      final updatedProduct = widget.product!.copyWith(
        productLocation: ProductLocation.both
      );
      
      await _inventoryService.updateProduct(updatedProduct);
      
      setState(() => _isInCart = true);
      _showSnackBar('Añadido al carrito 🛒', AppTheme.successGreen, Icons.shopping_cart);
      
      widget.onCartAction?.call();
    } else {
      _showSnackBar('Error al añadir al carrito', AppTheme.errorRed, Icons.error_outline);
    }
  } catch (e) {
    print('❌ Error en _addToCart: $e');
    _showSnackBar('Error al añadir al carrito: $e', AppTheme.errorRed, Icons.error_outline);
  }
}

  // Quitar del carrito
Future<void> _removeFromCart() async {
  if (widget.product == null) return;
  
  try {
    final shoppingListService = ShoppingListService();
    
    // Buscar el item en la lista de compras por nombre
    final shoppingItems = await shoppingListService.getShoppingItems();
    final matchingItem = shoppingItems.firstWhere(
      (item) => item.name.toLowerCase() == widget.product!.name.toLowerCase(),
      orElse: () => ShoppingItem(
        id: '',
        name: '',
        quantity: 0,
        unit: '',
        category: '',
      ),
    );
    
    if (matchingItem.id.isNotEmpty) {
      // Eliminar de la lista de compras
      await shoppingListService.removeShoppingItem(matchingItem.id);
    }
    
    // Actualizar el producto para que solo esté en inventario
    final updatedProduct = widget.product!.copyWith(
      productLocation: ProductLocation.inventory
    );
    
    await _inventoryService.updateProduct(updatedProduct);
    
    setState(() => _isInCart = false);
    _showSnackBar('Quitado del carrito', AppTheme.warningOrange, Icons.remove_shopping_cart);
    
    widget.onCartAction?.call();
  } catch (e) {
    print('❌ Error en _removeFromCart: $e');
    _showSnackBar('Error al quitar del carrito: $e', AppTheme.errorRed, Icons.error_outline);
  }
}

  // Mostrar opciones de carrito con long press
  void _showCartOptions() {
    HapticFeedback.heavyImpact();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCartOptionsSheet(),
    );
  }

  // Sheet de opciones del carrito
  Widget _buildCartOptionsSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
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
              SizedBox(height: 20),
              
              // Título
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.softTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.shopping_cart, color: AppTheme.softTeal),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Opciones de Carrito',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.mediumGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              // Opciones
              if (!_isInCart) ...[
                _buildCartOptionButton(
                  icon: Icons.add_shopping_cart,
                  title: 'Añadir al carrito',
                  subtitle: 'Mover a lista de compras',
                  color: AppTheme.successGreen,
                  onTap: () {
                    Navigator.pop(context);
                    _addToCart();
                  },
                ),
              ] else ...[
                _buildCartOptionButton(
                  icon: Icons.remove_shopping_cart,
                  title: 'Quitar del carrito',
                  subtitle: 'Remover de la lista de compras',
                  color: AppTheme.warningOrange,
                  onTap: () {
                    Navigator.pop(context);
                    _removeFromCart();
                  },
                ),
              ],
              
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartOptionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.mediumGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Métodos de utilidad existentes
  Color _getStatusColor() {
    final now = DateTime.now();
    final daysUntilExpiry = widget.expiryDate?.difference(now).inDays;
    
    if (daysUntilExpiry != null && daysUntilExpiry < 0) {
      return AppTheme.errorRed;
    } else if (widget.product?.hasCriticalStock() ?? false) {
      return AppTheme.errorRed;
    } else if ((daysUntilExpiry != null && daysUntilExpiry <= 3) || 
               (widget.product?.hasLowStock() ?? false)) {
      return AppTheme.warningOrange;
    } else {
      return AppTheme.successGreen;
    }
  }
  
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'lácteos': return const Color(0xFF64B5F6);
      case 'frutas': return const Color(0xFF81C784);
      case 'verduras': return const Color(0xFF4CAF50);
      case 'carnes': return const Color(0xFFEF9A9A);
      case 'pescados': return const Color(0xFF90CAF9);
      case 'granos': return const Color(0xFFFFCC80);
      case 'bebidas': return const Color(0xFF80DEEA);
      case 'snacks': return const Color(0xFFFFF59D);
      case 'congelados': return const Color(0xFF90CAF9);
      case 'panadería': return const Color(0xFFBCAAA4);
      case 'cereales': return const Color(0xFFFFCC80);
      case 'condimentos': return const Color(0xFFFFAB91);
      case 'conservas': return const Color(0xFFFF8A65);
      case 'dulces': return const Color(0xFFF48FB1);
      default: return AppTheme.softTeal;
    }
  }
  
  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'lácteos': return '🥛';
      case 'frutas': return '🍎';
      case 'verduras': return '🥦';
      case 'carnes': return '🥩';
      case 'pescados': return '🐟';
      case 'granos': return '🌾';
      case 'bebidas': return '🧃';
      case 'snacks': return '🍪';
      case 'congelados': return '❄️';
      case 'panadería': return '🍞';
      case 'cereales': return '🥣';
      case 'condimentos': return '🧂';
      case 'conservas': return '🥫';
      case 'dulces': return '🍬';
      default: return '📦';
    }
  }
  
  String _getLocationEmoji(String location) {
    switch (location.toLowerCase()) {
      case 'nevera': return '🧊';
      case 'congelador': return '❄️';
      case 'despensa': return '🗄️';
      case 'armario': return '🚪';
      case 'especias': return '🧂';
      default: return '📍';
    }
  }
  
  String _getExpiryText() {
    final now = DateTime.now();
    final days = widget.expiryDate?.difference(now).inDays;
    
    if (days == null) return '';
    
    if (days < 0) {
      return 'Caducado';
    } else if (days == 0) {
      return 'Hoy';
    } else if (days == 1) {
      return 'Mañana';
    } else if (days <= 7) {
      return '$days días';
    } else {
      return '${widget.expiryDate!.day}/${widget.expiryDate!.month}';
    }
  }

  void _showPopupMenu(BuildContext context) {
  final RenderBox button = context.findRenderObject() as RenderBox;
  final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );

  showMenu<String>(
    context: context,
    position: position,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 8,
    items: [
      _buildPopupMenuItem('edit', Icons.edit_outlined, 'Editar', AppTheme.coralMain),
      _buildPopupMenuItem('delete', Icons.delete_outline, 'Eliminar', AppTheme.errorRed),
      if (widget.product != null && !_isInCart)
        _buildPopupMenuItem('addToCart', Icons.shopping_cart_outlined, 'Añadir al carrito', AppTheme.softTeal),
      if (widget.product != null && _isInCart)
        _buildPopupMenuItem('removeFromCart', Icons.remove_shopping_cart_outlined, 'Quitar del carrito', AppTheme.warningOrange),
    ],
  ).then<void>((String? value) async {
    if (value == null) return;
    
    switch (value) {
      case 'edit':
        widget.onEdit();
        break;
      case 'delete':
        _confirmDelete(context);
        break;
      case 'addToCart':
        await _addToCart();
        break;
      case 'removeFromCart':
        await _removeFromCart();
        break;
    }
  });
}

  PopupMenuItem<String> _buildPopupMenuItem(String value, IconData icon, String text, Color color) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 12),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar producto?'),
        content: Text('¿Estás seguro de que quieres eliminar "${widget.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
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

  void _showSnackBar(String message, Color color, IconData icon) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        duration: Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
  
  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDarkMode = theme.brightness == Brightness.dark;
  
  final now = DateTime.now();
  final daysUntilExpiry = widget.expiryDate?.difference(now).inDays;
  final bool isExpired = daysUntilExpiry != null && daysUntilExpiry < 0;
  final bool isWarning = daysUntilExpiry != null && daysUntilExpiry <= 3 && daysUntilExpiry >= 0;
  final bool hasCriticalStock = widget.product?.hasCriticalStock() ?? false;
  final bool hasLowStock = widget.product?.hasLowStock() ?? false;
  
  int quantityValue = widget.product?.quantity ?? int.tryParse(widget.quantity.split(' ')[0]) ?? 0;
  final double percentRemaining = widget.maxQuantity > 0
      ? (quantityValue / widget.maxQuantity).clamp(0.0, 1.0)
      : 1.0;
  
  final statusColor = _getStatusColor();
  final bool hasWarning = isExpired || isWarning || hasCriticalStock || hasLowStock;
  final categoryColor = _getCategoryColor(widget.category);
  final categoryEmoji = _getCategoryEmoji(widget.category);

  return AnimatedBuilder(
    animation: _scaleAnimation,
    builder: (context, child) {
      return Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      );
    },
    child: GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: hasWarning 
              ? Border.all(color: statusColor.withOpacity(0.5), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: hasWarning ? 8 : 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Contenido principal
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila superior: Icono, Info, Botones de acción
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icono de categoría
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(categoryEmoji, style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      
                      SizedBox(width: 10),
                      
                      // Información del producto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            
                            // Cantidad y ubicación en líneas separadas
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Primera línea: Cantidad
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${widget.quantity} ${widget.unit}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: hasCriticalStock || hasLowStock ? FontWeight.bold : FontWeight.normal,
                                          color: hasCriticalStock ? AppTheme.errorRed : 
                                                 hasLowStock ? AppTheme.warningOrange : 
                                                 theme.textTheme.bodyMedium?.color,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                    if (widget.maxQuantity > 0) ...[
                                      Text(' / ${widget.maxQuantity}', 
                                        style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color)),
                                    ],
                                  ],
                                ),
                                
                                SizedBox(height: 2),
                                
                                // Segunda línea: Ubicación
                                Row(
                                  children: [
                                    Text(_getLocationEmoji(widget.location), style: TextStyle(fontSize: 12)),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        widget.location, 
                                        style: TextStyle(
                                          fontSize: 12, 
                                          color: theme.textTheme.bodySmall?.color
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Botones de acción rápida
                      Container(
                        width: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botón de favoritos
                            AnimatedBuilder(
                              animation: _favoriteAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _favoriteAnimation.value,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: _toggleFavorite,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: _isFavorite 
                                              ? AppTheme.coralMain.withOpacity(0.1)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                                          color: _isFavorite ? AppTheme.coralMain : AppTheme.mediumGrey,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            SizedBox(width: 2),
                            
                            // Botón de carrito con long press
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _quickCartAction,
                                onLongPress: _showCartOptions,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _isInCart 
                                        ? AppTheme.successGreen.withOpacity(0.1)
                                        : AppTheme.softTeal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    _isInCart ? Icons.shopping_cart : Icons.add_shopping_cart,
                                    color: _isInCart ? AppTheme.successGreen : AppTheme.softTeal,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            
                            SizedBox(width: 2),
                            
                            // Menú contextual
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showPopupMenu(context),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.more_horiz,
                                    color: AppTheme.mediumGrey,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Barra de progreso si hay máximo
                  if (widget.maxQuantity > 0) ...[
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: percentRemaining,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: percentRemaining <= 0.25 
                                        ? AppTheme.errorRed
                                        : percentRemaining <= 0.5
                                            ? AppTheme.warningOrange
                                            : AppTheme.successGreen,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${(percentRemaining * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Información de caducidad
                  if (daysUntilExpiry != null) ...[
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isExpired ? AppTheme.errorRed : 
                               isWarning ? AppTheme.warningOrange : 
                               AppTheme.successGreen).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isExpired ? AppTheme.errorRed : 
                                 isWarning ? AppTheme.warningOrange : 
                                 AppTheme.successGreen).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isExpired ? Icons.error_outline : 
                            isWarning ? Icons.access_time : 
                            Icons.event_available_outlined,
                            size: 14,
                            color: isExpired ? AppTheme.errorRed : 
                                   isWarning ? AppTheme.warningOrange : 
                                   AppTheme.successGreen,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _getExpiryText(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isExpired || isWarning ? FontWeight.bold : FontWeight.w500,
                              color: isExpired ? AppTheme.errorRed : 
                                     isWarning ? AppTheme.warningOrange : 
                                     AppTheme.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Badge de ubicación
            if (widget.product != null && widget.showLocationBadge && 
                widget.product!.productLocation == ProductLocation.both) ...[
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.softTeal,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.softTeal.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.sync_alt,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            
            // Badge de favorito
            if (_isFavorite) ...[
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.coralMain,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.coralMain.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.favorite,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            
            // Badge de carrito
            if (_isInCart) ...[
              Positioned(
                top: _isFavorite ? 32 : 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successGreen.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.shopping_cart,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            
            // Overlay de interacción visual
            if (_isPressed) ...[
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.coralMain.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
}