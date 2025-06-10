import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';

/// Widget para incrementar/decrementar la cantidad de un producto con entrada manual
/// Rediseñado con estilo minimalista con tonos coral/melocotón
class ProductCounter extends StatefulWidget {
  /// Valor actual del contador
  final int value;
  
  /// Valor mínimo permitido
  final int minValue;
  
  /// Valor máximo permitido
  final int maxValue;
  
  /// Incremento/decremento por paso
  final int step;
  
  /// Unidad de medida (para mostrar junto al valor)
  final String unit;
  
  /// Callback cuando cambia el valor
  final ValueChanged<int> onChanged;

  const ProductCounter({
    super.key,
    required this.value,
    this.minValue = 0,
    this.maxValue = 9999,
    this.step = 1,
    required this.unit,
    required this.onChanged,
  });

  @override
  State<ProductCounter> createState() => _ProductCounterState();
}

class _ProductCounterState extends State<ProductCounter> with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Inicializar con el valor como entero
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode();
    
    // Configurar controlador de animación
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _updateValueFromText();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProductCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Actualizar el controlador si el valor cambia externamente
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _updateValueFromText() {
    try {
      final text = _controller.text.trim();
      
      if (text.isEmpty) {
        _setValue(widget.minValue);
        return;
      }
      
      int? newValue = int.tryParse(text);
      
      if (newValue != null) {
        _setValue(newValue);
      } else {
        // Si no se puede parsear, volver al valor anterior
        _controller.text = widget.value.toString();
      }
    } catch (e) {
      // En caso de error, volver al valor anterior
      _controller.text = widget.value.toString();
    }
  }

  Future<void> _animateButtonPress() async {
    _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      _animationController.reverse();
    }
  }

  void _increment() async {
    await _animateButtonPress();
    
    final newValue = widget.value + widget.step;
    if (newValue <= widget.maxValue) {
      _setValue(newValue);
    } else {
      // Si el nuevo valor supera el máximo, establecer al máximo y mostrar mensaje
      _setValue(widget.maxValue);
      _showMessage('La cantidad no puede superar el máximo de ${widget.maxValue} ${widget.unit}', AppTheme.warningOrange);
    }
  }

  void _decrement() async {
    await _animateButtonPress();
    
    final newValue = widget.value - widget.step;
    if (newValue >= widget.minValue) {
      _setValue(newValue);
    } else if (widget.minValue == 0 && newValue < 0) {
      _showMessage('La cantidad no puede ser menor a ${widget.minValue}', AppTheme.errorRed);
    }
  }

  void _setValue(int value) {
    // Validación mejorada: asegurar que el valor esté dentro de los límites
    int limitedValue;
    
    if (value < widget.minValue) {
      limitedValue = widget.minValue;
    } else if (value > widget.maxValue) {
      limitedValue = widget.maxValue;
      // Mostrar mensaje si se intenta establecer un valor mayor al máximo
      if (value > widget.maxValue) {
        _showMessage('La cantidad no puede superar el máximo de ${widget.maxValue} ${widget.unit}', AppTheme.warningOrange);
      }
    } else {
      limitedValue = value;
    }
    
    // Actualizar el texto del controlador
    _controller.text = limitedValue.toString();
    
    // Notificar el cambio
    widget.onChanged(limitedValue);
  }

  // Método para mostrar un mensaje con SnackBar
  void _showMessage(String message, Color backgroundColor) {
    // Solo mostrar el mensaje si está en un contexto válido
    if (!mounted) return;
    
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: AppTheme.pureWhite,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        ),
        margin: const EdgeInsets.all(AppTheme.spacingMedium),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.minValue < widget.maxValue;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Colores según modo claro/oscuro
    final backgroundColor = isEnabled 
        ? (isDarkMode 
            ? const Color(0xFF2A2A2A) 
            : AppTheme.peachLight.withOpacity(0.3))
        : (isDarkMode 
            ? Colors.grey.shade800.withOpacity(0.3) 
            : Colors.grey.shade200.withOpacity(0.5));
    
    final buttonColor = isEnabled 
        ? AppTheme.coralMain.withOpacity(isDarkMode ? 0.9 : 0.8)
        : (isDarkMode 
            ? Colors.grey.shade700 
            : Colors.grey.shade400);
        
    final textColor = isEnabled 
        ? (isDarkMode ? AppTheme.pureWhite : AppTheme.darkGrey)
        : Theme.of(context).disabledColor;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Container(
          height: 54, // Altura incrementada ligeramente para más comodidad
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: isDarkMode 
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Botón de decremento
              _buildControlButton(
                icon: Icons.remove_rounded,
                onPressed: isEnabled && widget.value > widget.minValue 
                    ? _decrement 
                    : null,
                isLeft: true,
                backgroundColor: buttonColor,
                foregroundColor: AppTheme.pureWhite,
                isEnabled: isEnabled && widget.value > widget.minValue,
              ),
              
              // Campo de texto para entrada manual
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXSmall),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? const Color(0xFF222222) 
                        : AppTheme.pureWhite,
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      suffixText: widget.unit,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      isCollapsed: false,
                      suffixStyle: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    enabled: isEnabled,
                    onEditingComplete: () {
                      _updateValueFromText();
                      FocusScope.of(context).unfocus();
                    },
                    onSubmitted: (_) => _updateValueFromText(),
                  ),
                ),
              ),
              
              // Botón de incremento
              _buildControlButton(
                icon: Icons.add_rounded,
                onPressed: isEnabled && widget.value < widget.maxValue
                    ? _increment
                    : null,
                isLeft: false,
                backgroundColor: buttonColor,
                foregroundColor: AppTheme.pureWhite,
                isEnabled: isEnabled && widget.value < widget.maxValue,
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isLeft,
    required Color backgroundColor,
    required Color foregroundColor,
    required bool isEnabled,
  }) {
    return Material(
      color: isEnabled ? backgroundColor : backgroundColor.withOpacity(0.4),
      borderRadius: isLeft
        ? BorderRadius.only(
            topLeft: Radius.circular(AppTheme.borderRadiusLarge),
            bottomLeft: Radius.circular(AppTheme.borderRadiusLarge),
          )
        : BorderRadius.only(
            topRight: Radius.circular(AppTheme.borderRadiusLarge),
            bottomRight: Radius.circular(AppTheme.borderRadiusLarge),
          ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: isLeft
          ? BorderRadius.only(
              topLeft: Radius.circular(AppTheme.borderRadiusLarge),
              bottomLeft: Radius.circular(AppTheme.borderRadiusLarge),
            )
          : BorderRadius.only(
              topRight: Radius.circular(AppTheme.borderRadiusLarge),
              bottomRight: Radius.circular(AppTheme.borderRadiusLarge),
            ),
        splashColor: foregroundColor.withOpacity(0.1),
        highlightColor: foregroundColor.withOpacity(0.05),
        child: SizedBox(
          width: 54, // Ancho incrementado para mejor tacto
          height: 54,
          child: Icon(
            icon,
            color: isEnabled ? foregroundColor : foregroundColor.withOpacity(0.5),
            size: 24,
          ),
        ),
      ),
    );
  }
}