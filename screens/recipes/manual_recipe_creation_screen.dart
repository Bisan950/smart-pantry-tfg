// lib/screens/recipes/manual_recipe_creation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/recipe_model.dart';
import '../../services/recipe_service.dart';
import '../../services/gemini_recipe_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/custom_chip_widget.dart';
import '../../widgets/recipes/difficulty_indicator.dart';

// Extensión para añadir copyWith al modelo Recipe
extension RecipeCopyWith on Recipe {
 Recipe copyWith({
   String? id,
   String? name,
   String? description,
   String? imageUrl,
   int? preparationTime,
   int? cookingTime,
   int? servings,
   DifficultyLevel? difficulty,
   List<String>? categories,
   List<RecipeIngredient>? ingredients,
   List<String>? steps,
   int? calories,
   Map<String, dynamic>? nutrition,
   DateTime? createdAt,
   DateTime? updatedAt,
 }) {
   return Recipe(
     id: id ?? this.id,
     name: name ?? this.name,
     description: description ?? this.description,
     imageUrl: imageUrl ?? this.imageUrl,
     preparationTime: preparationTime ?? this.preparationTime,
     cookingTime: cookingTime ?? this.cookingTime,
     servings: servings ?? this.servings,
     difficulty: difficulty ?? this.difficulty,
     categories: categories ?? this.categories,
     ingredients: ingredients ?? this.ingredients,
     steps: steps ?? this.steps,
     calories: calories ?? this.calories,
     nutrition: nutrition ?? this.nutrition,
     createdAt: createdAt ?? this.createdAt,
     updatedAt: updatedAt ?? this.updatedAt,
   );
 }
}

class ManualRecipeCreationScreen extends StatefulWidget {
 final Recipe? recipeToEdit;
 
 const ManualRecipeCreationScreen({
   super.key,
   this.recipeToEdit,
 });

 @override
 State<ManualRecipeCreationScreen> createState() => _ManualRecipeCreationScreenState();
}

class _ManualRecipeCreationScreenState extends State<ManualRecipeCreationScreen> {
 final RecipeService _recipeService = RecipeService();
 final _formKey = GlobalKey<FormState>();
 final PageController _pageController = PageController();
 
 // Servicio para generar información nutricional con IA
 final GeminiRecipeService _geminiService = GeminiRecipeService();
 
 // Estado para la generación de información nutricional
 bool _isGeneratingNutrition = false;
 
 // Controladores de texto
 final _nameController = TextEditingController();
 final _descriptionController = TextEditingController();
 final _imageUrlController = TextEditingController();
 final _preparationTimeController = TextEditingController();
 final _cookingTimeController = TextEditingController();
 final _servingsController = TextEditingController();
 
 // Controladores para ingredientes
 final List<TextEditingController> _ingredientNameControllers = [];
 final List<TextEditingController> _ingredientQuantityControllers = [];
 final List<TextEditingController> _ingredientUnitControllers = [];
 
 // Controladores para pasos
 final List<TextEditingController> _stepControllers = [];
 
 // Estado
 bool _isLoading = false;
 bool _isEditMode = false;
 int _currentStep = 0;
 DifficultyLevel _selectedDifficulty = DifficultyLevel.medium;
 List<String> _selectedCategories = [];
 List<RecipeIngredient> _ingredients = [];
 List<String> _steps = [];
 
 // Nuevas variables para el estado del formulario
 bool _isFormValid = false;
 final Map<String, bool> _fieldCompletionStatus = {};
 
 // Opciones predefinidas
 final List<String> _availableCategories = [
   'Desayuno', 'Almuerzo', 'Cena', 'Aperitivo', 'Postre',
   'Vegetariana', 'Vegana', 'Sin Gluten', 'Saludable',
   'Rápida', 'Mediterránea', 'Italiana', 'Mexicana', 'Asiática',
   'Carnes', 'Pescados', 'Ensaladas', 'Sopas', 'Pasta',
 ];
 
 final List<String> _commonUnits = [
   'g', 'kg', 'ml', 'l', 'cucharadas', 'cucharaditas', 'tazas',
   'unidades', 'piezas', 'dientes', 'ramitas', 'hojas', 'pizca', 'paquete',
 ];

 final List<String> _stepTitles = [
   'Información básica',
   'Detalles',
   'Ingredientes',
   'Preparación'
 ];

 @override
 void initState() {
   super.initState();
   _initializeForm();
   _setupFormValidationListeners();
 }

 void _initializeForm() {
   _isEditMode = widget.recipeToEdit != null;
   
   if (_isEditMode) {
     final recipe = widget.recipeToEdit!;
     _nameController.text = recipe.name;
     _descriptionController.text = recipe.description;
     _imageUrlController.text = recipe.imageUrl;
     _preparationTimeController.text = recipe.preparationTime.toString();
     _cookingTimeController.text = recipe.cookingTime.toString();
     _servingsController.text = recipe.servings.toString();
     _selectedDifficulty = recipe.difficulty;
     _selectedCategories = List.from(recipe.categories);
     _ingredients = List.from(recipe.ingredients);
     _steps = List.from(recipe.steps);
   } else {
     _preparationTimeController.text = '15';
     _cookingTimeController.text = '30';
     _servingsController.text = '4';
     _ingredients = [_createEmptyIngredient()];
     _steps = [''];
   }
   
   _initializeControllers();
   _validateForm();
 }

 void _setupFormValidationListeners() {
   // Añadir listeners a todos los controladores para validación en tiempo real
   _nameController.addListener(_validateForm);
   _descriptionController.addListener(_validateForm);
   _preparationTimeController.addListener(_validateForm);
   _cookingTimeController.addListener(_validateForm);
   _servingsController.addListener(_validateForm);
 }

 void _initializeControllers() {
   _ingredientNameControllers.clear();
   _ingredientQuantityControllers.clear();
   _ingredientUnitControllers.clear();
   
   for (var ingredient in _ingredients) {
     final nameController = TextEditingController(text: ingredient.name);
     final quantityController = TextEditingController(text: ingredient.quantity.round().toString());
     final unitController = TextEditingController(text: ingredient.unit);
     
     nameController.addListener(_validateForm);
     quantityController.addListener(_validateForm);
     unitController.addListener(_validateForm);
     
     _ingredientNameControllers.add(nameController);
     _ingredientQuantityControllers.add(quantityController);
     _ingredientUnitControllers.add(unitController);
   }
   
   _stepControllers.clear();
   for (var step in _steps) {
     final stepController = TextEditingController(text: step);
     stepController.addListener(_validateForm);
     _stepControllers.add(stepController);
   }
 }

 RecipeIngredient _createEmptyIngredient() {
   return const RecipeIngredient(
     name: '',
     quantity: 1,
     unit: '',
   );
 }

 void _validateForm() {
   setState(() {
     // Validar campos básicos
     _fieldCompletionStatus['name'] = _nameController.text.trim().length >= 3;
     _fieldCompletionStatus['description'] = _descriptionController.text.trim().length >= 10;
     _fieldCompletionStatus['preparationTime'] = _preparationTimeController.text.trim().isNotEmpty && 
         int.tryParse(_preparationTimeController.text) != null && 
         int.parse(_preparationTimeController.text) > 0;
     _fieldCompletionStatus['cookingTime'] = _cookingTimeController.text.trim().isNotEmpty && 
         int.tryParse(_cookingTimeController.text) != null && 
         int.parse(_cookingTimeController.text) > 0;
     _fieldCompletionStatus['servings'] = _servingsController.text.trim().isNotEmpty && 
         int.tryParse(_servingsController.text) != null && 
         int.parse(_servingsController.text) > 0;
     
     // Validar ingredientes
     int validIngredients = 0;
     bool allIngredientsValid = true;
     
     for (int i = 0; i < _ingredientNameControllers.length; i++) {
       final name = _ingredientNameControllers[i].text.trim();
       final quantity = _ingredientQuantityControllers[i].text.trim();
       final unit = _ingredientUnitControllers[i].text.trim();
       
       if (name.isNotEmpty && quantity.isNotEmpty && unit.isNotEmpty) {
         if (name.length >= 2 && int.tryParse(quantity) != null && int.parse(quantity) > 0) {
           validIngredients++;
         } else {
           allIngredientsValid = false;
         }
       } else if (name.isNotEmpty || quantity.isNotEmpty || unit.isNotEmpty) {
         allIngredientsValid = false;
       }
     }
     
     _fieldCompletionStatus['ingredients'] = validIngredients > 0 && allIngredientsValid;
     
     // Validar pasos
     int validSteps = 0;
     bool allStepsValid = true;
     
     for (final controller in _stepControllers) {
       final step = controller.text.trim();
       if (step.isNotEmpty) {
         if (step.length >= 10) {
           validSteps++;
         } else {
           allStepsValid = false;
         }
       }
     }
     
     _fieldCompletionStatus['steps'] = validSteps > 0 && allStepsValid;
     
     // Determinar si el formulario es válido
     _isFormValid = _fieldCompletionStatus['name'] == true &&
         _fieldCompletionStatus['description'] == true &&
         _fieldCompletionStatus['preparationTime'] == true &&
         _fieldCompletionStatus['cookingTime'] == true &&
         _fieldCompletionStatus['servings'] == true &&
         _fieldCompletionStatus['ingredients'] == true &&
         _fieldCompletionStatus['steps'] == true;
   });
 }

 @override
 void dispose() {
   _nameController.dispose();
   _descriptionController.dispose();
   _imageUrlController.dispose();
   _preparationTimeController.dispose();
   _cookingTimeController.dispose();
   _servingsController.dispose();
   _pageController.dispose();
   
   for (var controller in _ingredientNameControllers) {
     controller.dispose();
   }
   for (var controller in _ingredientQuantityControllers) {
     controller.dispose();
   }
   for (var controller in _ingredientUnitControllers) {
     controller.dispose();
   }
   for (var controller in _stepControllers) {
     controller.dispose();
   }
   
   super.dispose();
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     backgroundColor: const Color(0xFFF8F9FA),
     appBar: _buildModernAppBar(),
     body: _isLoading
         ? _buildLoadingState()
         : Column(
             children: [
               _buildProgressIndicator(),
               _buildCompletionStatus(),
               Expanded(
                 child: SingleChildScrollView(
                   child: SizedBox(
                     height: MediaQuery.of(context).size.height - 280,
                     child: _buildStepContent(),
                   ),
                 ),
               ),
               _buildBottomNavigation(),
             ],
           ),
   );
 }

 PreferredSizeWidget _buildModernAppBar() {
   return AppBar(
     backgroundColor: Colors.white,
     elevation: 0,
     leading: IconButton(
       icon: Container(
         padding: const EdgeInsets.all(8),
         decoration: BoxDecoration(
           color: AppTheme.coralMain.withOpacity(0.1),
           borderRadius: BorderRadius.circular(12),
         ),
         child: Icon(Icons.arrow_back_ios_new, 
           color: AppTheme.coralMain, size: 16),
       ),
       onPressed: () => Navigator.of(context).pop(),
     ),
     title: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           _isEditMode ? 'Editar Receta' : 'Nueva Receta',
           style: const TextStyle(
             fontSize: 20,
             fontWeight: FontWeight.bold,
             color: Color(0xFF1A1D29),
           ),
         ),
         Text(
           _stepTitles[_currentStep],
           style: TextStyle(
             fontSize: 14,
             color: AppTheme.mediumGrey,
             fontWeight: FontWeight.w500,
           ),
         ),
       ],
     ),
     actions: [
       if (_isEditMode)
         Container(
           margin: const EdgeInsets.only(right: 16),
           child: IconButton(
             icon: Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: AppTheme.errorRed.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Icon(Icons.delete_outline, 
                 color: AppTheme.errorRed, size: 20),
             ),
             onPressed: _showDeleteConfirmation,
           ),
         ),
     ],
   );
 }

 Widget _buildLoadingState() {
   return Container(
     color: Colors.white,
     child: Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           CircularProgressIndicator(color: AppTheme.coralMain),
           const SizedBox(height: 20),
           Text(
             _isGeneratingNutrition 
                 ? 'Generando información nutricional con IA...'
                 : 'Guardando receta...',
             style: const TextStyle(
               fontSize: 16,
               fontWeight: FontWeight.w500,
               color: Color(0xFF6B7280),
             ),
           ),
           if (_isGeneratingNutrition) ...[
             const SizedBox(height: 12),
             const Text(
               'Analizando ingredientes y calculando valores nutricionales',
               style: TextStyle(
                 fontSize: 14,
                 color: Color(0xFF9CA3AF),
               ),
               textAlign: TextAlign.center,
             ),
           ],
         ],
       ),
     ),
   );
 }

 Widget _buildProgressIndicator() {
   return Container(
     padding: const EdgeInsets.all(20),
     decoration: const BoxDecoration(
       color: Colors.white,
       boxShadow: [
         BoxShadow(
           color: Color(0x0A000000),
           blurRadius: 10,
           offset: Offset(0, 2),
         ),
       ],
     ),
     child: Row(
       children: List.generate(4, (index) {
         final isActive = index == _currentStep;
         final isCompleted = index < _currentStep;
         
         return Expanded(
           child: Row(
             children: [
               Expanded(
                 child: Container(
                   height: 4,
                   decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(2),
                     color: isCompleted || isActive
                         ? AppTheme.coralMain
                         : const Color(0xFFE5E7EB),
                   ),
                 ),
               ),
               if (index < 3) const SizedBox(width: 8),
             ],
           ),
         );
       }),
     ),
   );
 }

 Widget _buildCompletionStatus() {
   final List<Widget> statusItems = [];
   
   // Status para cada paso
   if (_currentStep >= 0) {
     statusItems.addAll([
       _buildStatusItem('Nombre', _fieldCompletionStatus['name'] ?? false, isRequired: true),
       _buildStatusItem('Descripción', _fieldCompletionStatus['description'] ?? false, isRequired: true),
     ]);
   }
   
   if (_currentStep >= 1) {
     statusItems.addAll([
       _buildStatusItem('Tiempos', 
         (_fieldCompletionStatus['preparationTime'] ?? false) && 
         (_fieldCompletionStatus['cookingTime'] ?? false) && 
         (_fieldCompletionStatus['servings'] ?? false), 
         isRequired: true),
     ]);
   }
   
   if (_currentStep >= 2) {
     statusItems.add(
       _buildStatusItem('Ingredientes', _fieldCompletionStatus['ingredients'] ?? false, isRequired: true)
     );
   }
   
   if (_currentStep >= 3) {
     statusItems.add(
       _buildStatusItem('Pasos', _fieldCompletionStatus['steps'] ?? false, isRequired: true)
     );
   }

   if (statusItems.isEmpty) return const SizedBox.shrink();

   return Container(
     margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
     padding: const EdgeInsets.all(16),
     decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(12),
       border: Border.all(
         color: _isFormValid ? AppTheme.successGreen : const Color(0xFFE5E7EB),
         width: 1,
       ),
     ),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Row(
           children: [
             Icon(
               _isFormValid ? Icons.check_circle : Icons.info_outline,
               color: _isFormValid ? AppTheme.successGreen : AppTheme.coralMain,
               size: 16,
             ),
             const SizedBox(width: 8),
             Text(
               _isFormValid ? 'Receta lista para guardar' : 'Estado de la receta',
               style: TextStyle(
                 fontWeight: FontWeight.w600,
                 fontSize: 14,
                 color: _isFormValid ? AppTheme.successGreen : AppTheme.coralMain,
               ),
             ),
           ],
         ),
         const SizedBox(height: 12),
         Wrap(
           spacing: 8,
           runSpacing: 8,
           children: statusItems,
         ),
       ],
     ),
   );
 }

 Widget _buildStatusItem(String label, bool isCompleted, {bool isRequired = false}) {
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
     decoration: BoxDecoration(
       color: isCompleted 
           ? AppTheme.successGreen.withOpacity(0.1) 
           : isRequired 
               ? AppTheme.errorRed.withOpacity(0.1)
               : const Color(0xFFF3F4F6),
       borderRadius: BorderRadius.circular(20),
       border: Border.all(
         color: isCompleted 
             ? AppTheme.successGreen 
             : isRequired 
                 ? AppTheme.errorRed.withOpacity(0.3)
                 : const Color(0xFFE5E7EB),
         width: 1,
       ),
     ),
     child: Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Icon(
           isCompleted ? Icons.check : Icons.circle_outlined,
           size: 14,
           color: isCompleted 
               ? AppTheme.successGreen 
               : isRequired 
                   ? AppTheme.errorRed
                   : const Color(0xFF9CA3AF),
         ),
         const SizedBox(width: 6),
         Text(
           label + (isRequired && !isCompleted ? ' *' : ''),
           style: TextStyle(
             fontSize: 12,
             fontWeight: FontWeight.w500,
             color: isCompleted 
                 ? AppTheme.successGreen 
                 : isRequired 
                     ? AppTheme.errorRed
                     : const Color(0xFF6B7280),
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildStepContent() {
   return PageView(
     controller: _pageController,
     onPageChanged: (index) => setState(() => _currentStep = index),
     children: [
       _buildBasicInfoStep(),
       _buildDetailsStep(),
       _buildIngredientsStep(),
       _buildStepsSection(),
     ],
   );
 }

 Widget _buildBasicInfoStep() {
   return SingleChildScrollView(
     padding: const EdgeInsets.all(20),
     child: Form(
       key: _formKey,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // Nota sobre campos obligatorios
           Container(
             padding: const EdgeInsets.all(16),
             margin: const EdgeInsets.only(bottom: 20),
             decoration: BoxDecoration(
               color: AppTheme.coralMain.withOpacity(0.1),
               borderRadius: BorderRadius.circular(12),
               border: Border.all(
                 color: AppTheme.coralMain.withOpacity(0.3),
                 width: 1,
               ),
             ),
             child: Row(
               children: [
                 Icon(
                   Icons.info_outline,
                   color: AppTheme.coralMain,
                   size: 20,
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Text(
                     'Los campos marcados con * son obligatorios. Los campos opcionales pueden dejarse vacíos.',
                     style: TextStyle(
                       color: AppTheme.coralMain,
                       fontSize: 14,
                       fontWeight: FontWeight.w500,
                     ),
                   ),
                 ),
               ],
             ),
           ),
           
           _buildStepCard(
             title: 'Información Principal',
             icon: Icons.restaurant_menu,
             child: Column(
               children: [
                 _buildModernTextField(
                   label: 'Nombre de la receta *',
                   controller: _nameController,
                   hintText: 'Ej: Pasta carbonara casera',
                   icon: Icons.title,
                   isRequired: true,
                   validator: (value) {
                     if (value == null || value.trim().isEmpty) {
                       return 'El nombre de la receta es obligatorio';
                     }
                     if (value.trim().length < 3) {
                       return 'El nombre debe tener al menos 3 caracteres';
                     }
                     return null;
                   },
                 ),
                 const SizedBox(height: 20),
                 _buildModernTextField(
                   label: 'Descripción *',
                   controller: _descriptionController,
                   hintText: 'Describe brevemente tu receta... (mínimo 10 caracteres)',
                   icon: Icons.description,
                   maxLines: 4,
                   isRequired: true,
                   validator: (value) {
                     if (value == null || value.trim().isEmpty) {
                       return 'La descripción es obligatoria';
                     }
                     if (value.trim().length < 10) {
                       return 'La descripción debe tener al menos 10 caracteres';
                     }
                     return null;
                   },
                 ),
               ],
             ),
           ),
           const SizedBox(height: 20),
           _buildStepCard(
             title: 'Imagen (Opcional)',
             icon: Icons.image,
             child: _buildModernTextField(
               label: 'URL de la imagen',
               controller: _imageUrlController,
               hintText: 'https://ejemplo.com/imagen.jpg (opcional)',
               icon: Icons.link,
               keyboardType: TextInputType.url,
             ),
           ),
           const SizedBox(height: 20),
           _buildCategoriesCard(),
         ],
       ),
     ),
   );
 }

 Widget _buildDetailsStep() {
   return SingleChildScrollView(
     padding: const EdgeInsets.all(20),
     child: Column(
       children: [
         _buildStepCard(
           title: 'Tiempos de Preparación',
           icon: Icons.schedule,
           child: Column(
             children: [
               Row(
                 children: [
                   Expanded(
                     child: _buildTimeCard(
                       'Preparación *',
                       _preparationTimeController,
                       Icons.access_time,
                       'min',
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: _buildTimeCard(
                       'Cocción *',
                       _cookingTimeController,
                       Icons.timer,
                       'min',
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 16),
               _buildTimeCard(
                 'Porciones *',
                 _servingsController,
                 Icons.people,
                 'personas',
               ),
             ],
           ),
         ),
         const SizedBox(height: 20),
         _buildDifficultyCard(),
         const SizedBox(height: 20),
         _buildNutritionInfoCard(),
       ],
     ),
   );
 }

 Widget _buildIngredientsStep() {
   return Column(
     children: [
       Container(
         padding: const EdgeInsets.all(20),
         decoration: const BoxDecoration(
           color: Colors.white,
           border: Border(
             bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
           ),
         ),
         child: Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text(
                   'Ingredientes *',
                   style: TextStyle(
                     fontSize: 20,
                     fontWeight: FontWeight.bold,
                     color: Color(0xFF1A1D29),
                   ),
                 ),
                 Text(
                   '${_getValidIngredientsCount()} ingrediente${_getValidIngredientsCount() != 1 ? 's' : ''} válido${_getValidIngredientsCount() != 1 ? 's' : ''}',
                   style: TextStyle(
                     color: _getValidIngredientsCount() > 0 ? AppTheme.successGreen : AppTheme.errorRed,
                     fontSize: 14,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
               ],
             ),
             _buildFloatingActionButton(
               onPressed: _addIngredient,
               icon: Icons.add,
             ),
           ],
         ),
       ),
       Expanded(
         child: _ingredients.isEmpty
             ? _buildEmptyIngredientsState()
             : ListView.builder(
                 padding: const EdgeInsets.all(20),
                 itemCount: _ingredients.length,
                 itemBuilder: (context, index) => _buildIngredientCard(index),
               ),
       ),
     ],
   );
 }

 Widget _buildStepsSection() {
   return Column(
     children: [
       Container(
         padding: const EdgeInsets.all(20),
         decoration: const BoxDecoration(
           color: Colors.white,
           border: Border(
             bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
           ),
         ),
         child: Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text(
                   'Pasos de Preparación *',
                   style: TextStyle(
                     fontSize: 20,
                     fontWeight: FontWeight.bold,
                     color: Color(0xFF1A1D29),
                   ),
                 ),
                 Text(
                   '${_getValidStepsCount()} paso${_getValidStepsCount() != 1 ? 's' : ''} válido${_getValidStepsCount() != 1 ? 's' : ''}',
                   style: TextStyle(
                     color: _getValidStepsCount() > 0 ? AppTheme.successGreen : AppTheme.errorRed,
                     fontSize: 14,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
               ],
             ),
             _buildFloatingActionButton(
               onPressed: _addStep,
               icon: Icons.add,
             ),
           ],
         ),
       ),
       Expanded(
         child: _steps.isEmpty || (_steps.length == 1 && _steps.first.isEmpty)
             ? _buildEmptyStepsState()
             : ListView.builder(
                 padding: const EdgeInsets.all(20),
                 itemCount: _steps.length,
                 itemBuilder: (context, index) => _buildStepCard2(index),
               ),
       ),
     ],
   );
 }

 int _getValidIngredientsCount() {
   int count = 0;
   for (int i = 0; i < _ingredientNameControllers.length; i++) {
     final name = _ingredientNameControllers[i].text.trim();
     final quantity = _ingredientQuantityControllers[i].text.trim();
     final unit = _ingredientUnitControllers[i].text.trim();
     
     if (name.isNotEmpty && quantity.isNotEmpty && unit.isNotEmpty &&
         name.length >= 2 && int.tryParse(quantity) != null && int.parse(quantity) > 0) {
       count++;
     }
   }
   return count;
 }

 int _getValidStepsCount() {
   int count = 0;
   for (final controller in _stepControllers) {
     final step = controller.text.trim();
     if (step.isNotEmpty && step.length >= 10) {
       count++;
     }
   }
   return count;
 }

 Widget _buildStepCard({
   required String title,
   required IconData icon,
   required Widget child,
 }) {
   return Container(
     decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(16),
       boxShadow: const [
         BoxShadow(
           color: Color(0x08000000),
           blurRadius: 20,
           offset: Offset(0, 4),
         ),
       ],
     ),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Padding(
           padding: const EdgeInsets.all(20),
           child: Row(
             children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: AppTheme.coralMain.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Icon(icon, color: AppTheme.coralMain, size: 20),
               ),
               const SizedBox(width: 12),
               Text(
                 title,
                 style: const TextStyle(
                   fontSize: 18,
                   fontWeight: FontWeight.bold,
                   color: Color(0xFF1A1D29),
                 ),
               ),
             ],
           ),
         ),
         Padding(
           padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
           child: child,
         ),
       ],
     ),
   );
 }

 Widget _buildModernTextField({
   required String label,
   required TextEditingController controller,
   required String hintText,
   required IconData icon,
   int maxLines = 1,
   TextInputType? keyboardType,
   String? Function(String?)? validator,
   bool isRequired = false,
 }) {
   final isCompleted = controller.text.trim().isNotEmpty && 
       (validator == null || validator(controller.text) == null);
   
   return TextFormField(
     controller: controller,
     maxLines: maxLines,
     keyboardType: keyboardType,
     validator: validator,
     decoration: InputDecoration(
       labelText: label,
       hintText: hintText,
       prefixIcon: Container(
         margin: const EdgeInsets.all(12),
         padding: const EdgeInsets.all(8),
         decoration: BoxDecoration(
           color: isCompleted && isRequired
               ? AppTheme.successGreen.withOpacity(0.1)
               : AppTheme.coralMain.withOpacity(0.1),
           borderRadius: BorderRadius.circular(8),
         ),
         child: Icon(
           isCompleted && isRequired ? Icons.check : icon, 
           color: isCompleted && isRequired ? AppTheme.successGreen : AppTheme.coralMain, 
           size: 20,
         ),
       ),
       suffixIcon: isRequired ? Container(
         margin: const EdgeInsets.all(12),
         child: Icon(
           isCompleted ? Icons.check_circle : Icons.circle_outlined,
           color: isCompleted ? AppTheme.successGreen : AppTheme.mediumGrey,
           size: 20,
         ),
       ) : null,
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(16),
         borderSide: BorderSide(
           color: isCompleted && isRequired ? AppTheme.successGreen : const Color(0xFFE5E7EB),
         ),
       ),
       enabledBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(16),
         borderSide: BorderSide(
           color: isCompleted && isRequired ? AppTheme.successGreen : const Color(0xFFE5E7EB),
         ),
       ),
       focusedBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(16),
         borderSide: BorderSide(color: AppTheme.coralMain, width: 2),
       ),
       errorBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(16),
         borderSide: BorderSide(color: AppTheme.errorRed, width: 2),
       ),
       filled: true,
       fillColor: const Color(0xFFFAFAFA),
       contentPadding: const EdgeInsets.all(16),
     ),
   );
 }

 Widget _buildCategoriesCard() {
   return _buildStepCard(
     title: 'Categorías (Opcional)',
     icon: Icons.category,
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           'Selecciona las categorías que mejor describan tu receta:',
           style: TextStyle(
             color: AppTheme.mediumGrey,
             fontSize: 14,
           ),
         ),
         const SizedBox(height: 16),
         Wrap(
           spacing: 8,
           runSpacing: 8,
           children: _availableCategories.map((category) {
             final isSelected = _selectedCategories.contains(category);
             return GestureDetector(
               onTap: () {
                 setState(() {
                   if (isSelected) {
                     _selectedCategories.remove(category);
                   } else {
                     _selectedCategories.add(category);
                   }
                 });
               },
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(
                   color: isSelected 
                       ? AppTheme.coralMain 
                       : const Color(0xFFF3F4F6),
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(
                     color: isSelected 
                         ? AppTheme.coralMain 
                         : const Color(0xFFE5E7EB),
                   ),
                 ),
                 child: Text(
                   category,
                   style: TextStyle(
                     color: isSelected 
                         ? Colors.white 
                         : const Color(0xFF374151),
                     fontWeight: FontWeight.w500,
                     fontSize: 14,
                   ),
                 ),
               ),
             );
           }).toList(),
         ),
       ],
     ),
   );
 }

 Widget _buildTimeCard(
   String label,
   TextEditingController controller,
   IconData icon,
   String unit,
 ) {
   final isCompleted = controller.text.trim().isNotEmpty && 
       int.tryParse(controller.text) != null && 
       int.parse(controller.text) > 0;
   
   return Container(
     padding: const EdgeInsets.all(16),
     decoration: BoxDecoration(
       color: const Color(0xFFFAFAFA),
       borderRadius: BorderRadius.circular(12),
       border: Border.all(
         color: isCompleted ? AppTheme.successGreen : const Color(0xFFE5E7EB),
         width: isCompleted ? 2 : 1,
       ),
     ),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Row(
           children: [
             Icon(
               isCompleted ? Icons.check : icon, 
               color: isCompleted ? AppTheme.successGreen : AppTheme.coralMain, 
               size: 16,
             ),
             const SizedBox(width: 8),
             Expanded(
               child: Text(
                 label,
                 style: TextStyle(
                   fontSize: 14,
                   fontWeight: FontWeight.w600,
                   color: isCompleted ? AppTheme.successGreen : const Color(0xFF374151),
                 ),
               ),
             ),
           ],
         ),
         const SizedBox(height: 8),
         Row(
           children: [
             Expanded(
               child: TextFormField(
                 controller: controller,
                 keyboardType: TextInputType.number,
                 textAlign: TextAlign.center,
                 style: TextStyle(
                   fontSize: 18,
                   fontWeight: FontWeight.bold,
                   color: isCompleted ? AppTheme.successGreen : const Color(0xFF1A1D29),
                 ),
                 decoration: const InputDecoration(
                   border: InputBorder.none,
                   contentPadding: EdgeInsets.zero,
                 ),
                 validator: (value) {
                   if (value == null || value.isEmpty) {
                     return 'Requerido';
                   }
                   final time = int.tryParse(value);
                   if (time == null || time <= 0) {
                     return 'Inválido';
                   }
                   return null;
                 },
               ),
             ),
             Text(
               unit,
               style: TextStyle(
                 fontSize: 14,
                 color: AppTheme.mediumGrey,
                 fontWeight: FontWeight.w500,
               ),
             ),
           ],
         ),
       ],
     ),
   );
 }

 Widget _buildDifficultyCard() {
   return _buildStepCard(
     title: 'Nivel de Dificultad',
     icon: Icons.trending_up,
     child: Row(
       children: DifficultyLevel.values.map((difficulty) {
         final isSelected = _selectedDifficulty == difficulty;
         final label = _getDifficultyLabel(difficulty);
         final isLast = difficulty == DifficultyLevel.values.last;
         
         return Expanded(
           child: Container(
             margin: EdgeInsets.only(right: isLast ? 0 : 12),
             child: GestureDetector(
               onTap: () => setState(() => _selectedDifficulty = difficulty),
               child: Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: isSelected 
                       ? AppTheme.coralMain 
                       : const Color(0xFFFAFAFA),
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(
                     color: isSelected 
                         ? AppTheme.coralMain 
                         : const Color(0xFFE5E7EB),
                     width: isSelected ? 2 : 1,
                   ),
                 ),
                 child: Column(
                   children: [
                     DifficultyIndicator(
                       difficulty: difficulty,
                       showLabel: false,
                     ),
                     const SizedBox(height: 8),
                     Text(
                       label,
                       style: TextStyle(
                         fontSize: 14,
                         fontWeight: FontWeight.w600,
                         color: isSelected 
                             ? Colors.white 
                             : const Color(0xFF374151),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
           ),
         );
       }).toList(),
     ),
   );
 }

 Widget _buildNutritionInfoCard() {
   return _buildStepCard(
     title: 'Información Nutricional',
     icon: Icons.analytics,
     child: Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: AppTheme.successGreen.withOpacity(0.1),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(
           color: AppTheme.successGreen.withOpacity(0.3),
           width: 1,
         ),
       ),
       child: Row(
         children: [
           Icon(
             Icons.auto_awesome,
             color: AppTheme.successGreen,
             size: 24,
           ),
           const SizedBox(width: 12),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   'Generación automática con IA',
                   style: TextStyle(
                     color: AppTheme.successGreen,
                     fontSize: 16,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 const SizedBox(height: 4),
                 Text(
                   'Las calorías y valores nutricionales se calcularán automáticamente basándose en los ingredientes cuando guardes la receta.',
                   style: TextStyle(
                     color: AppTheme.successGreen,
                     fontSize: 14,
                     height: 1.4,
                   ),
                 ),
               ],
             ),
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildFloatingActionButton({
   required VoidCallback onPressed,
   required IconData icon,
 }) {
   return Container(
     decoration: BoxDecoration(
       color: AppTheme.coralMain,
       borderRadius: BorderRadius.circular(16),
       boxShadow: [
         BoxShadow(
           color: AppTheme.coralMain.withOpacity(0.3),
           blurRadius: 8,
           offset: const Offset(0, 4),
         ),
       ],
     ),
     child: Material(
       color: Colors.transparent,
       child: InkWell(
         onTap: onPressed,
         borderRadius: BorderRadius.circular(16),
         child: Container(
           padding: const EdgeInsets.all(12),
           child: Icon(icon, color: Colors.white, size: 24),
         ),
       ),
     ),
   );
 }

 Widget _buildEmptyIngredientsState() {
   return Center(
     child: Padding(
       padding: const EdgeInsets.all(40),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Container(
             padding: const EdgeInsets.all(24),
             decoration: BoxDecoration(
               color: AppTheme.coralMain.withOpacity(0.1),
               shape: BoxShape.circle,
             ),
             child: Icon(
               Icons.restaurant_menu,
               size: 48,
               color: AppTheme.coralMain,
             ),
           ),
           const SizedBox(height: 24),
           const Text(
             'No hay ingredientes',
             style: TextStyle(
               fontSize: 20,
               fontWeight: FontWeight.bold,
               color: Color(0xFF1A1D29),
             ),
           ),
           const SizedBox(height: 8),
           Text(
             'Añade los ingredientes necesarios\npara tu receta',
             textAlign: TextAlign.center,
             style: TextStyle(
               fontSize: 16,
               color: AppTheme.mediumGrey,
               height: 1.5,
             ),
           ),
           const SizedBox(height: 32),
           ElevatedButton.icon(
             onPressed: _addIngredient,
             icon: const Icon(Icons.add),
             label: const Text('Añadir primer ingrediente'),
             style: ElevatedButton.styleFrom(
               backgroundColor: AppTheme.coralMain,
               foregroundColor: Colors.white,
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(16),
               ),
               elevation: 0,
             ),
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildIngredientCard(int index) {
   final name = _ingredientNameControllers[index].text.trim();
   final quantity = _ingredientQuantityControllers[index].text.trim();
   final unit = _ingredientUnitControllers[index].text.trim();
   
   final isComplete = name.isNotEmpty && quantity.isNotEmpty && unit.isNotEmpty &&
       name.length >= 2 && int.tryParse(quantity) != null && int.parse(quantity) > 0;
   
   return Container(
     margin: const EdgeInsets.only(bottom: 16),
     decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(16),
       border: Border.all(
         color: isComplete ? AppTheme.successGreen : const Color(0xFFE5E7EB),
         width: isComplete ? 2 : 1,
       ),
       boxShadow: const [
         BoxShadow(
           color: Color(0x08000000),
           blurRadius: 20,
           offset: Offset(0, 4),
         ),
       ],
     ),
     child: Padding(
       padding: const EdgeInsets.all(20),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Row(
                 children: [
                   Icon(
                     isComplete ? Icons.check_circle : Icons.circle_outlined,
                     color: isComplete ? AppTheme.successGreen : AppTheme.mediumGrey,
                     size: 20,
                   ),
                   const SizedBox(width: 8),
                   Text(
                     'Ingrediente ${index + 1}',
                     style: TextStyle(
                       fontSize: 16,
                       fontWeight: FontWeight.bold,
                       color: isComplete ? AppTheme.successGreen : const Color(0xFF1A1D29),
                     ),
                   ),
                 ],
               ),
               if (_ingredients.length > 1)
                 GestureDetector(
                   onTap: () => _removeIngredient(index),
                   child: Container(
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(
                       color: AppTheme.errorRed.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Icon(
                       Icons.delete_outline,
                       color: AppTheme.errorRed,
                       size: 20,
                     ),
                   ),
                 ),
             ],
           ),
           const SizedBox(height: 16),
           _buildModernTextField(
             label: 'Nombre del ingrediente *',
             controller: _ingredientNameControllers[index],
             hintText: 'Ej: Tomate (mín. 2 caracteres)',
             icon: Icons.restaurant_menu,
             isRequired: true,
             validator: (value) {
               if (value == null || value.trim().isEmpty) {
                 return 'El nombre del ingrediente es obligatorio';
               }
               if (value.trim().length < 2) {
                 return 'El nombre debe tener al menos 2 caracteres';
               }
               return null;
             },
           ),
           const SizedBox(height: 16),
           Row(
             children: [
               Expanded(
                 flex: 2,
                 child: _buildModernTextField(
                   label: 'Cantidad *',
                   controller: _ingredientQuantityControllers[index],
                   hintText: 'Ej: 2',
                   icon: Icons.straighten,
                   keyboardType: TextInputType.number,
                   isRequired: true,
                   validator: (value) {
                     if (value == null || value.isEmpty) {
                       return 'La cantidad es obligatoria';
                     }
                     final quantity = int.tryParse(value);
                     if (quantity == null || quantity <= 0) {
                       return 'Debe ser un número entero mayor a 0';
                     }
                     return null;
                   },
                 ),
               ),
               const SizedBox(width: 16),
               Expanded(
                 flex: 2,
                 child: _buildUnitDropdown(index),
               ),
             ],
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildUnitDropdown(int index) {
  final currentValue = _ingredientUnitControllers[index].text.isNotEmpty
      ? _ingredientUnitControllers[index].text
      : null;
  final isCompleted = currentValue != null && currentValue.isNotEmpty;
  
  // Crear lista única de unidades
  final uniqueUnits = _commonUnits.toSet().toList();
  
  // Verificar que el valor actual esté en la lista
  final validValue = uniqueUnits.contains(currentValue) ? currentValue : null;
  
  return DropdownButtonFormField<String>(
    value: validValue, // Usar validValue en lugar de currentValue
    decoration: InputDecoration(
      labelText: 'Unidad *',
      prefixIcon: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCompleted 
              ? AppTheme.successGreen.withOpacity(0.1)
              : AppTheme.coralMain.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isCompleted ? Icons.check : Icons.scale, 
          color: isCompleted ? AppTheme.successGreen : AppTheme.coralMain, 
          size: 20,
        ),
      ),
      suffixIcon: Container(
        margin: const EdgeInsets.all(12),
        child: Icon(
          isCompleted ? Icons.check_circle : Icons.circle_outlined,
          color: isCompleted ? AppTheme.successGreen : AppTheme.mediumGrey,
          size: 20,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isCompleted ? AppTheme.successGreen : const Color(0xFFE5E7EB),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isCompleted ? AppTheme.successGreen : const Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.coralMain, width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.all(16),
    ),
    isExpanded: true,
    hint: const Text('Seleccionar unidad'),
    items: uniqueUnits.map((unit) {
      return DropdownMenuItem(
        value: unit,
        child: Text(
          unit,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList(),
    onChanged: (value) {
      if (value != null) {
        setState(() {
          _ingredientUnitControllers[index].text = value;
          _validateForm();
        });
      }
    },
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'La unidad es obligatoria';
      }
      return null;
    },
  );
}

 Widget _buildEmptyStepsState() {
   return Center(
     child: Padding(
       padding: const EdgeInsets.all(40),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Container(
             padding: const EdgeInsets.all(24),
             decoration: BoxDecoration(
               color: AppTheme.coralMain.withOpacity(0.1),
               shape: BoxShape.circle,
             ),
             child: Icon(
               Icons.format_list_numbered,
               size: 48,
               color: AppTheme.coralMain,
             ),
           ),
           const SizedBox(height: 24),
           const Text(
             'No hay pasos definidos',
             style: TextStyle(
               fontSize: 20,
               fontWeight: FontWeight.bold,
               color: Color(0xFF1A1D29),
             ),
           ),
           const SizedBox(height: 8),
           Text(
             'Describe paso a paso cómo\npreparar tu receta',
             textAlign: TextAlign.center,
             style: TextStyle(
               fontSize: 16,
               color: AppTheme.mediumGrey,
               height: 1.5,
             ),
           ),
           const SizedBox(height: 32),
           ElevatedButton.icon(
             onPressed: _addStep,
             icon: const Icon(Icons.add),
             label: const Text('Añadir primer paso'),
             style: ElevatedButton.styleFrom(
               backgroundColor: AppTheme.coralMain,
               foregroundColor: Colors.white,
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(16),
               ),
               elevation: 0,
             ),
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildStepCard2(int index) {
   final stepContent = _stepControllers[index].text.trim();
   final isComplete = stepContent.isNotEmpty && stepContent.length >= 10;
   
   return Container(
     margin: const EdgeInsets.only(bottom: 20),
     decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(16),
       border: Border.all(
         color: isComplete ? AppTheme.successGreen : const Color(0xFFE5E7EB),
         width: isComplete ? 2 : 1,
       ),
       boxShadow: const [
         BoxShadow(
           color: Color(0x08000000),
           blurRadius: 20,
           offset: Offset(0, 4),
         ),
       ],
     ),
     child: Padding(
       padding: const EdgeInsets.all(20),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               Container(
                 width: 40,
                 height: 40,
                 decoration: BoxDecoration(
                   color: isComplete ? AppTheme.successGreen : AppTheme.coralMain,
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Center(
                   child: isComplete 
                       ? const Icon(Icons.check, color: Colors.white, size: 20)
                       : Text(
                           '${index + 1}',
                           style: const TextStyle(
                             color: Colors.white,
                             fontWeight: FontWeight.bold,
                             fontSize: 16,
                           ),
                         ),
                 ),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       'Paso ${index + 1}',
                       style: TextStyle(
                         fontSize: 18,
                         fontWeight: FontWeight.bold,
                         color: isComplete ? AppTheme.successGreen : const Color(0xFF1A1D29),
                       ),
                     ),
                     if (stepContent.isNotEmpty && stepContent.length < 10)
                       Text(
                         'Necesita más detalles (mín. 10 caracteres)',
                         style: TextStyle(
                           fontSize: 12,
                           color: AppTheme.errorRed,
                         ),
                       ),
                   ],
                 ),
               ),
               if (_steps.length > 1)
                 GestureDetector(
                   onTap: () => _removeStep(index),
                   child: Container(
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(
                       color: AppTheme.errorRed.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Icon(
                       Icons.delete_outline,
                       color: AppTheme.errorRed,
                       size: 20,
                     ),
                   ),
                 ),
             ],
           ),
           const SizedBox(height: 16),
           TextFormField(
             controller: _stepControllers[index],
             maxLines: 4,
             decoration: InputDecoration(
               hintText: 'Describe detalladamente este paso... (mínimo 10 caracteres) *',
               border: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(12),
                 borderSide: BorderSide(
                   color: isComplete ? AppTheme.successGreen : const Color(0xFFE5E7EB),
                 ),
               ),
               enabledBorder: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(12),
                 borderSide: BorderSide(
                   color: isComplete ? AppTheme.successGreen : const Color(0xFFE5E7EB),
                 ),
               ),
               focusedBorder: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(12),
                 borderSide: BorderSide(color: AppTheme.coralMain, width: 2),
               ),
               filled: true,
               fillColor: const Color(0xFFFAFAFA),
               contentPadding: const EdgeInsets.all(16),
             ),
             validator: (value) {
               if (value == null || value.trim().isEmpty) {
                 return 'La descripción del paso es obligatoria';
               }
               if (value.trim().length < 10) {
                 return 'El paso debe tener al menos 10 caracteres';
               }
               return null;
             },
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildBottomNavigation() {
   return Container(
     padding: const EdgeInsets.all(20),
     decoration: const BoxDecoration(
       color: Colors.white,
       boxShadow: [
         BoxShadow(
           color: Color(0x0A000000),
           blurRadius: 20,
           offset: Offset(0, -4),
         ),
       ],
     ),
     child: SafeArea(
       top: false,
       child: Row(
         children: [
           if (_currentStep > 0)
             Expanded(
               child: OutlinedButton.icon(
                 onPressed: _previousStep,
                 icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                 label: const Text('Anterior'),
                 style: OutlinedButton.styleFrom(
                   foregroundColor: AppTheme.coralMain,
                   side: BorderSide(color: AppTheme.coralMain),
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(16),
                   ),
                 ),
               ),
             ),
           if (_currentStep > 0) const SizedBox(width: 16),
           Expanded(
             flex: _currentStep == 0 ? 1 : 2,
             child: _currentStep < 3
                 ? ElevatedButton.icon(
                     onPressed: _nextStep,
                     icon: const Icon(Icons.arrow_forward_ios, size: 16),
                     label: const Text('Siguiente'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppTheme.coralMain,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(vertical: 16),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(16),
                       ),
                       elevation: 0,
                     ),
                   )
                 : Row(
                     children: [
                       Expanded(
                         child: OutlinedButton.icon(
                           onPressed: _showPreview,
                           icon: const Icon(Icons.visibility, size: 16),
                           label: const Text('Vista previa'),
                           style: OutlinedButton.styleFrom(
                             foregroundColor: AppTheme.coralMain,
                             side: BorderSide(color: AppTheme.coralMain),
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(16),
                             ),
                           ),
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         flex: 2,
                         child: ElevatedButton.icon(
                           onPressed: _isFormValid ? _saveRecipe : null,
                           icon: Icon(
                             _isFormValid ? Icons.save : Icons.warning_rounded, 
                             size: 16,
                           ),
                           label: Text(_isEditMode ? 'Actualizar' : 'Guardar'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: _isFormValid 
                                 ? AppTheme.successGreen 
                                 : AppTheme.mediumGrey,
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(16),
                             ),
                             elevation: _isFormValid ? 2 : 0,
                           ),
                         ),
                       ),
                     ],
                   ),
           ),
         ],
       ),
     ),
   );
 }

 // Métodos de navegación
 void _nextStep() {
   if (_currentStep < 3) {
     _pageController.nextPage(
       duration: const Duration(milliseconds: 300),
       curve: Curves.easeInOut,
     );
   }
 }

 void _previousStep() {
   if (_currentStep > 0) {
     _pageController.previousPage(
       duration: const Duration(milliseconds: 300),
       curve: Curves.easeInOut,
     );
   }
 }

 // Métodos de acción
 void _addIngredient() {
   setState(() {
     _ingredients.add(_createEmptyIngredient());
     
     final nameController = TextEditingController();
     final quantityController = TextEditingController();
     final unitController = TextEditingController();
     
     nameController.addListener(_validateForm);
     quantityController.addListener(_validateForm);
     unitController.addListener(_validateForm);
     
     _ingredientNameControllers.add(nameController);
     _ingredientQuantityControllers.add(quantityController);
     _ingredientUnitControllers.add(unitController);
   });
 }

 void _removeIngredient(int index) {
   if (_ingredients.length > 1) {
     setState(() {
       _ingredients.removeAt(index);
       _ingredientNameControllers[index].dispose();
       _ingredientQuantityControllers[index].dispose();
       _ingredientUnitControllers[index].dispose();
       _ingredientNameControllers.removeAt(index);
       _ingredientQuantityControllers.removeAt(index);
       _ingredientUnitControllers.removeAt(index);
       _validateForm();
     });
   }
 }

 void _addStep() {
   setState(() {
     _steps.add('');
     final stepController = TextEditingController();
     stepController.addListener(_validateForm);
     _stepControllers.add(stepController);
   });
 }

 void _removeStep(int index) {
   if (_steps.length > 1) {
     setState(() {
       _steps.removeAt(index);
       _stepControllers[index].dispose();
       _stepControllers.removeAt(index);
       _validateForm();
     });
   }
 }

 void _showPreview() {
   if (!_isFormValid) {
     _showFormValidationError();
     return;
   }

   final recipe = _buildRecipeFromForm();
   
   showModalBottomSheet(
     context: context,
     isScrollControlled: true,
     backgroundColor: Colors.transparent,
     builder: (context) => DraggableScrollableSheet(
       initialChildSize: 0.9,
       minChildSize: 0.5,
       maxChildSize: 0.95,
       builder: (context, scrollController) => Container(
         decoration: const BoxDecoration(
           color: Color(0xFFF8F9FA),
           borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
         ),
         child: Column(
           children: [
             Container(
               margin: const EdgeInsets.symmetric(vertical: 12),
               width: 40,
               height: 4,
               decoration: BoxDecoration(
                 color: const Color(0xFFE5E7EB),
                 borderRadius: BorderRadius.circular(2),
               ),
             ),
             Container(
               padding: const EdgeInsets.all(20),
               decoration: const BoxDecoration(
                 color: Colors.white,
                 border: Border(
                   bottom: BorderSide(color: Color(0xFFE5E7EB)),
                 ),
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   const Text(
                     'Vista Previa',
                     style: TextStyle(
                       fontSize: 24,
                       fontWeight: FontWeight.bold,
                       color: Color(0xFF1A1D29),
                     ),
                   ),
                   IconButton(
                     onPressed: () => Navigator.pop(context),
                     icon: Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: const Color(0xFFF3F4F6),
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: const Icon(Icons.close, size: 20),
                     ),
                   ),
                 ],
               ),
             ),
             Expanded(
               child: SingleChildScrollView(
                 controller: scrollController,
                 padding: const EdgeInsets.all(20),
                 child: _buildRecipePreview(recipe),
               ),
             ),
           ],
         ),
       ),
     ),
   );
 }

 Widget _buildRecipePreview(Recipe recipe) {
   return Container(
     decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(20),
       boxShadow: const [
         BoxShadow(
           color: Color(0x08000000),
           blurRadius: 20,
           offset: Offset(0, 4),
         ),
       ],
     ),
     child: Padding(
       padding: const EdgeInsets.all(24),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           if (recipe.imageUrl.isNotEmpty) ...[
             ClipRRect(
               borderRadius: BorderRadius.circular(16),
               child: Image.network(
                 recipe.imageUrl,
                 height: 200,
                 width: double.infinity,
                 fit: BoxFit.cover,
                 errorBuilder: (context, error, stackTrace) => Container(
                   height: 200,
                   decoration: BoxDecoration(
                     color: const Color(0xFFF3F4F6),
                     borderRadius: BorderRadius.circular(16),
                   ),
                   child: const Center(
                     child: Icon(
                       Icons.broken_image_rounded,
                       size: 48,
                       color: Color(0xFF9CA3AF),
                     ),
                   ),
                 ),
               ),
             ),
             const SizedBox(height: 24),
           ],
           
           Text(
             recipe.name,
             style: const TextStyle(
               fontSize: 28,
               fontWeight: FontWeight.bold,
               color: Color(0xFF1A1D29),
             ),
           ),
           const SizedBox(height: 12),
           
           Text(
             recipe.description,
             style: const TextStyle(
               fontSize: 16,
               color: Color(0xFF6B7280),
               height: 1.6,
             ),
           ),
           const SizedBox(height: 24),
           
           Container(
             padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(
               color: const Color(0xFFFAFAFA),
               borderRadius: BorderRadius.circular(16),
             ),
             child: Row(
               children: [
                 Expanded(
                   child: _buildInfoItem(
                     Icons.timer_rounded,
                     '${(recipe.preparationTime ?? 0) + (recipe.cookingTime ?? 0)} min',
                     'Tiempo total',
                   ),
                 ),
                 Container(
                   width: 1,
                   height: 40,
                   color: const Color(0xFFE5E7EB),
                 ),
                 Expanded(
                   child: _buildInfoItem(
                     Icons.people_alt_rounded,
                     '${recipe.servings ?? 0}',
                     'Porciones',
                   ),
                 ),
                 Container(
                   width: 1,
                   height: 40,
                   color: const Color(0xFFE5E7EB),
                 ),
                 Expanded(
                   child: _buildInfoItem(
                     Icons.trending_up_rounded,
                     _getDifficultyDisplayName(recipe.difficulty),
                     'Dificultad',
                   ),
                 ),
               ],
             ),
           ),
           
           if (recipe.categories.isNotEmpty) ...[
             const SizedBox(height: 32),
             const Text(
               'Categorías',
               style: TextStyle(
                 fontSize: 20,
                 fontWeight: FontWeight.bold,
                 color: Color(0xFF1A1D29),
               ),
             ),
             const SizedBox(height: 12),
             Wrap(
               spacing: 8,
               runSpacing: 8,
               children: recipe.categories.map((category) => Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(
                   color: AppTheme.coralMain.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: AppTheme.coralMain.withOpacity(0.3)),
                 ),
                 child: Text(
                   category,
                   style: TextStyle(
                     color: AppTheme.coralMain,
                     fontWeight: FontWeight.w600,
                     fontSize: 14,
                   ),
                 ),
               )).toList(),
             ),
           ],
           
           const SizedBox(height: 32),
           const Text(
             'Ingredientes',
             style: TextStyle(
               fontSize: 20,
               fontWeight: FontWeight.bold,
               color: Color(0xFF1A1D29),
             ),
           ),
           const SizedBox(height: 16),
           Container(
             padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(
               color: const Color(0xFFFAFAFA),
               borderRadius: BorderRadius.circular(16),
             ),
             child: Column(
               children: recipe.ingredients.map((ingredient) => Padding(
                 padding: const EdgeInsets.only(bottom: 12),
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
                     const SizedBox(width: 16),
                     Expanded(
                       child: Text(
                         '${ingredient.quantity.round()} ${ingredient.unit} ${ingredient.name}'.trim(),
                         style: const TextStyle(
                           fontSize: 16,
                           color: Color(0xFF374151),
                           height: 1.5,
                         ),
                       ),
                     ),
                   ],
                 ),
               )).toList(),
             ),
           ),
           
           const SizedBox(height: 32),
           const Text(
             'Preparación',
             style: TextStyle(
               fontSize: 20,
               fontWeight: FontWeight.bold,
               color: Color(0xFF1A1D29),
             ),
           ),
           const SizedBox(height: 16),
           ...recipe.steps.asMap().entries.map((entry) {
             final index = entry.key;
             final step = entry.value;
             return Container(
               margin: const EdgeInsets.only(bottom: 20),
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: const Color(0xFFFAFAFA),
                 borderRadius: BorderRadius.circular(16),
               ),
               child: Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Container(
                     width: 32,
                     height: 32,
                     decoration: BoxDecoration(
                       color: AppTheme.coralMain,
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Center(
                       child: Text(
                         '${index + 1}',
                         style: const TextStyle(
                           color: Colors.white,
                           fontWeight: FontWeight.bold,
                           fontSize: 14,
                         ),
                       ),
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Text(
                       step,
                       style: const TextStyle(
                         fontSize: 16,
                         color: Color(0xFF374151),
                         height: 1.6,
                       ),
                     ),
                   ),
                 ],
               ),
             );
           }),
         ],
       ),
     ),
   );
 }

 Widget _buildInfoItem(IconData icon, String value, String label) {
   return Column(
     children: [
       Icon(icon, color: AppTheme.coralMain, size: 24),
       const SizedBox(height: 8),
       Text(
         value,
         style: const TextStyle(
           fontSize: 16,
           fontWeight: FontWeight.bold,
           color: Color(0xFF1A1D29),
         ),
       ),
       Text(
         label,
         style: const TextStyle(
           fontSize: 12,
           color: Color(0xFF6B7280),
         ),
       ),
     ],
   );
 }

 void _showFormValidationError() {
   final List<String> missingFields = [];
   
   if (!(_fieldCompletionStatus['name'] ?? false)) {
     missingFields.add('Nombre de la receta (mín. 3 caracteres)');
   }
   if (!(_fieldCompletionStatus['description'] ?? false)) {
     missingFields.add('Descripción (mín. 10 caracteres)');
   }
   if (!(_fieldCompletionStatus['preparationTime'] ?? false)) {
     missingFields.add('Tiempo de preparación');
   }
   if (!(_fieldCompletionStatus['cookingTime'] ?? false)) {
     missingFields.add('Tiempo de cocción');
   }
   if (!(_fieldCompletionStatus['servings'] ?? false)) {
     missingFields.add('Número de porciones');
   }
   if (!(_fieldCompletionStatus['ingredients'] ?? false)) {
     missingFields.add('Al menos un ingrediente completo');
   }
   if (!(_fieldCompletionStatus['steps'] ?? false)) {
     missingFields.add('Al menos un paso de preparación (mín. 10 caracteres)');
   }

   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
       backgroundColor: Colors.white,
       title: Row(
         children: [
           Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: AppTheme.errorRed.withOpacity(0.1),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Icon(Icons.warning_rounded, color: AppTheme.errorRed),
           ),
           const SizedBox(width: 16),
           const Expanded(
             child: Text(
               'Formulario incompleto',
               style: TextStyle(
                 fontSize: 20,
                 fontWeight: FontWeight.bold,
                 color: Color(0xFF1A1D29),
               ),
             ),
           ),
         ],
       ),
       content: Container(
         constraints: const BoxConstraints(maxHeight: 300),
         child: SingleChildScrollView(
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Text(
                 'Para guardar la receta, completa los siguientes campos:',
                 style: TextStyle(
                   fontSize: 16,
                   color: Color(0xFF6B7280),
                   height: 1.5,
                 ),
               ),
               const SizedBox(height: 16),
               ...missingFields.map((field) => Padding(
                 padding: const EdgeInsets.only(bottom: 8),
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Container(
                       margin: const EdgeInsets.only(top: 6),
                       width: 6,
                       height: 6,
                       decoration: BoxDecoration(
                         color: AppTheme.errorRed,
                         shape: BoxShape.circle,
                       ),
                     ),
                     const SizedBox(width: 12),
                     Expanded(
                       child: Text(
                         field,
                         style: TextStyle(
                           fontSize: 14,
                           color: AppTheme.errorRed,
                           height: 1.4,
                         ),
                       ),
                     ),
                   ],
                 ),
               )),
             ],
           ),
         ),
       ),
       actions: [
         ElevatedButton(
           onPressed: () => Navigator.of(context).pop(),
           style: ElevatedButton.styleFrom(
             backgroundColor: AppTheme.coralMain,
             foregroundColor: Colors.white,
             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             elevation: 0,
           ),
           child: const Text(
             'Entendido',
             style: TextStyle(fontWeight: FontWeight.w600),
           ),
         ),
       ],
     ),
   );
 }

 Future<void> _saveRecipe() async {
   if (!_isFormValid) {
     _showFormValidationError();
     return;
   }

   setState(() => _isLoading = true);

   try {
     // Crear la receta
     final recipe = _buildRecipeFromForm();
     
     // Generar información nutricional con IA
     final recipeWithNutrition = await _generateNutritionalInfo(recipe);
     
     String? result;

     if (_isEditMode) {
       final success = await _recipeService.updateRecipe(recipeWithNutrition);
       result = success ? recipeWithNutrition.id : null;
     } else {
       result = await _recipeService.addRecipe(recipeWithNutrition);
     }

     if (result != null && mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Row(
             children: [
               Icon(Icons.check_circle, color: Colors.white),
               const SizedBox(width: 12),
               Text(
                 _isEditMode 
                     ? 'Receta actualizada' 
                     : 'Receta creada'
               ),
             ],
           ),
           backgroundColor: AppTheme.successGreen,
           behavior: SnackBarBehavior.floating,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
           action: SnackBarAction(
             label: 'Ver recetas',
             textColor: Colors.white,
             onPressed: () {
               Navigator.pushNamedAndRemoveUntil(
                 context, 
                 Routes.recipes, 
                 (route) => false,
               );
             },
           ),
         ),
       );

       Future.delayed(const Duration(milliseconds: 500), () {
         if (mounted) {
           Navigator.pop(context, true);
         }
       });
     } else {
       throw Exception('No se pudo guardar la receta');
     }
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error al guardar la receta: $e'),
           backgroundColor: AppTheme.errorRed,
           behavior: SnackBarBehavior.floating,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
         ),
       );
     }
   } finally {
     if (mounted) {
       setState(() => _isLoading = false);
     }
   }
 }
 
 // Método para generar información nutricional con IA
 Future<Recipe> _generateNutritionalInfo(Recipe recipe) async {
   try {
     setState(() => _isGeneratingNutrition = true);
     
     // Crear prompt para la IA
     final nutritionPrompt = '''
     Analiza esta receta y proporciona información nutricional estimada por porción:
     
     Receta: ${recipe.name}
     Porciones: ${recipe.servings}
     
     Ingredientes:
     ${recipe.ingredients.map((ing) => '- ${ing.quantity.round()} ${ing.unit} ${ing.name}').join('\n')}
     
     Proporciona SOLO un JSON con esta estructura exacta:
     {
       "calories": número_entero_de_calorías_por_porción,
       "protein": gramos_de_proteína_por_porción,
       "carbs": gramos_de_carbohidratos_por_porción,
       "fats": gramos_de_grasas_por_porción,
       "fiber": gramos_de_fibra_por_porción,
       "sugar": gramos_de_azúcar_por_porción,
       "sodium": miligramos_de_sodio_por_porción
     }
     
     IMPORTANTE: Todos los valores deben ser números enteros realistas.
     ''';
     
     final nutritionInfo = await _geminiService.generateNutritionalInfo(nutritionPrompt);
     
     // Si la IA generó información nutricional, usarla; si no, usar valores por defecto
     int calories = 300; // Valor por defecto
     Map<String, dynamic> nutrition = {};
     
     if (nutritionInfo != null && nutritionInfo.isNotEmpty) {
       calories = nutritionInfo['calories'] ?? 300;
       nutrition = Map<String, dynamic>.from(nutritionInfo);
     }
     
     return recipe.copyWith(
       calories: calories,
       nutrition: nutrition,
     );
   } catch (e) {
     print('Error generando información nutricional: $e');
     // Si hay error, devolver la receta con valores por defecto
     return recipe.copyWith(
       calories: 300,
       nutrition: {},
     );
   } finally {
     setState(() => _isGeneratingNutrition = false);
   }
 }

 Recipe _buildRecipeFromForm() {
   final List<RecipeIngredient> ingredients = [];
   for (int i = 0; i < _ingredientNameControllers.length; i++) {
     final name = _ingredientNameControllers[i].text.trim();
     final quantityText = _ingredientQuantityControllers[i].text.trim();
     final unit = _ingredientUnitControllers[i].text.trim();

     if (name.isNotEmpty && quantityText.isNotEmpty && unit.isNotEmpty) {
       final quantity = int.tryParse(quantityText) ?? 1;
       ingredients.add(RecipeIngredient(
         name: name,
         quantity: quantity.toDouble(),
         unit: unit,
       ));
     }
   }

   final List<String> steps = [];
   for (final controller in _stepControllers) {
     final step = controller.text.trim();
     if (step.isNotEmpty) {
       steps.add(step);
     }
   }

   return Recipe(
     id: _isEditMode ? widget.recipeToEdit!.id : '',
     name: _nameController.text.trim(),
     description: _descriptionController.text.trim(),
     imageUrl: _imageUrlController.text.trim(),
     preparationTime: int.tryParse(_preparationTimeController.text) ?? 15,
     cookingTime: int.tryParse(_cookingTimeController.text) ?? 30,
     servings: int.tryParse(_servingsController.text) ?? 4,
     difficulty: _selectedDifficulty,
     categories: _selectedCategories,
     ingredients: ingredients,
     steps: steps,
     calories: 300, // Será calculado por la IA
     nutrition: const {},
     createdAt: _isEditMode ? widget.recipeToEdit!.createdAt : DateTime.now(),
     updatedAt: DateTime.now(),
   );
 }

 Future<void> _showDeleteConfirmation() async {
   final confirmed = await showDialog<bool>(
     context: context,
     builder: (context) => AlertDialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
       backgroundColor: Colors.white,
       title: Row(
         children: [
           Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: AppTheme.warningOrange.withOpacity(0.1),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange),
           ),
           const SizedBox(width: 16),
           const Text(
             'Eliminar receta',
             style: TextStyle(
               fontSize: 20,
               fontWeight: FontWeight.bold,
               color: Color(0xFF1A1D29),
             ),
           ),
         ],
       ),
       content: Padding(
         padding: const EdgeInsets.symmetric(vertical: 8),
         child: Text(
           '¿Estás seguro de que deseas eliminar "${widget.recipeToEdit?.name ?? 'esta receta'}"? Esta acción no se puede deshacer.',
           style: const TextStyle(
             height: 1.6,
             fontSize: 16,
             color: Color(0xFF6B7280),
           ),
         ),
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).pop(false),
           style: TextButton.styleFrom(
             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
           ),
           child: const Text(
             'Cancelar',
             style: TextStyle(
               color: Color(0xFF6B7280),
               fontWeight: FontWeight.w600,
             ),
           ),
         ),
         ElevatedButton(
           onPressed: () => Navigator.of(context).pop(true),
           style: ElevatedButton.styleFrom(
             backgroundColor: AppTheme.errorRed,
             foregroundColor: Colors.white,
             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             elevation: 0,
           ),
           child: const Text(
             'Eliminar',
             style: TextStyle(fontWeight: FontWeight.w600),
           ),
         ),
       ],
     ),
   );

   if (confirmed == true && _isEditMode && widget.recipeToEdit != null) {
     setState(() => _isLoading = true);
     
     try {
       final success = await _recipeService.deleteRecipe(widget.recipeToEdit!.id);
       
       if (success && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Row(
               children: [
                 Icon(Icons.check_circle, color: Colors.white),
                 const SizedBox(width: 12),
                 const Text('Receta eliminada correctamente'),
               ],
             ),
             backgroundColor: AppTheme.successGreen,
             behavior: SnackBarBehavior.floating,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
           ),
         );
         
         Navigator.pop(context, true);
       } else {
         throw Exception('No se pudo eliminar la receta');
       }
     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Error al eliminar la receta: $e'),
             backgroundColor: AppTheme.errorRed,
             behavior: SnackBarBehavior.floating,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
           ),
         );
       }
     } finally {
       if (mounted) {
         setState(() => _isLoading = false);
       }
     }
   }
 }

 String _getDifficultyDisplayName(DifficultyLevel difficulty) {
   switch (difficulty) {
     case DifficultyLevel.easy:
       return 'Fácil';
     case DifficultyLevel.medium:
       return 'Medio';
     case DifficultyLevel.hard:
       return 'Difícil';
   }
 }

 String _getDifficultyLabel(DifficultyLevel difficulty) {
   switch (difficulty) {
     case DifficultyLevel.easy:
       return 'Fácil';
     case DifficultyLevel.medium:
       return 'Medio';
     case DifficultyLevel.hard:
       return 'Difícil';
   }
 }
}