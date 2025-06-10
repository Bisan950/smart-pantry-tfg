import 'package:flutter/material.dart';
import '../../config/theme.dart';

class RecipeNutritionCard extends StatelessWidget {
  final int calories;
  final Map<String, dynamic> nutrition;

  const RecipeNutritionCard({
    super.key,
    required this.calories,
    required this.nutrition,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: AppTheme.elevationSmall,
      color: isDarkMode
          ? const Color(0xFF2C2C2C)
          : AppTheme.peachLight.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calorías
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_fire_department_rounded, 
                  color: AppTheme.coralMain
                ),
                const SizedBox(width: 8),
                Text(
                  '$calories kcal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.coralMain,
                  ),
                ),
                Text(
                  ' por porción',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? AppTheme.lightGrey : AppTheme.darkGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            
            // Detalles de nutrición
            if (nutrition.isNotEmpty) ...[
              const Text(
                'Información nutricional detallada:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              
              // Mostrar cada nutriente en orden
              ...['proteins', 'carbs', 'fats', 'fiber'].where((key) => nutrition.containsKey(key)).map((key) {
                final value = nutrition[key];
                String label;
                Color color;
                
                switch (key) {
                  case 'proteins':
                    label = 'Proteínas';
                    color = const Color(0xFF5B8CFF); // Azul más moderno
                    break;
                  case 'carbs':
                    label = 'Carbohidratos';
                    color = AppTheme.yellowAccent;
                    break;
                  case 'fats':
                    label = 'Grasas';
                    color = AppTheme.coralMain;
                    break;
                  case 'fiber':
                    label = 'Fibra';
                    color = AppTheme.successGreen;
                    break;
                  default:
                    label = key;
                    color = AppTheme.mediumGrey;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.2),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$label:',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const Spacer(),
                          Text(
                            '$value g',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Barra de progreso
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                        child: LinearProgressIndicator(
                          value: _getNormalizedValue(key, value),
                          backgroundColor: color.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              Center(
                child: Text(
                  'No hay información nutricional disponible',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppTheme.mediumGrey,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Normalizar el valor para la barra de progreso
  double _getNormalizedValue(String nutrient, dynamic value) {
    // Valores máximos aproximados para cada nutriente
    const Map<String, double> maxValues = {
      'proteins': 100, // 100g de proteína es mucho para una comida
      'carbs': 200,    // 200g de carbohidratos es un máximo razonable
      'fats': 80,      // 80g de grasa sería alto
      'fiber': 50,     // 50g de fibra sería muy alto
    };
    
    if (value is num) {
      final max = maxValues[nutrient] ?? 100;
      return (value / max).clamp(0.05, 1.0); // Mínimo 5% para visibilidad
    }
    
    return 0.1; // Valor por defecto si no se puede normalizar
  }
}