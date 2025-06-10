// lib/screens/meal_planner/add_to_meal_plan_screen.dart

import 'package:flutter/material.dart';
import '../../models/recipe_model.dart';
import '../../models/meal_plan_model.dart';
import '../../models/meal_type_model.dart';
import '../../services/meal_plan_service.dart';
import '../../config/theme.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_button.dart';

class AddToMealPlanScreen extends StatefulWidget {
  final Recipe? recipe;

  const AddToMealPlanScreen({
    super.key,
    this.recipe,
  });

  @override
  _AddToMealPlanScreenState createState() => _AddToMealPlanScreenState();
}

class _AddToMealPlanScreenState extends State<AddToMealPlanScreen> {
  final MealPlanService _mealPlanService = MealPlanService();
  
  // Estado
  DateTime _selectedDate = DateTime.now();
  String _selectedMealTypeId = '';
  bool _isLoading = false;
  
  // Lista de tipos de comida predefinidos
  final List<MealType> _mealTypes = MealType.getPredefinedTypes();

  @override
  void initState() {
    super.initState();
    // Seleccionar el primer tipo de comida por defecto
    if (_mealTypes.isNotEmpty) {
      _selectedMealTypeId = _mealTypes.first.id;
    }
  }

  // Añadir al plan de comidas
  Future<void> _addToMealPlan() async {
    // Verificar que tengamos receta
    if (widget.recipe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No hay receta para añadir al plan'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          ),
        ),
      );
      return;
    }
    
    // Verificar que haya seleccionado un tipo de comida
    if (_selectedMealTypeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, selecciona un tipo de comida'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          ),
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Crear el plan de comida
      final mealPlan = MealPlan(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // ID temporal
        date: _selectedDate,
        mealTypeId: _selectedMealTypeId,
        recipeId: widget.recipe!.id,
        recipe: widget.recipe,
        isCompleted: false,
      );
      
      // Guardar en la base de datos
      final mealPlanId = await _mealPlanService.addMealPlan(mealPlan);
      
      if (mealPlanId != null) {
        // Navegar de vuelta con resultado exitoso
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al añadir al plan de comidas'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Añadir al Plan de Comidas',
      ),
      body: _isLoading 
        ? Center(
            child: CircularProgressIndicator(
              color: AppTheme.coralMain,
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mostrar nombre de la receta
                if (widget.recipe != null) ...[
                  Text(
                    'Receta: ${widget.recipe!.name}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.coralMain,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                ],
                
                // Selector de fecha
                Text(
                  'Selecciona una fecha:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSmall),
                Card(
                  elevation: AppTheme.elevationSmall,
                  shadowColor: AppTheme.darkGrey.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppTheme.darkGrey.withOpacity(0.3) : AppTheme.pureWhite,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: AppTheme.coralMain,
                          onPrimary: AppTheme.pureWhite,
                          surface: isDarkMode ? const Color(0xFF2C2C2C) : AppTheme.pureWhite,
                          onSurface: isDarkMode ? AppTheme.lightGrey : AppTheme.darkGrey,
                        ),
                      ),
                      child: CalendarDatePicker(
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        onDateChanged: (date) {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingLarge),
                
                // Selector de tipo de comida
                Text(
                  'Selecciona el tipo de comida:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSmall),
                
                // Lista de tipos de comida
                Wrap(
                  spacing: AppTheme.spacingSmall,
                  runSpacing: AppTheme.spacingSmall,
                  children: _mealTypes.map((mealType) {
                    final isSelected = _selectedMealTypeId == mealType.id;
                    
                    return ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            mealType.icon,
                            size: 18,
                            color: isSelected ? AppTheme.pureWhite : AppTheme.coralMain,
                          ),
                          const SizedBox(width: 8),
                          Text(mealType.name),
                        ],
                      ),
                      selectedColor: AppTheme.coralMain,
                      backgroundColor: isDarkMode 
                          ? AppTheme.darkGrey.withOpacity(0.3) 
                          : AppTheme.peachLight.withOpacity(0.3),
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.pureWhite : (isDarkMode ? AppTheme.lightGrey : AppTheme.darkGrey),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      elevation: isSelected ? AppTheme.elevationSmall : 0,
                      shadowColor: isSelected ? AppTheme.coralMain.withOpacity(0.3) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMedium,
                        vertical: AppTheme.spacingSmall,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedMealTypeId = mealType.id;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                
                const Spacer(),
                
                // Botón para añadir
                CustomButton(
                  text: "Añadir al Plan de Comidas",
                  icon: Icons.add_rounded,
                  onPressed: _addToMealPlan,
                  type: ButtonType.primary,
                  isFullWidth: true,
                ),
              ],
            ),
          ),
    );
  }
}