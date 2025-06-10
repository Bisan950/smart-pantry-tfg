// lib/screens/recipes/ai_recipe_generator_screen.dart - CORREGIDO

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:smart_pantry/models/product_location_model.dart';
import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../models/recipe_model.dart';
import '../../services/gemini_recipe_service.dart';
import '../../services/inventory_service.dart';
import '../../services/meal_plan_service.dart';
import '../../services/recipe_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_chip_widget.dart';
import '../../widgets/recipes/ingredient_availability_widget.dart';
import '../../config/routes.dart';
import 'recipe_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/shopping_list_provider.dart';

class AIRecipeGeneratorScreen extends StatefulWidget {
  const AIRecipeGeneratorScreen({super.key});

  @override
  State<AIRecipeGeneratorScreen> createState() => _AIRecipeGeneratorScreenState();
}

class _AIRecipeGeneratorScreenState extends State<AIRecipeGeneratorScreen> 
    with TickerProviderStateMixin {
  
  // Servicios
  final InventoryService _inventoryService = InventoryService();
  final GeminiRecipeService _geminiService = GeminiRecipeService();
  final MealPlanService _mealPlanService = MealPlanService();
  final RecipeService _recipeService = RecipeService();
  
  // Estados principales
  List<Recipe> _generatedRecipes = [];
  bool _isLoading = false;
  String? _message;
  bool _isErrorMessage = false;
  
  // Configuración de generación
  bool _prioritizeExpiringProducts = true;
  bool _useNutritionalData = true;
  String _selectedCuisine = 'Cualquiera';
  String _selectedDiet = 'Cualquiera';
  int _recipeCount = 3;
  
  // Condiciones personalizadas
  final TextEditingController _conditionsController = TextEditingController();
  final FocusNode _conditionsFocusNode = FocusNode();
  bool _showConditionsField = false;
  
  // Datos del inventario
  List<Product> _inventoryProducts = [];
  List<Product> _expiringProducts = [];
  List<Product> _productsWithMacros = [];

  // Controladores de animación
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Configuraciones
  final List<String> _cuisines = [
    'Cualquiera', 'Española', 'Italiana', 'Mexicana', 'Asiática',
    'Mediterránea', 'Francesa', 'India', 'Japonesa',
  ];
  
  final List<String> _diets = [
    'Cualquiera', 'Vegetariana', 'Vegana', 'Sin Gluten', 'Keto',
    'Fitness', 'Baja en Calorías', 'Alta en Proteínas', 'Baja en Carbohidratos',
  ];
  
  final List<int> _recipeCounts = [1, 2, 3, 4, 5];

  final List<String> _quickConditions = [
    'Sin lactosa', 'Para deportistas', 'Postre saludable', 'Cena ligera',
    'Desayuno energético', 'Receta rápida (< 30 min)', 'Para niños',
    'Rico en omega-3', 'Ideal para meal prep',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInventoryProducts();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _conditionsController.dispose();
    _conditionsFocusNode.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));

    _fadeController.forward();
    _slideController.forward();
  }
  
  Future<void> _loadInventoryProducts() async {
    setState(() => _isLoading = true);
    
    try {
      final products = await _inventoryService.getAllProducts();
      final inventoryProducts = products.where((product) => 
        product.productLocation == ProductLocation.inventory || 
        product.productLocation == ProductLocation.both
      ).toList();
      
      final expiringProducts = await _inventoryService.getExpiringProducts(5);
      final productsWithMacros = inventoryProducts.where((product) => 
        product.hasNutritionalInfo
      ).toList();
      
      setState(() {
        _inventoryProducts = inventoryProducts;
        _expiringProducts = expiringProducts;
        _productsWithMacros = productsWithMacros;
      });
      
      print('📊 Productos cargados:');
      print('- Total en inventario: ${inventoryProducts.length}');
      print('- Por caducar: ${expiringProducts.length}');
      print('- Con información nutricional: ${productsWithMacros.length}');
      
    } catch (e) {
      _setMessage('Error al cargar productos: $e', true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addQuickCondition(String condition) {
    final currentText = _conditionsController.text;
    final newText = currentText.isEmpty ? condition : '$currentText, $condition';
    _conditionsController.text = newText;
    
    if (!_showConditionsField) {
      setState(() => _showConditionsField = true);
    }
  }

  void _clearConditions() {
    _conditionsController.clear();
    setState(() => _showConditionsField = false);
  }

  Future<void> _generateRecipes() async {
    if (_inventoryProducts.isEmpty) {
      _setMessage('No hay productos en el inventario. Añade algunos productos antes de generar recetas.', true);
      return;
    }
    
    setState(() {
      _isLoading = true;
      _message = _buildLoadingMessage();
      _isErrorMessage = false;
      _generatedRecipes = [];
    });
    
    try {
      // Determinar qué productos usar para la generación
      List<Product> primaryProducts = _prioritizeExpiringProducts && _expiringProducts.isNotEmpty
          ? _expiringProducts : _inventoryProducts;
      
      // ¡IMPORTANTE! Si se usa análisis nutricional, priorizar productos con macros
      if (_useNutritionalData && _productsWithMacros.isNotEmpty) {
        primaryProducts = _productsWithMacros;
        print('🔬 Usando ${primaryProducts.length} productos con información nutricional para optimización');
      }
      
      final userConditions = _conditionsController.text.trim();
      
      // Generar recetas usando el servicio completo con análisis nutricional
      List<Recipe> recipes = await _geminiService.generateEnhancedRecipesFromIngredients(
        availableIngredients: _inventoryProducts,
        priorityIngredients: primaryProducts,
        productsWithNutrition: _productsWithMacros, // ¡CLAVE! Pasar productos con macros
        cuisine: _selectedCuisine == 'Cualquiera' ? null : _selectedCuisine,
        dietaryPreferences: _selectedDiet == 'Cualquiera' ? null : _selectedDiet,
        userConditions: userConditions.isNotEmpty ? userConditions : null,
        includeNutritionalAnalysis: _useNutritionalData, // ¡CLAVE! Habilitar análisis
        numberOfRecipes: _recipeCount,
      );
      
      if (recipes.isEmpty) {
        _setMessage('No se pudieron generar recetas con los ingredientes disponibles. Intenta cambiar las preferencias o añade más productos.', true);
        return;
      }
      
      // Mensaje informativo sobre el resultado
      String resultMessage = 'Se han generado ${recipes.length} recetas';
      if (_useNutritionalData && _productsWithMacros.isNotEmpty) {
        resultMessage += ' optimizadas nutricionalmente';
      }
      if (userConditions.isNotEmpty) {
        resultMessage += ' según tus condiciones específicas';
      }
      
      setState(() {
        _generatedRecipes = recipes;
        _message = resultMessage;
        _isErrorMessage = false;
      });

      _slideController.reset();
      _slideController.forward();
      
    } catch (e) {
      _setMessage('Error al generar recetas: $e', true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _buildLoadingMessage() {
    List<String> messages = ['Analizando ingredientes'];
    
    if (_useNutritionalData && _productsWithMacros.isNotEmpty) {
      messages.add('optimizando nutrición');
    }
    if (_conditionsController.text.trim().isNotEmpty) {
      messages.add('aplicando condiciones');
    }
    if (_prioritizeExpiringProducts && _expiringProducts.isNotEmpty) {
      messages.add('priorizando productos urgentes');
    }
    
    return '${messages.join(' • ')}...';
  }

  Future<void> _saveRecipeToCollection(Recipe recipe) async {
    setState(() {
      _isLoading = true;
      _message = 'Guardando receta...';
      _isErrorMessage = false;
    });
    
    try {
      Recipe validRecipe = recipe;
      if (recipe.name.isEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        validRecipe = recipe.copyWith(
          name: 'Receta IA #${timestamp.substring(timestamp.length - 6)}',
        );
      }
      
      final recipeId = await _recipeService.addRecipe(validRecipe);
      
      if (recipeId != null) {
        _setMessage('Receta "${validRecipe.name}" guardada en tu colección', false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Receta guardada correctamente')),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              action: SnackBarAction(
                label: 'Ver recetas',
                textColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.2),
                onPressed: () => Navigator.pushReplacementNamed(context, Routes.recipes),
              ),
            ),
          );
        }
      } else {
        _setMessage('Error al guardar la receta', true);
      }
    } catch (e) {
      _setMessage('Error: $e', true);
    } finally {
      setState(() => _isLoading = false);
    }
  }
    
  Future<void> _addMissingIngredientsToShoppingList(Recipe recipe) async {
    setState(() {
      _isLoading = true;
      _message = 'Añadiendo ingredientes con IA...';
      _isErrorMessage = false;
    });
    
    try {
      final shoppingProvider = Provider.of<ShoppingListProvider>(context, listen: false);
      
      final success = await _mealPlanService.addMissingIngredientsToShoppingList(
        recipe,
        context: context,
        shoppingProvider: shoppingProvider,
      );
      
      if (success) {
        _setMessage('🤖 Se han añadido los ingredientes faltantes a tu lista usando IA.', false);
      } else {
        _setMessage('ℹ️ Todos los ingredientes ya están disponibles en tu inventario o lista.', false);
      }
    } catch (e) {
      _setMessage('❌ Error al añadir ingredientes: $e', true);
    } finally {
      setState(() => _isLoading = false);
    }
  }
    
  void _setMessage(String message, bool isError) {
    setState(() {
      _message = message;
      _isErrorMessage = isError;
    });
  }

  void _navigateToRecipeDetail(Recipe recipe) {
    Navigator.push(
      context, 
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => RecipeDetailScreen(
          recipeId: recipe.id,
          recipe: recipe,
          showAddToMealPlanButton: true,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: const CustomAppBar(
        title: 'Chef IA',
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: _isLoading ? _buildLoadingOverlay() : _buildMainContent(isTablet),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.floatingShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.coralMain.withOpacity(0.1), AppTheme.coralMain.withOpacity(0.05)],
                ),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralMain),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Cocinando con IA...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _message ?? 'Creando recetas perfectas para ti',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMainContent(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Configuración en diseño compacto
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildCompactConfiguration(),
                    ),
                    const SizedBox(height: 20),
                    
                    // Estado del inventario
                    _buildInventoryStatus(),
                    const SizedBox(height: 20),
                    
                    // Botón principal o resultados
                    if (_generatedRecipes.isEmpty) 
                      _buildGenerateButton()
                    else 
                      _buildRecipeResults(),
                      
                    // Mensaje de estado
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      _buildStatusMessage(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactConfiguration() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: AppTheme.coralMain),
              const SizedBox(width: 8),
              Text(
                'Configuración',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Switches compactos
          _buildCompactSwitches(),
          const SizedBox(height: 16),
          
          // Selectores en grid
          _buildSelectorsGrid(),
          const SizedBox(height: 16),
          
          // Condiciones rápidas
          _buildQuickConditions(),
          
          // Campo personalizado
          if (_showConditionsField) ...[
            const SizedBox(height: 12),
            _buildCustomConditionsField(),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactSwitches() {
    return Column(
      children: [
        // ¡SWITCH NUTRICIONAL MEJORADO!
        if (_productsWithMacros.isNotEmpty)
          _buildNutritionalSwitch(),
        
        const SizedBox(height: 8),
        
        // Switch expiring products
        _buildCompactSwitch(
          'Priorizar productos urgentes',
          _prioritizeExpiringProducts,
          (value) => setState(() => _prioritizeExpiringProducts = value),
          Icons.schedule_rounded,
          _expiringProducts.isNotEmpty ? AppTheme.warningOrange : AppTheme.mediumGrey,
          subtitle: _expiringProducts.isEmpty 
              ? 'No hay productos por caducar'
              : '${_expiringProducts.length} productos caducarán pronto',
        ),
      ],
    );
  }

  // ¡NUEVO! Switch específico para análisis nutricional
  Widget _buildNutritionalSwitch() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.successGreen.withOpacity(0.05),
            AppTheme.successGreen.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.science_rounded, size: 16, color: AppTheme.successGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Optimización nutricional inteligente',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    Text(
                      '${_productsWithMacros.length} productos con macros disponibles',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.successGreen.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _useNutritionalData,
                onChanged: (value) => setState(() => _useNutritionalData = value),
                activeColor: AppTheme.successGreen,
                activeTrackColor: AppTheme.successGreen.withOpacity(0.3),
              ),
            ],
          ),
          
          // Información adicional cuando está activado
          if (_useNutritionalData) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_rounded, size: 12, color: AppTheme.successGreen),
                      const SizedBox(width: 6),
                      Text(
                        'Productos que se usarán para optimización:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _productsWithMacros.take(4).map((product) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_productsWithMacros.length > 4)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${_productsWithMacros.length - 4} productos más con información nutricional',
                        style: TextStyle(
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.successGreen.withOpacity(0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactSwitch(
    String title,
    bool value,
    Function(bool) onChanged,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            activeTrackColor: color.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCompactSelector('Cocina', _cuisines, _selectedCuisine, 
                (value) => setState(() => _selectedCuisine = value))),
            const SizedBox(width: 12),
            Expanded(child: _buildCompactSelector('Dieta', _diets, _selectedDiet, 
                (value) => setState(() => _selectedDiet = value))),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _buildCompactSelector('Recetas', _recipeCounts.map((e) => e.toString()).toList(), 
              _recipeCount.toString(), (value) => setState(() => _recipeCount = int.parse(value))),
        ),
      ],
    );
  }

  Widget _buildCompactSelector(String label, List<String> options, String selected, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.coralMain,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.coralMain.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.coralMain),
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: (value) => onChanged(value!),
              items: options.map((option) => DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickConditions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on_rounded, size: 16, color: AppTheme.yellowAccent),
            const SizedBox(width: 6),
            Text(
              'Condiciones rápidas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.yellowAccent,
              ),
            ),
            const Spacer(),
            if (_showConditionsField)
              TextButton(
                onPressed: _clearConditions,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  'Limpiar',
                  style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _quickConditions.take(6).map((condition) {
            return GestureDetector(
              onTap: () => _addQuickCondition(condition),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.yellowAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.yellowAccent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 12, color: AppTheme.yellowAccent),
                    const SizedBox(width:4),
                   Text(
                     condition,
                     style: TextStyle(
                       fontSize: 11,
                       fontWeight: FontWeight.w600,
                       color: AppTheme.yellowAccent,
                     ),
                   ),
                 ],
               ),
             ),
           );
         }).toList(),
       ),
       if (!_showConditionsField) ...[
         const SizedBox(height: 8),
         GestureDetector(
           onTap: () {
             setState(() => _showConditionsField = true);
             Future.delayed(const Duration(milliseconds: 100), () {
               _conditionsFocusNode.requestFocus();
             });
           },
           child: Container(
             width: double.infinity,
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: AppTheme.coralMain.withOpacity(0.05),
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: AppTheme.coralMain.withOpacity(0.2), style: BorderStyle.solid),
             ),
             child: Row(
               children: [
                 Icon(Icons.add_circle_outline_rounded, color: AppTheme.coralMain, size: 16),
                 const SizedBox(width: 8),
                 Text(
                   'Añadir condiciones específicas...',
                   style: TextStyle(
                     color: AppTheme.coralMain,
                     fontSize: 13,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
               ],
             ),
           ),
         ),
       ],
     ],
   );
 }

 Widget _buildCustomConditionsField() {
   return TextField(
     controller: _conditionsController,
     focusNode: _conditionsFocusNode,
     maxLines: 2,
     style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
     decoration: InputDecoration(
       hintText: 'Ej: Sin lactosa, para 6 personas, postre sin azúcar...',
       hintStyle: TextStyle(
         color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
         fontSize: 12,
       ),
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(8),
         borderSide: BorderSide(color: AppTheme.coralMain.withOpacity(0.3)),
       ),
       focusedBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(8),
         borderSide: BorderSide(color: AppTheme.coralMain, width: 1.5),
       ),
       filled: true,
       fillColor: Theme.of(context).colorScheme.surface,
       contentPadding: const EdgeInsets.all(12),
       isDense: true,
     ),
   );
 }

 Widget _buildInventoryStatus() {
   if (_inventoryProducts.isEmpty) {
     return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
         gradient: LinearGradient(
           colors: [AppTheme.coralMain.withOpacity(0.05), AppTheme.coralMain.withOpacity(0.02)],
         ),
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: AppTheme.coralMain.withOpacity(0.2)),
       ),
       child: Column(
         children: [
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: AppTheme.coralMain.withOpacity(0.1),
               shape: BoxShape.circle,
             ),
             child: Icon(Icons.kitchen_rounded, color: AppTheme.coralMain, size: 32),
           ),
           const SizedBox(height: 16),
           Text(
             'Tu despensa está vacía',
             style: Theme.of(context).textTheme.titleMedium?.copyWith(
               fontWeight: FontWeight.bold,
               color: AppTheme.coralMain,
             ),
           ),
           const SizedBox(height: 8),
           Text(
             'Añade ingredientes para crear recetas increíbles',
             textAlign: TextAlign.center,
             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
               color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
             ),
           ),
           const SizedBox(height: 16),
           ElevatedButton.icon(
             onPressed: () => Navigator.pushReplacementNamed(context, Routes.inventory),
             icon: const Icon(Icons.add_rounded, size: 18),
             label: const Text('Llenar despensa', style: TextStyle(fontWeight: FontWeight.w600)),
             style: ElevatedButton.styleFrom(
               backgroundColor: AppTheme.coralMain,
               foregroundColor: Colors.white,
               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             ),
           ),
         ],
       ),
     );
   }

   // Resumir estado del inventario de manera compacta
   return Container(
     padding: const EdgeInsets.all(16),
     decoration: BoxDecoration(
       color: Theme.of(context).colorScheme.surface,
       borderRadius: BorderRadius.circular(16),
       border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
       boxShadow: AppTheme.cardShadow,
     ),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Row(
           children: [
             Container(
               padding: const EdgeInsets.all(6),
               decoration: BoxDecoration(
                 color: AppTheme.successGreen.withOpacity(0.1),
                 shape: BoxShape.circle,
               ),
               child: Icon(Icons.inventory_2_rounded, size: 16, color: AppTheme.successGreen),
             ),
             const SizedBox(width: 8),
             Text(
               'Tu despensa',
               style: Theme.of(context).textTheme.titleMedium?.copyWith(
                 fontWeight: FontWeight.bold,
               ),
             ),
             const Spacer(),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 color: AppTheme.successGreen.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Text(
                 '${_inventoryProducts.length} productos',
                 style: TextStyle(
                   fontSize: 12,
                   fontWeight: FontWeight.bold,
                   color: AppTheme.successGreen,
                 ),
               ),
             ),
           ],
         ),
         const SizedBox(height: 12),
         
         // Estadísticas rápidas en fila
         Row(
           children: [
             Expanded(
               child: _buildStatItem(
                 'Con macros',
                 '${_productsWithMacros.length}',
                 AppTheme.successGreen,
                 Icons.science_rounded,
               ),
             ),
             const SizedBox(width: 8),
             Expanded(
               child: _buildStatItem(
                 'Por caducar',
                 '${_expiringProducts.length}',
                 _expiringProducts.isNotEmpty ? AppTheme.warningOrange : AppTheme.mediumGrey,
                 Icons.schedule_rounded,
               ),
             ),
             const SizedBox(width: 8),
             Expanded(
               child: _buildStatItem(
                 'Categorías',
                 '${_inventoryProducts.map((p) => p.category).toSet().length}',
                 AppTheme.softTeal,
                 Icons.category_rounded,
               ),
             ),
           ],
         ),
       ],
     ),
   );
 }

 Widget _buildStatItem(String label, String value, Color color, IconData icon) {
   return Container(
     padding: const EdgeInsets.all(8),
     decoration: BoxDecoration(
       color: color.withOpacity(0.05),
       borderRadius: BorderRadius.circular(8),
       border: Border.all(color: color.withOpacity(0.1)),
     ),
     child: Column(
       children: [
         Icon(icon, size: 16, color: color),
         const SizedBox(height: 4),
         Text(
           value,
           style: TextStyle(
             fontSize: 14,
             fontWeight: FontWeight.bold,
             color: color,
           ),
         ),
         Text(
           label,
           style: TextStyle(
             fontSize: 10,
             color: color.withOpacity(0.8),
           ),
           textAlign: TextAlign.center,
         ),
       ],
     ),
   );
 }

 Widget _buildGenerateButton() {
   return Container(
     width: double.infinity,
     height: 56,
     decoration: BoxDecoration(
       gradient: LinearGradient(
         colors: [AppTheme.coralMain, AppTheme.coralMain.withOpacity(0.8)],
       ),
       borderRadius: BorderRadius.circular(16),
       boxShadow: [
         BoxShadow(
           color: AppTheme.coralMain.withOpacity(0.3),
           blurRadius: 12,
           offset: const Offset(0, 4),
         ),
       ],
     ),
     child: ElevatedButton.icon(
       onPressed: _generateRecipes,
       icon: Container(
         padding: const EdgeInsets.all(6),
         decoration: BoxDecoration(
           color: Colors.white.withOpacity(0.2),
           shape: BoxShape.circle,
         ),
         child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
       ),
       label: Text(
         _useNutritionalData && _productsWithMacros.isNotEmpty
             ? 'Generar Recetas Inteligentes'
             : 'Generar Recetas Mágicas',
         style: const TextStyle(
           color: Colors.white,
           fontSize: 16,
           fontWeight: FontWeight.bold,
         ),
       ),
       style: ElevatedButton.styleFrom(
         backgroundColor: Colors.transparent,
         shadowColor: Colors.transparent,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       ),
     ),
   );
 }

 Widget _buildStatusMessage() {
   return Container(
     padding: const EdgeInsets.all(16),
     decoration: BoxDecoration(
       gradient: LinearGradient(
         colors: _isErrorMessage 
             ? [AppTheme.errorRed.withOpacity(0.1), AppTheme.errorRed.withOpacity(0.05)]
             : [AppTheme.successGreen.withOpacity(0.1), AppTheme.successGreen.withOpacity(0.05)],
       ),
       borderRadius: BorderRadius.circular(12),
       border: Border.all(
         color: (_isErrorMessage ? AppTheme.errorRed : AppTheme.successGreen).withOpacity(0.2),
       ),
     ),
     child: Row(
       children: [
         Container(
           padding: const EdgeInsets.all(6),
           decoration: BoxDecoration(
             color: (_isErrorMessage ? AppTheme.errorRed : AppTheme.successGreen).withOpacity(0.15),
             shape: BoxShape.circle,
           ),
           child: Icon(
             _isErrorMessage ? Icons.warning_rounded : Icons.check_circle_rounded,
             color: _isErrorMessage ? AppTheme.errorRed : AppTheme.successGreen,
             size: 16,
           ),
         ),
         const SizedBox(width: 12),
         Expanded(
           child: Text(
             _message!,
             style: TextStyle(
               color: _isErrorMessage ? AppTheme.errorRed : AppTheme.successGreen,
               fontWeight: FontWeight.w500,
               fontSize: 13,
             ),
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildRecipeResults() {
   return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       // Header de resultados
       Row(
         children: [
           Container(
             padding: const EdgeInsets.all(6),
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 colors: [AppTheme.coralMain, AppTheme.coralMain.withOpacity(0.8)],
               ),
               shape: BoxShape.circle,
             ),
             child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 16),
           ),
           const SizedBox(width: 8),
           Text(
             'Recetas generadas',
             style: Theme.of(context).textTheme.titleMedium?.copyWith(
               fontWeight: FontWeight.bold,
             ),
           ),
           const Spacer(),
           TextButton.icon(
             onPressed: _generateRecipes,
             icon: const Icon(Icons.refresh_rounded, size: 16),
             label: const Text('Más recetas'),
             style: TextButton.styleFrom(
               foregroundColor: AppTheme.coralMain,
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             ),
           ),
         ],
       ),
       const SizedBox(height: 16),
       
       // Lista compacta de recetas
       ...List.generate(_generatedRecipes.length, (index) {
         final recipe = _generatedRecipes[index];
         return Padding(
           padding: const EdgeInsets.only(bottom: 16),
           child: _buildCompactRecipeCard(recipe, index),
         );
       }),
     ],
   );
 }

 Widget _buildCompactRecipeCard(Recipe recipe, int index) {
   final availablePercentage = recipe.availableIngredientsPercentage * 100;
   final availabilityColor = availablePercentage >= 80 
       ? AppTheme.successGreen 
       : availablePercentage >= 50 
           ? AppTheme.yellowAccent 
           : AppTheme.errorRed;
   
   return Container(
     decoration: BoxDecoration(
       color: Theme.of(context).colorScheme.surface,
       borderRadius: BorderRadius.circular(16),
       border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
       boxShadow: AppTheme.cardShadow,
     ),
     child: Column(
       children: [
         // Header compacto de la receta
         Container(
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             gradient: LinearGradient(
               colors: _getGradientColors(index).map((c) => c.withOpacity(0.1)).toList(),
             ),
             borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
           ),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               // Título y badges
               Row(
                 children: [
                   Expanded(
                     child: Text(
                       recipe.name,
                       style: Theme.of(context).textTheme.titleMedium?.copyWith(
                         fontWeight: FontWeight.bold,
                       ),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                   const SizedBox(width: 8),
                   // ¡BADGE NUTRICIONAL MEJORADO!
                   if (_useNutritionalData && recipe.nutrition.isNotEmpty)
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                       decoration: BoxDecoration(
                         gradient: LinearGradient(
                           colors: [AppTheme.successGreen.withOpacity(0.9), AppTheme.successGreen.withOpacity(0.7)],
                         ),
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           const Icon(Icons.science_rounded, size: 10, color: Colors.white),
                           const SizedBox(width: 3),
                           const Text(
                             'Optimizada',
                             style: TextStyle(
                               color: Colors.white,
                               fontWeight: FontWeight.bold,
                               fontSize: 9,
                             ),
                           ),
                         ],
                       ),
                     ),
                 ],
               ),
               
               if (recipe.description.isNotEmpty) ...[
                 const SizedBox(height: 6),
                 Text(
                   recipe.description,
                   style: Theme.of(context).textTheme.bodySmall?.copyWith(
                     color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                   ),
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                 ),
               ],
               
               const SizedBox(height: 12),
               
               // Info chips compactos
               Wrap(
                 spacing: 6,
                 runSpacing: 4,
                 children: [
                   _buildInfoChip(Icons.access_time_rounded, '${recipe.totalTime}min', AppTheme.coralMain),
                   _buildInfoChip(Icons.people_alt_rounded, '${recipe.servings}', AppTheme.softTeal),
                   _buildInfoChip(
                     Icons.bar_chart_rounded, 
                     _getDifficultyText(recipe.difficulty), 
                     AppTheme.yellowAccent,
                   ),
                   if (recipe.calories > 0)
                     _buildInfoChip(Icons.local_fire_department_rounded, '${recipe.calories} kcal', AppTheme.warningOrange),
                 ],
               ),
             ],
           ),
         ),
         
         // Contenido principal
         Padding(
           padding: const EdgeInsets.all(16),
           child: Column(
             children: [
               // Análisis de disponibilidad compacto - ¡MEJORADO CON EL WIDGET ORIGINAL!
               IngredientAvailabilityWidget(
                 recipe: recipe,
                 showAddButton: false, // Manejamos los botones por separado
               ),
               
               const SizedBox(height: 16),
               
               // ¡INFORMACIÓN NUTRICIONAL MEJORADA!
               if (recipe.nutrition.isNotEmpty && _useNutritionalData) ...[
                 Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     gradient: LinearGradient(
                       colors: [
                         AppTheme.successGreen.withOpacity(0.05),
                         AppTheme.successGreen.withOpacity(0.1),
                       ],
                     ),
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: AppTheme.successGreen.withOpacity(0.2)),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         children: [
                           Icon(Icons.analytics_rounded, size: 12, color: AppTheme.successGreen),
                           const SizedBox(width: 6),
                           Text(
                             'Análisis nutricional optimizado por IA',
                             style: TextStyle(
                               fontWeight: FontWeight.w600,
                               fontSize: 11,
                               color: AppTheme.successGreen,
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 6),
                       Wrap(
                         spacing: 4,
                         runSpacing: 2,
                         children: [
                           if (recipe.calories > 0)
                             _buildNutritionChip('${recipe.calories} kcal', AppTheme.coralMain),
                           if (recipe.nutrition['protein'] != null)
                             _buildNutritionChip('P: ${recipe.nutrition['protein']}g', AppTheme.successGreen),
                           if (recipe.nutrition['carbs'] != null)
                             _buildNutritionChip('C: ${recipe.nutrition['carbs']}g', AppTheme.yellowAccent),
                           if (recipe.nutrition['fats'] != null)
                             _buildNutritionChip('G: ${recipe.nutrition['fats']}g', AppTheme.softTeal),
                         ],
                       ),
                     ],
                   ),
                 ),
                 const SizedBox(height: 16),
               ],
               
               // Botones de acción compactos
               Row(
                 children: [
                   Expanded(
                     child: OutlinedButton.icon(
                       onPressed: () => _navigateToRecipeDetail(recipe),
                       icon: const Icon(Icons.visibility_rounded, size: 16),
                       label: const Text('Ver', style: TextStyle(fontWeight: FontWeight.w600)),
                       style: OutlinedButton.styleFrom(
                         foregroundColor: AppTheme.coralMain,
                         side: BorderSide(color: AppTheme.coralMain),
                         padding: const EdgeInsets.symmetric(vertical: 8),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       ),
                     ),
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: ElevatedButton.icon(
                       onPressed: () => _saveRecipeToCollection(recipe),
                       icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                       label: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w600)),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppTheme.coralMain,
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 8),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       ),
                     ),
                   ),
                 ],
               ),
               
               // Botón de lista de compras compacto
               if (recipe.missingIngredients.isNotEmpty) ...[
                 const SizedBox(height: 8),
                 SizedBox(
                   width: double.infinity,
                   child: TextButton.icon(
                     onPressed: () => _addMissingIngredientsToShoppingList(recipe),
                     icon: Icon(Icons.auto_awesome_rounded, size: 14, color: AppTheme.yellowAccent),
                     label: Text(
                       'Añadir ${recipe.missingIngredients.length} ingredientes con IA',
                       style: TextStyle(
                         color: AppTheme.yellowAccent,
                         fontWeight: FontWeight.w600,
                         fontSize: 12,
                       ),
                     ),
                     style: TextButton.styleFrom(
                       backgroundColor: AppTheme.yellowAccent.withOpacity(0.05),
                       padding: const EdgeInsets.symmetric(vertical: 6),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(8),
                         side: BorderSide(color: AppTheme.yellowAccent.withOpacity(0.2)),
                       ),
                     ),
                   ),
                 ),
               ],
             ],
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildInfoChip(IconData icon, String text, Color color) {
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
     decoration: BoxDecoration(
       color: color.withOpacity(0.1),
       borderRadius: BorderRadius.circular(8),
       border: Border.all(color: color.withOpacity(0.3)),
     ),
     child: Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Icon(icon, size: 10, color: color),
         const SizedBox(width: 3),
         Text(
           text,
           style: TextStyle(
             fontSize: 10,
             fontWeight: FontWeight.w600,
             color: color,
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildNutritionChip(String text, Color color) {
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
     decoration: BoxDecoration(
       color: color.withOpacity(0.1),
       borderRadius: BorderRadius.circular(6),
       border: Border.all(color: color.withOpacity(0.3)),
     ),
     child: Text(
       text,
       style: TextStyle(
         fontSize: 9,
         fontWeight: FontWeight.bold,
         color: color,
       ),
     ),
   );
 }

 List<Color> _getGradientColors(int index) {
   final gradients = [
     [AppTheme.coralMain, AppTheme.coralMain.withOpacity(0.7)],
     [AppTheme.softTeal, AppTheme.softTeal.withOpacity(0.7)],
     [AppTheme.yellowAccent, AppTheme.yellowAccent.withOpacity(0.7)],
     [AppTheme.successGreen, AppTheme.successGreen.withOpacity(0.7)],
     [AppTheme.warningOrange, AppTheme.warningOrange.withOpacity(0.7)],
   ];
   
   return gradients[index % gradients.length];
 }

 String _getDifficultyText(DifficultyLevel difficulty) {
   switch (difficulty) {
     case DifficultyLevel.easy:
       return 'Fácil';
     case DifficultyLevel.medium:
       return 'Media';
     case DifficultyLevel.hard:
       return 'Difícil';
     default:
       return 'Media';
   }
 }
}