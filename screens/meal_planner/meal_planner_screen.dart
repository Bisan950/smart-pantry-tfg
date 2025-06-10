import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/meal_plan_model.dart';
import '../../models/meal_type_model.dart';
import '../../services/meal_plan_service.dart';
import '../../widgets/common/bottom_navigation.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/meal_planner/meal_plan_card.dart';
import '../recipes/recipe_detail_screen.dart';
import '../../models/recipe_model.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen>
    with TickerProviderStateMixin {
  final MealPlanService _mealPlanService = MealPlanService();
  
  late DateTime _selectedDate;
  String _selectedMealTypeId = 'breakfast';
  late List<MealPlan> _mealPlans;
  bool _isLoading = false;
  
  // Animaciones optimizadas
  late AnimationController _animationController;
  late AnimationController _headerAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Control de scroll para efectos
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderCollapsed = false;
  
  final List<MealType> _mealTypes = MealType.getPredefinedTypes();
  int _currentNavIndex = 2;

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
    _selectedDate = DateTime.now();
    _mealPlans = [];
    _setupAnimations();
    _setupScrollListener();
    _loadMealPlans();
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
    _animationController.dispose();
    _headerAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMealPlans() async {
    setState(() => _isLoading = true);
    
    try {
      final plans = await _mealPlanService.getMealPlansForDate(_selectedDate);
      setState(() => _mealPlans = plans);
    } catch (e) {
      _loadMockData();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onNavTap(int index) {
    if (_currentNavIndex == index) return;
    
    setState(() => _currentNavIndex = index);
    HapticFeedback.selectionClick();
    
    switch (index) {
      case 0: Navigator.pushNamedAndRemoveUntil(context, Routes.dashboard, (route) => false); break;
      case 1: Navigator.pushNamedAndRemoveUntil(context, Routes.inventory, (route) => false); break;
      case 2: break;
      case 3: Navigator.pushNamedAndRemoveUntil(context, Routes.shoppingList, (route) => false); break;
      case 4: Navigator.pushNamedAndRemoveUntil(context, Routes.recipes, (route) => false); break;
    }
  }

  void _loadMockData() {
    final today = DateTime.now();
    
    _mealPlans = [
      MealPlan(
        id: '1',
        date: today,
        mealTypeId: 'breakfast',
        recipeId: '101',
        recipe: Recipe(
          id: '101',
          name: 'Tostadas con aguacate',
          description: 'Tostadas con aguacate fresco, huevo y tomate.',
          imageUrl: 'https://example.com/avocado-toast.jpg',
          cookingTime: 15,
          servings: 2,
          difficulty: DifficultyLevel.easy,
          categories: ['saludable', 'vegano'],
          ingredients: [
            Ingredient(name: 'Pan integral', quantity: 2, unit: 'rebanadas', isAvailable: true),
            Ingredient(name: 'Aguacate', quantity: 1, unit: 'unidad', isAvailable: true),
            Ingredient(name: 'Huevo', quantity: 2, unit: 'unidades', isAvailable: true),
            Ingredient(name: 'Tomate', quantity: 1, unit: 'unidad', isAvailable: false),
          ],
          steps: [
            'Tostar el pan.',
            'Machacar el aguacate y esparcir sobre el pan.',
            'Freír los huevos y colocar sobre el aguacate.',
            'Decorar con rodajas de tomate.',
          ],
          calories: 350,
          nutrition: {
            'protein': 12,
            'carbs': 30,
            'fat': 20,
            'fiber': 8,
            'sugar': 5,
            'sodium': 120,
          },
        ),
        isCompleted: false,
      ),
    ];
  }

  List<MealPlan> _getMealsForSelectedDate() {
    return _mealPlans.where((meal) => 
      DateUtils.isSameDay(meal.date, _selectedDate)
    ).toList();
  }

  String _formatDateShort(DateTime date) {
    final weekdayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final monthNames = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    
    final weekday = (date.weekday - 1) % 7;
    final month = date.month - 1;
    
    return '${weekdayNames[weekday]} ${date.day} ${monthNames[month]}';
  }

  String _getDayShortName(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate.isAtSameMomentAs(today)) {
      return 'Hoy';
    } else if (targetDate.isAtSameMomentAs(tomorrow)) {
      return 'Mañ';
    } else {
      final shortWeekdayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final weekday = (date.weekday - 1) % 7;
      return shortWeekdayNames[weekday];
    }
  }

  void _navigateToRecipes() async {
    Navigator.pushNamed(context, Routes.recipes).then((_) => _loadMealPlans());
  }

  Future<void> _removeMealPlan(MealPlan mealPlan) async {
    try {
      final success = await _mealPlanService.deleteMealPlan(mealPlan.id);
      
      if (success) {
        _loadMealPlans();
        final recipeName = mealPlan.recipe?.name ?? 'Comida';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$recipeName eliminado de tu plan'),
            backgroundColor: AppTheme.coralMain,
            action: SnackBarAction(
              label: 'Deshacer',
              textColor: AppTheme.pureWhite,
              onPressed: () {
                _mealPlanService.addMealPlan(mealPlan);
                _loadMealPlans();
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar la comida: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _toggleMealCompleted(MealPlan mealPlan, bool isCompleted) async {
    try {
      final success = await _mealPlanService.toggleMealPlanCompleted(
        mealPlan.id, 
        isCompleted
      );
      
      if (success) {
        _loadMealPlans();
        final recipeName = mealPlan.recipe?.name ?? 'Comida';
        final message = isCompleted 
            ? '$recipeName marcada como completada'
            : '$recipeName marcada como pendiente';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isCompleted ? AppTheme.successGreen : AppTheme.darkGrey,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar el estado: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundGrey,
        body: const Center(child: LoadingIndicator()),
        bottomNavigationBar: BottomNavigation(
          currentIndex: _currentNavIndex,
          onTap: _onNavTap,
          items: _navItems,
          showLabels: false,
        ),
      );
    }

    final mealsForSelectedDate = _getMealsForSelectedDate();
    final mealsByType = MealPlan.groupByMealType(mealsForSelectedDate);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            color: AppTheme.softTeal,
            backgroundColor: AppTheme.pureWhite,
            strokeWidth: 2,
            onRefresh: () async => await _loadMealPlans(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildCrispAppBar(),
                _buildCrispContent(mealsForSelectedDate, mealsByType),
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

  Widget _buildCrispAppBar() {
    final mealsForSelectedDate = _getMealsForSelectedDate();
    final plannedMeals = mealsForSelectedDate.length;
    final completedMeals = mealsForSelectedDate.where((meal) => meal.isCompleted).length;
    
    return SliverAppBar(
      expandedHeight: 100, // Reducido significativamente
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.softTeal,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: _isHeaderCollapsed ? _buildCollapsedTitle(plannedMeals, completedMeals) : null,
      actions: _isHeaderCollapsed ? _buildCollapsedActions() : null,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildExpandedHeaderContent(),
        collapseMode: CollapseMode.parallax,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(16),
        child: Container(
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.backgroundGrey,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Center(
            child: Container(
              width: 28,
              height: 2,
              decoration: BoxDecoration(
                color: AppTheme.mediumGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedTitle(int plannedMeals, int completedMeals) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text('Planificador', 
            style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.w700, 
              fontSize: 18,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (plannedMeals > 0) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$completedMeals/$plannedMeals',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildCollapsedActions() {
    return [
      _buildHeaderButton(
        icon: Icons.calendar_today_rounded,
        onTap: () {},
        size: 32,
      ),
      const SizedBox(width: 8),
      _buildHeaderButton(
        icon: Icons.add_rounded,
        onTap: _navigateToRecipes,
        size: 32,
      ),
      const SizedBox(width: 12),
    ];
  }

  Widget _buildExpandedHeaderContent() {
    return Container(
      color: AppTheme.softTeal,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo/Título expandido
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text('Planificador de Comidas', 
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Acciones expandidas
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeaderButton(
                    icon: Icons.calendar_today_rounded,
                    onTap: () {},
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  _buildHeaderButton(
                    icon: Icons.add_rounded,
                    onTap: _navigateToRecipes,
                    size: 36,
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
    final buttonSize = size ?? 36.0;
    final iconSize = size != null ? size * 0.45 : 16.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: iconSize)),
      ),
    );
  }

  Widget _buildCrispContent(List<MealPlan> mealsForSelectedDate, Map<String, List<MealPlan>> mealsByType) {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Selector de fecha y stats en una fila compacta
          _buildCrispDateAndStats(mealsForSelectedDate),
          const SizedBox(height: 20),
          
          // Acciones rápidas
          _buildCrispQuickActions(),
          const SizedBox(height: 20),
          
          // Comidas planificadas
          _buildCrispMealsSection(mealsByType),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _buildCrispDateAndStats(List<MealPlan> mealsForDate) {
    final plannedMeals = mealsForDate.length;
    final completedMeals = mealsForDate.where((meal) => meal.isCompleted).length;
    final totalCalories = mealsForDate.fold<int>(
      0, 
      (sum, meal) => sum + (meal.recipe?.calories ?? 0)
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Selector de fecha
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Selecciona un día', 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w700, 
                    color: AppTheme.darkGrey,
                  )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.softTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.softTeal.withOpacity(0.2)),
                  ),
                  child: Text(
                    _formatDateShort(_selectedDate),
                    style: TextStyle(
                      color: AppTheme.softTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Días horizontales compactos
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));
                  final isSelected = DateUtils.isSameDay(date, _selectedDate);
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = date);
                      _loadMealPlans();
                    },
                    child: Container(
                      width: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.softTeal : AppTheme.backgroundGrey,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.softTeal : AppTheme.lightGrey.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getDayShortName(date),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppTheme.pureWhite : AppTheme.mediumGrey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.pureWhite : AppTheme.darkGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Stats en fila
            Row(
              children: [
                Expanded(child: _buildCrispStatItem(
                  title: 'Planificadas', 
                  value: '$plannedMeals', 
                  icon: Icons.restaurant_rounded, 
                  color: AppTheme.softTeal)),
                Container(width: 1, height: 40, color: AppTheme.lightGrey.withOpacity(0.5)),
                Expanded(child: _buildCrispStatItem(
                  title: 'Completadas', 
                  value: '$completedMeals', 
                  icon: Icons.check_circle_rounded, 
                  color: AppTheme.successGreen)),
                Container(width: 1, height: 40, color: AppTheme.lightGrey.withOpacity(0.5)),
                Expanded(child: _buildCrispStatItem(
                  title: 'Calorías', 
                  value: '$totalCalories', 
                  icon: Icons.local_fire_department_rounded, 
                  color: AppTheme.warningOrange)),
              ],
            ),
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
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

  Widget _buildCrispQuickActions() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
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
              )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildCrispActionCard(
                  title: 'Añadir comida', 
                  icon: Icons.add_circle_rounded,
                  color: AppTheme.softTeal,
                  onTap: _navigateToRecipes)),
                const SizedBox(width: 12),
                Expanded(child: _buildCrispActionCard(
                  title: 'Ver recetas', 
                  icon: Icons.restaurant_menu_rounded,
                  color: AppTheme.coralMain,
                  onTap: () => Navigator.pushNamed(context, Routes.recipes))),
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
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(title, 
                style: TextStyle(
                  fontSize: 12, 
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

  Widget _buildCrispMealsSection(Map<String, List<MealPlan>> mealsByType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comidas planificadas', 
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w700, 
            color: AppTheme.darkGrey,
          )),
        const SizedBox(height: 16),
        
        // Lista vertical por tipo de comida como antes
        ..._mealTypes.map((mealType) {
          final mealsForType = mealsByType[mealType.id] ?? [];
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de la sección de comida
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.pureWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.softTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          mealType.icon,
                          color: AppTheme.softTeal,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mealType.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ),
                      if (mealsForType.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.mediumGrey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.mediumGrey.withOpacity(0.2)),
                          ),
                          child: Text(
                            'Sin planificar',
                            style: TextStyle(
                              color: AppTheme.mediumGrey,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.successGreen.withOpacity(0.2)),
                          ),
                          child: Text(
                            '${mealsForType.length} ${mealsForType.length == 1 ? 'comida' : 'comidas'}',
                            style: TextStyle(
                              color: AppTheme.successGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Contenido de las comidas - siempre centrado
              if (mealsForType.isNotEmpty)
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      children: mealsForType.map((meal) => 
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: MealPlanCard(
                            mealPlan: meal,
                            onTap: () {
                              if (meal.recipe != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RecipeDetailScreen(
                                      recipeId: meal.recipeId,
                                      recipe: meal.recipe,
                                    ),
                                  ),
                                );
                              }
                            },
                            onDelete: () => _removeMealPlan(meal),
                            onCompleteToggle: (isCompleted) => _toggleMealCompleted(meal, isCompleted),
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                )
              else
                Center(child: _buildCrispEmptyMealCard(mealType)),
              
              const SizedBox(height: 20),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildCrispEmptyMealCard(MealType mealType) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softTeal.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.softTeal.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedMealTypeId = mealType.id);
            _navigateToRecipes();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.softTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.softTeal.withOpacity(0.2)),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: AppTheme.softTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Añadir ${mealType.name.toLowerCase()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.softTeal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Explora recetas y añade una comida a tu plan',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}