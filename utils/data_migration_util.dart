// lib/utils/data_migration_util.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/recipe_service.dart';
import '../services/meal_plan_service.dart';
import '../services/firestore_service.dart';

class DataMigrationUtil {
  // Singleton para acceso global a la utilidad
  static final DataMigrationUtil _instance = DataMigrationUtil._internal();
  factory DataMigrationUtil() => _instance;
  DataMigrationUtil._internal();
  
  // Servicios
  final RecipeService _recipeService = RecipeService();
  final MealPlanService _mealPlanService = MealPlanService();
  final FirestoreService _firestoreService = FirestoreService();
  
  // Variables para seguir el progreso de migración
  bool _isMigrating = false;
  double _progress = 0.0;
  String _statusMessage = '';
  
  // Getters para el estado de migración
  bool get isMigrating => _isMigrating;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  
  // Stream para notificar cambios en el estado de migración
  final _migrationStatusController = StreamController<MigrationStatus>.broadcast();
  Stream<MigrationStatus> get migrationStatus => _migrationStatusController.stream;
  
  // Comprobar si se necesita migración
  Future<bool> needsMigration() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return false;
      
      // Verificar si existe la nueva colección de recetas
      final hasNewRecipes = await _firestoreService.collectionExists('recipes');
      
      // Si ya existe la colección de recetas, no necesita migración
      if (hasNewRecipes) return false;
      
      // Verificar si hay recetas personalizadas o planes de comida que migrar
      final hasCustomRecipes = await _firestoreService.collectionExists('custom_recipes');
      final hasMealPlans = await _firestoreService.collectionExists('mealPlans');
      
      return hasCustomRecipes || hasMealPlans;
    } catch (e) {
      print('Error al verificar necesidad de migración: $e');
      return false;
    }
  }
  
  // Método principal para migrar datos del usuario
  Future<bool> migrateUserData() async {
    if (_isMigrating) return false; // Ya hay una migración en curso
    
    try {
      _isMigrating = true;
      _progress = 0.0;
      _statusMessage = 'Iniciando migración de datos...';
      _notifyMigrationStatus();
      
      // 1. Asegurar que las colecciones existan
      _updateStatus(0.1, 'Preparando estructura de datos...');
      await _firestoreService.ensureUserCollectionsExist();
      
      // 2. Migrar recetas
      _updateStatus(0.2, 'Migrando recetas...');
      final recipeResult = await _recipeService.migrateExistingRecipes();
      
      if (!recipeResult.isSuccess) {
        _updateStatus(_progress, 'Error al migrar recetas: ${recipeResult.failedMigrations} fallos');
      } else {
        _updateStatus(0.5, 'Recetas migradas: ${recipeResult.totalRecipes}');
      }
      
      // 3. Migrar planes de comida
      _updateStatus(0.6, 'Migrando planes de comida...');
      final mealPlanResult = await _mealPlanService.migrateMealPlans();
      
      if (!mealPlanResult.isSuccess) {
        _updateStatus(_progress, 'Error al migrar planes de comida: ${mealPlanResult.message}');
      } else {
        _updateStatus(0.9, 'Planes de comida migrados: ${mealPlanResult.totalMigrated}');
      }
      
      // 4. Verificar resultados finales
      _updateStatus(1.0, 'Migración completada');
      
      // Resumen de migración
      final summary = 'Migración completada: '
          '${recipeResult.totalRecipes} recetas, '
          '${mealPlanResult.totalMigrated} planes de comida.';
      
      print(summary);
      _statusMessage = summary;
      _notifyMigrationStatus();
      
      // Esperar un momento antes de finalizar para que se pueda ver el mensaje final
      await Future.delayed(const Duration(seconds: 2));
      
      _isMigrating = false;
      _notifyMigrationStatus();
      
      return true;
    } catch (e) {
      _updateStatus(_progress, 'Error durante la migración: $e');
      print('Error general durante la migración: $e');
      
      _isMigrating = false;
      _notifyMigrationStatus();
      
      return false;
    }
  }
  
  // Método para migrar datos del usuario sin mostrar UI
  Future<bool> migrateUserDataSilently() async {
    try {
      // Verificar si necesita migración
      final needsMigrate = await needsMigration();
      if (!needsMigrate) return true; // No necesita migración
      
      print('Iniciando migración silenciosa...');
      
      // Asegurar que las colecciones existan
      await _firestoreService.ensureUserCollectionsExist();
      
      // Migrar recetas
      final recipeResult = await _recipeService.migrateExistingRecipes();
      print('Recetas migradas: ${recipeResult.totalRecipes}, Fallos: ${recipeResult.failedMigrations}');
      
      // Migrar planes de comida
      final mealPlanResult = await _mealPlanService.migrateMealPlans();
      print('Planes de comida migrados: ${mealPlanResult.totalMigrated}, Fallos: ${mealPlanResult.failedMigrations}');
      
      return recipeResult.isSuccess && mealPlanResult.isSuccess;
    } catch (e) {
      print('Error durante la migración silenciosa: $e');
      return false;
    }
  }
  
  // Método para actualizar el estado de la migración
  void _updateStatus(double progress, String message) {
    _progress = progress;
    _statusMessage = message;
    _notifyMigrationStatus();
    print('Migración: $progress - $message');
  }
  
  // Método para notificar a los oyentes del cambio de estado
  void _notifyMigrationStatus() {
    if (!_migrationStatusController.isClosed) {
      _migrationStatusController.add(MigrationStatus(
        isMigrating: _isMigrating,
        progress: _progress,
        statusMessage: _statusMessage,
      ));
    }
  }
  
  // Cerrar controlador al finalizar
  void dispose() {
    _migrationStatusController.close();
  }
}

// Clase para representar el estado de la migración
class MigrationStatus {
  final bool isMigrating;
  final double progress;
  final String statusMessage;
  
  MigrationStatus({
    required this.isMigrating,
    required this.progress,
    required this.statusMessage,
  });
}

// Widget para mostrar un diálogo de migración
class MigrationDialog extends StatelessWidget {
  final Stream<MigrationStatus> migrationStatus;
  
  const MigrationDialog({
    super.key,
    required this.migrationStatus,
  });
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildDialogContent(context),
    );
  }
  
  Widget _buildDialogContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: StreamBuilder<MigrationStatus>(
        stream: migrationStatus,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          final status = snapshot.data!;
          
          // Si la migración ha terminado, mostrar botón para cerrar
          if (!status.isMigrating && status.progress >= 1.0) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Migración completada',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(status.statusMessage),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          }
          
          // Mostrar progreso de migración
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Migrando datos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: status.progress,
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(height: 16),
              Text(
                status.statusMessage,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

// Método auxiliar para mostrar diálogo de migración
Future<void> showMigrationDialog(BuildContext context) async {
  final migrationUtil = DataMigrationUtil();
  
  // Verificar si se necesita migración
  final needsMigrate = await migrationUtil.needsMigration();
  if (!needsMigrate) return;
  
  // Mostrar diálogo de migración
  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MigrationDialog(
        migrationStatus: migrationUtil.migrationStatus,
      ),
    );
    
    // Iniciar migración
    migrationUtil.migrateUserData();
  }
}