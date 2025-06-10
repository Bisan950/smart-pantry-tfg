// lib/widgets/settings/notification_settings_widget.dart - MEJORADO CON PERMISOS
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../services/notification_service.dart';
import '../../utils/snackbar_utils.dart';
import 'permission_status_widget.dart';

class NotificationSettingsWidget extends StatefulWidget {
  const NotificationSettingsWidget({super.key});

  @override
  State<NotificationSettingsWidget> createState() => _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState extends State<NotificationSettingsWidget> {
  final NotificationService _notificationService = NotificationService();
  
  bool _notificationsEnabled = true;
  bool _expiryNotifications = true;
  bool _stockNotifications = true;
  bool _shoppingReminders = true;
  bool _mealPlanReminders = true;
  bool _recipesSuggestions = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _expiryNotifications = prefs.getBool('expiry_notifications') ?? true;
        _stockNotifications = prefs.getBool('stock_notifications') ?? true;
        _shoppingReminders = prefs.getBool('shopping_reminders') ?? true;
        _mealPlanReminders = prefs.getBool('meal_plan_reminders') ?? true;
        _recipesSuggestions = prefs.getBool('recipe_suggestions') ?? false;
      });
    } catch (e) {
      print('Error al cargar configuraciones: $e');
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('expiry_notifications', _expiryNotifications);
      await prefs.setBool('stock_notifications', _stockNotifications);
      await prefs.setBool('shopping_reminders', _shoppingReminders);
      await prefs.setBool('meal_plan_reminders', _mealPlanReminders);
      await prefs.setBool('recipe_suggestions', _recipesSuggestions);
      
      // Actualizar el servicio de notificaciones
      await _notificationService.enableNotifications(_notificationsEnabled);
      
      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          '✅ Configuración guardada correctamente',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Error al guardar configuración: $e',
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
    return SingleChildScrollView(
      child: Column(
        children: [
          // NUEVO: Estado de permisos del sistema
          const PermissionStatusWidget(),
          
          // Configuración principal de notificaciones
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingLarge),
                  decoration: BoxDecoration(
                    color: AppTheme.coralMain.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.borderRadiusLarge),
                      topRight: Radius.circular(AppTheme.borderRadiusLarge),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: AppTheme.coralMain,
                        size: 24,
                      ),
                      const SizedBox(width: AppTheme.spacingMedium),
                      Text(
                        'Configuración de Notificaciones',
                        style: TextStyle(
                    fontSize: 14,
                    color: _notificationsEnabled 
                        ? AppTheme.coralMain.withOpacity(0.8)
                        : AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
            activeColor: AppTheme.coralMain,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String priority,
    required String frequency,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: value 
                    ? AppTheme.coralMain.withOpacity(0.1)
                    : AppTheme.lightGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: value ? AppTheme.coralMain : AppTheme.mediumGrey,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: value ? AppTheme.darkGrey : AppTheme.mediumGrey,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(priority).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getPriorityColor(priority).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          priority,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _getPriorityColor(priority),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 12,
                        color: AppTheme.mediumGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        frequency,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.mediumGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.coralMain,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: AppTheme.spacingMedium),
          _buildDivider(),
          const SizedBox(height: AppTheme.spacingMedium),
        ],
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: AppTheme.lightGrey,
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.coralMain.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppTheme.coralMain,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'alta':
        return AppTheme.errorRed;
      case 'media':
        return AppTheme.warningOrange;
      case 'baja':
        return AppTheme.successGreen;
      default:
        return AppTheme.mediumGrey;
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await _notificationService.sendCustomReminder(
        '🧪 Notificación de Prueba',
        '¡Perfecto! Las notificaciones están funcionando correctamente. Tu configuración de SmartPantry está lista.',
        payload: 'test_notification',
      );
      
      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          '📱 Notificación de prueba enviada - Revisa tu bandeja de notificaciones',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Error al enviar notificación: $e',
        );
      }
    }
  }
}
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.coralMain,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Settings
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingLarge),
                  child: Column(
                    children: [
                      // Notificaciones principales
                      _buildMainToggle(),
                      
                      if (_notificationsEnabled) ...[
                        const SizedBox(height: AppTheme.spacingLarge),
                        _buildDivider(),
                        const SizedBox(height: AppTheme.spacingLarge),
                        
                        // Configuraciones específicas
                        _buildNotificationOption(
                          title: 'Alertas de Caducidad',
                          subtitle: 'Recibe avisos cuando productos estén por caducar',
                          icon: Icons.warning_amber_rounded,
                          value: _expiryNotifications,
                          onChanged: (value) => setState(() => _expiryNotifications = value),
                          priority: 'Alta',
                          frequency: 'Cada 6 horas',
                        ),
                        
                        _buildNotificationOption(
                          title: 'Stock Bajo',
                          subtitle: 'Avisos cuando productos tengan poco stock',
                          icon: Icons.inventory_2_outlined,
                          value: _stockNotifications,
                          onChanged: (value) => setState(() => _stockNotifications = value),
                          priority: 'Media',
                          frequency: 'Cada 12 horas',
                        ),
                        
                        _buildNotificationOption(
                          title: 'Recordatorios de Compras',
                          subtitle: 'Recordatorios semanales para revisar tu lista',
                          icon: Icons.shopping_cart_outlined,
                          value: _shoppingReminders,
                          onChanged: (value) => setState(() => _shoppingReminders = value),
                          priority: 'Media',
                          frequency: 'Domingos 10:00',
                        ),
                        
                        _buildNotificationOption(
                          title: 'Planificación de Comidas',
                          subtitle: 'Recordatorios para planificar tus comidas',
                          icon: Icons.restaurant_menu_outlined,
                          value: _mealPlanReminders,
                          onChanged: (value) => setState(() => _mealPlanReminders = value),
                          priority: 'Media',
                          frequency: 'Domingos 18:00',
                        ),
                        
                        _buildNotificationOption(
                          title: 'Sugerencias de Recetas',
                          subtitle: 'Recetas sugeridas basadas en tu inventario',
                          icon: Icons.auto_awesome_outlined,
                          value: _recipesSuggestions,
                          onChanged: (value) => setState(() => _recipesSuggestions = value),
                          priority: 'Baja',
                          frequency: 'Diario',
                          isLast: true,
                        ),
                      ],
                      
                      const SizedBox(height: AppTheme.spacingLarge),
                      
                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _sendTestNotification,
                              icon: const Icon(Icons.notifications_active),
                              label: const Text('Enviar Prueba'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.coralMain,
                                side: BorderSide(color: AppTheme.coralMain),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: AppTheme.spacingMedium),
                          
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _saveSettings,
                              icon: _isLoading 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_isLoading ? 'Guardando...' : 'Guardar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.coralMain,
                                foregroundColor: AppTheme.pureWhite,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // NUEVO: Información adicional sobre funcionamiento
          Container(
            margin: const EdgeInsets.all(AppTheme.spacingMedium),
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              border: Border.all(
                color: AppTheme.mediumGrey.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.coralMain,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cómo Funcionan las Notificaciones',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.coralMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                
                _buildInfoItem(
                  icon: Icons.phone_android,
                  title: 'Con la App Abierta',
                  description: '100% de las notificaciones se entregan inmediatamente',
                ),
                
                _buildInfoItem(
                  icon: Icons.pause_circle_outline,
                  title: 'Con la App en Segundo Plano',
                  description: '95% de las notificaciones se entregan correctamente',
                ),
                
                _buildInfoItem(
                  icon: Icons.power_off,
                  title: 'Con la App Cerrada',
                  description: '70-90% dependiendo de los permisos del sistema',
                ),
                
                const SizedBox(height: AppTheme.spacingMedium),
                
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    border: Border.all(
                      color: AppTheme.successGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: AppTheme.successGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tip: Para mejores resultados, concede todos los permisos arriba y desactiva la optimización de batería para SmartPantry.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainToggle() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: _notificationsEnabled 
            ? AppTheme.coralMain.withOpacity(0.1)
            : AppTheme.lightGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(
          color: _notificationsEnabled 
              ? AppTheme.coralMain.withOpacity(0.3)
              : AppTheme.mediumGrey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _notificationsEnabled 
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            color: _notificationsEnabled ? AppTheme.coralMain : AppTheme.mediumGrey,
            size: 28,
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificaciones ${_notificationsEnabled ? "Activadas" : "Desactivadas"}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _notificationsEnabled ? AppTheme.coralMain : AppTheme.mediumGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _notificationsEnabled 
                      ? 'Recibirás notificaciones automáticas incluso con la app cerrada'
                      : 'No recibirás ninguna notificación',
                  style: TextStyle(