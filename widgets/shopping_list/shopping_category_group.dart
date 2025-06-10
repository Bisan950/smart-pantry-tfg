import 'package:flutter/material.dart';
import '../../config/theme.dart';

class ShoppingCategoryGroup extends StatelessWidget {
  final String title;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final IconData icon;
  final Color color;

  const ShoppingCategoryGroup({
    super.key,
    required this.title,
    required this.count,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppTheme.elevationTiny,
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      child: InkWell(
        onTap: onToggleExpanded,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Row(
            children: [
              // Icono de categoría con fondo coral suave
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.peachLight,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.coralMain,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              
              // Nombre de categoría
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppTheme.darkGrey
                        : AppTheme.pureWhite,
                  ),
                ),
              ),
              
              // Contador con fondo suave
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSmall,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.yellowAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: AppTheme.darkGrey,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              
              // Icono de expandir/contraer
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                child: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.coralMain,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}