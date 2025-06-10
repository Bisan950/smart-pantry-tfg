// lib/screens/recipes/recipe_detail_screen.dart - VERSIÓN OPTIMIZADA CON PRINCIPIOS DEL DASHBOARD

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/recipe_model.dart';
import '../../models/meal_type_model.dart';
import '../../models/meal_plan_model.dart';
import '../../services/recipe_service.dart';
import '../../services/meal_plan_service.dart';
import '../../config/routes.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/recipes/recipe_nutrition_card.dart';
import '../../widgets/recipes/ingredient_availability_widget.dart'; // WIDGET CON IA
import 'recipe_image_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/shopping_list_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe? recipe;
  final String? recipeId;
  final bool showAddToMealPlanButton;
  
  const RecipeDetailScreen({
    super.key,
    this.recipe,
    this.recipeId,
    this.showAddToMealPlanButton = false,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final RecipeService _recipeService = RecipeService();
  final MealPlanService _mealPlanService = MealPlanService();
  
  late Recipe? _recipe;
  bool _isLoading = false;
  bool _isFavorite = false;
  
  // Control de scroll para header compacto
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderCollapsed = false;
  
  // Lista de categorías predefinidas para sugerir
  final List<String> _suggestedCategories = [
    'Saludable', 'Rápidas', 'Vegetarianas', 'Postres', 'Carnes', 'Pescados',
    'Sin Gluten', 'Veganas', 'Italiana', 'Mexicana', 'Mediterránea', 'Asiática',
    'Desayuno', 'Almuerzo', 'Cena', 'Merienda', 'Bajo en calorías'
  ];
  
  // Controlador para el campo de texto de nueva categoría
  final TextEditingController _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initRecipe();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // APLICANDO PRINCIPIO 1: HEADER COMPACTO
  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!mounted) return;
      
      // Umbral coherente con dashboard (80px)
      final shouldCollapse = _scrollController.offset > 80;
      if (shouldCollapse != _isHeaderCollapsed) {
        setState(() => _isHeaderCollapsed = shouldCollapse);
      }
    });
  }

  Future<void> _initRecipe() async {
    setState(() {
      _isLoading = true;
      _recipe = widget.recipe;
    });

    try {
      // Si no tenemos receta, pero tenemos el ID, intentar cargarla
      if (_recipe == null && widget.recipeId != null) {
        final recipe = await _recipeService.getRecipeById(widget.recipeId!);
        setState(() {
          _recipe = recipe;
        });
      }
      
      // CORREGIDO: Usar el estado de favorito de la propia receta
      if (_recipe != null) {
        setState(() {
          _isFavorite = _recipe!.isFavorite;
        });
      }
    } catch (e) {
      print('Error al cargar receta: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecipe() async {
    try {
      final updatedRecipe = await _recipeService.getRecipeById(_recipe!.id);
      if (updatedRecipe != null) {
        setState(() {
          _recipe = updatedRecipe;
        });
      }
    } catch (e) {
      print('Error al cargar receta actualizada: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_recipe == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // CORREGIDO: Actualizar la receta completa con el nuevo estado de favorito
      final updatedRecipe = _recipe!.copyWith(
        isFavorite: !_isFavorite,
        updatedAt: DateTime.now(),
      );
      
      // Actualizar en el servicio
      final success = await _recipeService.updateRecipe(updatedRecipe);
      
      if (success) {
        setState(() {
          _isFavorite = !_isFavorite;
          _recipe = updatedRecipe;
        });
        
        // PRINCIPIO 5: Feedback visual claro
        _showCrispSnackBar(
          type: _isFavorite ? SnackBarType.success : SnackBarType.info,
          title: _isFavorite ? 'Añadida a favoritos' : 'Eliminada de favoritos',
          icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        );
      } else {
        throw Exception('No se pudo actualizar el estado de favorito');
      }
    } catch (e) {
      print('Error al cambiar favorito: $e');
      _showCrispSnackBar(
        type: SnackBarType.error,
        title: 'Error al actualizar favorito',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // APLICANDO PRINCIPIO 4: ELEMENTOS ESENCIALES - Diálogo simplificado
  void _showTagsDialog() {
    if (_recipe == null) return;
    
    List<String> currentCategories = List<String>.from(_recipe!.categories);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Gestionar etiquetas'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Etiquetas actuales - PRINCIPIO 2: DISEÑO NÍTIDO
                if (currentCategories.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: currentCategories.map((category) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.coralMain,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.coralMain, width: 1), // PRINCIPIO 2
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(category, 
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    currentCategories.remove(category);
                                  });
                                },
                                child: Container(
                                  width: 16, // PRINCIPIO 5: Tamaño mínimo
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 10, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Campo para agregar nueva etiqueta - COMPACTO
                Text('Añadir etiqueta:', 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.pureWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            hintText: 'Nueva etiqueta',
                            hintStyle: TextStyle(fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onSubmitted: (value) {
                            final newCategory = value.trim();
                            if (newCategory.isNotEmpty && !currentCategories.contains(newCategory)) {
                              setState(() {
                                currentCategories.add(newCategory);
                                _categoryController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(4),
                        child: ElevatedButton(
                          onPressed: () {
                            final newCategory = _categoryController.text.trim();
                            if (newCategory.isNotEmpty && !currentCategories.contains(newCategory)) {
                              setState(() {
                                currentCategories.add(newCategory);
                                _categoryController.clear();
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.coralMain,
                            minimumSize: const Size(32, 32), // PRINCIPIO 5: Tamaño mínimo
                            padding: const EdgeInsets.all(6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Etiquetas sugeridas - PRINCIPIO 3: ROW HORIZONTAL
                Text('Sugeridas:', 
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w600, 
                    color: AppTheme.darkGrey,
                  )),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _suggestedCategories
                        .where((category) => !currentCategories.contains(category))
                        .take(6)
                        .map((category) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              currentCategories.add(category);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGrey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
                            ),
                            child: Text(category, 
                              style: TextStyle(
                                fontSize: 11, 
                                color: AppTheme.darkGrey,
                                fontWeight: FontWeight.w500,
                              )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: AppTheme.mediumGrey, fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, currentCategories);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralMain,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Guardar', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    ).then((updatedCategories) async {
      if (updatedCategories != null) {
        setState(() => _isLoading = true);
        
        try {
          final updatedRecipe = _recipe!.copyWith(categories: updatedCategories);
          final success = await _recipeService.updateRecipe(updatedRecipe);
          
          if (success) {
            await _loadRecipe();
            _showCrispSnackBar(
              type: SnackBarType.success,
              title: 'Etiquetas actualizadas',
              icon: Icons.check_circle_rounded,
            );
          }
        } catch (e) {
          _showCrispSnackBar(
            type: SnackBarType.error,
            title: 'Error al actualizar',
            icon: Icons.error_outline_rounded,
          );
        } finally {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  // APLICANDO PRINCIPIO 4: ELEMENTOS ESENCIALES - Diálogo simplificado
  void _showAddToMealPlanDialog() {
    if (_recipe == null) return;
    
    DateTime selectedDate = DateTime.now();
    String selectedMealTypeId = 'breakfast';
    final mealTypes = MealType.getPredefinedTypes();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Añadir al plan'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selector de fecha - PRINCIPIO 2: DISEÑO NÍTIDO
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
                ),
                child: ListTile(
                  title: Text('Fecha:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(_formatDate(selectedDate), style: TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.calendar_today_rounded, color: AppTheme.coralMain, size: 20),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Selector de tipo de comida - CORREGIDO: Usar Wrap en lugar de GridView
              Text('Tipo de comida:', 
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkGrey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mealTypes.map((type) {
                  final isSelected = type.id == selectedMealTypeId;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedMealTypeId = type.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.coralMain : AppTheme.lightGrey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.coralMain : AppTheme.lightGrey.withOpacity(0.5), 
                          width: 1
                        ), // PRINCIPIO 2
                      ),
                      child: Text(
                        type.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.darkGrey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: AppTheme.mediumGrey, fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addToMealPlan(selectedDate, selectedMealTypeId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralMain,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Añadir', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekdayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final monthNames = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    
    final weekday = (date.weekday - 1) % 7;
    final month = date.month - 1;
    
    return '${weekdayNames[weekday]}, ${date.day} de ${monthNames[month]}';
  }

  Future<void> _addToMealPlan(DateTime date, String mealTypeId) async {
    if (_recipe == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final mealPlan = MealPlan(
        id: '',
        date: date,
        mealTypeId: mealTypeId,
        recipeId: _recipe!.id,
        recipe: _recipe,
        isCompleted: false,
      );
      
      final mealPlanId = await _mealPlanService.addMealPlan(mealPlan);
      
      if (mealPlanId != null && mounted) {
        final mealType = MealType.getPredefinedTypes()
            .firstWhere((type) => type.id == mealTypeId, 
                       orElse: () => MealType(id: mealTypeId, name: 'Comida', icon: Icons.restaurant));
        
        _showCrispSnackBar(
          type: SnackBarType.success,
          title: 'Añadido al plan',
          icon: Icons.check_circle_rounded,
          action: SnackBarAction(
            label: 'VER',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, Routes.mealPlanner),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showCrispSnackBar(
          type: SnackBarType.error,
          title: 'Error al añadir',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // APLICANDO PRINCIPIO 2: SOMBRAS SUTILES Y FEEDBACK CLARO
  void _showCrispSnackBar({
    required SnackBarType type,
    required String title,
    required IconData icon,
    SnackBarAction? action,
  }) {
    final colors = _getSnackBarColors(type);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 28, // PRINCIPIO 5: Tamaño mínimo
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, 
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.w600, 
                  fontSize: 14,
                )),
            ),
          ],
        ),
        backgroundColor: colors.backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        action: action,
      ),
    );
  }

  SnackBarColors _getSnackBarColors(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return SnackBarColors(backgroundColor: AppTheme.successGreen, iconColor: Colors.white);
      case SnackBarType.error:
        return SnackBarColors(backgroundColor: AppTheme.errorRed, iconColor: Colors.white);
      case SnackBarType.warning:
        return SnackBarColors(backgroundColor: AppTheme.warningOrange, iconColor: Colors.white);
      case SnackBarType.info:
        return SnackBarColors(backgroundColor: AppTheme.darkGrey, iconColor: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _recipe?.name ?? 'Cargando...',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_recipe != null)
            IconButton(
              icon: const Icon(Icons.label_outline, size: 20),
              onPressed: _showTagsDialog,
              tooltip: 'Etiquetas',
            ),
          if (_recipe != null)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFavorite ? AppTheme.errorRed : AppTheme.darkGrey,
                size: 22,
              ),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildCrispContent(),
      floatingActionButton: widget.showAddToMealPlanButton && _recipe != null
          ? FloatingActionButton.extended(
              onPressed: _showAddToMealPlanDialog,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: const Text('Al plan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              backgroundColor: AppTheme.coralMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )
          : null,
    );
  }

  // APLICANDO TODOS LOS PRINCIPIOS: CONTENIDO NÍTIDO Y COMPACTO
  Widget _buildCrispContent() {
    if (_recipe == null) {
      return _buildErrorState();
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // APLICANDO PRINCIPIO 1: HEADER COMPACTO (reducido de 260 a 120px)
        SliverAppBar(
          expandedHeight: 120,
          automaticallyImplyLeading: false,
          pinned: true,
          backgroundColor: AppTheme.backgroundGrey,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildCrispHeader(),
            collapseMode: CollapseMode.parallax,
          ),
        ),
        
        // Contenido principal
        SliverPadding(
          padding: const EdgeInsets.all(20), // PRINCIPIO 3: Padding consistente
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Info principal compacta
              _buildCrispMainInfo(),
              const SizedBox(height: 20),
              
              // Stats en row horizontal
              _buildCrispStats(),
              const SizedBox(height: 20),
              
              // Widget de disponibilidad con IA (mantenido)
              IngredientAvailabilityWidget(
                recipe: _recipe!,
                showAddButton: true,
                onIngredientsAdded: () {
                  print('Ingredientes añadidos con IA');
                },
              ),
              const SizedBox(height: 20),
              
              // Ingredientes simplificados
              _buildCrispIngredients(),
              const SizedBox(height: 20),
              
              // Pasos simplificados
              _buildCrispSteps(),
              const SizedBox(height: 20),
              
              // Nutrición compacta
              _buildCrispNutrition(),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }

  // APLICANDO PRINCIPIO 1: HEADER COMPACTO
  Widget _buildCrispHeader() {
    final hasValidImage = _recipe!.imageUrl.isNotEmpty && 
                         !_recipe!.imageUrl.startsWith('https://example.com/');
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.coralMain.withOpacity(0.1),
        border: Border.all(color: AppTheme.coralMain.withOpacity(0.2), width: 1), // PRINCIPIO 2
      ),
      child: Stack(
        children: [
          if (hasValidImage)
            Image.network(
              _recipe!.imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
            )
          else
            _buildImagePlaceholder(),
          
          // Overlay para legibilidad
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
          
          // Etiquetas compactas en la parte inferior
          if (_recipe!.categories.isNotEmpty)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _recipe!.categories.take(3).map((category) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.coralMain,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.coralMain, width: 1), // PRINCIPIO 2
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          
          // Botón de imagen
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _navigateToImageEdit,
              child: Container(
                width: 32, // PRINCIPIO 5: Tamaño mínimo
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // APLICANDO PRINCIPIO 4: INFORMACIÓN ESENCIAL
  Widget _buildCrispMainInfo() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02), // PRINCIPIO 2: Sombras sutiles
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16), // PRINCIPIO 3: Padding consistente
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _recipe!.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGrey,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              _recipe!.description,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mediumGrey,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            
            // Etiquetas compactas
            if (_recipe!.categories.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.label_outline, color: AppTheme.coralMain, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showTagsDialog,
                      child: Text(
                        _recipe!.categories.join(', '),
                        style: TextStyle(
                          color: AppTheme.darkGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showTagsDialog,
                    child: Container(
                      width: 24, // PRINCIPIO 5: Tamaño mínimo
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.coralMain.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.coralMain.withOpacity(0.3), width: 1), // PRINCIPIO 2
                      ),
                      child: Icon(Icons.edit, color: AppTheme.coralMain, size: 12),
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: _showTagsDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: AppTheme.mediumGrey, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Añadir etiquetas',
                        style: TextStyle(
                          color: AppTheme.mediumGrey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // APLICANDO PRINCIPIO 3: ROW HORIZONTAL EN LUGAR DE LISTAS VERTICALES
  Widget _buildCrispStats() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _buildCrispStatItem(
              icon: Icons.timer_rounded,
              value: '${_recipe!.cookingTime}min',
              label: 'Tiempo',
              color: AppTheme.coralMain,
            )),
            Container(width: 1, height: 40, color: AppTheme.lightGrey.withOpacity(0.5)),
            Expanded(child: _buildCrispStatItem(
              icon: Icons.people_alt_rounded,
              value: '${_recipe!.servings}',
              label: 'Porciones',
              color: AppTheme.softTeal,
            )),
            Container(width: 1, height: 40, color: AppTheme.lightGrey.withOpacity(0.5)),
            Expanded(child: _buildCrispStatItem(
              icon: _getDifficultyIcon(_recipe!.difficulty),
              value: _getDifficultyText(_recipe!.difficulty),
              label: 'Dificultad',
              color: _getDifficultyColor(_recipe!.difficulty),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCrispStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 28, // PRINCIPIO 5: Tamaño mínimo optimizado
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.2), width: 1), // PRINCIPIO 2
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 6),
        Text(value, 
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w800, 
            color: color,
            height: 1.0,
          )),
        const SizedBox(height: 2),
        Text(label, 
          style: TextStyle(
            fontSize: 10, 
            color: AppTheme.darkGrey,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
          textAlign: TextAlign.center),
      ],
    );
  }

  // APLICANDO PRINCIPIO 4: INGREDIENTES SIMPLIFICADOS (solo enteros, sin colores)
  Widget _buildCrispIngredients() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.successGreen.withOpacity(0.2), width: 1), // PRINCIPIO 2
                  ),
                  child: Icon(Icons.list_alt_rounded, color: AppTheme.successGreen, size: 14),
                ),
                const SizedBox(width: 8),
                Text('Ingredientes', 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w700, 
                    color: AppTheme.darkGrey,
                    height: 1.0,
                  )),
              ],
            ),
            const SizedBox(height: 12),
            
            // Lista simplificada de ingredientes (solo enteros, sin colores de disponibilidad)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recipe!.ingredients.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ingredient = _recipe!.ingredients[index];
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
                  ),
                  child: Row(
                    children: [
                      // Cantidad simplificada (solo enteros)
                      Container(
                        width: 32,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.darkGrey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.darkGrey.withOpacity(0.2), width: 1), // PRINCIPIO 2
                        ),
                        child: Center(
                          child: Text(
                            ingredient.quantity.round().toString(), // SIMPLIFICADO: Solo enteros
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Unidad
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.mediumGrey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.mediumGrey.withOpacity(0.2), width: 1), // PRINCIPIO 2
                        ),
                        child: Text(
                          ingredient.unit,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mediumGrey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Nombre del ingrediente
                      Expanded(
                        child: Text(
                          ingredient.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // APLICANDO PRINCIPIO 4: PASOS SIMPLIFICADOS
  Widget _buildCrispSteps() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.yellowAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.yellowAccent.withOpacity(0.2), width: 1), // PRINCIPIO 2
                  ),
                  child: Icon(Icons.format_list_numbered_rounded, color: AppTheme.yellowAccent, size: 14),
                ),
                const SizedBox(width: 8),
                Text('Preparación', 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w700, 
                    color: AppTheme.darkGrey,
                    height: 1.0,
                  )),
              ],
            ),
            const SizedBox(height: 12),
            
            // Lista simplificada de pasos
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recipe!.steps.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final step = _recipe!.steps[index]; // step es String según el modelo
                
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Número del paso
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.yellowAccent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.yellowAccent, width: 1), // PRINCIPIO 2
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Descripción del paso - CORREGIDO: step es String según recipe_model.dart
                      Expanded(
                        child: Text(
                          step, // Directamente el string, no step.description
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.darkGrey,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // APLICANDO PRINCIPIO 2: NUTRICIÓN COMPACTA Y NÍTIDA
  Widget _buildCrispNutrition() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGrey.withOpacity(0.5), width: 1), // PRINCIPIO 2
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.coralMain.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.coralMain.withOpacity(0.2), width: 1), // PRINCIPIO 2
                  ),
                  child: Icon(Icons.restaurant_menu_rounded, color: AppTheme.coralMain, size: 14),
                ),
                const SizedBox(width: 8),
                Text('Información Nutricional', 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w700, 
                    color: AppTheme.darkGrey,
                    height: 1.0,
                  )),
              ],
            ),
            const SizedBox(height: 12),
            
            // Calorías destacadas
            if (_recipe!.calories > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.coralMain.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.coralMain.withOpacity(0.2), width: 1), // PRINCIPIO 2
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: AppTheme.coralMain, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_recipe!.calories} calorías por porción',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.coralMain,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Información nutricional detallada si está disponible
            if (_recipe!.nutritionalInfo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
                ),
                child: Column(
                  children: [
                    // Macronutrientes en row horizontal
                    Row(
                      children: [
                        Expanded(child: _buildNutrientItem(
                          'Proteínas', 
                          '${_recipe!.nutritionalInfo!.proteins.toStringAsFixed(1)}g',
                          AppTheme.successGreen,
                        )),
                        Container(width: 1, height: 30, color: AppTheme.lightGrey.withOpacity(0.5)),
                        Expanded(child: _buildNutrientItem(
                          'Carbohidratos', 
                          '${_recipe!.nutritionalInfo!.carbs.toStringAsFixed(1)}g',
                          AppTheme.yellowAccent,
                        )),
                        Container(width: 1, height: 30, color: AppTheme.lightGrey.withOpacity(0.5)),
                        Expanded(child: _buildNutrientItem(
                          'Grasas', 
                          '${_recipe!.nutritionalInfo!.fats.toStringAsFixed(1)}g',
                          AppTheme.warningOrange,
                        )),
                      ],
                    ),
                    if (_recipe!.nutritionalInfo!.fiber > 0) ...[
                      const SizedBox(height: 8),
                      Divider(color: AppTheme.lightGrey.withOpacity(0.5), height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.grass_rounded, color: AppTheme.softTeal, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Fibra: ${_recipe!.nutritionalInfo!.fiber.toStringAsFixed(1)}g',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.softTeal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (_recipe!.nutrition.isNotEmpty) ...[
              // Mostrar información de nutrition map si nutritionalInfo no está disponible
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
                ),
                child: Column(
                  children: _recipe!.nutrition.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.darkGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            entry.value.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mediumGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ] else if (_recipe!.calories == 0) ...[
              // Solo mostrar mensaje si no hay calorías ni información nutricional
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.lightGrey.withOpacity(0.3), width: 1), // PRINCIPIO 2
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.mediumGrey, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Información nutricional no disponible',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGrey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Widget helper para nutrientes individuales
  Widget _buildNutrientItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: AppTheme.darkGrey,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppTheme.lightGrey.withOpacity(0.2),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 32,
              color: AppTheme.mediumGrey,
            ),
            const SizedBox(height: 8),
            Text(
              'Sin imagen',
              style: TextStyle(
                color: AppTheme.mediumGrey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorRed.withOpacity(0.3), width: 1), // PRINCIPIO 2
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.errorRed.withOpacity(0.2), width: 1), // PRINCIPIO 2
              ),
              child: Icon(Icons.error_outline_rounded, size: 24, color: AppTheme.errorRed),
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar receta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se pudo obtener la información',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.mediumGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Volver', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToImageEdit() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeImageScreen(recipe: _recipe!),
        ),
      );
      
      if (result == true) {
        setState(() => _isLoading = true);
        await _loadRecipe();
        setState(() => _isLoading = false);
        
        _showCrispSnackBar(
          type: SnackBarType.success,
          title: 'Imagen actualizada',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      _showCrispSnackBar(
        type: SnackBarType.error,
        title: 'Error al editar imagen',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  IconData _getDifficultyIcon(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return Icons.sentiment_very_satisfied_rounded;
      case DifficultyLevel.medium:
        return Icons.sentiment_neutral_rounded;
      case DifficultyLevel.hard:
        return Icons.sentiment_very_dissatisfied_rounded;
      default:
        return Icons.help_outline_rounded;
    }
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
        return '?';
    }
  }

  Color _getDifficultyColor(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return AppTheme.successGreen;
      case DifficultyLevel.medium:
        return AppTheme.warningOrange;
      case DifficultyLevel.hard:
        return AppTheme.errorRed;
      default:
        return AppTheme.mediumGrey;
    }
  }
}

/// Tipos de SnackBar
enum SnackBarType {
  success,
  error,
  warning,
  info,
}

/// Colores para SnackBar
class SnackBarColors {
  final Color backgroundColor;
  final Color iconColor;

  SnackBarColors({
    required this.backgroundColor,
    required this.iconColor,
  });
}