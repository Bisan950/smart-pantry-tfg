import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shopping_list_preferences_model.dart';
import '../../providers/shopping_list_preferences_provider.dart';
import '../../config/theme.dart';
import '../../models/product_model.dart';

class CustomizableCartWidget extends StatefulWidget {
  final Product? product;
  final String name;
  final String category;
  final DateTime? expiryDate;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onCartAction;
  final bool isInCart;
  final bool isFavorite;
  
  const CustomizableCartWidget({
    Key? key,
    this.product,
    required this.name,
    required this.category,
    this.expiryDate,
    this.onTap,
    this.onFavoriteToggle,
    this.onCartAction,
    this.isInCart = false,
    this.isFavorite = false,
  }) : super(key: key);

  @override
  State<CustomizableCartWidget> createState() => _CustomizableCartWidgetState();
}

class _CustomizableCartWidgetState extends State<CustomizableCartWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _favoriteController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _favoriteAnimation;
  
  bool _isPressed = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _favoriteController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _favoriteAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _favoriteController,
      curve: Curves.elasticOut,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _favoriteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShoppingListPreferencesProvider>(
      builder: (context, prefsProvider, child) {
        final prefs = prefsProvider.preferences;
        
        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: _buildCard(context, prefs),
            );
          },
        );
      },
    );
  }
  
  Widget _buildCard(BuildContext context, ShoppingListPreferences prefs) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: prefs.compactMode ? 8 : 12,
        vertical: prefs.compactMode ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _getCardBackgroundColor(prefs),
        borderRadius: BorderRadius.circular(prefs.cardBorderRadius),
        boxShadow: prefs.enableAnimations ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: prefs.cardElevation * 2,
            offset: Offset(0, prefs.cardElevation),
          ),
        ] : null,
        border: _getCardBorder(prefs),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(prefs.cardBorderRadius),
          onTap: _handleTap,
          onTapDown: prefs.enableAnimations ? _onTapDown : null,
          onTapUp: prefs.enableAnimations ? _onTapUp : null,
          onTapCancel: prefs.enableAnimations ? _onTapCancel : null,
          child: Padding(
            padding: EdgeInsets.all(prefs.compactMode ? 12 : 16),
            child: prefs.compactMode ? _buildCompactLayout(prefs) : _buildFullLayout(prefs),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFullLayout(ShoppingListPreferences prefs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con imagen y acciones
        Row(
          children: [
            if (prefs.showProductImages) ..[
              _buildProductImage(prefs),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: prefs.compactMode ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (prefs.showItemDetails) ..[
                    const SizedBox(height: 4),
                    _buildCategoryChip(prefs),
                  ],
                ],
              ),
            ),
            if (prefs.enableQuickActions) _buildQuickActions(prefs),
          ],
        ),
        
        if (prefs.showItemDetails && widget.expiryDate != null) ..[
          const SizedBox(height: 12),
          _buildExpiryInfo(prefs),
        ],
        
        if (prefs.enableQuickActions) ..[
          const SizedBox(height: 12),
          _buildActionButtons(prefs),
        ],
      ],
    );
  }
  
  Widget _buildCompactLayout(ShoppingListPreferences prefs) {
    return Row(
      children: [
        if (prefs.showProductImages) ..[
          _buildProductImage(prefs, size: 32),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGrey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (prefs.showItemDetails)
                Text(
                  widget.category,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
            ],
          ),
        ),
        if (prefs.enableQuickActions) _buildQuickActions(prefs, compact: true),
      ],
    );
  }
  
  Widget _buildProductImage(ShoppingListPreferences prefs, {double? size}) {
    final imageSize = size ?? (prefs.compactMode ? 40 : 48);
    
    return Container(
      width: imageSize,
      height: imageSize,
      decoration: BoxDecoration(
        color: _getCategoryColor(widget.category).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getCategoryColor(widget.category).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          _getCategoryEmoji(widget.category),
          style: TextStyle(fontSize: imageSize * 0.5),
        ),
      ),
    );
  }
  
  Widget _buildCategoryChip(ShoppingListPreferences prefs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getCategoryColor(widget.category).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getCategoryColor(widget.category).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        widget.category,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _getCategoryColor(widget.category),
        ),
      ),
    );
  }
  
  Widget _buildQuickActions(ShoppingListPreferences prefs, {bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón de favorito
        AnimatedBuilder(
          animation: _favoriteAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _favoriteAnimation.value,
              child: IconButton(
                icon: Icon(
                  widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: widget.isFavorite ? AppTheme.coralMain : AppTheme.mediumGrey,
                  size: compact ? 18 : 20,
                ),
                onPressed: _handleFavoriteToggle,
                padding: EdgeInsets.all(compact ? 4 : 8),
                constraints: BoxConstraints(
                  minWidth: compact ? 32 : 40,
                  minHeight: compact ? 32 : 40,
                ),
              ),
            );
          },
        ),
        
        // Botón de carrito
        IconButton(
          icon: Icon(
            widget.isInCart ? Icons.remove_shopping_cart : Icons.add_shopping_cart,
            color: widget.isInCart ? AppTheme.warningOrange : AppTheme.successGreen,
            size: compact ? 18 : 20,
          ),
          onPressed: _handleCartAction,
          padding: EdgeInsets.all(compact ? 4 : 8),
          constraints: BoxConstraints(
            minWidth: compact ? 32 : 40,
            minHeight: compact ? 32 : 40,
          ),
        ),
      ],
    );
  }
  
  Widget _buildExpiryInfo(ShoppingListPreferences prefs) {
    if (widget.expiryDate == null) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final daysUntilExpiry = widget.expiryDate!.difference(now).inDays;
    final statusColor = _getStatusColor();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            daysUntilExpiry < 0 ? Icons.warning : Icons.schedule,
            size: 12,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            daysUntilExpiry < 0 
                ? 'Expirado'
                : daysUntilExpiry == 0
                    ? 'Expira hoy'
                    : 'Expira en $daysUntilExpiry días',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(ShoppingListPreferences prefs) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: widget.isInCart ? Icons.remove_shopping_cart : Icons.add_shopping_cart,
            label: widget.isInCart ? 'Quitar' : 'Añadir',
            color: widget.isInCart ? AppTheme.warningOrange : AppTheme.successGreen,
            onTap: _handleCartAction,
            prefs: prefs,
          ),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.more_vert,
          label: 'Más',
          color: AppTheme.softTeal,
          onTap: _showMoreOptions,
          prefs: prefs,
          isSecondary: true,
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required ShoppingListPreferences prefs,
    bool isSecondary = false,
  }) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isSecondary ? color.withOpacity(0.1) : color,
        borderRadius: BorderRadius.circular(8),
        border: isSecondary ? Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSecondary ? color : Colors.white,
                ),
                if (!isSecondary) ..[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Métodos de manejo de eventos
  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }
  
  void _handleFavoriteToggle() {
    _favoriteController.forward().then((_) {
      _favoriteController.reverse();
    });
    
    if (widget.onFavoriteToggle != null) {
      widget.onFavoriteToggle!();
    }
  }
  
  void _handleCartAction() {
    if (widget.onCartAction != null) {
      widget.onCartAction!();
    }
  }
  
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMoreOptionsSheet(),
    );
  }
  
  Widget _buildMoreOptionsSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 20),
          
          // Título
          Text(
            'Opciones para ${widget.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Opciones
          _buildOptionTile(
            icon: Icons.edit,
            title: 'Editar producto',
            subtitle: 'Modificar información',
            onTap: () {
              Navigator.pop(context);
              // Implementar edición
            },
          ),
          _buildOptionTile(
            icon: Icons.share,
            title: 'Compartir',
            subtitle: 'Enviar a otros usuarios',
            onTap: () {
              Navigator.pop(context);
              // Implementar compartir
            },
          ),
          _buildOptionTile(
            icon: Icons.delete_outline,
            title: 'Eliminar',
            subtitle: 'Quitar del inventario',
            color: AppTheme.errorRed,
            onTap: () {
              Navigator.pop(context);
              // Implementar eliminación
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final tileColor = color ?? AppTheme.softTeal;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tileColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tileColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tileColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: tileColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
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
                Icon(Icons.chevron_right, color: tileColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Métodos de animación
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
      _handleTap();
    }
  }
  
  void _onTapCancel() {
    if (_isPressed) {
      _controller.reverse();
      setState(() => _isPressed = false);
    }
  }
  
  // Métodos de utilidad
  Color _getCardBackgroundColor(ShoppingListPreferences prefs) {
    switch (prefs.backgroundStyle) {
      case 'gradient':
        return Colors.white;
      case 'colored':
        return _getCategoryColor(widget.category).withOpacity(0.05);
      default:
        return Colors.white;
    }
  }
  
  Border? _getCardBorder(ShoppingListPreferences prefs) {
    if (prefs.backgroundStyle == 'outlined') {
      return Border.all(
        color: _getCategoryColor(widget.category).withOpacity(0.3),
        width: 1,
      );
    }
    return null;
  }
  
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
}