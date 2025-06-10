// lib/widgets/settings/permission_status_widget.dart - SIMPLIFICADO
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/notification_service.dart';

class PermissionStatusWidget extends StatefulWidget {
  const PermissionStatusWidget({super.key});

  @override
  State<PermissionStatusWidget> createState() => _PermissionStatusWidgetState();
}

class _PermissionStatusWidgetState extends State<PermissionStatusWidget> {
  final NotificationService _notificationService = NotificationService();
  Map<String, bool> _permissionStatus = {};
  List<String> _recommendations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatus();
  }

  Future<void> _loadPermissionStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _permissionStatus = _notificationService.getPermissionStatus();
      _recommendations = _notificationService.getConfigurationRecommendations();
    } catch (e) {
      print('Error al cargar estado de permisos: $e');
      // Valores por defecto en caso de error
      _permissionStatus = {
        'notifications': false,
        'battery_optimization': false,
        'exact_alarms': false,
        'ignore_battery': false,
      };
      _recommendations = ['Error al cargar configuración de permisos'];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.requestPermissionsManually();
      await _loadPermissionStatus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Permisos actualizados'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al solicitar permisos: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAllPermissions = _permissionStatus.values.every((granted) => granted);
    
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            decoration: BoxDecoration(
              color: hasAllPermissions 
                  ? AppTheme.successGreen.withOpacity(0.1)
                  : AppTheme.warningOrange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.borderRadiusLarge),
                topRight: Radius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasAllPermissions 
                      ? Icons.verified_outlined
                      : Icons.warning_amber_rounded,
                  color: hasAllPermissions 
                      ? AppTheme.successGreen
                      : AppTheme.warningOrange,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasAllPermissions 
                            ? 'Permisos Óptimos'
                            : 'Permisos Requeridos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: hasAllPermissions 
                              ? AppTheme.successGreen
                              : AppTheme.warningOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasAllPermissions 
                            ? 'Las notificaciones funcionarán correctamente'
                            : 'Algunos permisos faltan para funcionamiento óptimo',
                        style: TextStyle(
                          fontSize: 14,
                          color: (hasAllPermissions 
                                  ? AppTheme.successGreen
                                  : AppTheme.warningOrange).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          
          // Estado de permisos
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estado de Permisos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                
                ..._permissionStatus.entries.map((entry) => 
                  _buildPermissionItem(entry.key, entry.value)
                ),
                
                const SizedBox(height: AppTheme.spacingLarge),
                
                // Recomendaciones
                if (_recommendations.isNotEmpty) ...[
                  const Text(
                    'Recomendaciones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _recommendations.map((recommendation) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                recommendation.startsWith('✅') 
                                    ? Icons.check_circle_outline
                                    : Icons.info_outline,
                                size: 16,
                                color: recommendation.startsWith('✅') 
                                    ? AppTheme.successGreen
                                    : AppTheme.warningOrange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  recommendation,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingLarge),
                ],
                
                // Botón de acción
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _requestPermissions,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Solicitar Permisos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.coralMain,
                      foregroundColor: AppTheme.pureWhite,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String key, bool granted) {
    final permissionInfo = _getPermissionInfo(key);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: granted 
                  ? AppTheme.successGreen.withOpacity(0.1)
                  : AppTheme.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              granted ? Icons.check : Icons.close,
              size: 16,
              color: granted ? AppTheme.successGreen : AppTheme.errorRed,
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingMedium),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permissionInfo['title']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  permissionInfo['description']!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: granted 
                  ? AppTheme.successGreen
                  : AppTheme.errorRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              granted ? 'Concedido' : 'Faltante',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _getPermissionInfo(String key) {
    switch (key) {
      case 'notifications':
        return {
          'title': 'Notificaciones',
          'description': 'Mostrar alertas y recordatorios',
        };
      case 'battery_optimization':
        return {
          'title': 'Optimización de Batería',
          'description': 'Ejecutar en segundo plano',
        };
      case 'exact_alarms':
        return {
          'title': 'Alarmas Exactas',
          'description': 'Horarios precisos para recordatorios',
        };
      case 'ignore_battery':
        return {
          'title': 'Ignorar Ahorro de Batería',
          'description': 'Funcionamiento continuo',
        };
      default:
        return {
          'title': key,
          'description': 'Permiso del sistema',
        };
    }
  }
}