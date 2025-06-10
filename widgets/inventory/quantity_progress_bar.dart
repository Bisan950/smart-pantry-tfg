import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Widget que muestra una barra de progreso para visualizar la cantidad restante de un producto
/// Rediseñado con estilo minimalista con tonos coral/melocotón
class QuantityProgressBar extends StatelessWidget {
  /// La cantidad actual del producto
  final double currentQuantity;
  
  /// La cantidad máxima que puede tener el producto (cuando está lleno/nuevo)
  final double maxQuantity;
  
  /// Unidad de medida (para mostrar en el texto)
  final String unit;
  
  /// Si se debe mostrar el texto con la cantidad numérica
  final bool showText;
  
  /// Altura de la barra de progreso
  final double height;
  
  /// Si se debe mostrar el porcentaje
  final bool showPercentage;
  
  /// Callback cuando se toca la barra
  final VoidCallback? onTap;

  const QuantityProgressBar({
    super.key,
    required this.currentQuantity,
    required this.maxQuantity,
    required this.unit,
    this.showText = true,
    this.height = 12.0, // Incrementado ligeramente para mejor visibilidad
    this.showPercentage = true,
    this.onTap,
  });

  /// Calcula el porcentaje de cantidad restante
  double get percentRemaining {
    if (maxQuantity <= 0) return 1.0; // Si no hay máximo, se considera 100%
    return (currentQuantity / maxQuantity).clamp(0.0, 1.0);
  }
  
  /// Determina el color según el porcentaje
  Color _getProgressColor() {
    if (percentRemaining <= 0.25) {
      return AppTheme.errorRed;
    } else if (percentRemaining <= 0.5) {
      return AppTheme.warningOrange;
    } else {
      return AppTheme.softTeal;
    }
  }

  /// Determina el icono según el porcentaje
  IconData _getStatusIcon() {
    if (percentRemaining <= 0.25) {
      return Icons.error_outline_rounded;
    } else if (percentRemaining <= 0.5) {
      return Icons.warning_amber_rounded;
    } else {
      return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode 
        ? const Color(0xFF2A2A2A) 
        : AppTheme.peachLight.withOpacity(0.3);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        splashColor: AppTheme.coralMain.withOpacity(0.1),
        highlightColor: AppTheme.coralMain.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingXSmall,
            horizontal: AppTheme.spacingXSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showText) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(),
                          size: 16,
                          color: _getProgressColor(),
                        ),
                        const SizedBox(width: AppTheme.spacingXSmall),
                        Text(
                          'Cantidad restante',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (showPercentage)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSmall,
                          vertical: AppTheme.spacingXSmall / 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getProgressColor().withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                        ),
                        child: Text(
                          '${(percentRemaining * 100).toInt()}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _getProgressColor(),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSmall),
              ],
              
              // Contenedor exterior con sombra sutil
              Container(
                height: height + 4, // Ajuste para el padding interno
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular((height + 4) / 2),
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
                padding: const EdgeInsets.all(2), // Padding para el efecto de borde
                child: Stack(
                  children: [
                    // Fondo de la barra con radio redondeado mayor
                    Container(
                      height: height,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    ),
                    // Barra de progreso con animación
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: height,
                      width: percentRemaining * MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getProgressColor(),
                            _getProgressColor().withOpacity(0.8),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(height / 2),
                        boxShadow: [
                          BoxShadow(
                            color: _getProgressColor().withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              if (showText) ...[
                const SizedBox(height: AppTheme.spacingSmall),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$currentQuantity / $maxQuantity $unit',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Toca para editar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumGrey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}