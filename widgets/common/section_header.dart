import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// SectionHeader - Encabezado de sección para SmartPantry
/// 
/// Proporciona un encabezado consistente para las distintas secciones dentro de una página,
/// con opciones para botones de acción, iconos y visualización de totales.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final IconData? icon; // Nuevo: Icono para mostrar junto al título
  final int? count;
  final bool showDivider;
  final TextStyle? titleStyle;
  final TextStyle? actionTextStyle;
  final Color? iconColor; // Nuevo: Color personalizable para el icono

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionPressed,
    this.actionIcon,
    this.icon, // Añadido como parámetro opcional
    this.count,
    this.showDivider = false,
    this.titleStyle,
    this.actionTextStyle,
    this.iconColor, // Añadido como parámetro opcional
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Título con posible contador e icono - uso de Expanded para evitar desbordamientos
            Expanded(
              flex: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min, // Minimiza el espacio usado
                children: [
                  // Icono (si se proporciona)
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 20,
                      color: iconColor ?? Theme.of(context).textTheme.titleLarge?.color,
                    ),
                    const SizedBox(width: 8), // Espacio entre el icono y el texto
                  ],
                  
                  // Título con elipsis si es demasiado largo
                  Flexible(
                    child: Text(
                      title,
                      style: titleStyle ?? Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  
                  // Contador de elementos (si se proporciona)
                  if (count != null) ...[
                    const SizedBox(width: AppTheme.spacingSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSmall,
                        vertical: AppTheme.spacingXSmall / 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                      ),
                      child: Text(
                        count.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Botón de acción (si se proporciona)
            if (actionText != null && onActionPressed != null)
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 0, // Permite que se encoja si es necesario
                      maxWidth: 150, // Limita el ancho máximo
                    ),
                    child: TextButton(
                      onPressed: onActionPressed,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        minimumSize: Size.zero, // No fuerza un tamaño mínimo
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Importante para evitar desbordamiento
                        children: [
                          // Texto del botón con elipsis si es necesario
                          Flexible(
                            child: Text(
                              actionText!,
                              style: actionTextStyle ?? TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 12.0, // Reducido para evitar desbordamiento
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (actionIcon != null) ...[
                            const SizedBox(width: 4.0), // Reducido desde AppTheme.spacingXSmall
                            Icon(
                              actionIcon,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        
        // Divisor opcional
        if (showDivider) ...[
          const SizedBox(height: AppTheme.spacingSmall),
          Divider(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            thickness: 1.0,
          ),
        ],
      ],
    );
  }
}