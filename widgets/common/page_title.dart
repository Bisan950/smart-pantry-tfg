import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// PageTitle - Título consistente para todas las páginas de SmartPantry
/// 
/// Proporciona un estilo unificado para los títulos de las páginas,
/// con opciones para subtítulos, iconos y acciones adicionales.
class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget>? actions;
  final bool divider;
  final Color? iconColor;
  final double? iconSize;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const PageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions,
    this.divider = true,
    this.iconColor,
    this.iconSize = 28,
    this.titleStyle,
    this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: iconSize,
                color: iconColor ?? Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingSmall),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: titleStyle ?? Theme.of(context).textTheme.headlineMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppTheme.spacingXSmall),
                    Text(
                      subtitle!,
                      style: subtitleStyle ?? Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              ...actions!,
            ],
          ],
        ),
        if (divider) ...[
          const SizedBox(height: AppTheme.spacingMedium),
          Divider(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            thickness: 1.0,
          ),
          const SizedBox(height: AppTheme.spacingSmall),
        ],
      ],
    );
  }
}