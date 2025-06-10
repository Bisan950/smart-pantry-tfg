// lib/screens/dashboard/dashboard_screen.dart - VERSIÓN CON HEADER AMPLIADO

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/shopping_list_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/bottom_navigation.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/avatar_selector.dart';
import '../../models/product_model.dart';
import '../../models/product_location_model.dart';
import '../../utils/category_helpers.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  int _currentNavIndex = 0;
  late AnimationController _animationController;
  late AnimationController _headerAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ScrollController _scrollController = ScrollController();
  bool _isHeaderCollapsed = false;
  
  // Cache optimizado
  Map<String, dynamic>? _cachedStats;
  Timer? _cacheRefreshTimer;
  
  // Control de estados
  bool _isInitialized = false;
  bool _isRefreshing = false;

  // Items de navegación
  static List<BottomNavigationItem> _navItems = [
    BottomNavigationItem(label: 'Inicio', icon: Icons.home_rounded),
    BottomNavigationItem(label: 'Inventario', icon: Icons.inventory_2_rounded),
    BottomNavigationItem(label: 'Planificador', icon: Icons.calendar_today_rounded),
    BottomNavigationItem(label: 'Compras', icon: Icons.shopping_cart_rounded),
    BottomNavigationItem(label: 'Recetas', icon: Icons.restaurant_menu_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupScrollListener();
    _initializeData();
  }

  void _initializeData() {
    if (_isInitialized) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataWithTimeout();
    });
  }

  Future<void> _loadDataWithTimeout() async {
    if (!mounted || _isInitialized) return;
    
    try {
      setState(() => _isRefreshing = true);
      
      await Future.wait([
        _loadInventoryData(),
        _loadShoppingData(),
      ]).timeout(const Duration(seconds: 8));
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isRefreshing = false;
        });
        _animationController.forward();
        _startCacheRefreshTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadInventoryData() async {
    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    if (!inventoryProvider.isLoading && inventoryProvider.allProducts.isEmpty) {
      await inventoryProvider.refreshData();
    }
  }

  Future<void> _loadShoppingData() async {
    final shoppingProvider = Provider.of<ShoppingListProvider>(context, listen: false);
    if (!shoppingProvider.isLoading && shoppingProvider.getItemCount() == 0) {
      await shoppingProvider.refreshData();
    }
  }

  void _startCacheRefreshTimer() {
    _cacheRefreshTimer?.cancel();
    _cacheRefreshTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (mounted) _cachedStats = null;
    });
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
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!mounted) return;
      
      // Aumentamos el umbral para que se colapse más tarde
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
    _cacheRefreshTimer?.cancel();
    _animationController.dispose();
    _headerAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (_currentNavIndex == index) return;
    
    setState(() => _currentNavIndex = index);
    
    switch (index) {
      case 0: break;
      case 1: Navigator.pushNamed(context, Routes.inventory); break;
      case 2: Navigator.pushNamed(context, Routes.mealPlanner); break;
      case 3: Navigator.pushNamed(context, Routes.shoppingList); break;
      case 4: Navigator.pushNamed(context, Routes.recipes); break;
    }
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    _cachedStats = null;
    
    try {
      final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
      final shoppingProvider = Provider.of<ShoppingListProvider>(context, listen: false);
      
      await Future.wait([
        inventoryProvider.refreshData(),
        shoppingProvider.refreshData(),
      ]).timeout(const Duration(seconds: 6));
      
    } catch (e) {
      // Error silencioso para mejor UX
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (!_isInitialized) {
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

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: _buildBody(),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        items: _navItems,
        showLabels: false,
      ),
    );
  }

  Widget _buildBody() {
    return Consumer3<InventoryProvider, ShoppingListProvider, AuthProvider>(
      builder: (context, inventoryProvider, shoppingProvider, authProvider, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              color: AppTheme.coralMain,
              backgroundColor: AppTheme.pureWhite,
              strokeWidth: 2,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildExpandedAppBar(authProvider.user),
                  _buildCrispContent(inventoryProvider, shoppingProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandedAppBar(dynamic user) {
    return SliverAppBar(
      expandedHeight: 160, // Aumentado de 100 a 160
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.coralMain,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: _isHeaderCollapsed ? _buildCollapsedTitle() : null,
      actions: _isHeaderCollapsed ? _buildCollapsedActions() : null,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildExpandedHeaderContent(user),
        collapseMode: CollapseMode.parallax,
      ),
      bottom: _buildExpandedAppBarBottom(),
    );
  }

  Widget _buildCollapsedTitle() {
    return Row(
      children: [
        Container(
          width: 26, // Ajustado para mejor fit
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.home_rounded, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text('Smart Pantry', 
            style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.w700, 
              fontSize: 18, // Ajustado para mejor fit
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
      _buildExpandedHeaderButton(
        icon: Icons.search_rounded,
        onTap: () => Navigator.pushNamed(context, Routes.inventory),
        size: 32, // Tamaño reducido para estado colapsado
      ),
      const SizedBox(width: 8),
      _buildExpandedHeaderButton(
        icon: Icons.notifications_rounded,
        hasBadge: true,
        onTap: () {},
        size: 32,
      ),
      const SizedBox(width: 12),
    ];
  }

  PreferredSize _buildExpandedAppBarBottom() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(20), // Aumentado de 16 a 20
      child: Container(
        height: 20,
        decoration: BoxDecoration(
          color: AppTheme.backgroundGrey,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20), // Aumentado de 16 a 20
            topRight: Radius.circular(20),
          ),
        ),
        child: Center(
          child: Container(
            width: 36, // Aumentado de 28 a 36
            height: 3, // Aumentado de 2 a 3
            decoration: BoxDecoration(
              color: AppTheme.mediumGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedHeaderContent(dynamic user) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.coralMain,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Reducido padding
          child: Column(
            children: [
              // Fila principal con logo y acciones
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo/Título expandido - con flex para controlar overflow
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          width: 40, // Reducido de 44 a 40
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10), // Reducido de 12 a 10
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                          ),
                          child: Icon(Icons.home_rounded, color: Colors.white, size: 22), // Reducido de 24 a 22
                        ),
                        const SizedBox(width: 12), // Reducido de 16 a 12
                        Flexible(
                          child: Text('Smart Pantry', 
                            style: TextStyle(
                              color: Colors.white, 
                              fontSize: 24, // Reducido de 28 a 24
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Acciones expandidas - con espaciado optimizado
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildExpandedHeaderButton(
                        icon: Icons.search_rounded,
                        onTap: () => Navigator.pushNamed(context, Routes.inventory),
                        size: 40, // Especificamos tamaño consistente
                      ),
                      const SizedBox(width: 10), // Reducido de 14 a 10
                      _buildExpandedHeaderButton(
                        icon: Icons.notifications_rounded,
                        hasBadge: true,
                        onTap: () {},
                        size: 40,
                      ),
                      const SizedBox(width: 10), // Reducido de 14 a 10
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, Routes.settings),
                        child: Container(
                          width: 40, // Reducido de 44 a 40
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                          ),
                          child: AvatarDisplay(
                            avatarId: user?.avatarId,
                            photoUrl: user?.photoUrl ?? '',
                            fallbackText: user?.name?.substring(0, 1) ?? 'U',
                            size: 32, // Reducido de 36 a 32
                            showBorder: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12), // Reducido de 16 a 12
              // Subtítulo o información adicional - responsivo
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Reducido padding
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16), // Reducido de 20 a 16
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.eco_rounded, color: Colors.white, size: 12), // Reducido de 14 a 12
                          const SizedBox(width: 5), // Reducido de 6 a 5
                          Flexible(
                            child: Text('Gestión inteligente de despensa', 
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 11, // Reducido de 12 a 11
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    bool hasBadge = false,
    double? size,
  }) {
    final buttonSize = size ?? 40.0; // Tamaño por defecto ajustado de 44 a 40
    final iconSize = size != null ? size * 0.45 : 18.0; // Ajustado de 20 a 18
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10), // Reducido de 12 a 10
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, color: Colors.white, size: iconSize)),
            if (hasBadge)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrispContent(InventoryProvider inventoryProvider, ShoppingListProvider shoppingListProvider) {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Stats principales - ultra nítidos
          _buildCrispMainStats(inventoryProvider, shoppingListProvider),
          const SizedBox(height: 20),
          
          // Alertas críticas - nítidas
          _buildCrispAlertsSection(inventoryProvider),
          const SizedBox(height: 20),
          
          // Acciones rápidas - grid nítido
          _buildCrispQuickActions(),
          const SizedBox(height: 20),
          
          // Vista rápida del inventario - nítida
          _buildCrispInventoryView(inventoryProvider),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _buildCrispMainStats(InventoryProvider inventoryProvider, ShoppingListProvider shoppingProvider) {
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
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(child: _buildCrispStatItem(
              title: 'Productos', 
              value: '${inventoryProvider.allProducts.length}', 
              icon: Icons.inventory_2_rounded, 
              color: AppTheme.coralMain)),
            Container(width: 1, height: 50, color: AppTheme.lightGrey.withOpacity(0.5)),
            Expanded(child: _buildCrispStatItem(
              title: 'Compras', 
              value: '${shoppingProvider.getItemCount()}', 
              icon: Icons.shopping_cart_rounded, 
              color: AppTheme.softTeal)),
            Container(width: 1, height: 50, color: AppTheme.lightGrey.withOpacity(0.5)),
            Expanded(child: _buildCrispStatItem(
              title: 'Próximos', 
              value: '${inventoryProvider.expiringProducts.length}', 
              icon: Icons.schedule_rounded, 
              color: AppTheme.warningOrange)),
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, 
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.w800, 
            color: color,
            height: 1.0,
          )),
        const SizedBox(height: 2),
        Text(title, 
          style: TextStyle(
            fontSize: 12, 
            color: AppTheme.darkGrey,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
          textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildCrispAlertsSection(InventoryProvider provider) {
    final expiringCount = provider.expiringProducts.length;
    
    if (expiringCount == 0) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.successGreen.withOpacity(0.2), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Todo perfecto - No hay productos próximos a caducar', 
                  style: TextStyle(
                    fontWeight: FontWeight.w600, 
                    color: AppTheme.successGreen, 
                    fontSize: 14,
                    height: 1.2,
                  )),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, Routes.expiryControl),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorRed.withOpacity(0.2), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('$expiringCount productos por caducar - Revisar ahora', 
                  style: TextStyle(
                    fontWeight: FontWeight.w600, 
                    color: AppTheme.errorRed, 
                    fontSize: 14,
                    height: 1.2,
                  )),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.errorRed, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrispQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acciones rápidas', 
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w700, 
            color: AppTheme.darkGrey,
            height: 1.0,
          )),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildCrispActionCard(
              title: 'Añadir', 
              icon: Icons.add_circle_rounded,
              color: AppTheme.coralMain,
              onTap: () => Navigator.pushNamed(context, Routes.addProduct))),
            const SizedBox(width: 12),
            Expanded(child: _buildCrispActionCard(
              title: 'Compras', 
              icon: Icons.shopping_cart_rounded,
              color: AppTheme.softTeal,
              onTap: () => Navigator.pushNamed(context, Routes.shoppingList))),
            const SizedBox(width: 12),
            Expanded(child: _buildCrispActionCard(
              title: 'Comidas', 
              icon: Icons.restaurant_rounded,
              color: AppTheme.yellowAccent,
              onTap: () => Navigator.pushNamed(context, Routes.mealPlanner))),
            const SizedBox(width: 12),
            Expanded(child: _buildCrispActionCard(
              title: 'Chat IA', 
              icon: Icons.psychology_rounded,
              color: AppTheme.successGreen,
              onTap: () => Navigator.pushNamed(context, Routes.chatBot))),
          ],
        ),
      ],
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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

  Widget _buildCrispInventoryView(InventoryProvider provider) {
    final locationStats = _getCachedLocationStats(provider);
    
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Inventario por ubicación', 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w700, 
                    color: AppTheme.darkGrey,
                    height: 1.0,
                  )),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, Routes.inventory),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.coralMain.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Ver todo', 
                      style: TextStyle(
                        color: AppTheme.coralMain, 
                        fontWeight: FontWeight.w600, 
                        fontSize: 12,
                      )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildCrispLocationCard(
                  title: 'Nevera', 
                  count: locationStats['Nevera'] ?? 0, 
                  icon: Icons.kitchen_rounded,
                  color: AppTheme.softTeal)),
                const SizedBox(width: 12),
                Expanded(child: _buildCrispLocationCard(
                  title: 'Despensa', 
                  count: locationStats['Despensa'] ?? 0, 
                  icon: Icons.kitchen_outlined,
                  color: AppTheme.yellowAccent)),
                const SizedBox(width: 12),
                Expanded(child: _buildCrispLocationCard(
                  title: 'Congelador', 
                  count: locationStats['Congelador'] ?? 0, 
                  icon: Icons.ac_unit_rounded,
                  color: Color(0xFF6BB6FF))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrispLocationCard({
    required String title, 
    required int count, 
    required IconData icon, 
    required Color color,
  }) {
    return Container(
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
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text('$count', 
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
        ),
      ),
    );
  }

  // Métodos auxiliares optimizados
  Map<String, int> _getCachedLocationStats(InventoryProvider provider) {
    if (_cachedStats != null && _cachedStats!['locationStats'] != null) {
      return _cachedStats!['locationStats'];
    }

    final products = provider.allProducts.where((product) =>
      product.productLocation == ProductLocation.inventory || 
      product.productLocation == ProductLocation.both
    ).toList();
    
    Map<String, int> locationStats = {};
    const mainLocations = ['Nevera', 'Despensa', 'Congelador', 'Armario', 'Especias', 'Bebidas'];
    
    for (String location in mainLocations) {
      locationStats[location] = products.where((product) => product.location == location).length;
    }
    
    final otherLocations = products
        .where((product) => !mainLocations.contains(product.location))
        .length;
    
    if (otherLocations > 0) {
      locationStats['Otros'] = otherLocations;
    }
    
    _cachedStats ??= {};
    _cachedStats!['locationStats'] = locationStats;
    return locationStats;
  }
}