// lib/screens/auth/welcome_screen.dart - VERSIÓN UX OPTIMIZADA

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late AnimationController _logoAnimationController;
  late AnimationController _featuresAnimationController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _featuresStaggerAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkCurrentUser();
  }

  void _setupAnimations() {
    // Controlador principal
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Controlador del logo
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    // Controlador de características
    _featuresAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Animaciones principales
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    // Animaciones del logo
    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    
    _logoRotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );
    
    // Animación de características
    _featuresStaggerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _featuresAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // Iniciar animaciones en secuencia
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _logoAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _featuresAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _logoAnimationController.dispose();
    _featuresAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentUser() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.dashboard);
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safePadding = MediaQuery.of(context).padding;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.coralMain,
              AppTheme.coralMain.withOpacity(0.9),
              AppTheme.yellowAccent.withOpacity(0.8),
              AppTheme.peachLight.withOpacity(0.7),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Efectos de fondo mejorados
            _buildBackgroundEffects(),
            
            // Contenido principal con mejor espaciado
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: size.height - safePadding.top - safePadding.bottom,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              // Espaciado superior dinámico
                              SizedBox(height: size.height * 0.04),
                              
                              // Logo animado optimizado
                              _buildAnimatedLogo(context),
                              
                              // Espaciado proporcionado
                              SizedBox(height: size.height * 0.03),
                              
                              // Título principal con efectos
                              _buildMainTitle(),
                              
                              // Espaciado entre título y subtítulo
                              SizedBox(height: size.height * 0.02),
                              
                              // Subtítulo con diseño moderno
                              _buildSubtitle(),
                              
                              // Espaciado flexible
                              SizedBox(height: size.height * 0.05),
                              
                              // Características con mejor espaciado
                              _buildAnimatedFeatures(),
                              
                              // Espaciado flexible antes de botones
                              const Spacer(),
                              
                              // Botones de acción optimizados
                              _buildActionButtons(),
                              
                              // Espaciado inferior seguro
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return Stack(
      children: [
        // Efectos de fondo con coral predominante
        Positioned(
          top: -60,
          right: -60,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.pureWhite.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: -40,
          left: -40,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.pureWhite.withOpacity(0.05),
            ),
          ),
        ),
        Positioned(
          top: 120,
          left: 40,
          child: Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.pureWhite.withOpacity(0.2),
            ),
          ),
        ),
        Positioned(
          top: 280,
          right: 60,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.pureWhite.withOpacity(0.15),
            ),
          ),
        ),
        Positioned(
          bottom: 180,
          right: 80,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.yellowAccent.withOpacity(0.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedLogo(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return Center(
    child: AnimatedBuilder(
      animation: _logoScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoScaleAnimation.value,
          child: Transform.rotate(
            angle: _logoRotateAnimation.value * 0.1, // Rotación sutil
            child: Container(
              width: size.width * 0.32,
              height: size.width * 0.32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(20.0), // Más padding para centrar mejor
                  child: Image.asset(
                    'assets/LOGOS/icono_app_zanahoria.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Widget de fallback si la imagen no se encuentra
                      return Icon(
                        Icons.restaurant,
                        size: size.width * 0.15,
                        color: AppTheme.coralMain,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

  Widget _buildMainTitle() {
    return Column(
      children: [
        Text(
          'SmartPantry',
          style: TextStyle(
            color: AppTheme.pureWhite,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            height: 1.1,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 45,
          height: 3,
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite.withOpacity(0.12),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppTheme.pureWhite.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'Tu despensa inteligente en un solo lugar',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          color: AppTheme.pureWhite,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildAnimatedFeatures() {
    final features = [
      {
        'icon': Icons.inventory_2_rounded,
        'title': 'Gestiona tu inventario',
        'description': 'Mantén el control de tus alimentos',
        'color': AppTheme.successGreen,
      },
      {
        'icon': Icons.shopping_cart_rounded,
        'title': 'Lista de compras inteligente',
        'description': 'Sugerencias basadas en tu inventario',
        'color': AppTheme.softTeal,
      },
      {
        'icon': Icons.restaurant_menu_rounded,
        'title': 'Recetas personalizadas',
        'description': 'Aprovecha al máximo tus ingredientes',
        'color': AppTheme.warningOrange,
      },
    ];

    return AnimatedBuilder(
      animation: _featuresStaggerAnimation,
      builder: (context, child) {
        return Column(
          children: features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            final delay = index * 0.2;
            final animationValue = (_featuresStaggerAnimation.value - delay).clamp(0.0, 1.0);
            
            return Transform.translate(
              offset: Offset(0, 20 * (1 - animationValue)),
              child: Opacity(
                opacity: animationValue,
                child: Container(
                  margin: EdgeInsets.only(bottom: index < features.length - 1 ? 12 : 0),
                  child: _buildModernFeatureItem(
                    icon: feature['icon'] as IconData,
                    title: feature['title'] as String,
                    description: feature['description'] as String,
                    color: feature['color'] as Color,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildModernFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.pureWhite.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppTheme.pureWhite,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.pureWhite,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.pureWhite.withOpacity(0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: CircularProgressIndicator(
          color: AppTheme.pureWhite,
          strokeWidth: 3,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // Botón principal (Iniciar sesión)
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.pureWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppTheme.pureWhite.withOpacity(0.8),
                  blurRadius: 20,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pushNamed(context, Routes.login),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.login_rounded,
                        color: AppTheme.coralMain,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Iniciar sesión',
                        style: TextStyle(
                          color: AppTheme.coralMain,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Botón secundario (Registrarse)
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.pureWhite.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.pureWhite.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pushNamed(context, Routes.register),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_add_rounded,
                        color: AppTheme.pureWhite,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Registrarse',
                        style: TextStyle(
                          color: AppTheme.pureWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}