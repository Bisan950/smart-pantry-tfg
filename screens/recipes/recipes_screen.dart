import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/recipe_model.dart';
import '../../services/recipe_service.dart';
import '../../widgets/common/bottom_navigation.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/custom_search_bar.dart';
import '../../widgets/recipes/recipe_card.dart';
import '../recipes/recipe_detail_screen.dart';
import '../recipes/ai_recipe_generator_screen.dart';
import 'manual_recipe_creation_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen>
    with TickerProviderStateMixin {
  final RecipeService _recipeService = RecipeService();
  
  // Estado de carga
  bool _isLoading = false;
  String _error = '';
  
  // Estado para búsqueda y filtrado
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Todas';
  String _selectedDifficulty = 'Todas';
  String _selectedTime = 'Todas';
  
  // Recetas y categorías
  List<Recipe> _recipes = [];
  final List<String> _categories = [
    'Todas', 'Saludable', 'Rápidas', 'Vegetarianas', 
    'Postres', 'Carnes', 'Pescados', 'Ensaladas'
  ];
  final List<String> _difficulties = ['Todas', 'Fácil', 'Intermedio', 'Difícil'];
  final List<String> _timeFilters = ['Todas', '< 15min', '15-30min', '30-60min', '> 1h'];
  
  // Índice de navegación
  int _currentNavIndex = 4;

  // Animaciones
  late AnimationController _animationController;
  late AnimationController _headerAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Control de scroll para efectos
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderCollapsed = false;

  // Lista de items para la navegación inferior
  final List<BottomNavigationItem> _navItems = [
    BottomNavigationItem(label: 'Inicio', icon: Icons.home_rounded),
    BottomNavigationItem(label: 'Inventario', icon: Icons.inventory_2_rounded),
    BottomNavigationItem(label: 'Plan Comidas', icon: Icons.calendar_today_rounded),
    BottomNavigationItem(label: 'Compras', icon: Icons.shopping_cart_rounded),
    BottomNavigationItem(label: 'Recetas', icon: Icons.restaurant_menu_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupScrollListener();
    _loadRecipes();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!mounted) return;
      
      // Aumentamos el umbral para que se colapse más tarde (coherente con dashboard)
      final shouldCollapse = _scrollController.offset > 80;
      if (shouldCollapse != _isHeaderCollapsed) {
        setState(() => _isHeaderCollapsed = shouldCollapse);
        
        if (shouldCollapse) {
          _headerAnimationController.forward();
        } else {
          _headerAnimationController.reverse();
        }
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

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final recipes = await _recipeService.getAllRecipes();
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    try {
      final confirm = await _showDeleteConfirmationDialog(recipe);
      if (confirm == true) {
        setState(() => _isLoading = true);
        final result = await _recipeService.deleteRecipe(recipe.id);
        
        if (result && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Receta "${recipe.name}" eliminada correctamente'),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          await _loadRecipes();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar la receta: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(Recipe recipe) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange),
            const SizedBox(width: 16),
            const Text('Eliminar receta'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${recipe.name}"? Esta acción no se puede deshacer.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.darkGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  List<Recipe> _getFilteredRecipes() {
    return _recipes.where((recipe) {
      // Filtro de búsqueda
      final matchesSearch = _searchQuery.isEmpty ||
          recipe.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          recipe.description.toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Filtro de categoría
      final matchesCategory = _selectedCategory == 'Todas' ||
          recipe.hasCategory(_selectedCategory);
      
      // Filtro de dificultad
      final matchesDifficulty = _selectedDifficulty == 'Todas' ||
          recipe.difficultyDisplayName == _selectedDifficulty;
      
      // Filtro de tiempo
      bool matchesTime = _selectedTime == 'Todas';
      if (!matchesTime) {
        switch (_selectedTime) {
          case '< 15min':
            matchesTime = recipe.totalTime < 15;
            break;
          case '15-30min':
            matchesTime = recipe.totalTime >= 15 && recipe.totalTime <= 30;
            break;
          case '30-60min':
            matchesTime = recipe.totalTime > 30 && recipe.totalTime <= 60;
            break;
          case '> 1h':
            matchesTime = recipe.totalTime > 60;
            break;
        }
      }
      
      return matchesSearch && matchesCategory && matchesDifficulty && matchesTime;
    }).toList();
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

  void _navigateToRecipeDetail(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(
          recipeId: recipe.id,
          recipe: recipe,
          showAddToMealPlanButton: true,
        ),
      ),
    ).then((_) => _loadRecipes());
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = _getFilteredRecipes();
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: _isLoading 
        ? const Center(child: LoadingIndicator())
        : _error.isNotEmpty
          ? _buildErrorState()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: RefreshIndicator(
                  color: AppTheme.coralMain,
                  backgroundColor: AppTheme.pureWhite,
                  strokeWidth: 2,
                  onRefresh: _loadRecipes,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      _buildExpandedAppBar(),
                      _buildCrispContent(filteredRecipes),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        items: _navItems,
        showLabels: false,
      ),
    );
  }

  // APLICANDO PRINCIPIO 1: HEADER COMPACTO (80-100px max)
  Widget _buildExpandedAppBar() {
    return SliverAppBar(
      expandedHeight: 100, // COMPACTO: Reducido de 220 a 100px
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.coralMain,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: _isHeaderCollapsed ? _buildCollapsedTitle() : null,
      actions: _isHeaderCollapsed ? _buildCollapsedActions() : null,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildExpandedHeaderContent(),
        collapseMode: CollapseMode.parallax,
      ),
      bottom: _buildExpandedAppBarBottom(),
    );
  }

  Widget _buildCollapsedTitle() {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1), // PRINCIPIO 2: Siempre Border.all()
          ),
          child: Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text('Recetas', 
            style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.w700, 
              fontSize: 18,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCollapsedActions() {
    return [
      _buildHeaderButton(
        icon: Icons.auto_awesome_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AIRecipeGeneratorScreen()),
        ).then((_) => _loadRecipes()),
        size: 32,
      ),
      const SizedBox(width: 8),
      _buildHeaderButton(
        icon: Icons.tune_rounded,
        onTap: _showAdvancedFilters,
        size: 32,
      ),
      const SizedBox(width: 12),
    ];
  }

  PreferredSize _buildExpandedAppBarBottom() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(20),
      child: Container(
        height: 20,
        decoration: BoxDecoration(
          color: AppTheme.backgroundGrey,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Center(
          child: Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.mediumGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
      ),
    );
  }

  // APLICANDO PRINCIPIO 1: INFORMACIÓN CRÍTICA ARRIBA
  Widget _buildExpandedHeaderContent() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.coralMain,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // COMPACTO: Padding reducido
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo/Título compacto
              Row(
                children: [
                  Container(
                    width: 32, // Reducido
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1), // PRINCIPIO 2
                    ),
                    child: Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Recetas', 
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 20, // Reducido
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          height: 1.0,
                        )),
                      Text('${_recipes.length} disponibles', 
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8), 
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        )),
                    ],
                  ),
                ],
              ),
              // Acciones compactas
              Row(
                children: [
                  _buildHeaderButton(
                    icon: Icons.auto_awesome_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AIRecipeGeneratorScreen()),
                    ).then((_) => _loadRecipes()),
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderButton(
                    icon: Icons.tune_rounded,
                    onTap: _showAdvancedFilters,
                    size: 32,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    double? size,
  }) {
    final buttonSize = size ?? 32.0;
    final iconSize = buttonSize * 0.5;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1), // PRINCIPIO 2
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: iconSize)),
      ),
    );
  }

  // APLICANDO PRINCIPIO 2: DISEÑO NÍTIDO Y PRINCIPIO 3: APROVECHAMIENTO DEL ESPACIO
  Widget _buildCrispContent(List<Recipe> filteredRecipes) {
    return SliverPadding(
      padding: const EdgeInsets.all(20), // PRINCIPIO 3: Padding consistente
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Stats principales compactos
          _buildCrispMainStats(),
          const SizedBox(height: 20),
          
          // Búsqueda compacta
          _buildCrispSearchBar(),
          const SizedBox(height: 16),
          
          // Filtros rápidos en row
          _buildCrispQuickFilters(),
          const SizedBox(height: 20),
          
          // Acciones rápidas en grid 2x2
          _buildCrispQuickActions(),
          const SizedBox(height: 20),
          
          // Lista de recetas
          filteredRecipes.isEmpty 
            ? _buildEmptyState() 
            : _buildCrispRecipesList(filteredRecipes),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  // APLICANDO PRINCIPIO 3: ROW EN LUGAR DE LISTAS VERTICALES
  Widget _buildCrispMainStats() {
    final totalRecipes = _recipes.length;
    final favoriteRecipes = _recipes.where((r) => r.isFavorite).length;
    final avgTime = totalRecipes > 0 
        ? (_recipes.map((r) => r.totalTime).reduce((a, b) => a + b) / totalRecipes).round()
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02), // PRINCIPIO 2: Sombras sutiles
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16), // PRINCIPIO 3: Padding interno consistente
        child: Row(
          children: [
            Expanded(child: _buildCrispStatItem(
              title: 'Total', 
              value: '$totalRecipes', 
              icon: Icons.restaurant_menu_rounded, 
              color: AppTheme.coralMain)),
            Container(width: 1, height: 40, color: AppTheme.lightGrey.withOpacity(0.5)),
            Expanded(child: _buildCrispStatItem(
              title: 'Favoritas', 
              value: '$favoriteRecipes', 
              icon: Icons.favorite_rounded, 
              color: AppTheme.errorRed)),
            Container(width: 1, height: 40, color: AppTheme.lightGrey.withOpacity(0.5)),
            Expanded(child: _buildCrispStatItem(
              title: 'Promedio', 
              value: '${avgTime}min', 
              icon: Icons.timer_rounded, 
              color: AppTheme.successGreen)),
          ],
        ),
      ),
    );
  }

  Widget _buildCrispStatItem({
    required String title, 
    required String value, 
    required IconData icon, 
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 28, // PRINCIPIO 5: Tamaño mínimo optimizado
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.2), width: 1), // PRINCIPIO 2
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 6),
        Text(value, 
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w800, 
            color: color,
            height: 1.0,
          )),
        const SizedBox(height: 2),
        Text(title, 
          style: TextStyle(
            fontSize: 10, 
            color: AppTheme.darkGrey,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
          textAlign: TextAlign.center),
      ],
    );
  }

  // APLICANDO PRINCIPIO 4: ELEMENTOS ESENCIALES
  Widget _buildCrispSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Buscar recetas...',
          hintStyle: TextStyle(color: AppTheme.mediumGrey, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.coralMain, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: AppTheme.mediumGrey, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // APLICANDO PRINCIPIO 3: ROW HORIZONTAL COMPACTO
  Widget _buildCrispQuickFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCrispFilterChip('Categoría', _selectedCategory, Icons.category_rounded),
          const SizedBox(width: 8),
          _buildCrispFilterChip('Dificultad', _selectedDifficulty, Icons.trending_up_rounded),
          const SizedBox(width: 8),
          _buildCrispFilterChip('Tiempo', _selectedTime, Icons.timer_rounded),
        ],
      ),
    );
  }

  Widget _buildCrispFilterChip(String label, String selectedValue, IconData icon) {
    final isFiltered = selectedValue != 'Todas';
    
    return GestureDetector(
      onTap: () => _showFilterOptions(label, selectedValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isFiltered ? AppTheme.coralMain : AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFiltered ? AppTheme.coralMain : AppTheme.lightGrey.withOpacity(0.5),
            width: 1,
          ), // PRINCIPIO 2
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isFiltered ? AppTheme.pureWhite : AppTheme.darkGrey,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              isFiltered ? selectedValue : label,
              style: TextStyle(
                color: isFiltered ? AppTheme.pureWhite : AppTheme.darkGrey,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // APLICANDO PRINCIPIO 3: GRID 2x2 EN LUGAR DE LISTA VERTICAL
  Widget _buildCrispQuickActions() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Acciones rápidas', 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w700, 
                color: AppTheme.darkGrey,
                height: 1.0,
              )),
            const SizedBox(height: 12),
            // GRID 2x2 COMPACTO
            Row(
              children: [
                Expanded(child: _buildCrispActionCard(
                  title: 'Crear', 
                  icon: Icons.add_circle_rounded,
                  color: AppTheme.coralMain,
                  onTap: () => Navigator.pushNamed(context, Routes.manualRecipeCreation).then((_) => _loadRecipes()))),
                const SizedBox(width: 8),
                Expanded(child: _buildCrispActionCard(
                  title: 'Chef IA', 
                  icon: Icons.psychology_rounded,
                  color: AppTheme.softTeal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AIRecipeGeneratorScreen()),
                  ).then((_) => _loadRecipes()))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrispActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 1), // PRINCIPIO 2
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Container(
                width: 28, // PRINCIPIO 5: Tamaño mínimo
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.2), width: 1), // PRINCIPIO 2
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(height: 6),
              Text(title, 
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.w600, 
                  color: AppTheme.darkGrey,
                  height: 1.0,
                ),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // APLICANDO PRINCIPIO 2: DISEÑO NÍTIDO CON GRID COMPACTO
  Widget _buildCrispRecipesList(List<Recipe> recipes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recetas (${recipes.length})', 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w700, 
                color: AppTheme.darkGrey,
                height: 1.0,
              )),
            if (recipes.length > 6)
              GestureDetector(
                onTap: () {
                  // Mostrar vista completa
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.coralMain.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.coralMain.withOpacity(0.2), width: 1), // PRINCIPIO 2
                  ),
                  child: Text('Ver todas', 
                    style: TextStyle(
                      color: AppTheme.coralMain, 
                      fontWeight: FontWeight.w600, 
                      fontSize: 11,
                    )),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCrispRecipesGrid(recipes),
      ],
    );
  }

  // GRID COMPACTO Y NÍTIDO
  Widget _buildCrispRecipesGrid(List<Recipe> recipes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75, // CORREGIDO: Más altura para evitar corte de texto
        crossAxisSpacing: 10, // PRINCIPIO 3: Espaciado consistente
        mainAxisSpacing: 10,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _buildCrispRecipeCard(recipe, index);
      },
    );
  }

  // APLICANDO TODOS LOS PRINCIPIOS: TARJETA NÍTIDA Y FUNCIONAL
  Widget _buildCrispRecipeCard(Recipe recipe, int index) {
    final colors = [
      AppTheme.coralMain,
      AppTheme.softTeal,
      AppTheme.successGreen,
      AppTheme.yellowAccent,
    ];
    final cardColor = colors[index % colors.length];

    return GestureDetector(
      onTap: () => _navigateToRecipeDetail(recipe),
      onLongPress: () => _showRecipeOptions(recipe),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02), // PRINCIPIO 2: Sombras sutiles
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGEN COMPACTA - PRINCIPIO 4: ESENCIAL
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border.all(color: cardColor.withOpacity(0.2), width: 1), // PRINCIPIO 2
                ),
                child: Stack(
                  children: [
                    // Imagen o placeholder
                    if (recipe.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                        child: Image.network(
                          recipe.imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildImagePlaceholder(cardColor),
                        ),
                      )
                    else
                      _buildImagePlaceholder(cardColor),
                    
                    // PRINCIPIO 4: INFO ESENCIAL - Tiempo
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_rounded, color: AppTheme.pureWhite, size: 10),
                            SizedBox(width: 2),
                            Text(
                              recipe.formattedTime,
                              style: TextStyle(
                                color: AppTheme.pureWhite,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // PRINCIPIO 5: Botón favorito con tamaño mínimo
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => _toggleFavorite(recipe),
                        child: Container(
                          width: 28, // PRINCIPIO 5: Tamaño mínimo
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            recipe.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: recipe.isFavorite ? AppTheme.errorRed : AppTheme.pureWhite,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // INFORMACIÓN COMPACTA - PRINCIPIO 1: INFO CRÍTICA
            Expanded(
              flex: 3, // CORREGIDO: Aumentado de 2 a 3 para más espacio al texto
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12), // PRINCIPIO 3: Padding interno consistente
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // CORREGIDO: Distribución equilibrada
                  children: [
                    // Nombre - PRINCIPIO 4: ESENCIAL
                    Flexible( // CORREGIDO: Cambiado de Expanded a Flexible
                      child: Text(
                        recipe.name,
                        style: TextStyle(
                          fontSize: 12, // CORREGIDO: Reducido de 13 a 12 para mejor fit
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGrey,
                          height: 1.2, // CORREGIDO: Altura de línea optimizada
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 8), // CORREGIDO: Más espacio
                    
                    // Info footer - PRINCIPIO 3: ROW HORIZONTAL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dificultad
                        Flexible( // CORREGIDO: Añadido Flexible para evitar overflow
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getDifficultyColor(recipe.difficulty).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getDifficultyColor(recipe.difficulty).withOpacity(0.3), 
                                width: 1
                              ), // PRINCIPIO 2
                            ),
                            child: Text(
                              recipe.difficultyDisplayName,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: _getDifficultyColor(recipe.difficulty),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 4), // CORREGIDO: Espacio entre elementos
                        
                        // Porciones
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_alt_rounded, size: 11, color: AppTheme.mediumGrey),
                            SizedBox(width: 2),
                            Text(
                              '${recipe.servings}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.mediumGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(11),
          topRight: Radius.circular(11),
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 24,
          color: color.withOpacity(0.6),
        ),
      ),
    );
  }

  Color _getDifficultyColor(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return AppTheme.successGreen;
      case DifficultyLevel.medium:
        return AppTheme.warningOrange;
      case DifficultyLevel.hard:
        return AppTheme.errorRed;
    }
  }

  void _toggleFavorite(Recipe recipe) async {
    try {
      final updatedRecipe = recipe.toggleFavorite();
      
      setState(() {
        final index = _recipes.indexWhere((r) => r.id == recipe.id);
        if (index != -1) {
          _recipes[index] = updatedRecipe;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedRecipe.isFavorite 
                ? 'Receta añadida a favoritas' 
                : 'Receta eliminada de favoritas'
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar favoritos'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRecipeOptions(Recipe recipe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20), // PRINCIPIO 3: Padding consistente
        decoration: BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            SizedBox(height: 20),
            
            _buildOptionTile(
              icon: Icons.visibility_rounded,
              title: 'Ver receta',
              onTap: () {
                Navigator.pop(context);
                _navigateToRecipeDetail(recipe);
              },
            ),
            
            _buildOptionTile(
              icon: recipe.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              title: recipe.isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite(recipe);
              },
            ),
            
            _buildOptionTile(
              icon: Icons.edit_rounded,
              title: 'Editar receta',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context, 
                  Routes.manualRecipeCreation,
                  arguments: recipe,
                ).then((_) => _loadRecipes());
              },
            ),
            
            _buildOptionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Eliminar receta',
              color: AppTheme.errorRed,
              onTap: () {
                Navigator.pop(context);
                _deleteRecipe(recipe);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        width: 32, // PRINCIPIO 5: Tamaño mínimo
        height: 32,
        decoration: BoxDecoration(
          color: (color ?? AppTheme.darkGrey).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: (color ?? AppTheme.darkGrey).withOpacity(0.2), width: 1), // PRINCIPIO 2
        ),
        child: Icon(icon, color: color ?? AppTheme.darkGrey, size: 16),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? AppTheme.darkGrey,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _showFilterOptions(String filterType, String currentValue) {
    List<String> options = [];
    switch (filterType) {
      case 'Categoría':
        options = _categories;
        break;
      case 'Dificultad':
        options = _difficulties;
        break;
      case 'Tiempo':
        options = _timeFilters;
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtrar por $filterType',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGrey,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...options.map((option) => ListTile(
              title: Text(option, style: TextStyle(fontSize: 14)),
              trailing: currentValue == option 
                  ? Icon(Icons.check_rounded, color: AppTheme.coralMain, size: 18)
                  : null,
              onTap: () {
                setState(() {
                  switch (filterType) {
                    case 'Categoría':
                      _selectedCategory = option;
                      break;
                    case 'Dificultad':
                      _selectedDifficulty = option;
                      break;
                    case 'Tiempo':
                      _selectedTime = option;
                      break;
                  }
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtros avanzados',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGrey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
                        ),
                        child: Text(
                          'Filtros avanzados próximamente...',
                          style: TextStyle(
                            color: AppTheme.mediumGrey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty || _selectedCategory != 'Todas' || 
        _selectedDifficulty != 'Todas' || _selectedTime != 'Todas') {
      return Container(
        padding: EdgeInsets.all(32), // PRINCIPIO 3: Padding consistente
        decoration: BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.mediumGrey.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.mediumGrey.withOpacity(0.2), width: 1), // PRINCIPIO 2
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 32,
                color: AppTheme.mediumGrey,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'No se encontraron recetas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGrey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Prueba ajustando los filtros',
              style: TextStyle(
                color: AppTheme.mediumGrey,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _selectedCategory = 'Todas';
                  _selectedDifficulty = 'Todas';
                  _selectedTime = 'Todas';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralMain,
                foregroundColor: AppTheme.pureWhite,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Limpiar filtros', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.coralMain.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.coralMain.withOpacity(0.2), width: 1), // PRINCIPIO 2
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 32,
              color: AppTheme.coralMain,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '¡Crea tu primera receta!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGrey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Empieza tu aventura culinaria',
            style: TextStyle(
              color: AppTheme.mediumGrey,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          // PRINCIPIO 3: ROW EN LUGAR DE COLUMNA
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.manualRecipeCreation).then((_) => _loadRecipes()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.coralMain,
                    foregroundColor: AppTheme.pureWhite,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Crear', style: TextStyle(fontSize: 13)),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AIRecipeGeneratorScreen()),
                  ).then((_) => _loadRecipes()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.coralMain,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: AppTheme.coralMain),
                  ),
                  child: Text('Chef IA', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorRed.withOpacity(0.3), width: 1), // PRINCIPIO 2
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.errorRed.withOpacity(0.2), width: 1), // PRINCIPIO 2
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppTheme.errorRed,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Error al cargar recetas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGrey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _error,
              style: TextStyle(
                color: AppTheme.mediumGrey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRecipes,
              icon: Icon(Icons.refresh_rounded, size: 16),
              label: Text('Reintentar', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: AppTheme.pureWhite,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}