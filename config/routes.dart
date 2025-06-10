// lib/config/routes.dart - Actualizado con rutas de tickets

import 'package:flutter/material.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/inventory/add_product_screen.dart';
import '../screens/inventory/expiry_control_screen.dart';
import '../screens/recipes/recipes_screen.dart';
import '../screens/recipes/recipe_detail_screen.dart';
import '../screens/recipes/ai_recipe_generator_screen.dart';
import '../screens/recipes/manual_recipe_creation_screen.dart';
import '../screens/meal_planner/meal_planner_screen.dart';
import '../screens/meal_planner/add_to_meal_plan_screen.dart';
import '../screens/shopping_list/shopping_list_screen.dart';
import '../screens/shopping_list/ticket_capture_screen.dart';
import '../screens/shopping_list/ticket_history_screen.dart'; // NUEVA IMPORTACIÓN
import '../screens/shopping_list/ticket_detail_screen.dart'; // NUEVA IMPORTACIÓN
import '../screens/settings/settings_screen.dart';
import '../screens/settings/avatar_selection_screen.dart';
import '../screens/settings/profile_edit_screen.dart';
import '../screens/inventory/favorites_screen.dart';
import '../screens/chat/chat_bot_screen.dart';
import '../models/recipe_model.dart';
import '../models/ticket_model.dart'; // NUEVA IMPORTACIÓN

class Routes {
  // Definir rutas como constantes estáticas
  static const String welcome = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String inventory = '/inventory';
  static const String addProduct = '/add-product';
  static const String productDetail = '/product-detail';
  static const String expiryControl = '/expiry-control';
  static const String recipes = '/recipes';
  static const String recipeDetail = '/recipe-detail';
  static const String aiRecipeGenerator = '/recipes/ai-generator';
  static const String manualRecipeCreation = '/recipes/manual-creation';
  static const String mealPlanner = '/meal-planner';
  static const String addToMealPlan = '/add-to-meal-plan';
  static const String shoppingList = '/shopping-list';
  static const String ticketCapture = '/shopping-list/ticket-capture';
  static const String ticketHistory = '/shopping-list/ticket-history'; // NUEVA RUTA
  static const String ticketDetail = '/shopping-list/ticket-detail'; // NUEVA RUTA
  static const String settings = '/settings';
  static const String avatarSelection = '/settings/avatar-selection';
  static const String profileEdit = '/settings/profile-edit';
  static const String barcodeScanner = '/barcode-scanner';
  static const String favorites = '/favorites';
  static const String chatBot = '/chat-bot';
  
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Obtener el nombre de la ruta
    final String? routeName = settings.name;
    
    // Imprimir el nombre de la ruta para depuración
    print('Navegando a la ruta: $routeName');
    
    if (routeName == welcome) {
      return MaterialPageRoute(builder: (_) => const WelcomeScreen());
    } else if (routeName == login) {
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    } else if (routeName == register) {
      return MaterialPageRoute(builder: (_) => const RegisterScreen());
    } else if (routeName == dashboard) {
      return MaterialPageRoute(builder: (_) => const DashboardScreen());
    } else if (routeName == inventory) {
      return MaterialPageRoute(builder: (_) => const InventoryScreen());
    } else if (routeName == addProduct) {
      return MaterialPageRoute(builder: (_) => const AddProductScreen());
    } else if (routeName == productDetail) {
      return MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Detalle de Producto')),
          body: const Center(child: Text('Selecciona un producto para ver detalles')),
        ),
      );
    } else if (routeName == expiryControl) {
      return MaterialPageRoute(builder: (_) => const ExpiryControlScreen());
    } else if (routeName == recipes) {
      return MaterialPageRoute(builder: (_) => const RecipesScreen());
    } else if (routeName == aiRecipeGenerator) {
      return MaterialPageRoute(builder: (_) => const AIRecipeGeneratorScreen());
    } else if (routeName == manualRecipeCreation) {
      // Manejo de la ruta de creación manual de recetas
      final Recipe? recipeToEdit = settings.arguments as Recipe?;
      return MaterialPageRoute(
        builder: (_) => ManualRecipeCreationScreen(recipeToEdit: recipeToEdit),
      );
    } else if (routeName == recipeDetail) {
      final Map<String, dynamic>? args = settings.arguments as Map<String, dynamic>?;
      final String? recipeId = args?['recipeId'] as String?;
      final Recipe? recipe = args?['recipe'] as Recipe?;
      
      return MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipeId: recipeId ?? '',
          recipe: recipe,
        ),
      );
    } else if (routeName == addToMealPlan) {
      final Recipe? recipe = settings.arguments as Recipe?;
      return MaterialPageRoute(
        builder: (_) => AddToMealPlanScreen(recipe: recipe),
      );
    } else if (routeName == mealPlanner) {
      return MaterialPageRoute(builder: (_) => const MealPlannerScreen());
    } else if (routeName == shoppingList) {
      return MaterialPageRoute(builder: (_) => const ShoppingListScreen());
    } else if (routeName == ticketCapture) {
      // Análisis de tickets de compra
      return MaterialPageRoute(builder: (_) => const TicketCaptureScreen());
    } else if (routeName == ticketHistory) {
      // NUEVA RUTA: Historial de tickets
      return MaterialPageRoute(builder: (_) => const TicketHistoryScreen());
    } else if (routeName == ticketDetail) {
      // NUEVA RUTA: Detalle de ticket específico
      final TicketModel? ticket = settings.arguments as TicketModel?;
      
      if (ticket != null) {
        return MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticket: ticket),
        );
      } else {
        // Manejar el caso cuando no se pasa un ticket
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(
              child: Text(
                'No se pudo cargar el detalle del ticket',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      }
    } else if (routeName == settings) {
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    } else if (routeName == avatarSelection) {
      return MaterialPageRoute(builder: (_) => const AvatarSelectionScreen());
    } else if (routeName == profileEdit) {
      return MaterialPageRoute(builder: (_) => const ProfileEditScreen());
    } else if (routeName == favorites) {
      return MaterialPageRoute(builder: (_) => const FavoritesScreen());
    } else if (routeName == chatBot) {
      return MaterialPageRoute(builder: (_) => const ChatBotScreen());
    } else {
      // Ruta por defecto para manejar rutas no definidas
      return MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(
            child: Text('Ruta no definida para $routeName'),
          ),
        ),
      );
    }
  }
}