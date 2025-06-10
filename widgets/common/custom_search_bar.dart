import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// CustomSearchBar - Barra de búsqueda personalizada para SmartPantry
/// 
/// Proporciona una barra de búsqueda con estilos consistentes con el diseño minimalista
/// de la aplicación, incluye opciones para filtrado, escaneo de códigos de barras y búsqueda por voz.
class CustomSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final Function(String)? onChanged;
  final VoidCallback? onFilterPressed;
  final VoidCallback? onBarcodeScanPressed;
  final VoidCallback? onVoiceSearchPressed;
  final bool showFilterButton;
  final bool showBarcodeButton;
  final bool showVoiceButton;
  final bool autofocus;
  final Color? backgroundColor;
  final FocusNode? focusNode;

  const CustomSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Buscar...',
    this.onChanged,
    this.onFilterPressed,
    this.onBarcodeScanPressed,
    this.onVoiceSearchPressed,
    this.showFilterButton = true,
    this.showBarcodeButton = true,
    this.showVoiceButton = true,
    this.autofocus = false,
    this.backgroundColor,
    this.focusNode,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  bool _showClearButton = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    
    // Inicializar controlador de animación para efectos visuales
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _controller.removeListener(_onTextChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _showClearButton = _controller.text.isNotEmpty;
    });
    if (widget.onChanged != null) {
      widget.onChanged!(_controller.text);
    }
  }

  void _clearSearch() {
    _controller.clear();
    if (widget.onChanged != null) {
      widget.onChanged!('');
    }
  }

  // Método para obtener el color del icono según el estado
  Color _getIconColor(BuildContext context, bool isActive) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    if (isActive) {
      return AppTheme.coralMain;
    } else {
      return isDarkMode ? AppTheme.mediumGrey : AppTheme.darkGrey.withOpacity(0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actualBackgroundColor = widget.backgroundColor ?? 
        Theme.of(context).inputDecorationTheme.fillColor ?? 
        Theme.of(context).colorScheme.surface;
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: actualBackgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          if (_isFocused)
            BoxShadow(
              color: AppTheme.coralMain.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
        ],
        border: Border.all(
          color: _isFocused 
              ? AppTheme.coralMain.withOpacity(0.3) 
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Focus(
        onFocusChange: (hasFocus) {
          setState(() {
            _isFocused = hasFocus;
          });
          if (hasFocus) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }
        },
        child: Row(
          children: [
            // Icono de búsqueda con animación
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.search_rounded,
                  color: _isFocused 
                      ? AppTheme.coralMain 
                      : isDarkMode 
                          ? AppTheme.mediumGrey 
                          : AppTheme.darkGrey.withOpacity(0.6),
                  size: 22,
                ),
              ),
            ),
            
            // Campo de texto
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                autofocus: widget.autofocus,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: isDarkMode 
                        ? AppTheme.mediumGrey 
                        : AppTheme.mediumGrey.withOpacity(0.7),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingMedium,
                  ),
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode 
                      ? AppTheme.pureWhite 
                      : AppTheme.darkGrey,
                ),
                textInputAction: TextInputAction.search,
                cursorColor: AppTheme.coralMain,
                cursorRadius: const Radius.circular(2),
                onTap: () {
                  if (!_isFocused) {
                    setState(() {
                      _isFocused = true;
                    });
                    _animationController.forward();
                  }
                },
              ),
            ),
            
            // Botón de cerrar/limpiar búsqueda
            if (_showClearButton)
              _buildAnimatedIconButton(
                Icons.close_rounded,
                _clearSearch,
                true,
              ),
              
            // Botón de búsqueda por voz (solo visible si no hay texto y está habilitado)
            if (!_showClearButton && widget.showVoiceButton)
              _buildAnimatedIconButton(
                Icons.mic_none_rounded,
                widget.onVoiceSearchPressed,
                _isFocused,
              ),
              
            // Botón para escanear código de barras
            if (widget.showBarcodeButton)
              _buildAnimatedIconButton(
                Icons.qr_code_scanner_rounded,
                widget.onBarcodeScanPressed,
                _isFocused,
              ),
              
            // Botón para mostrar filtros
            if (widget.showFilterButton)
              _buildAnimatedIconButton(
                Icons.tune_rounded,
                widget.onFilterPressed,
                _isFocused,
                showDivider: false,
              ),
              
            // Espacio final para mejor apariencia
            const SizedBox(width: AppTheme.spacingSmall),
          ],
        ),
      ),
    );
  }

  // Construye un botón de icono animado con separador opcional
  Widget _buildAnimatedIconButton(
    IconData icon,
    VoidCallback? onPressed,
    bool isActive, {
    bool showDivider = true,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Separador vertical sutil
        if (showDivider)
          Container(
            height: 24,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
          ),
        
        // Botón con efecto de pulsación
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            splashColor: AppTheme.coralMain.withOpacity(0.1),
            highlightColor: AppTheme.coralMain.withOpacity(0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
              child: Icon(
                icon,
                size: 22,
                color: _getIconColor(context, isActive),
              ),
            ),
          ),
        ),
      ],
    );
  }
}