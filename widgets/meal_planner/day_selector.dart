import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Modelo para cada ítem de día en el selector
class DayItem {
  final DateTime date;
  final String label;
  final String shortLabel;

  DayItem({
    required this.date,
    required this.label,
    required this.shortLabel,
  });
}

/// Widget para seleccionar un día en el planificador de comidas
class DaySelector extends StatelessWidget {
  final List<DayItem> days;
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const DaySelector({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Calcular el ancho del ítem según el espacio disponible
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 40) / 5; // Mostrar aprox. 5 ítems visibles
    
    return SizedBox(
      height: 70, // Altura fija para prevenir desbordamientos
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = DateUtils.isSameDay(day.date, selectedDate);
          
          // Determinar colores según la selección y el tema actual
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          final backgroundColor = isSelected 
              ? AppTheme.coralMain 
              : Colors.transparent;
          final textColor = isSelected 
              ? AppTheme.pureWhite 
              : Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.darkGrey;
          final borderColor = isSelected 
              ? AppTheme.coralMain 
              : isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
          
          return Container(
            width: itemWidth,
            margin: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () => onDateSelected(day.date),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: Border.all(
                    color: borderColor,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppTheme.coralMain.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0, // Reducido
                  vertical: 8.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Día de la semana
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        day.label,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12.0, // Reducido
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    // Día del mes
                    Container(
                      width: 28.0,
                      height: 28.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected 
                            ? AppTheme.pureWhite 
                            : isDarkMode ? Colors.grey[800] : AppTheme.peachLight.withOpacity(0.3),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ] : null,
                      ),
                      child: Center(
                        child: Text(
                          '${day.date.day}',
                          style: TextStyle(
                            color: isSelected 
                                ? AppTheme.coralMain 
                                : isDarkMode ? AppTheme.pureWhite : AppTheme.darkGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}