// lib/utils/ingredients_shopping_helper.dart - Versión final corregida

import 'package:flutter/material.dart';
import '../models/recipe_model.dart';
import '../models/product_model.dart';
import '../models/product_location_model.dart';
import '../services/inventory_service.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/common/custom_button.dart';

/// Este método es una función utilitaria que podemos incluir en cualquier archivo
/// que necesite añadir ingredientes a la lista de compras, como servicios o pantallas
Future<bool> addIngredientsToShoppingList({
  required BuildContext context,
  required List<RecipeIngredient> ingredients,
  required InventoryService inventoryService,
}) async {
  try {
    // Filtrar solo los ingredientes que no están disponibles
    final missingIngredients = ingredients
      .where((ingredient) => !ingredient.isAvailable && !ingredient.isOptional)
      .toList();
    
    if (missingIngredients.isEmpty) {
      SnackBarUtils.showInfo(context, 'Todos los ingredientes ya están disponibles');
      return false;
    }
    
    // Mostrar diálogo de confirmación
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir ingredientes a lista de compras'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se añadirán ${missingIngredients.length} ingredientes a tu lista de compras:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...missingIngredients.take(5).map((ingredient) => 
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 4),
                child: Text('• ${ingredient.name}'),
              )
            ),
            if (missingIngredients.length > 5)
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 4),
                child: Text('• y ${missingIngredients.length - 5} más...'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          CustomButton(
            text: 'Añadir',
            onPressed: () => Navigator.pop(context, true),
            type: ButtonType.secondary,
          ),
        ],
      ),
    ) ?? false;
    
    if (!shouldAdd) return false;
    
    // Obtener el ID del usuario una sola vez usando el método público
    String userId;
    try {
      // Usar el método getCurrentUserId que hemos añadido a InventoryService
      userId = await inventoryService.getCurrentUserId();
    } catch (e) {
      // Si falla, mostrar error y salir
      SnackBarUtils.showError(context, 'No hay un usuario autenticado');
      return false;
    }
    
    // Añadir ingredientes a la lista de compras
    int successCount = 0;
    
    for (final ingredient in missingIngredients) {
      try {
        // Convertir cantidad a int si es posible
        int quantity = 1; // Por defecto
        
        if (ingredient.quantity is int) {
          quantity = ingredient.quantity;
        } else if (ingredient.quantity is double) {
          quantity = (ingredient.quantity as double).toInt();
        } else if (ingredient.quantity is String) {
          quantity = int.tryParse(ingredient.quantity.toString()) ?? 1;
        }
        
        // Crear un producto a partir del ingrediente
        final newProduct = Product(
          id: DateTime.now().millisecondsSinceEpoch.toString() + ingredient.name,
          name: ingredient.name,
          quantity: quantity,
          unit: ingredient.unit,
          category: 'Varios', // Categoría por defecto
          productLocation: ProductLocation.shoppingList,
          userId: userId,
          location: '',  // Campo obligatorio
          // Otros campos opcionales según tu modelo Product
          expiryDate: null,
          imageUrl: '',
          isPurchased: false, // Si existe este campo en tu modelo
        );
        
        // Añadir producto a la lista de compras
        await inventoryService.addProduct(newProduct);
        successCount++;
      } catch (e) {
        print('Error al añadir ingrediente ${ingredient.name} a la lista: $e');
      }
    }
    
    // Mostrar resultado
    if (successCount > 0) {
      SnackBarUtils.showSuccess(
        context, 
        'Se añadieron $successCount ingredientes a la lista de compras'
      );
      return true;
    } else {
      SnackBarUtils.showError(
        context, 
        'No se pudo añadir ningún ingrediente a la lista'
      );
      return false;
    }
  } catch (e) {
    SnackBarUtils.showError(context, 'Error: $e');
    return false;
  }
}