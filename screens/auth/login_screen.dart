// lib/screens/auth/login_screen.dart - SIN MARCO ROJO DE ERROR

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/snackbar_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _rememberMe = true;
  
  // Estados de validación personalizados
  bool _emailHasError = false;
  bool _passwordHasError = false;
  String _emailError = '';
  String _passwordError = '';
  
  // Controladores de animación
  late AnimationController _animationController;
  late AnimationController _logoAnimationController;
  late AnimationController _formAnimationController;
  
  // Animaciones
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _formStaggerAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Controlador principal
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Controlador del logo
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Controlador del formulario
    _formAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
    
    // Animación del logo
    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    
    // Animación del formulario
    _formStaggerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _formAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // Iniciar animaciones en secuencia
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _logoAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _formAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _logoAnimationController.dispose();
    _formAnimationController.dispose();
    super.dispose();
  }

  // Validación personalizada sin usar el validador de Flutter
  void _validateFields() {
    setState(() {
      // Validar email
      if (_emailController.text.isEmpty) {
        _emailHasError = true;
        _emailError = 'Por favor, ingresa tu email';
      } else if (!_isValidEmail(_emailController.text)) {
        _emailHasError = true;
        _emailError = 'Ingresa un email válido';
      } else {
        _emailHasError = false;
        _emailError = '';
      }
      
      // Validar contraseña
      if (_passwordController.text.isEmpty) {
        _passwordHasError = true;
        _passwordError = 'Por favor, ingresa tu contraseña';
      } else if (_passwordController.text.length < 6) {
        _passwordHasError = true;
        _passwordError = 'La contraseña debe tener al menos 6 caracteres';
      } else {
        _passwordHasError = false;
        _passwordError = '';
      }
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _signIn() async {
    _validateFields();
    
    if (_emailHasError || _passwordHasError) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );

      if (success) {
        if (mounted) {
          SnackBarUtils.showSuccess(context, '¡Bienvenido de nuevo!');
          Navigator.pushReplacementNamed(context, Routes.dashboard);
        }
      } else {
        setState(() {
          _errorMessage = authProvider.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al iniciar sesión: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Ingresa tu email para recuperar la contraseña';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.resetPassword(_emailController.text.trim());

      if (success) {
        if (mounted) {
          SnackBarUtils.showSuccess(
            context, 
            'Se ha enviado un email para restablecer tu contraseña'
          );
        }
      } else {
        setState(() {
          _errorMessage = authProvider.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al enviar email de recuperación: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            // Efectos de fondo
            _buildBackgroundEffects(),
            
            // Contenido principal
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: size.height - safePadding.top - safePadding.bottom,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Espaciado superior
                                SizedBox(height: size.height * 0.02),
                                
                                // Header con botón de volver
                                _buildHeader(),
                                
                                // Espaciado
                                SizedBox(height: size.height * 0.04),
                                
                                // Logo animado
                                _buildAnimatedLogo(size),
                                
                                // Espaciado
                                SizedBox(height: size.height * 0.03),
                                
                                // Título y subtítulo
                                _buildTitleSection(),
                                
                                // Espaciado
                                SizedBox(height: size.height * 0.04),
                                
                                // Formulario animado
                                _buildAnimatedForm(),
                                
                                // Spacer flexible
                                const Spacer(),
                                
                                // Footer con registro
                                _buildFooter(),
                                
                                // Espaciado inferior
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return Stack(
      children: [
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
          top: 150,
          left: 30,
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
          top: 300,
          right: 50,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.pureWhite.withOpacity(0.15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.pureWhite.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.pureWhite.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.pureWhite,
              size: 20,
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.pureWhite.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.login_rounded, color: AppTheme.pureWhite, size: 16),
              const SizedBox(width: 8),
              Text(
                'Iniciar Sesión',
                style: TextStyle(
                  color: AppTheme.pureWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedLogo(Size size) {
    return Hero(
      tag: 'app_logo',
      child: AnimatedBuilder(
        animation: _logoAnimationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _logoScaleAnimation.value,
            child: Container(
              width: size.width * 0.288, // 20% más grande
              height: size.width * 0.288, // 20% más grande
              decoration: BoxDecoration(
                // color: AppTheme.pureWhite, // Elimina o comenta esta línea
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppTheme.pureWhite.withOpacity(0.5),
                    blurRadius: 25,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/LOGOS/icono_app_Texto.png',
                width: size.width * 0.144, // 20% más grande
                height: size.width * 0.144, // 20% más grande
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      children: [
        Text(
          'Bienvenido de nuevo',
          style: TextStyle(
            color: AppTheme.pureWhite,
            fontSize: 28,
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
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.pureWhite.withOpacity(0.25)),
          ),
          child: Text(
            'Ingresa a tu cuenta de SmartPantry',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.pureWhite.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedForm() {
    return AnimatedBuilder(
      animation: _formStaggerAnimation,
      builder: (context, child) {
        return Column(
          children: [
            // Mensaje de error moderno
            if (_errorMessage.isNotEmpty)
              Transform.translate(
                offset: Offset(0, 20 * (1 - _formStaggerAnimation.value)),
                child: Opacity(
                  opacity: _formStaggerAnimation.value,
                  child: _buildErrorMessage(),
                ),
              ),
            
            // Campo Email
            Transform.translate(
              offset: Offset(0, 30 * (1 - _formStaggerAnimation.value)),
              child: Opacity(
                opacity: _formStaggerAnimation.value,
                child:                 _buildModernTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Email',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  hasError: _emailHasError,
                  errorText: _emailError,
                  onChanged: (value) {
                    // Limpiar error mientras escribe
                    if (_emailHasError) {
                      setState(() {
                        _emailHasError = false;
                        _emailError = '';
                      });
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Campo Contraseña
            Transform.translate(
              offset: Offset(0, 40 * (1 - _formStaggerAnimation.value)),
              child: Opacity(
                opacity: _formStaggerAnimation.value,
                child:                 _buildModernTextField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  hint: 'Contraseña',
                  icon: Icons.lock_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  hasError: _passwordHasError,
                  errorText: _passwordError,
                  onSubmitted: (_) => _signIn(),
                  onChanged: (value) {
                    // Limpiar error mientras escribe
                    if (_passwordHasError) {
                      setState(() {
                        _passwordHasError = false;
                        _passwordError = '';
                      });
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Recordar sesión y olvidar contraseña
            Transform.translate(
              offset: Offset(0, 50 * (1 - _formStaggerAnimation.value)),
              child: Opacity(
                opacity: _formStaggerAnimation.value,
                child: _buildOptionsRow(),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Botón de login
            Transform.translate(
              offset: Offset(0, 60 * (1 - _formStaggerAnimation.value)),
              child: Opacity(
                opacity: _formStaggerAnimation.value,
                child: _buildLoginButton(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorRed.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppTheme.errorRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: AppTheme.errorRed,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = ''),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: AppTheme.errorRed,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Function(String)? onSubmitted,
    Function(String)? onChanged,
    bool hasError = false,
    String errorText = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contenedor con sombra exterior y padding extra para el label
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: hasError 
                  ? AppTheme.errorRed.withOpacity(0.2)
                  : Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: AppTheme.pureWhite.withOpacity(0.8),
                blurRadius: 20,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.pureWhite.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: hasError ? Border.all(
                color: AppTheme.errorRed.withOpacity(0.6),
                width: 2,
              ) : null,
            ),
            child: TextFormField(
              controller: controller,
              obscureText: isPassword,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onFieldSubmitted: onSubmitted,
              onChanged: onChanged,
              validator: null,
              style: TextStyle(
                color: AppTheme.darkGrey.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                // Usar hintText en lugar de labelText para evitar el problema
                hintText: hint.isEmpty ? label : hint,
                // Label flotante deshabilitado
                floatingLabelBehavior: FloatingLabelBehavior.never,
                prefixIcon: Icon(
                  icon, 
                  color: hasError 
                    ? AppTheme.errorRed 
                    : AppTheme.coralMain
                ),
                hintStyle: TextStyle(
                  color: AppTheme.mediumGrey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                errorStyle: const TextStyle(height: 0),
              ),
            ),
          ),
        ),
        
        // Mensaje de error personalizado
        if (hasError && errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.error_rounded,
                  color: AppTheme.errorRed,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  errorText,
                  style: TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }


  Widget _buildOptionsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.pureWhite.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _rememberMe 
                      ? AppTheme.pureWhite 
                      : AppTheme.pureWhite.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: AppTheme.pureWhite,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _rememberMe
                    ? Icon(
                        Icons.check_rounded,
                        color: AppTheme.coralMain,
                        size: 16,
                      )
                    : null,
                ),
                const SizedBox(width: 10),
                Text(
                  'Recordar sesión',
                  style: TextStyle(
                    color: AppTheme.pureWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _resetPassword,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.pureWhite.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.pureWhite.withOpacity(0.4)),
              ),
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  color: AppTheme.pureWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.pureWhite.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.pureWhite,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return Container(
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
          onTap: _signIn,
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
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.pureWhite),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿No tienes cuenta?',
            style: TextStyle(
              color: AppTheme.mediumGrey, // Texto oscuro para contraste
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, Routes.register),
            child: Text(
              'Registrarse',
              style: TextStyle(
                color: AppTheme.coralMain, // Coral para destacar
                fontSize: 15,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.coralMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}