import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/meal_plan_model.dart';
import '../../models/meal_type_model.dart';
import '../../models/recipe_model.dart';
import '../../models/product_model.dart';
import '../../models/product_location_model.dart';
import '../../services/inventory_service.dart';
import '../../services/meal_plan_service.dart';
import '../../services/gemini_recipe_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/meal_planner/day_selector.dart';
import '../../widgets/meal_planner/meal_plan_card.dart';
import '../../providers/shopping_list_provider.dart';

class AIMealPlanScreen extends StatefulWidget {
  const AIMealPlanScreen({super.key});

  @override
  State<AIMealPlanScreen> createState() => _AIMealPlanScreenState();
}

class _AIMealPlanScreenState extends State<AIMealPlanScreen> {
  // Referencias a servicios
  final InventoryService _inventoryService = InventoryService();
  final MealPlanService _mealPlanService = MealPlanService();
  final GeminiRecipeService _geminiService = GeminiRecipeService();
  
  // Estado para la fecha seleccionada
  late DateTime _selectedDate;
  
  // Estado para los tipos de comida seleccionados
  final List<String> _selectedMealTypeIds = [];
  
  // Lista de tipos de comida disponibles
  final List<MealType> _mealTypes = MealType.getPredefinedTypes();
  
  // Estado para las recetas generadas
  List<MealPlan> _generatedMealPlans = [];
  
  // Estado de carga
  bool _isLoading = false;
  
  // Estado para las preferencias de generación
  bool _prioritizeExpiringProducts = true;
  String _selectedCuisine = 'Cualquiera';
  
  // Lista de cocinas disponibles
  final List<String> _cuisines = [
    'Cualquiera',
    'Española',
    'Italiana',
    'Mexicana',
    'Asiática',
    'Mediterránea',
    'Vegetariana',
    'Vegana',
  ];
  
  // Lista de productos del inventario (para mostrar resumen)
  List<Product> _inventoryProducts = [];
  List<Product> _expiringProducts = [];
  
  // Mensaje de error o información
  String? _message;
  bool _isErrorMessage = false;

  @override
  void initState() {
    super.initState();
    
    // Inicializar la fecha seleccionada al día actual
    _selectedDate = DateTime.now();
    
    // Por defecto, seleccionar desayuno, comida y cena
    _selectedMealTypeIds.addAll(['breakfast', 'lunch', 'dinner']);
    
    // Cargar productos del inventario
    _loadInventoryProducts();
  }
  
  // Cargar productos del inventario
  Future<void> _loadInventoryProducts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Obtener todos los productos
      final products = await _inventoryService.getAllProducts();
      
      // Filtrar productos en el inventario
      final inventoryProducts = products.where((product) => 
        product.productLocation == ProductLocation.inventory || 
        product.productLocation == ProductLocation.both
      ).toList();
      
      // Obtener productos a punto de caducar
      final expiringProducts = await _inventoryService.getExpiringProducts(5);
      
      setState(() {
        _inventoryProducts = inventoryProducts;
        _expiringProducts = expiringProducts;
      });
    } catch (e) {
      _setMessage('Error al cargar productos del inventario: $e', true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Generar planes de comida con IA
  Future<void> _generateMealPlans() async {
    // Validar que se haya seleccionado al menos un tipo de comida
    if (_selectedMealTypeIds.isEmpty) {
      _setMessage('Por favor, selecciona al menos un tipo de comida', true);
      return;
    }
    
    // Validar que haya productos en el inventario
    if (_inventoryProducts.isEmpty) {
      _setMessage('No hay productos en el inventario. Añade algunos productos antes de generar un plan de comidas.', true);
      return;
    }
    
    setState(() {
      _isLoading = true;
      _message = 'Generando planes de comida con IA...';
      _isErrorMessage = false;
      _generatedMealPlans = [];
    });
    
    try {
      // Generar recetas utilizando el servicio de Gemini
      List<Recipe> recipes;
      
      if (_prioritizeExpiringProducts && _expiringProducts.isNotEmpty) {
        // Generar recetas priorizando productos que están por caducar
        recipes = await _geminiService.generateRecipesFromIngredients(
          availableIngredients: _inventoryProducts,
          expiringIngredients: _expiringProducts,
          cuisine: _selectedCuisine == 'Cualquiera' ? null : _selectedCuisine,
          numberOfRecipes: _selectedMealTypeIds.length,
        );
      } else {
        // Generar recetas normales
        recipes = await _geminiService.generateRecipesFromIngredients(
          availableIngredients: _inventoryProducts,
          cuisine: _selectedCuisine == 'Cualquiera' ? null : _selectedCuisine,
          numberOfRecipes: _selectedMealTypeIds.length,
        );
      }
      
      // Verificar si se generaron recetas
      if (recipes.isEmpty) {
        _setMessage('No se pudieron generar recetas con los ingredientes disponibles. Intenta cambiar las preferencias o añade más productos a tu inventario.', true);
        return;
      }
      
      // Actualizar estado con los planes generados
      final List<MealPlan> mealPlans = [];
      
      // Asignar recetas a tipos de comida
      for (int i = 0; i < _selectedMealTypeIds.length; i++) {
        final mealTypeId = _selectedMealTypeIds[i];
        // Si hay menos recetas que tipos de comida, usar el índice circular
        final recipeIndex = i % recipes.length;
        
        mealPlans.add(MealPlan(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(), // ID temporal
          date: _selectedDate,
          mealTypeId: mealTypeId,
          recipeId: recipes[recipeIndex].id, // Añadido el recipeId requerido
          recipe: recipes[recipeIndex],      // Recipe ahora es opcional pero lo incluimos
          isCompleted: false,
        ));
      }
      
      setState(() {
        _generatedMealPlans = mealPlans;
        _message = 'Se han generado ${mealPlans.length} recetas para tu plan de comidas';
        _isErrorMessage = false;
      });
    } catch (e) {
      _setMessage('Error al generar plan de comidas: $e', true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Guardar los planes de comida generados
  Future<void> _saveMealPlans() async {
    if (_generatedMealPlans.isEmpty) {
      _setMessage('No hay planes de comida para guardar. Genera un plan primero.', true);
      return;
    }
    
    setState(() {
      _isLoading = true;
      _message = 'Guardando planes de comida...';
      _isErrorMessage = false;
    });
    
    try {
      // Guardar los planes de comida en la base de datos
      final ids = await _mealPlanService.saveMealPlans(_generatedMealPlans);
      
      if (ids.isEmpty) {
        _setMessage('No se pudo guardar el plan de comidas. Inténtalo de nuevo.', true);
        return;
      }
      
      // Actualizar estado después de guardar
      setState(() {
        _message = 'Plan de comidas guardado correctamente';
        _isErrorMessage = false;
      });
      
      // Volver a la pantalla anterior después de un breve retraso
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      _setMessage('Error al guardar plan de comidas: $e', true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Añadir ingredientes faltantes a la lista de compras
  // Fixed method to add missing ingredients to shopping list
Future<void> _addMissingToShoppingList() async {
  if (_generatedMealPlans.isEmpty) {
    _setMessage('No hay planes de comida para añadir a la lista de compras. Genera un plan primero.', true);
    return;
  }
  
  setState(() {
    _isLoading = true;
    _message = 'Añadiendo ingredientes faltantes a la lista de compras...';
    _isErrorMessage = false;
  });
  
  try {
    // Create a ShoppingListProvider instance directly
    // Since your provider doesn't seem to require external dependencies in constructor
    final shoppingProvider = ShoppingListProvider();
    
    // Para cada receta, añadir los ingredientes faltantes a la lista de compras
    int successCount = 0;
    List<String> addedIngredients = [];
    
    for (final mealPlan in _generatedMealPlans) {
      // Verificar que recipe no sea nulo
      if (mealPlan.recipe != null) {
        // Instead of using the meal plan service method, directly add ingredients
        // using the shopping provider methods
        final recipe = mealPlan.recipe!;
        
        // Get missing ingredients (those not available and not optional)
        final missingIngredients = recipe.ingredients
            .where((ingredient) => !ingredient.isAvailable && !ingredient.isOptional)
            .toList();
        
        // Add each missing ingredient to shopping list
        for (final ingredient in missingIngredients) {
          try {
            final shoppingItem = ShoppingItem(
              id: DateTime.now().millisecondsSinceEpoch.toString() + ingredient.name.hashCode.toString(),
              name: ingredient.name,
              quantity: ingredient.quantity.toInt(),
              unit: ingredient.unit,
              category: _getCategoryFromIngredient(ingredient.name),
              imageUrl: '',
              location: 'Despensa',
              priority: 2, // Normal priority
              isSuggested: false,
              isPurchased: false,
            );
            
            await shoppingProvider.addItem(shoppingItem);
            addedIngredients.add(ingredient.name);
            
          } catch (e) {
            print('Error adding ingredient ${ingredient.name}: $e');
          }
        }
        
        if (missingIngredients.isNotEmpty) {
          successCount++;
        }
      }
    }
    
    // Eliminar duplicados
    addedIngredients = addedIngredients.toSet().toList();
    
    if (successCount == 0) {
      _setMessage('Todos los ingredientes ya están disponibles en tu inventario o lista de compras.', false);
    } else {
      _setMessage(
        'Se han añadido ${addedIngredients.length} ingredientes a tu lista de compras para $successCount recetas.\n'
        'Ingredientes: ${addedIngredients.take(5).join(", ")}${addedIngredients.length > 5 ? "..." : ""}',
        false
      );
    }
  } catch (e) {
    _setMessage('Error al añadir ingredientes a la lista de compras: $e', true);
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

// Helper method to categorize ingredients
String _getCategoryFromIngredient(String ingredientName) {
  final name = ingredientName.toLowerCase();
  
  if (name.contains('carne') || name.contains('pollo') || name.contains('pescado') || 
      name.contains('ternera') || name.contains('cerdo') || name.contains('jamón')) {
    return 'Carnes y Pescados';
  } else if (name.contains('leche') || name.contains('queso') || name.contains('yogur') || 
             name.contains('mantequilla') || name.contains('nata')) {
    return 'Lácteos';
  } else if (name.contains('tomate') || name.contains('cebolla') || name.contains('ajo') || 
             name.contains('lechuga') || name.contains('zanahoria') || name.contains('pepino')) {
    return 'Verduras';
  } else if (name.contains('manzana') || name.contains('plátano') || name.contains('naranja') || 
             name.contains('pera') || name.contains('uva')) {
    return 'Frutas';
  } else if (name.contains('arroz') || name.contains('pasta') || name.contains('pan') || 
             name.contains('harina') || name.contains('cereales')) {
    return 'Cereales y Granos';
  } else if (name.contains('aceite') || name.contains('vinagre') || name.contains('sal') || 
             name.contains('pimienta') || name.contains('especias')) {
    return 'Condimentos';
  } else {
    return 'General';
  }
}
  
  // Probar conexión con Gemini
  Future<void> _testGeminiConnection() async {
    setState(() {
      _isLoading = true;
      _message = 'Probando conexión con Gemini AI...';
      _isErrorMessage = false;
    });
    
    try {
      final isConnected = await _geminiService.testGeminiConnection();
      
      setState(() {
        if (isConnected) {
          _message = '✅ Conexión exitosa con Gemini AI. Revisa la consola para más detalles.';
          _isErrorMessage = false;
        } else {
          _message = '❌ Error al conectar con Gemini AI. Revisa la consola para más detalles.';
          _isErrorMessage = true;
        }
      });
    } catch (e) {
      setState(() {
        _message = '❌ Error inesperado al probar conexión: $e';
        _isErrorMessage = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Método para establecer mensaje de feedback
  void _setMessage(String message, bool isError) {
    setState(() {
      _message = message;
      _isErrorMessage = isError;
    });
  }

  // Alternar selección de tipo de comida
  void _toggleMealType(String mealTypeId) {
    setState(() {
      if (_selectedMealTypeIds.contains(mealTypeId)) {
        _selectedMealTypeIds.remove(mealTypeId);
      } else {
        _selectedMealTypeIds.add(mealTypeId);
      }
    });
  }
  
  // Método para obtener el nombre del tipo de comida por ID
  String _getMealTypeName(String mealTypeId) {
    final mealType = _mealTypes.firstWhere(
      (type) => type.id == mealTypeId,
      orElse: () => MealType(id: mealTypeId, name: mealTypeId, icon: Icons.question_mark),
    );
    return mealType.name;
  }
  
  // Método para obtener el icono del tipo de comida por ID
  IconData _getMealTypeIcon(String mealTypeId) {
    final mealType = _mealTypes.firstWhere(
      (type) => type.id == mealTypeId,
      orElse: () => MealType(id: mealTypeId, name: mealTypeId, icon: Icons.question_mark),
    );
    return mealType.icon;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Generar Plan con IA',
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(
              child: LoadingIndicator(
                message: 'Generando plan de comidas...',
              ),
            )
          : _buildContent(),
      ),
      bottomNavigationBar: _generatedMealPlans.isNotEmpty
        ? _buildBottomActions()
        : null,
    );
  }
  
  Widget _buildContent() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de fecha
            const SectionHeader(
              title: 'Fecha para el plan',
              icon: Icons.calendar_today_rounded,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildDateSelector(),
            const SizedBox(height: AppTheme.spacingMedium),
            
            // Sección de tipos de comida
            const SectionHeader(
              title: 'Tipos de comida',
              icon: Icons.restaurant_menu_rounded,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildMealTypeSelection(),
            const SizedBox(height: AppTheme.spacingMedium),
            
            // Secció preferencias
            const SectionHeader(
              title: 'Preferencias',
              icon: Icons.tune_rounded,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildPreferences(),
            const SizedBox(height: AppTheme.spacingMedium),
            
            // Sección de productos disponibles
            SectionHeader(
              title: 'Productos disponibles (${_inventoryProducts.length})',
              icon: Icons.inventory_2_rounded,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildProductsSummary(),
            const SizedBox(height: AppTheme.spacingMedium),
            
            // Botón para probar conexión
            CustomButton(
              text: "Probar conexión con Gemini",
              icon: Icons.power_rounded,
              onPressed: _testGeminiConnection,
              type: ButtonType.outline,
              isFullWidth: true,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            
            // Botón para generar plan
            if (_generatedMealPlans.isEmpty)
              CustomButton(
                text: "Generar Plan de Comidas",
                icon: Icons.smart_toy_rounded,
                onPressed: _generateMealPlans,
                type: ButtonType.primary,
                isFullWidth: true,
              ),
              
            // Mostrar mensaje de error o info
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingMedium),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                  decoration: BoxDecoration(
                    color: _isErrorMessage 
                        ? AppTheme.errorRed.withAlpha(26) // 0.1 * 255 ≈ 26
                        : AppTheme.successGreen.withAlpha(26),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    border: Border.all(
                      color: _isErrorMessage ? AppTheme.errorRed : AppTheme.successGreen,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isErrorMessage 
                            ? Icons.error_outline_rounded 
                            : Icons.check_circle_outline_rounded,
                        color: _isErrorMessage ? AppTheme.errorRed : AppTheme.successGreen,
                      ),
                      const SizedBox(width: AppTheme.spacingSmall),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _isErrorMessage ? AppTheme.errorRed : AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
            // Mostrar planes generados
            if (_generatedMealPlans.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingMedium),
              const SectionHeader(
                title: 'Plan de Comidas Generado',
                icon: Icons.dining_rounded,
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              ..._buildGeneratedMealPlans(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDateSelector() {
    // Crear lista de días para el selector
    final List<DayItem> days = [];
    final now = DateTime.now();
    
    // Obtener 14 días desde hoy
    for (int i = 0; i < 14; i++) {
      final date = now.add(Duration(days: i));
      days.add(_createDayItem(date));
    }
    
    return ClipRect(
      child: SizedBox(
        height: 70,
        child: DaySelector(
          days: days,
          selectedDate: _selectedDate,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
        ),
      ),
    );
  }

  DayItem _createDayItem(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    String label;
    String shortLabel;
    if (targetDate.isAtSameMomentAs(today)) {
      label = 'Hoy';
      shortLabel = 'Hoy';
    } else if (targetDate.isAtSameMomentAs(tomorrow)) {
      label = 'Mañana';
      shortLabel = 'Mañ';  // Acortado para evitar desbordamiento
    } else {
      // Nombres de los días en español
      final weekdayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      final shortWeekdayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      // Ajustamos para que lunes sea 0 y domingo sea 6
      final weekday = (date.weekday - 1) % 7;
      label = weekdayNames[weekday];
      shortLabel = shortWeekdayNames[weekday];
    }

    // Añadir el día del mes al shortLabel para mejor identificación
    shortLabel = '$shortLabel ${date.day}';

    return DayItem(
      date: date,
      label: label,
      shortLabel: shortLabel,
    );
  }
  
  Widget _buildMealTypeSelection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Wrap(
      spacing: AppTheme.spacingSmall,
      runSpacing: AppTheme.spacingSmall,
      children: _mealTypes.map((mealType) {
        final isSelected = _selectedMealTypeIds.contains(mealType.id);
        
        return FilterChip(
          selected: isSelected,
          backgroundColor: isDarkMode ? AppTheme.darkGrey.withOpacity(0.3) : AppTheme.lightGrey,
          selectedColor: AppTheme.coralMain.withOpacity(0.9),
          labelStyle: TextStyle(
            color: isSelected ? AppTheme.pureWhite : (isDarkMode ? AppTheme.lightGrey : AppTheme.darkGrey),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          elevation: isSelected ? AppTheme.elevationSmall : 0,
          shadowColor: isSelected ? AppTheme.coralMain.withOpacity(0.3) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mealType.icon,
                size: 16,
                color: isSelected ? AppTheme.pureWhite : (isDarkMode ? AppTheme.lightGrey : AppTheme.coralMain),
              ),
              const SizedBox(width: 4),
              Text(mealType.name),
            ],
          ),
          onSelected: (selected) {
            _toggleMealType(mealType.id);
          },
        );
      }).toList(),
    );
  }
  
  Widget _buildPreferences() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Switch para priorizar productos a punto de caducar
        SwitchListTile(
          title: const Text('Priorizar productos a punto de caducar'),
          subtitle: Text(
            _expiringProducts.isEmpty 
              ? 'No hay productos a punto de caducar' 
              : '${_expiringProducts.length} productos caducarán pronto',
            style: TextStyle(
              color: _expiringProducts.isEmpty 
                  ? (isDarkMode ? AppTheme.lightGrey : AppTheme.darkGrey) 
                  : AppTheme.coralMain,
              fontSize: 12,
            ),
          ),
          value: _prioritizeExpiringProducts,
          activeColor: AppTheme.coralMain,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _prioritizeExpiringProducts = value;
            });
          },
        ),
        
        const SizedBox(height: AppTheme.spacingSmall),
        
        // Selector de tipo de cocina
        const Text(
          'Tipo de cocina:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.spacingXSmall),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkGrey.withOpacity(0.3) : AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSmall),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedCuisine,
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: AppTheme.coralMain,
              ),
              dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : AppTheme.pureWhite,
              items: _cuisines.map((cuisine) {
                return DropdownMenuItem<String>(
                  value: cuisine,
                  child: Text(
                    cuisine,
                    style: TextStyle(
                      color: cuisine == _selectedCuisine ? AppTheme.coralMain : null,
                      fontWeight: cuisine == _selectedCuisine ? FontWeight.bold : null,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCuisine = value;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildProductsSummary() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_inventoryProducts.isEmpty) {
      return EmptyStateWidget(
        title: 'No hay productos en el inventario',
        message: 'Añade productos a tu inventario para poder generar un plan de comidas.',
        icon: Icons.inventory_2_outlined,
        buttonText: 'Ir al Inventario',
        onButtonPressed: () {
          Navigator.pop(context);
          // Aquí podrías navegar a la pantalla de inventario
        },
      );
    }
    
    // Agrupar productos por categoría
    final Map<String, List<Product>> productsByCategory = {};
    
    for (final product in _inventoryProducts) {
      if (!productsByCategory.containsKey(product.category)) {
        productsByCategory[product.category] = [];
      }
      productsByCategory[product.category]!.add(product);
    }
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkGrey.withOpacity(0.3) : AppTheme.peachLight.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: isDarkMode 
              ? Colors.transparent 
              : AppTheme.peachLight.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mostrar número de productos por categoría
          ...productsByCategory.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.coralMain,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSmall),
                  Text(
                    '${entry.key}: ${entry.value.length} productos',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          }),
          
          if (_expiringProducts.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            const Divider(color: AppTheme.peachLight, thickness: 1),
            const SizedBox(height: AppTheme.spacingSmall),
            
            // Mostrar productos a punto de caducar
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppTheme.coralMain,
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                Text(
                  'Productos a punto de caducar: ${_expiringProducts.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.coralMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            
            // Mostrar lista de productos a punto de caducar
            ...(_expiringProducts.take(3).map((product) {
              return Padding(
                padding: const EdgeInsets.only(
                  left: AppTheme.spacingMedium,
                  bottom: AppTheme.spacingXSmall,
                ),
                child: Text(
                  '${product.name} (${product.daysUntilExpiry} días)',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList()),
            
            // Si hay más de 3 productos caducando, mostrar "y X más"
            if (_expiringProducts.length > 3)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppTheme.spacingMedium,
                  bottom: AppTheme.spacingXSmall,
                ),
                child: Text(
                  'y ${_expiringProducts.length - 3} más...',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDarkMode ? AppTheme.lightGrey : AppTheme.mediumGrey,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
  
  List<Widget> _buildGeneratedMealPlans() {
    return _generatedMealPlans.map((mealPlan) {
      return Padding(padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título del tipo de comida
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppTheme.spacingXSmall,
                left: AppTheme.spacingSmall,
              ),
              child: Row(
                children: [
                  Icon(
                    _getMealTypeIcon(mealPlan.mealTypeId),
                    size: 20,
                    color: AppTheme.coralMain,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getMealTypeName(mealPlan.mealTypeId),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            // Tarjeta de receta
            MealPlanCard(
              mealPlan: mealPlan,
              onTap: () {
                // En una implementación real, navegarías al detalle de la receta
              },
              onDelete: null, // No permitir eliminar aquí
              onCompleteToggle: null, // No permitir marcar como completado aquí
            ),
          ],
        ),
      );
    }).toList();
  }
  
  Widget _buildBottomActions() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : AppTheme.pureWhite,
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGrey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          // Botón para añadir ingredientes faltantes a la lista de compras
          Expanded(
            child: CustomButton(
              text: "Añadir a Lista",
              icon: Icons.shopping_cart_rounded,
              onPressed: _addMissingToShoppingList,
              type: ButtonType.outline,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          
          // Botón para guardar el plan de comidas
          Expanded(
            child: CustomButton(
              text: "Guardar Plan",
              icon: Icons.save_rounded,
              onPressed: _saveMealPlans,
              type: ButtonType.primary,
            ),
          ),
        ],
      ),
    );
  }
}