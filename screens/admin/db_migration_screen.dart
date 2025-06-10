// lib/screens/admin/db_migration_screen.dart

import 'package:flutter/material.dart';
import '../../tools/db_migration.dart';
import '../../config/theme.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../services/inventory_service.dart';
import '../../models/product_location_model.dart';

class DBMigrationScreen extends StatefulWidget {
  const DBMigrationScreen({super.key});

  @override
  State<DBMigrationScreen> createState() => _DBMigrationScreenState();
}

class _DBMigrationScreenState extends State<DBMigrationScreen> {
  final DBMigration _dbMigration = DBMigration();
  final InventoryService _inventoryService = InventoryService();
  
  bool _isMigrating = false;
  String _statusMessage = 'Pendiente';
  List<String> _logMessages = [];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Migración de Base de Datos',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Información sobre migraciones
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Herramienta de Migración de Datos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                    Text(
                      'Esta herramienta permite actualizar la estructura de la base de datos para añadir el campo ProductLocation a todos los productos.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16),
                        const SizedBox(width: AppTheme.spacingXSmall),
                        Expanded(
                          child: Text(
                            'Estado: $_statusMessage',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingMedium),
            
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isMigrating ? null : _startMigration,
                    icon: const Icon(Icons.system_update_alt),
                    label: const Text('Iniciar Migración'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isMigrating ? null : _testProductLocation,
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Probar ProductLocation'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMedium),
            
            // Log de migraciones
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMedium),
                      child: Text(
                        'Log de migraciones',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _isMigrating
                          ? const Center(child: CircularProgressIndicator())
                          : _logMessages.isEmpty
                              ? const Center(
                                  child: Text('No hay entradas en el log'),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                                  itemCount: _logMessages.length,
                                  itemBuilder: (context, index) {
                                    final message = _logMessages[index];
                                    final isSuccess = message.contains('✅');
                                    final isError = message.contains('❌');
                                    
                                    Color textColor = Theme.of(context).textTheme.bodyMedium!.color!;
                                    if (isSuccess) {
                                      textColor = Colors.green;
                                    } else if (isError) {
                                      textColor = Colors.red;
                                    }
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
                                      child: Text(
                                        message,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    );
                                  },
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

  void _addLogMessage(String message) {
    setState(() {
      _logMessages.add(message);
    });
  }

  // Método sincrónico para iniciar la migración
  void _startMigration() {
    _runAllMigrations();
  }

  // Método sincrónico para probar ProductLocation
  void _testProductLocation() {
    _checkProductLocation();
  }

  // Método asincrónico para ejecutar las migraciones
  Future<void> _runAllMigrations() async {
    setState(() {
      _isMigrating = true;
      _statusMessage = 'Ejecutando migraciones...';
      _logMessages = [];
    });
    
    try {
      _addLogMessage('Iniciando proceso de migración...');
      
      // 1. Migrar productLocation para productos existentes
      _addLogMessage('Migrando campo productLocation...');
      await _inventoryService.migrateExistingProductsAddProductLocation();
      _addLogMessage('✅ Campo productLocation migrado correctamente');
      
      // 2. Ejecutar todas las migraciones
      _addLogMessage('Ejecutando migraciones principales...');
      await _dbMigration.runMigrations();
      _addLogMessage('✅ Migraciones principales completadas');
      
      // 3. Verificar esquema de DB
      _addLogMessage('Verificando esquema de base de datos...');
      await _dbMigration.checkAndMigrateDBSchema();
      _addLogMessage('✅ Esquema de base de datos verificado');
      
      setState(() {
        _statusMessage = 'Completado';
        _isMigrating = false;
      });
      
      _addLogMessage('✅ Proceso de migración completado con éxito');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isMigrating = false;
      });
      
      _addLogMessage('❌ Error durante la migración: $e');
    }
  }
  
  // Método asincrónico para probar ProductLocation
  Future<void> _checkProductLocation() async {
    setState(() {
      _isMigrating = true;
      _statusMessage = 'Probando ProductLocation...';
      _logMessages = [];
    });
    
    try {
      _addLogMessage('Verificando implementación de ProductLocation...');
      
      // Obtener productos con ProductLocation.inventory
      final inventoryProducts = await _inventoryService.getProductsByAppLocation(
        ProductLocation.inventory
      );
      _addLogMessage('Productos en inventario: ${inventoryProducts.length}');
      
      // Obtener productos con ProductLocation.shoppingList
      final shoppingListProducts = await _inventoryService.getProductsByAppLocation(
        ProductLocation.shoppingList
      );
      _addLogMessage('Productos en lista de compras: ${shoppingListProducts.length}');
      
      // Obtener productos con ProductLocation.both
      final bothProducts = await _inventoryService.getProductsByAppLocation(
        ProductLocation.both
      );
      _addLogMessage('Productos en ambos lugares: ${bothProducts.length}');
      
      setState(() {
        _statusMessage = 'Prueba completada';
        _isMigrating = false;
      });
      
      _addLogMessage('✅ ProductLocation funciona correctamente');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error en prueba: $e';
        _isMigrating = false;
      });
      
      _addLogMessage('❌ Error al probar ProductLocation: $e');
    }
  }
}