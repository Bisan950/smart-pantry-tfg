// lib/widgets/inventory/storage_location_selector.dart
// Versión corregida con iconos existentes

import 'package:flutter/material.dart';
import '../../config/theme.dart';

class StorageLocation {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const StorageLocation({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class StorageLocationSelector extends StatelessWidget {
  final List<StorageLocation> locations;
  final String selectedLocationId;
  final Function(String) onLocationSelected;

  const StorageLocationSelector({
    super.key,
    required this.locations,
    required this.selectedLocationId,
    required this.onLocationSelected,
  });

  // Ubicaciones predefinidas actualizadas con colores del nuevo tema e iconos válidos
  static List<StorageLocation> get defaultLocations => [
    StorageLocation(
      id: 'Nevera',
      name: 'Nevera',
      icon: Icons.kitchen_rounded,
      color: const Color(0xFF64B5F6), // Azul claro
    ),
    StorageLocation(
      id: 'Congelador',
      name: 'Congelador',
      icon: Icons.ac_unit_rounded,
      color: const Color(0xFF00B4D8), // Azul intenso
    ),
    StorageLocation(
      id: 'Despensa',
      name: 'Despensa',
      // Reemplazado por un icono válido de estantería/almacén
      icon: Icons.inventory_2_rounded, 
      color: AppTheme.warningOrange,
    ),
    StorageLocation(
      id: 'Armario',
      name: 'Armario',
      icon: Icons.door_sliding_rounded,
      color: const Color(0xFF8D6E63), // Marrón
    ),
    StorageLocation(
      id: 'Especias',
      name: 'Especias',
      icon: Icons.restaurant_rounded,
      color: AppTheme.coralMain, // Usando el color principal para especias
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.spacingMedium,
            bottom: AppTheme.spacingSmall,
          ),
          child: Text(
            'Ubicación',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600, // Semibold en lugar de bold
              color: isDarkMode ? AppTheme.pureWhite : AppTheme.darkGrey,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF1E1E1E)
                : AppTheme.lightGrey.withOpacity(0.5), // Más claro, más minimalista
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge), // Más redondeado
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03), // Sombra más sutil
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingMedium,
            horizontal: AppTheme.spacingSmall,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: locations.map((location) {
                final isSelected = selectedLocationId == location.id;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSmall),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Container del icono con mejor efecto visual
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(50),
                        child: InkWell(
                          onTap: () => onLocationSelected(location.id),
                          borderRadius: BorderRadius.circular(50),
                          splashColor: location.color.withOpacity(0.2),
                          highlightColor: location.color.withOpacity(0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0), // Padding para hacer el área táctil más grande
                            child: TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 200),
                              tween: Tween<double>(
                                begin: 0.9,
                                end: isSelected ? 1.0 : 0.9,
                              ),
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 52, // Ligeramente más grande
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? location.color
                                          : isDarkMode
                                              ? const Color(0xFF2C2C2C)
                                              : Colors.grey[200],
                                      shape: BoxShape.circle,
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: location.color.withOpacity(0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        location.icon,
                                        color: isSelected
                                            ? AppTheme.pureWhite
                                            : isDarkMode
                                                ? AppTheme.pureWhite.withOpacity(0.7)
                                                : AppTheme.darkGrey,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      
                      // Espacio y texto debajo del icono
                      const SizedBox(height: 6), // Un poco más de espacio
                      SizedBox(
                        width: 64, // Ancho fijo ligeramente mayor
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isSelected
                                ? location.color
                                : isDarkMode
                                    ? AppTheme.pureWhite.withOpacity(0.8)
                                    : AppTheme.darkGrey,
                            fontSize: 12, // Ligeramente más grande
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          child: Text(
                            location.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // Indicador de selección (opcional, añade un toque visual)
                      if (isSelected)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(top: 4),
                          width: 16,
                          height: 2,
                          decoration: BoxDecoration(
                            color: location.color,
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}