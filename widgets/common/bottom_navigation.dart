// lib/widgets/common/bottom_navigation.dart - Versión corregida

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';

class BottomNavigationItem {
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final bool hasBadge;

  BottomNavigationItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.hasBadge = false,
  });
}

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationItem> items;
  final bool showLabels;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : AppTheme.pureWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8.0,
            horizontal: 8.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              items.length,
              (index) => _buildNavItem(
                context: context, 
                item: items[index], 
                index: index,
                isSelected: currentIndex == index,
                isDarkMode: isDarkMode,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required BottomNavigationItem item,
    required int index,
    required bool isSelected,
    required bool isDarkMode,
  }) {
    // Importante: Cada item debe tener su propio GestureDetector independiente
    return Expanded(
      child: GestureDetector(
        // Captura el tap incluso si ocurre ligeramente fuera del icono visible
        behavior: HitTestBehavior.opaque,
        // CAMBIO IMPORTANTE: Captura y maneja el tap en cada elemento
        onTap: () {
          // Proporcionar feedback háptico para mejorar la experiencia
          HapticFeedback.selectionClick();
          
          // Llamar a la función onTap con el índice del elemento
          onTap(index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDarkMode 
                    ? AppTheme.coralMain.withOpacity(0.15) 
                    : AppTheme.peachLight.withOpacity(0.4))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected 
                        ? (item.activeIcon ?? item.icon)  // Usar activeIcon si existe, o icon como fallback
                        : item.icon,
                    color: isSelected 
                        ? AppTheme.coralMain 
                        : AppTheme.mediumGrey,
                    size: 24,
                  ),
                  if (item.hasBadge)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode 
                                ? const Color(0xFF1E1E1E) 
                                : AppTheme.pureWhite,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              if (showLabels) ...[
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected 
                        ? AppTheme.coralMain 
                        : AppTheme.mediumGrey,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}