// lib/screens/auth/register_screen.dart - SIN MARCO ROJO DE ERROR

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/snackbar_utils.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _acceptTerms = false;
  
  // Estados de validación personalizados
  bool _nameHasError = false;
  bool _emailHasError = false;
  bool _passwordHasError = false;
  bool _confirmPasswordHasError = false;
  String _nameError = '';
  String _emailError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';
  
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    _logoAnimationController.dispose();
    _formAnimationController.dispose();
    super.dispose();
  }

  // Validación personalizada sin usar el validador de Flutter
  void _validateFields() {
    setState(() {
      // Validar nombre
      if (_nameController.text.isEmpty) {
        _nameHasError = true;
        _nameError = 'Por favor, ingresa tu nombre';
      } else if (_nameController.text.length < 2) {
        _nameHasError = true;
        _nameError = 'El nombre debe tener al menos 2 caracteres';
      } else {
        _nameHasError = false;
        _nameError = '';
      }
      
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
      
      // Validar confirmación de contraseña
      if (_confirmPasswordController.text.isEmpty) {
        _confirmPasswordHasError = true;
        _confirmPasswordError = 'Por favor, confirma tu contraseña';
      } else if (_confirmPasswordController.text != _passwordController.text) {
        _confirmPasswordHasError = true;
        _confirmPasswordError = 'Las contraseñas no coinciden';
      } else {
        _confirmPasswordHasError = false;
        _confirmPasswordError = '';
      }
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _register() async {
    _validateFields();
    
    if (_nameHasError || _emailHasError || _passwordHasError || _confirmPasswordHasError) {
      return;
    }

    if (!_acceptTerms) {
      setState(() {
        _errorMessage = 'Debes aceptar los términos y condiciones';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: true,
      );

      if (success) {
        if (mounted) {
          SnackBarUtils.showSuccess(context, '¡Cuenta creada exitosamente!');
          Navigator.pushReplacementNamed(context, Routes.dashboard);
        }
      } else {
        setState(() {
          _errorMessage = authProvider.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al crear la cuenta: $e';
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
                                SizedBox(height: size.height * 0.03),
                                
                                // Logo animado
                                _buildAnimatedLogo(size),
                                
                                // Espaciado
                                SizedBox(height: size.height * 0.02),
                                
                                // Título y subtítulo
                                _buildTitleSection(),
                                
                                // Espaciado
                                SizedBox(height: size.height * 0.025),
                                
                                // Formulario animado
                                _buildAnimatedForm(),
                                
                                // Espaciado adicional antes del footer
                                SizedBox(height: size.height * 0.04),
                                
                                // Footer con login
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
              Icon(Icons.person_add_rounded, color: AppTheme.pureWhite, size: 16),
              const SizedBox(width: 8),
              Text(
                'Crear Cuenta',
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
              width: size.width * 0.264, // 20% más grande que 0.22
              height: size.width * 0.264, // 20% más grande que 0.22
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
                width: size.width * 0.132, // 20% más grande que 0.11
                height: size.width * 0.132, // 20% más grande que 0.11
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
          'Crea tu cuenta',
          style: TextStyle(
            color: AppTheme.pureWhite,
            fontSize: 26,
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
            'Únete a SmartPantry hoy mismo',
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
            
            // Campo Nombre
            Transform.translate(
              offset: Offset(0, 30 * (1 - _formStaggerAnimation.value)),
              child: Opacity(
                opacity: _formStaggerAnimation.value,
                child: _buildModernTextField(
                  controller: _nameController,
                  label: 'Nombre completo',
                  hint: 'Nombre completo',
                  icon: Icons.person_rounded,
                  keyboardType: TextInputType.name,
                  hasError: _nameHasError,
                  errorText: _nameError,
                  onChanged: (value) {
                    // Limpiar error mientras escribe
                    if (_nameHasError) {
                      setState(() {
                        _nameHasError = false;
                        _nameError = '';
                      });
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Campo Email
            Transform.translate(
              offset: Offset(0, 40 * (1 - _formStaggerAnimation.value)),
              child: Opacity(
                opacity: _formStaggerAnimation.value,
                child: _buildModernTextField(
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
              offset: Offset(0, 50 * (1 - _formStaggerAnimation.value)),
              child: Opacity(
                opacity: _formStaggerAnimation.value,
                child: _buildModernTextField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  hint: 'Contraseña',
                  icon: Icons.lock_rounded,
                  isPassword: true,
                  hasError: _passwordHasError,
                  errorText: _passwordError,
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
            
            const SizedBox(height: 16),
            
            // Campo Confirmar Contraseña
            Transform.translate(
              offset: Offset(0, 60 * (1 - _formStaggerAnimation.value)),
              child: Opacity(
                opacity: _formStaggerAnimation.value,
                child: _buildModernTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar contraseña',
                  hint: 'Confirmar contraseña',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  hasError: _confirmPasswordHasError,
                  errorText: _confirmPasswordError,
                  onSubmitted: (_) => _register(),
                  onChanged: (value) {
                    // Limpiar error mientras escribe
                    if (_confirmPasswordHasError) {
                      setState(() {
                        _confirmPasswordHasError = false;
                        _confirmPasswordError = '';
                      });
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Términos y condiciones
            Transform.translate(
              offset: Offset(0, 70 * (1 - _formStaggerAnimation.value)),
              child: Opacity(
                opacity: _formStaggerAnimation.value,
                child: _buildTermsRow(),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Botón de registro
            Transform.translate(
              offset: Offset(0, 80 * (1 - _formStaggerAnimation.value)),
              child: Opacity(
                opacity: _formStaggerAnimation.value,
                child: _buildRegisterButton(),
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

  Widget _buildTermsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.pureWhite.withOpacity(0.3)),
      ),
      child: GestureDetector(
        onTap: () => setState(() => _acceptTerms = !_acceptTerms),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _acceptTerms 
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
              child: _acceptTerms
                ? Icon(
                    Icons.check_rounded,
                    color: AppTheme.coralMain,
                    size: 16,
                  )
                : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Acepto los ',
                      style: TextStyle(
                        color: AppTheme.pureWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    TextSpan(
                      text: 'términos y condiciones',
                      style: TextStyle(
                        color: AppTheme.pureWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.pureWhite,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
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
          onTap: _register,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_rounded,
                  color: AppTheme.coralMain,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Crear cuenta',
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
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '¿Ya tienes cuenta?',
                style: TextStyle(
                  color: AppTheme.mediumGrey,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, Routes.login),
                child: Text(
                  'Iniciar sesión',
                  style: TextStyle(
                    color: AppTheme.coralMain,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.coralMain,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}