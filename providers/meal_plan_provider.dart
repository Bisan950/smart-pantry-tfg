// lib/providers/meal_plan_provider.dart

import 'package:flutter/foundation.dart';
import '../models/meal_plan_model.dart';
import '../services/meal_plan_service.dart';

class MealPlanProvider with ChangeNotifier {
  final MealPlanService _mealPlanService = MealPlanService();
  
  List<MealPlan> _mealPlans = [];
  bool _isLoading = false;
  String? _error;
  
  List<MealPlan> get mealPlans => _mealPlans;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Cargar planes de comida
  Future<void> loadMealPlans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _mealPlans = await _mealPlanService.getMealPlans();
    } catch (e) {
      _error = 'Error al cargar planes de comida: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Cargar planes de comida para una fecha específica
  Future<void> loadMealPlansForDate(DateTime date) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _mealPlans = await _mealPlanService.getMealPlansForDate(date);
    } catch (e) {
      _error = 'Error al cargar planes de comida para la fecha: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Añadir un plan de comida
  Future<bool> addMealPlan(MealPlan mealPlan) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final mealPlanId = await _mealPlanService.addMealPlan(mealPlan);
      if (mealPlanId != null) {
        // Actualizar lista local
        final updatedMealPlan = MealPlan(
          id: mealPlanId,
          date: mealPlan.date,
          mealTypeId: mealPlan.mealTypeId,
          recipeId: mealPlan.recipeId,
          recipe: mealPlan.recipe,
          isCompleted: mealPlan.isCompleted,
        );
        _mealPlans.add(updatedMealPlan);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Error al añadir plan de comida: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Eliminar un plan de comida
  Future<bool> deleteMealPlan(String mealPlanId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final success = await _mealPlanService.deleteMealPlan(mealPlanId);
      if (success) {
        // Actualizar lista local
        _mealPlans.removeWhere((plan) => plan.id == mealPlanId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Error al eliminar plan de comida: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Marcar un plan de comida como completado
  Future<bool> toggleMealPlanCompleted(String mealPlanId, bool isCompleted) async {
    try {
      final success = await _mealPlanService.toggleMealPlanCompleted(mealPlanId, isCompleted);
      if (success) {
        // Actualizar lista local
        final index = _mealPlans.indexWhere((plan) => plan.id == mealPlanId);
        if (index != -1) {
          _mealPlans[index] = MealPlan(
            id: _mealPlans[index].id,
            date: _mealPlans[index].date,
            mealTypeId: _mealPlans[index].mealTypeId,
            recipeId: _mealPlans[index].recipeId,
            recipe: _mealPlans[index].recipe,
            isCompleted: isCompleted,
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Error al actualizar estado del plan de comida: $e';
      return false;
    }
  }
  
  // Guardar múltiples planes de comida
  Future<bool> saveMealPlans(List<MealPlan> mealPlans) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final savedIds = await _mealPlanService.saveMealPlans(mealPlans);
      if (savedIds.isNotEmpty) {
        // Recargar planes para tener la lista actualizada
        await loadMealPlans();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Error al guardar planes de comida: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Generar planes de comida con IA
  Future<List<MealPlan>> generateMealPlanWithAI({
    required DateTime date,
    required List<String> mealTypeIds,
    String? cuisine,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final generatedPlans = await _mealPlanService.generateMealPlanWithAI(
        date: date,
        mealTypeIds: mealTypeIds,
        cuisine: cuisine,
      );
      return generatedPlans;
    } catch (e) {
      _error = 'Error al generar planes de comida con IA: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Generar planes de comida para productos por caducar
  Future<List<MealPlan>> generateMealPlanForExpiringProducts({
    required DateTime date,
    required List<String> mealTypeIds,
    int daysThreshold = 5,
    String? cuisine,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final generatedPlans = await _mealPlanService.generateMealPlanForExpiringProducts(
        date: date,
        mealTypeIds: mealTypeIds,
        daysThreshold: daysThreshold,
        cuisine: cuisine,
      );
      return generatedPlans;
    } catch (e) {
      _error = 'Error al generar planes para productos por caducar: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Obtener estadísticas del plan de comidas
  Future<Map<String, dynamic>> getMealPlanStats() async {
    try {
      return await _mealPlanService.getMealPlanStats();
    } catch (e) {
      _error = 'Error al obtener estadísticas: $e';
      return {'error': _error};
    }
  }
  
  // Depurar estado del plan de comidas
  Future<Map<String, dynamic>> debugMealPlanState() async {
    try {
      return await _mealPlanService.debugMealPlanState();
    } catch (e) {
      _error = 'Error al depurar estado: $e';
      return {'error': _error};
    }
  }
}