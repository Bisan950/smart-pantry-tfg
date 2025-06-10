// lib/widgets/common/avatar_selector.dart - Versión sin overflow
import 'package:flutter/material.dart';
import '../../models/avatar_model.dart';
import '../../services/avatar_service.dart';

/// Widget para seleccionar un avatar de la lista disponible
class AvatarSelector extends StatefulWidget {
  final String? selectedAvatarId;
  final Function(AvatarModel) onAvatarSelected;
  final bool showCategories;
  final bool showSearch;
  final EdgeInsets padding;

  const AvatarSelector({
    super.key,
    this.selectedAvatarId,
    required this.onAvatarSelected,
    this.showCategories = true,
    this.showSearch = true,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector> {
  final AvatarService _avatarService = AvatarService();
  
  List<AvatarModel> _allAvatars = [];
  List<AvatarModel> _filteredAvatars = [];
  List<String> _categories = [];
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  bool _isLoading = true;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAvatars();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatars() async {
    try {
      setState(() => _isLoading = true);
      
      final avatars = await _avatarService.getAllAvatars();
      final categories = await _avatarService.getCategories();
      
      setState(() {
        _allAvatars = avatars;
        _filteredAvatars = avatars;
        _categories = ['Todos', ...categories];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar avatares: $e')),
        );
      }
    }
  }

  void _filterAvatars() {
    List<AvatarModel> filtered = _allAvatars;

    // Filtrar por categoría
    if (_selectedCategory != 'Todos') {
      filtered = filtered.where((avatar) => avatar.category == _selectedCategory).toList();
    }

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((avatar) => 
        avatar.name.toLowerCase().contains(query) ||
        avatar.category.toLowerCase().contains(query)
      ).toList();
    }

    setState(() {
      _filteredAvatars = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterAvatars();
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterAvatars();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando avatares...'),
          ],
        ),
      );
    }

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título - Usar FittedBox para evitar overflow
          FittedBox(
            child: Text(
              'Selecciona tu avatar',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Barra de búsqueda - Usar Flexible en lugar de Container width
          if (widget.showSearch) ...[
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar avatares...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                isDense: true, // Hacer el campo más compacto
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Filtros por categoría - Usar SizedBox con altura fija
          if (widget.showCategories && _categories.isNotEmpty) ...[
            SizedBox(
              height: 36, // Altura fija para evitar overflow
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  
                  return FilterChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => _onCategoryChanged(category),
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    selectedColor: Theme.of(context).primaryColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Lista de avatares - Usar Expanded para llenar el espacio restante
          Expanded(
            child: _filteredAvatars.isEmpty
                ? _buildEmptyState()
                : _buildAvatarGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No se encontraron avatares'
                : 'No hay avatares disponibles',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'Intenta con otros términos de búsqueda'
                  : 'Verifica la configuración de avatares',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_allAvatars.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAvatars,
              child: const Text('Recargar avatares'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarGrid() {
    // Usar LayoutBuilder para determinar el número de columnas según el ancho
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular columnas dinámicamente
        final crossAxisCount = _calculateCrossAxisCount(constraints.maxWidth);
        final itemSize = (constraints.maxWidth - (widget.padding.horizontal + (crossAxisCount - 1) * 12)) / crossAxisCount;
        
        return GridView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: _filteredAvatars.length,
          itemBuilder: (context, index) {
            final avatar = _filteredAvatars[index];
            final isSelected = avatar.id == widget.selectedAvatarId;
            
            return _buildAvatarItem(avatar, isSelected, itemSize);
          },
        );
      },
    );
  }

  int _calculateCrossAxisCount(double width) {
    // Determinar número de columnas según el ancho disponible
    if (width < 300) return 3;
    if (width < 400) return 4;
    if (width < 600) return 5;
    return 6;
  }

  Widget _buildAvatarItem(AvatarModel avatar, bool isSelected, double size) {
    return GestureDetector(
      onTap: () => widget.onAvatarSelected(avatar),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.white,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagen del avatar
              Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  avatar.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant,
                          color: Colors.grey[400],
                          size: size * 0.3,
                        ),
                        const SizedBox(height: 2),
                        Flexible(
                          child: Text(
                            avatar.name,
                            style: TextStyle(
                              fontSize: size * 0.12,
                              color: Colors.grey[400],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              
              // Indicador de selección
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: size * 0.2,
                    height: size * 0.2,
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                      maxWidth: 24,
                      maxHeight: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: size * 0.12,
                    ),
                  ),
                ),
              
              // Indicador premium
              if (avatar.isPremium)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    width: size * 0.2,
                    height: size * 0.2,
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                      maxWidth: 24,
                      maxHeight: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(size * 0.1),
                    ),
                    child: Icon(
                      Icons.star,
                      color: Colors.white,
                      size: size * 0.12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget simple para mostrar un avatar (para usar en otros lugares de la app)
class AvatarDisplay extends StatelessWidget {
  final String? avatarId;
  final String? photoUrl;
  final String fallbackText;
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AvatarDisplay({
    super.key,
    this.avatarId,
    this.photoUrl,
    this.fallbackText = 'U',
    this.size = 48,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(
                  color: borderColor ?? Theme.of(context).primaryColor,
                  width: 2,
                )
              : null,
          boxShadow: showBorder
              ? [
                  BoxShadow(
                    color: (borderColor ?? Theme.of(context).primaryColor)
                        .withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: _buildAvatarContent(),
        ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    // Prioridad: avatarId > photoUrl > fallback
    if (avatarId != null && avatarId!.isNotEmpty) {
      return FutureBuilder<AvatarModel?>(
        future: AvatarService().getAvatarById(avatarId!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Container(
              color: Colors.white, // NUEVO: Fondo blanco para avatares
              child: Padding(
                padding: EdgeInsets.all(size * 0.1),
                child: Image.asset(
                  snapshot.data!.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => _buildFallback(context),
                ),
              ),
            );
          }
          return _buildFallback(context);
        },
      );
    }
    
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return Builder(
        builder: (context) => Container(
          color: Colors.white, // NUEVO: Fondo blanco para fotos
          child: Image.network(
            photoUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(context),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildFallback(context);
            },
          ),
        ),
      );
    }
    
    return Builder(
      builder: (context) => _buildFallback(context),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      color: Colors.white, // CAMBIO: Fondo blanco en lugar del color primario
      child: Center(
        child: Text(
          fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Theme.of(context).primaryColor, // CAMBIO: Texto en color primario
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}