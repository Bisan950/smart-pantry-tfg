// lib/screens/inventory/expiry_control_screen.dart - ACTUALIZADO CON NOTIFICACIONES

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../models/expiry_settings_model.dart';
import '../../services/inventory_service.dart';
import '../../services/expiry_settings_service.dart';
import '../../services/inventory_monitor_service.dart'; // NUEVO
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/inventory/expiry_alert.dart';
import '../../utils/snackbar_utils.dart';
import 'product_detail_screen.dart';

class ExpiryControlScreen extends StatefulWidget {
  const ExpiryControlScreen({super.key});

  @override
  State<ExpiryControlScreen> createState() => _ExpiryControlScreenState();
}

class _ExpiryControlScreenState extends State<ExpiryControlScreen> 
    with SingleTickerProviderStateMixin {
  final InventoryService _inventoryService = InventoryService();
  final ExpirySettingsService _settingsService = ExpirySettingsService();
  final InventoryMonitorService _monitorService = InventoryMonitorService(); // NUEVO
  late TabController _tabController;
  
  late Future<List<Product>> _expiringProductsFuture = Future.value([]);
  late Future<List<Product>> _expiredProductsFuture = Future.value([]);
  late Future<ExpirySettings> _settingsFuture;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _settingsFuture = _settingsService.getSettings();
    _initializeData();
    _initializeMonitorService(); // NUEVO
  }
  
  // NUEVO: Inicializar el servicio de monitoreo
  Future<void> _initializeMonitorService() async {
    try {
      await _monitorService.initialize();
      print('✅ Servicio de monitoreo inicializado en ExpiryControlScreen');
    } catch (e) {
      print('Error al inicializar servicio de monitoreo: $e');
    }
  }
  
  Future<void> _initializeData() async {
    try {
      final settings = await _settingsFuture;
      
      if (mounted) {
        setState(() {
          _expiringProductsFuture = _inventoryService.getExpiringProducts(settings.warningDays);
          _expiredProductsFuture = _inventoryService.getExpiredProducts();
        });
      }
    } catch (e) {
      print('Error al inicializar datos: $e');
      if (mounted) {
        setState(() {
          _expiringProductsFuture = _inventoryService.getExpiringProducts(7);
          _expiredProductsFuture = _inventoryService.getExpiredProducts();
        });
      }
    }
  }
  
  void _refreshData() async {
    try {
      final settings = await _settingsFuture;
      
      if (mounted) {
        setState(() {
          _expiringProductsFuture = _inventoryService.getExpiringProducts(settings.warningDays);
          _expiredProductsFuture = _inventoryService.getExpiredProducts();
        });
      }
      
      // NUEVO: Forzar verificación del monitor
      await _monitorService.forceCheck();
    } catch (e) {
      print('Error al refrescar datos: $e');
      if (mounted) {
        setState(() {
          _expiringProductsFuture = _inventoryService.getExpiringProducts(7);
          _expiredProductsFuture = _inventoryService.getExpiredProducts();
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  void _navigateToProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    ).then((_) => _refreshData());
  }
  
  void _dismissProduct(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar acción'),
        content: Text('¿Qué deseas hacer con el producto ${product.name}?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _inventoryService.deleteProduct(product.id);
              _refreshData();
              
              // NUEVO: Marcar como notificado para evitar notificaciones futuras
              _monitorService.markProductAsNotified(product.id, forExpiry: true);
              
              SnackBarUtils.showError(
                context, 
                '${product.name} eliminado'
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Eliminar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              // NUEVO: Marcar como notificado para evitar spam de notificaciones
              _monitorService.markProductAsNotified(product.id, forExpiry: true);
              
              SnackBarUtils.showInfo(
                context,
                'Alerta ignorada - no recibirás más notificaciones de este producto'
              );
            },
            child: const Text('Ignorar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: CustomAppBar(
        title: 'Control de Caducidad',
        actions: [
          // NUEVO: Botón para estadísticas del monitor
          IconButton(
            icon: Icon(
              Icons.analytics_outlined,
              color: AppTheme.coralMain,
            ),
            onPressed: _showMonitorStats,
            tooltip: 'Estadísticas de Notificaciones',
          ),
          // NUEVO: Botón para forzar verificación
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: AppTheme.coralMain,
            ),
            onPressed: () async {
              SnackBarUtils.showInfo(context, 'Verificando productos...');
              await _monitorService.forceCheck();
              _refreshData();
              SnackBarUtils.showSuccess(context, 'Verificación completada');
            },
            tooltip: 'Verificar Ahora',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // NUEVO: Banner de información sobre notificaciones
            _buildNotificationBanner(),
            
            // Pestañas existentes
            Container(
              margin: const EdgeInsets.all(AppTheme.spacingMedium),
              decoration: BoxDecoration(
                color: AppTheme.pureWhite,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkGrey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.coralMain,
                  unselectedLabelColor: AppTheme.mediumGrey,
                  indicatorColor: AppTheme.coralMain,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(
                      text: 'Por caducar',
                      icon: Icon(Icons.warning_amber_rounded, size: 20),
                    ),
                    Tab(
                      text: 'Caducados',
                      icon: Icon(Icons.dangerous_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExpiringProductsTab(),
                  _buildExpiredProductsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NUEVO: Banner informativo sobre notificaciones
  Widget _buildNotificationBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingMedium,
        AppTheme.spacingSmall,
        AppTheme.spacingMedium,
        0,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.coralMain.withOpacity(0.1),
            AppTheme.coralMain.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(
          color: AppTheme.coralMain.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.coralMain.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: AppTheme.coralMain,
              size: 18,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificaciones Automáticas Activas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.coralMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Recibirás alertas automáticas sobre productos por caducar',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.coralMain.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.auto_awesome_rounded,
            color: AppTheme.coralMain.withOpacity(0.6),
            size: 16,
          ),
        ],
      ),
    );
  }

  // NUEVO: Mostrar estadísticas del monitor
  void _showMonitorStats() {
    final stats = _monitorService.getMonitorStats();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              color: AppTheme.coralMain,
            ),
            const SizedBox(width: 8),
            const Text('Estadísticas de Monitoreo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Estado del Monitor', 
                stats['isMonitoring'] ? 'Activo ✅' : 'Inactivo ❌'),
            _buildStatRow('Última Verificación de Caducidad', 
                _formatDateTime(stats['lastExpiryCheck'])),
            _buildStatRow('Última Verificación de Stock', 
                _formatDateTime(stats['lastStockCheck'])),
            _buildStatRow('Productos Notificados (Caducidad)', 
                '${stats['notifiedExpiredProducts']}'),
            _buildStatRow('Productos Notificados (Stock)', 
                '${stats['notifiedLowStockProducts']}'),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _monitorService.clearNotificationHistory();
              SnackBarUtils.showSuccess(context, 'Historial de notificaciones limpiado');
            },
            child: const Text('Limpiar Historial'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Nunca';
    
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes} minutos';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours} horas';
      } else {
        return 'Hace ${difference.inDays} días';
      }
    } catch (e) {
      return 'Error';
    }
  }

  // Métodos existentes _buildExpiringProductsTab y _buildExpiredProductsTab
  // (mantener igual que en la versión anterior)
  
  Widget _buildExpiringProductsTab() {
    return FutureBuilder<List<Product>>(
      future: _expiringProductsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.coralMain,
                  strokeWidth: 3,
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                Text(
                  'Cargando productos...',
                  style: TextStyle(
                    color: AppTheme.mediumGrey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(AppTheme.spacingLarge),
              padding: const EdgeInsets.all(AppTheme.spacingLarge),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                border: Border.all(
                  color: AppTheme.errorRed.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.errorRed,
                    size: 48,
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  Text(
                    'Error al cargar los datos',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: AppTheme.errorRed.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        final expiringProducts = snapshot.data ?? [];
        
        if (expiringProducts.isEmpty) {
          return const EmptyStateWidget(
            title: 'No hay productos por caducar',
            message: 'Todos tus productos están en buen estado • Recibirás notificaciones automáticas cuando algo esté por caducar',
            icon: Icons.check_circle_outline_rounded,
          );
        }
        
        // Ordenar productos por fecha de caducidad (más cercanos primero)
        expiringProducts.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
        
        return FutureBuilder<ExpirySettings>(
          future: _settingsFuture,
          builder: (context, settingsSnapshot) {
            final settings = settingsSnapshot.data ?? 
                ExpirySettings(userId: '', warningDays: 7, criticalDays: 3);
            
            return ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMedium,
                vertical: AppTheme.spacingSmall,
              ),
              itemCount: expiringProducts.length,
              itemBuilder: (context, index) {
                final product = expiringProducts[index];
                final isNotified = _monitorService.isProductNotified(product.id, forExpiry: true);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
                  child: Stack(
                    children: [
                      ExpiryAlert(
                        title: product.name,
                        subtitle: _buildTruncatedSubtitle(product),
                        daysUntilExpiry: product.daysUntilExpiry,
                        onTap: () => _navigateToProductDetail(product),
                        onDismiss: () => _dismissProduct(product),
                        warningDays: settings.warningDays,
                        criticalDays: settings.criticalDays,
                      ),
                      // NUEVO: Indicador de notificación enviada
                      if (isNotified)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.coralMain,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.notifications_active,
                              color: AppTheme.pureWhite,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          }
        );
      },
    );
  }

  Widget _buildExpiredProductsTab() {
    return FutureBuilder<List<Product>>(
      future: _expiredProductsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.coralMain,
                  strokeWidth: 3,
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                Text(
                  'Cargando productos...',
                  style: TextStyle(
                    color: AppTheme.mediumGrey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(AppTheme.spacingLarge),
              padding: const EdgeInsets.all(AppTheme.spacingLarge),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                border: Border.all(
                  color: AppTheme.errorRed.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.errorRed,
                    size: 48,
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  Text(
                    'Error al cargar los datos',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: AppTheme.errorRed.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        final expiredProducts = snapshot.data ?? [];
        
        if (expiredProducts.isEmpty) {
          return const EmptyStateWidget(
            title: 'No hay productos caducados',
            message: 'Todos tus productos están en buen estado o han sido retirados',
            icon: Icons.check_circle_outline_rounded,
          );
        }
        
        // Ordenar productos por fecha de caducidad (más lejanos primero)
        expiredProducts.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
        
        return FutureBuilder<ExpirySettings>(
          future: _settingsFuture,
          builder: (context, settingsSnapshot) {
            final settings = settingsSnapshot.data ?? 
                ExpirySettings(userId: '', warningDays: 7, criticalDays: 3);
            
            return ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMedium,
                vertical: AppTheme.spacingSmall,
              ),
              itemCount: expiredProducts.length,
              itemBuilder: (context, index) {
                final product = expiredProducts[index];
                final isNotified = _monitorService.isProductNotified(product.id, forExpiry: true);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
                  child: Stack(
                    children: [
                      ExpiryAlert(
                        title: product.name,
                        subtitle: _buildTruncatedSubtitle(product),
                        daysUntilExpiry: product.daysUntilExpiry,
                        onTap: () => _navigateToProductDetail(product),
                        onDismiss: () => _dismissProduct(product),
                        warningDays: settings.warningDays,
                        criticalDays: settings.criticalDays,
                      ),
                      // NUEVO: Indicador de notificación enviada
                      if (isNotified)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.notifications_active,
                              color: AppTheme.pureWhite,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          }
        );
      },
    );
  }

  // Método para construir un subtítulo truncado que evita overflow
  String _buildTruncatedSubtitle(Product product) {
    final fullSubtitle = '${product.quantity} ${product.unit} - ${product.location}';
    if (fullSubtitle.length > 35) {
      return '${fullSubtitle.substring(0, 32)}...';
    }
    return fullSubtitle;
  }
}