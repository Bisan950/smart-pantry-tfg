import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// CustomTextField - Campo de texto personalizado para la aplicación SmartPantry
/// 
/// Versión corregida que evita setState() durante build
class CustomTextField extends StatefulWidget {
  /// Etiqueta que describe el campo
  final String label;
  
  /// Texto de ayuda que aparece cuando el campo está vacío
  final String? hintText;
  
  /// Controlador para el campo de texto
  final TextEditingController? controller;
  
  /// Tipo de teclado a mostrar
  final TextInputType keyboardType;
  
  /// Si es un campo de contraseña
  final bool isPassword;
  
  /// Icono para mostrar al inicio del campo
  final IconData? prefixIcon;
  
  /// Icono para mostrar al final del campo
  final IconData? suffixIcon;
  
  /// Acción al presionar el icono de sufijo
  final VoidCallback? onSuffixIconPressed;
  
  /// Función de validación
  final String? Function(String?)? validator;
  
  /// Callback cuando cambia el contenido
  final Function(String)? onChanged;
  
  /// Si el campo está habilitado
  final bool isEnabled;
  
  /// Número máximo de líneas
  final int maxLines;
  
  /// Nodo de foco para control de teclado
  final FocusNode? focusNode;
  
  /// Acción del teclado cuando se completa la entrada
  final TextInputAction textInputAction;
  
  /// Callback cuando se envía el campo
  final Function(String)? onSubmitted;
  
  /// Color del borde cuando está enfocado (opcional)
  final Color? focusedBorderColor;
  
  /// Texto auxiliar debajo del campo
  final String? helperText;
  
  /// Si debe autovalidar al cambiar
  final bool autovalidate;

  const CustomTextField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.validator,
    this.onChanged,
    this.isEnabled = true,
    this.maxLines = 1,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.focusedBorderColor,
    this.helperText,
    this.autovalidate = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> with SingleTickerProviderStateMixin {
  bool _obscureText = true;
  bool _hasFocus = false;
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _iconScaleAnimation;
  String? _errorText;
  
  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    
    // Inicializar el controlador de animación
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _iconScaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void dispose() {
    // Solo dispose del FocusNode si lo creamos internamente
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }
  
  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
        if (_hasFocus) {
          _animationController.forward();
        } else {
          _animationController.reverse();
          // Validar al perder el foco
          if (widget.validator != null && widget.controller != null) {
            _errorText = widget.validator!(widget.controller!.text);
          }
        }
      });
    }
  }

  // Método para obtener si hay texto SIN usar setState
  bool get _hasText {
    return widget.controller?.text.isNotEmpty ?? false;
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color labelColor = _hasFocus 
      ? (widget.focusedBorderColor ?? AppTheme.coralMain)
      : isDarkMode ? AppTheme.pureWhite.withOpacity(0.9) : AppTheme.darkGrey;
    
    final Color borderColor = _hasFocus
      ? (widget.focusedBorderColor ?? AppTheme.coralMain)
      : isDarkMode 
        ? Colors.grey.shade700
        : AppTheme.lightGrey.withOpacity(0.7);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty)
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: _hasFocus ? 14 : 15,
              fontWeight: _hasFocus ? FontWeight.w600 : FontWeight.w500,
              color: labelColor,
              letterSpacing: _hasFocus ? 0.1 : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: AppTheme.spacingSmall,
                left: AppTheme.spacingXSmall,
              ),
              child: Text(widget.label),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            boxShadow: widget.isEnabled ? [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            obscureText: widget.isPassword && _obscureText,
            validator: widget.validator,
            autovalidateMode: widget.autovalidate 
                ? AutovalidateMode.onUserInteraction 
                : AutovalidateMode.disabled,
            onChanged: widget.onChanged,
            enabled: widget.isEnabled,
            maxLines: widget.isPassword ? 1 : widget.maxLines,
            focusNode: _focusNode,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onSubmitted,
            cursorColor: widget.focusedBorderColor ?? AppTheme.coralMain,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppTheme.pureWhite : AppTheme.darkGrey,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.5) 
                    : Colors.grey.shade500,
                fontWeight: FontWeight.normal,
              ),
              helperText: widget.helperText,
              helperStyle: TextStyle(
                fontSize: 12,
                color: isDarkMode 
                    ? Colors.grey.shade400 
                    : Colors.grey.shade600,
              ),
              errorStyle: const TextStyle(
                fontSize: 12,
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w500,
              ),
              errorMaxLines: 2,
              filled: true,
              fillColor: isDarkMode 
                  ? const Color(0xFF262626) 
                  : AppTheme.pureWhite,
              contentPadding: EdgeInsets.symmetric(
                horizontal: widget.prefixIcon != null ? 0 : AppTheme.spacingMedium,
                vertical: AppTheme.spacingMedium,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? AnimatedBuilder(
                      animation: _iconScaleAnimation,
                      builder: (context, child) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            widget.prefixIcon,
                            color: _hasFocus 
                                ? (widget.focusedBorderColor ?? AppTheme.coralMain)
                                : isDarkMode 
                                    ? Colors.grey.shade400 
                                    : Colors.grey.shade500,
                            size: 20,
                          ),
                        );
                      },
                    )
                  : null,
              suffixIcon: widget.isPassword
                  ? _buildPasswordToggleIcon(isDarkMode)
                  : widget.suffixIcon != null
                      ? _buildSuffixIcon(isDarkMode)
                      : _hasText
                          ? _buildClearButton(isDarkMode)
                          : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                borderSide: BorderSide(
                  color: borderColor,
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                borderSide: BorderSide(
                  color: widget.focusedBorderColor ?? AppTheme.coralMain,
                  width: 2.0,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                borderSide: const BorderSide(
                  color: AppTheme.errorRed,
                  width: 1.0,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                borderSide: const BorderSide(
                  color: AppTheme.errorRed,
                  width: 2.0,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                borderSide: BorderSide(
                  color: isDarkMode 
                      ? Colors.grey.shade800 
                      : Colors.grey.shade300,
                  width: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordToggleIcon(bool isDarkMode) {
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Icon(
          _obscureText 
              ? Icons.visibility_rounded 
              : Icons.visibility_off_rounded,
          key: ValueKey<bool>(_obscureText),
          color: _hasFocus 
              ? (widget.focusedBorderColor ?? AppTheme.coralMain)
              : isDarkMode 
                  ? Colors.grey.shade400 
                  : Colors.grey.shade600,
          size: 20,
        ),
      ),
      splashRadius: 20,
      onPressed: () {
        setState(() {
          _obscureText = !_obscureText;
        });
      },
    );
  }

  Widget _buildSuffixIcon(bool isDarkMode) {
    return IconButton(
      icon: Icon(
        widget.suffixIcon,
        color: _hasFocus 
            ? (widget.focusedBorderColor ?? AppTheme.coralMain)
            : isDarkMode 
                ? Colors.grey.shade400 
                : Colors.grey.shade600,
        size: 20,
      ),
      splashRadius: 20,
      onPressed: widget.onSuffixIconPressed,
    );
  }

  Widget _buildClearButton(bool isDarkMode) {
    return Visibility(
      visible: _hasText,
      child: IconButton(
        icon: const Icon(
          Icons.clear_rounded,
          size: 18,
        ),
        splashRadius: 20,
        color: isDarkMode 
            ? Colors.grey.shade400 
            : Colors.grey.shade500,
        onPressed: () {
          if (widget.controller != null) {
            widget.controller!.clear();
            widget.onChanged?.call('');
            // Forzar rebuild para actualizar el botón de limpiar
            if (mounted) {
              setState(() {});
            }
          }
        },
      ),
    );
  }
}