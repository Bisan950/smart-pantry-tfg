// lib/widgets/recipes/ingredient_availability_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/recipe_model.dart';
import '../../models/product_model.dart';
import '../../services/smart_ingredient_analyzer.dart';
import '../../providers/shopping_list_provider.dart';
import '../../services/meal_plan_service.dart';

class IngredientAvailabilityWidget extends StatefulWidget {
  final Recipe recipe;
  final bool showAddButton;
  final VoidCallback? onIngredientsAdded;

  const IngredientAvailabilityWidget({
    super.key,
    required this.recipe,
    this.showAddButton = true,
    this.onIngredientsAdded,
  });

  @override
  State<IngredientAvailabilityWidget> createState() => 
      _IngredientAvailabilityWidgetState();
}

class _IngredientAvailabilityWidgetState 
    extends State<IngredientAvailabilityWidget> {
  
  final SmartIngredientAnalyzerService _analyzer = SmartIngredientAnalyzerService();
  final MealPlanService _mealPlanService = MealPlanService();
  
  StreamSubscription<IngredientAvailabilityResult>? _availabilitySubscription;
  IngredientAvailabilityResult? _currentResult;
  bool _isLoading = true;
  bool _isAddingIngredients = false;

  @override
  void initState() {
    super.initState();
    _initializeAvailabilityStream();
  }

  @override
  void dispose() {
    _availabilitySubscription?.cancel();
    super.dispose();
  }

  void _initializeAvailabilityStream() {
    _availabilitySubscription = _analyzer
        .getIngredientAvailabilityStream(widget.recipe.ingredients)
        .listen(
      (result) {
        if (mounted) {
          setState(() {
            _currentResult = result;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        print('❌ Error en stream de disponibilidad: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _addMissingIngredients(BuildContext context) async {
    if (_currentResult == null || _isAddingIngredients) return;

    setState(() {
      _isAddingIngredients = true;
    });

    try {
      final shoppingProvider = Provider.of<ShoppingListProvider>(context, listen: false);
      
      final success = await _mealPlanService.addMissingIngredientsToShoppingList(
        widget.recipe,
        shoppingProvider: shoppingProvider,
        context: context,
      );

      if (success && widget.onIngredientsAdded != null) {
        widget.onIngredientsAdded!();
      }
    } catch (e) {
      print('❌ Error añadiendo ingredientes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingIngredients = false;
        });
      }
    }
  }

  Color _getAvailabilityColor(double percentage) {
    if (percentage >= 80) return AppTheme.successGreen;
    if (percentage >= 50) return AppTheme.yellowAccent;
    return AppTheme.errorRed;
  }

  IconData _getAvailabilityIcon(double percentage) {
    if (percentage >= 80) return Icons.check_circle_rounded;
    if (percentage >= 50) return Icons.warning_rounded;
    return Icons.error_rounded;
  }

  String _getAvailabilityMessage(double percentage) {
    if (percentage >= 90) return '¡Tienes casi todos los ingredientes!';
    if (percentage >= 80) return 'Tienes la mayoría de ingredientes';
    if (percentage >= 50) return 'Te faltan algunos ingredientes';
    if (percentage >= 25) return 'Te faltan varios ingredientes';
    return 'Necesitas comprar ingredientes';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_currentResult == null) {
      return _buildErrorState();
    }

    return _buildAvailabilityContent(context);
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: AppTheme.lightGrey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralMain),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Analizando disponibilidad con IA...',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: AppTheme.errorRed.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppTheme.errorRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No se pudo analizar la disponibilidad',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.errorRed,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _initializeAvailabilityStream();
            },
            child: Text(
              'Reintentar',
              style: TextStyle(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityContent(BuildContext context) {
    final result = _currentResult!;
    final availabilityColor = _getAvailabilityColor(result.availabilityPercentage);
    final availabilityIcon = _getAvailabilityIcon(result.availabilityPercentage);
    final availabilityMessage = _getAvailabilityMessage(result.availabilityPercentage);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            availabilityColor.withOpacity(0.05),
            availabilityColor.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: availabilityColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con estadísticas principales
          _buildHeader(result, availabilityColor, availabilityIcon, availabilityMessage),
          
          // Lista de ingredientes categorizada
          _buildIngredientsList(result),
          
          // Botón de acción (si está habilitado)
          if (widget.showAddButton && result.missingIngredients.isNotEmpty)
            _buildActionButton(context, result),
        ],
      ),
    );
  }

  Widget _buildHeader(
    IngredientAvailabilityResult result,
    Color availabilityColor,
    IconData availabilityIcon,
    String availabilityMessage,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y porcentaje
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: availabilityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                child: Icon(
                  availabilityIcon,
                  color: availabilityColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disponibilidad de ingredientes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      availabilityMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: availabilityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Porcentaje en círculo
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: availabilityColor.withOpacity(0.1),
                  border: Border.all(
                    color: availabilityColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${result.availabilityPercentage.round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: availabilityColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            child: LinearProgressIndicator(
              value: result.availabilityPercentage / 100,
              backgroundColor: AppTheme.lightGrey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(availabilityColor),
              minHeight: 6,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Estadísticas resumidas
          Row(
            children: [
              _buildStatChip(
                '${result.availableIngredients.length} disponibles',
                AppTheme.successGreen,
                Icons.check_circle_outline,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                '${result.missingIngredients.length} faltan',
                AppTheme.errorRed,
                Icons.shopping_cart_outlined,
              ),
              if (result.optionalIngredients.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildStatChip(
                  '${result.optionalIngredients.length} opcionales',
                  AppTheme.yellowAccent,
                  Icons.help_outline,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsList(IngredientAvailabilityResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ingredientes disponibles
          if (result.availableIngredients.isNotEmpty)
            _buildIngredientCategory(
              'Disponibles',
              result.availableIngredients,
              AppTheme.successGreen,
              Icons.check_circle,
              result.matchedProducts,
            ),
          
          // Ingredientes faltantes
          if (result.missingIngredients.isNotEmpty)
            _buildIngredientCategory(
              'Necesarios para comprar',
              result.missingIngredients,
              AppTheme.errorRed,
              Icons.shopping_cart,
              {},
            ),
          
          // Ingredientes opcionales
          if (result.optionalIngredients.isNotEmpty)
            _buildIngredientCategory(
              'Opcionales',
              result.optionalIngredients,
              AppTheme.yellowAccent,
              Icons.help_outline,
              {},
            ),
        ],
      ),
    );
  }

  Widget _buildIngredientCategory(
    String title,
    List<RecipeIngredient> ingredients,
    Color color,
    IconData icon,
    Map<String, Product> matchedProducts,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la categoría
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${ingredients.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Lista de ingredientes
          ...ingredients.map((ingredient) => _buildIngredientItem(
                ingredient,
                color,
                matchedProducts[ingredient.name],
              )),
        ],
      ),
    );
  }

  Widget _buildIngredientItem(
    RecipeIngredient ingredient,
    Color color,
    Product? matchedProduct,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        border: Border.all(
          color: color.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ingredient.formattedQuantity} ${ingredient.unit} de ${ingredient.name}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                if (matchedProduct != null)
                  Text(
                    'Tienes: ${matchedProduct.name} (${matchedProduct.quantity} ${matchedProduct.unit})',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.successGreen,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          if (ingredient.isOptional)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.yellowAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Opcional',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.yellowAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IngredientAvailabilityResult result) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isAddingIngredients ? null : () => _addMissingIngredients(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.coralMain,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.spacingMedium,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            ),
            elevation: AppTheme.elevationSmall,
          ),
          icon: _isAddingIngredients
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.auto_awesome_rounded),
          label: Text(
            _isAddingIngredients
                ? 'Añadiendo con IA...'
                : result.hasOptionalIngredients
                    ? 'Añadir ingredientes con IA'
                    : 'Añadir ${result.missingIngredients.length} ingredientes',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}