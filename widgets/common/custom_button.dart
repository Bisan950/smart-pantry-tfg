import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// CustomButton - Botón personalizado para la aplicación SmartPantry
/// 
/// Implementación simplificada con estilo minimalista y paleta coral/melocotón
class CustomButton extends StatefulWidget {
  /// Texto a mostrar en el botón
  final String text;
  
  /// Acción a ejecutar cuando se presiona el botón
  final VoidCallback? onPressed;
  
  /// Tipo de botón a mostrar
  final ButtonType type;
  
  /// Si el botón debe ocupar todo el ancho disponible
  final bool isFullWidth;
  
  /// Si se debe mostrar un indicador de carga
  final bool isLoading;
  
  /// Icono opcional para mostrar junto al texto
  final IconData? icon;
  
  /// Altura personalizada del botón
  final double? height;
  
  /// Ancho personalizado del botón (si isFullWidth es false)
  final double? width;
  
  /// Padding personalizado del botón
  final EdgeInsets? padding;
  
  /// Si el botón debe tener una sombra elevada
  final bool elevated;
  
  /// Tamaño del texto del botón
  final double? fontSize;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.isFullWidth = true,
    this.isLoading = false,
    this.icon,
    this.height,
    this.width,
    this.padding,
    this.elevated = true,
    this.fontSize,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Obtener configuración de colores basada en el tipo de botón
    final ButtonConfig config = _getButtonConfig();
    
    // Construir el contenedor principal del botón
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null && !widget.isLoading) {
          setState(() => _isPressed = true);
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null && !widget.isLoading) {
          setState(() => _isPressed = false);
        }
      },
      onTapCancel: () {
        if (widget.onPressed != null && !widget.isLoading) {
          setState(() => _isPressed = false);
        }
      },
      child: _buildButtonContainer(config),
    );
  }
  
  /// Configura los colores y estilos según el tipo de botón
  ButtonConfig _getButtonConfig() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    switch (widget.type) {
      case ButtonType.primary:
        return ButtonConfig(
          background: AppTheme.coralMain,
          foreground: AppTheme.pureWhite,
          splash: Colors.white.withOpacity(0.2),
          border: null,
        );
        
      case ButtonType.secondary:
        return ButtonConfig(
          background: AppTheme.yellowAccent,
          foreground: AppTheme.darkGrey,
          splash: Colors.black.withOpacity(0.05),
          border: null,
        );
        
      case ButtonType.text:
        return ButtonConfig(
          background: Colors.transparent,
          foreground: AppTheme.coralMain,
          splash: AppTheme.coralMain.withOpacity(0.05),
          border: null,
        );
        
      case ButtonType.outline:
        return ButtonConfig(
          background: Colors.transparent,
          foreground: AppTheme.coralMain,
          splash: AppTheme.coralMain.withOpacity(0.05),
          border: AppTheme.coralMain,
        );
        
      case ButtonType.danger:
        return ButtonConfig(
          background: AppTheme.errorRed,
          foreground: AppTheme.pureWhite,
          splash: Colors.white.withOpacity(0.2),
          border: null,
        );
    }
  }
  
  /// Construye el contenedor principal del botón con animación de escala
  Widget _buildButtonContainer(ButtonConfig config) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: widget.isFullWidth ? double.infinity : widget.width,
      height: widget.height,
      transform: _isPressed ? (Matrix4.identity()..scale(0.98)) : Matrix4.identity(),
      child: _buildButton(config),
    );
  }
  
  /// Construye el botón con su contenido
  Widget _buildButton(ButtonConfig config) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final buttonPadding = widget.padding ?? const EdgeInsets.symmetric(
      horizontal: AppTheme.spacingLarge,
      vertical: AppTheme.spacingMedium,
    );
    
    // Para botones tipo text, usamos un TextButton
    if (widget.type == ButtonType.text) {
      return TextButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        style: TextButton.styleFrom(
          foregroundColor: config.foreground,
          padding: buttonPadding,
        ),
        child: _buildButtonContent(config.foreground),
      );
    }
    
    // Para los demás botones, construimos un contenedor personalizado
    return Ink(
      decoration: BoxDecoration(
        color: isEnabled ? config.background : config.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: config.border != null 
            ? Border.all(color: config.border!, width: 1.5) 
            : null,
        boxShadow: widget.elevated && config.background.opacity > 0
            ? [
                BoxShadow(
                  color: config.background.withOpacity(0.3),
                  blurRadius: _isPressed ? 3 : 5,
                  offset: _isPressed ? const Offset(0, 1) : const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: widget.isLoading ? null : widget.onPressed,
        splashColor: config.splash,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        child: Container(
          width: widget.isFullWidth ? double.infinity : widget.width,
          height: widget.height,
          padding: buttonPadding,
          alignment: Alignment.center,
          child: _buildButtonContent(config.foreground),
        ),
      ),
    );
  }
  
  /// Construye el contenido del botón (texto, icono o indicador de carga)
  Widget _buildButtonContent(Color textColor) {
    if (widget.isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 20, color: textColor),
          const SizedBox(width: AppTheme.spacingSmall),
          Text(
            widget.text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: widget.fontSize ?? 16,
            ),
          ),
        ],
      );
    }

    return Text(
      widget.text,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
        fontSize: widget.fontSize ?? 16,
      ),
    );
  }
}

/// Configuración de color para cada tipo de botón
class ButtonConfig {
  final Color background;
  final Color foreground;
  final Color splash;
  final Color? border;
  
  ButtonConfig({
    required this.background,
    required this.foreground,
    required this.splash,
    this.border,
  });
}

/// Tipos de botón disponibles en la aplicación
enum ButtonType {
  primary,   // Coral - Para acciones principales (login, registro, confirmar)
  secondary, // Amarillo - Para acciones secundarias (añadir, guardar)
  text,      // Solo texto coral - Para enlaces y acciones terciarias
  outline,   // Solo borde coral - Para alternar estados o acciones neutrales
  danger,    // Rojo - Para acciones destructivas (eliminar, cancelar suscripción)
}