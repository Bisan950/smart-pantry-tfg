import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Widget que muestra una alerta para productos próximos a caducar
/// Rediseñado con estilo minimalista con tonos coral/melocotón
class ExpiryAlert extends StatelessWidget {
  /// Título de la alerta (nombre del producto)
  final String title;
  
  /// Subtítulo (detalles adicionales)
  final String subtitle;
  
  /// Días restantes hasta la caducidad
  final int daysUntilExpiry;
  
  /// Callback cuando se toca la alerta
  final VoidCallback? onTap;
  
  /// Callback cuando se desliza para descartar
  final VoidCallback? onDismiss;
  
  /// Umbral de advertencia configurable (días)
  final int warningDays;
  
  /// Umbral crítico configurable (días)
  final int criticalDays;

  const ExpiryAlert({
    super.key,
    required this.title,
    required this.subtitle,
    required this.daysUntilExpiry,
    this.onTap,
    this.onDismiss,
    this.warningDays = 7, // Por defecto 7 días
    this.criticalDays = 3, // Por defecto 3 días
  });

  /// Determina el color de la alerta según los días restantes para caducar
  Color _getAlertColor() {
    if (daysUntilExpiry <= 0) return AppTheme.errorRed; // Caducado
    if (daysUntilExpiry <= criticalDays) return AppTheme.errorRed; // Crítico
    if (daysUntilExpiry <= warningDays) return AppTheme.warningOrange; // Advertencia
    return AppTheme.yellowAccent; // Próximo, pero no urgente
  }

  /// Obtiene el texto de la alerta según los días restantes
  String _getAlertText() {
    if (daysUntilExpiry < 0) {
      final days = -daysUntilExpiry;
      return days == 1 ? 'Caducado ayer' : 'Caducado hace $days días';
    }
    if (daysUntilExpiry == 0) return 'Caduca hoy';
    if (daysUntilExpiry == 1) return 'Caduca mañana';
    return 'Caduca en $daysUntilExpiry días';
  }

  /// Obtiene el icono según los días restantes
  IconData _getAlertIcon() {
    if (daysUntilExpiry <= 0) return Icons.error_rounded;
    if (daysUntilExpiry <= criticalDays) return Icons.warning_rounded;
    if (daysUntilExpiry <= warningDays) return Icons.access_time_rounded;
    return Icons.event_note_rounded;
  }
  
  /// Obtiene la animación para el icono de eliminación
  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: AppTheme.errorRed,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Eliminar',
            style: const TextStyle(
              color: AppTheme.pureWhite,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          const Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.pureWhite,
            size: 24,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertColor = _getAlertColor();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Dismissible(
      key: Key('expiry_alert_${title}_$daysUntilExpiry'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss?.call(),
      background: _buildDeleteBackground(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingXSmall,
          horizontal: AppTheme.spacingSmall,
        ),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: AppTheme.elevationTiny,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              gradient: LinearGradient(
                colors: [
                  alertColor.withOpacity(0.1),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.6],
              ),
              border: Border.all(
                color: alertColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                splashColor: alertColor.withOpacity(0.1),
                highlightColor: alertColor.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                  child: Row(
                    children: [
                      _buildAlertIcon(alertColor),
                      const SizedBox(width: AppTheme.spacingMedium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? AppTheme.pureWhite : AppTheme.darkGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppTheme.spacingXSmall / 2),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDarkMode 
                                    ? AppTheme.pureWhite.withOpacity(0.7) 
                                    : AppTheme.mediumGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMedium),
                      _buildExpiryBadge(context, alertColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Construye el icono de alerta con animación de pulso para casos críticos
  Widget _buildAlertIcon(Color alertColor) {
    // Si está caducado o es crítico, aplicar animación de pulso
    final isCritical = daysUntilExpiry <= criticalDays;
    
    if (isCritical) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.9, end: 1.1),
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: _buildIconContainer(alertColor),
      );
    }
    
    return _buildIconContainer(alertColor);
  }
  
  /// Construye el contenedor del icono
  Widget _buildIconContainer(Color alertColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.15),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: alertColor.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _getAlertIcon(),
        color: alertColor,
        size: 24,
      ),
    );
  }
  
  /// Construye la etiqueta de días hasta caducidad
  Widget _buildExpiryBadge(BuildContext context, Color alertColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
        boxShadow: [
          BoxShadow(
            color: alertColor.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        _getAlertText(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: alertColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}